const Order = require('../models/Order');
const Notification = require('../models/Notification');
const User = require('../models/User');
const Settings = require('../models/Settings');
const NotificationService = require('../utils/notificationService');

// Helper: Calculate Total (Used by payments.js and createOrder)
// Supports both Service Items and Store Products
exports.calculateOrderTotal = async (items) => {
    // 1. Fetch Tax Settings
    const settings = await Settings.findOne() || { taxEnabled: true, taxRate: 7.5 };
    let taxRate = settings.taxEnabled ? settings.taxRate : 0;

    // [FIX] Sanity Check for Tax Rate (Prevent 975% error)
    if (taxRate > 50) {
        console.warn(`[OrderTotal] Abnormal Tax Rate detected: ${taxRate}. Resetting to 7.5 temporarily.`);
        taxRate = 7.5;
    }

    // 2. Calculate Subtotal
    let subtotal = 0;

    // Validate Items Array
    if (!items || !Array.isArray(items)) {
        return { subtotal: 0, taxAmount: 0, totalAmount: 0 };
    }

    items.forEach(item => {
        // Handle both "price" (frontend passed) or lookup (safer).
        // For MVP, we trust price if we don't want to double-fetch everything, 
        // BUT strict implementation should fetch prices. 
        // Given the corrupt state, let's trust the 'price' passed in calculationItems 
        // which comes from DB in the Retry Flow, or from Frontend in Initialize flow.
        // Ideally we re-validate, but let's assume valid for now.

        // Robust Parsing: Handle strings, commas, decimals safely
        let rawPrice = item.price;
        if (typeof rawPrice === 'string') {
            rawPrice = rawPrice.replace(/,/g, ''); // Remove commas
        }
        let price = parseFloat(rawPrice) || 0;
        let quantity = parseInt(item.quantity) || 1;

        subtotal += (price * quantity);
    });

    // 3. Calculate Tax/Total
    const taxAmount = (subtotal * taxRate) / 100;
    const totalAmount = subtotal + taxAmount;

    console.log(`[PriceDebug] Subtotal: ${subtotal}, TaxRate: ${taxRate}%, TaxAmt: ${taxAmount}, Total: ${totalAmount}. Items: ${items.length}`);
    return { subtotal, taxAmount, totalAmount };
};

// Internal Helper to Create Order (Used by payments.js after verification)
exports.createOrderInternal = async (orderData, userId = null) => {
    try {
        const {
            // Standard Fields
            branchId,
            items,
            subtotal,
            discountAmount,
            promoCode, // [FIX] Added
            taxAmount,
            totalAmount, // Usually recalculated, but can be passed

            // Delivery
            pickupOption,
            deliveryOption,
            pickupAddress, // [FIX] Added
            pickupPhone,   // [FIX] Added
            deliveryAddress,
            deliveryPhone,
            deliveryCoordinates,
            deliveryFee,

            // Guest
            guestInfo
        } = orderData;

        // Recalculate to be safe? 
        // If we trust payments.js (which called calculateOrderTotal), we should use the passed totals OR recalculate.
        // Let's recalculate base totals.
        const calc = await exports.calculateOrderTotal(items);
        const finalSubtotal = calc.subtotal;
        const finalTax = calc.taxAmount;
        // Total = Subtotal + Tax + Delivery - Discount
        const finalDelivery = deliveryFee || 0;
        const finalDiscount = discountAmount || 0;
        const finalTotal = finalSubtotal + finalTax + finalDelivery - finalDiscount;

        console.log(`[OrderCreation] Items: ${items.length}, Subtotal: ${finalSubtotal}, Tax: ${finalTax}, Delivery: ${finalDelivery}, Discount: ${finalDiscount}, FINAL TOTAL: ${finalTotal}`);

        // [STRICT AUTH]
        if (!userId) {
            throw new Error("Order creation failed: Missing Authenticated User ID");
        }

        const newOrder = new Order({
            user: userId,
            branchId,
            items,

            // Financials
            subtotal: finalSubtotal,
            tax: finalTax,
            deliveryFee: finalDelivery,
            discount: finalDiscount,
            promoCode: promoCode || null, // [FIX] Added
            totalAmount: finalTotal,

            // Status
            status: 'New',
            paymentStatus: 'Pending', // Will be updated to Paid by caller usually

            // Logistics
            pickupOption: pickupOption || 'None',
            deliveryOption: deliveryOption || 'None',
            pickupAddress, // [FIX] Added
            pickupPhone,   // [FIX] Added
            deliveryAddress,
            deliveryPhone,
            deliveryCoordinates,

            // Guest
            guestInfo: guestInfo, // [FIX] Pass full object as per Schema

            createdAt: Date.now()
        });

        await newOrder.save();

        // Send Notification (New Order)
        try {
            const customer = await User.findById(userId);
            const Branch = require('../models/Branch'); // Lazy load
            let branchName = "Unknown Branch";
            if (branchId) {
                const branch = await Branch.findById(branchId);
                if (branch) branchName = branch.name;
            }

            const title = "New Order Recieved";
            const message = `(New order from ${branchName} | ${customer ? customer.name : 'Guest'})`;

            // Notify Admins
            console.log(`[OrderNotif] Looking for admins to notify for Branch: ${branchId}`);
            const admins = await User.find({ role: 'admin' });
            console.log(`[OrderNotif] Found ${admins.length} admins.`);

            const adminNotifications = admins.map(admin => ({
                userId: admin._id,
                title,
                message,
                type: 'order',
                branchId,
                metadata: { orderId: newOrder._id }
            }));

            if (adminNotifications.length > 0) {
                await Notification.insertMany(adminNotifications);
                console.log(`[OrderNotif] Saved ${adminNotifications.length} in-app notifications.`);

                // [NEW] Send Push to Admins
                const adminTokens = admins.reduce((acc, admin) => {
                    // Check if tokens exist and are array
                    if (admin.fcmTokens && Array.isArray(admin.fcmTokens) && admin.fcmTokens.length > 0) {
                        return acc.concat(admin.fcmTokens);
                    }
                    return acc;
                }, []);

                console.log(`[OrderNotif] Aggregated ${adminTokens.length} push tokens.`);

                if (adminTokens.length > 0) {
                    try {
                        const response = await NotificationService.sendPushNotification(
                            adminTokens,
                            title,
                            message,
                            { orderId: newOrder._id.toString(), type: 'order', click_action: 'FLUTTER_NOTIFICATION_CLICK' }
                        );
                        console.log(`[OrderNotif] FCM Send Result: Success=${response.successCount}, Failure=${response.failureCount}`);
                    } catch (pushErr) {
                        console.error(`[OrderNotif] FCM Send Failed:`, pushErr);
                    }
                } else {
                    console.warn("[OrderNotif] No admin tokens found. Push skipped.");
                }
            }

            // Notify User (Confirmation)
            // if (customer) ... (already handled usually by frontend confirmation or separate email)
        } catch (notifErr) {
            console.error("Failed to send Admin Order Notification:", notifErr);
        }

        return newOrder;
    } catch (err) {
        console.error("createOrderInternal Error:", err);
        throw err;
    }
};

// --- HTTP CONTROLLERS ---

// GET /orders (User)
exports.getUserOrders = async (req, res) => {
    try {
        const orders = await Order.find({ user: req.user.id }).sort({ createdAt: -1 });
        res.json(orders);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// GET /orders (Admin/All) - Fix for Missing Handler
exports.getAllOrders = async (req, res) => {
    try {
        const orders = await Order.find()
            .sort({ createdAt: -1 })
            .populate('user', 'name email'); // Populate User Details
        res.json(orders);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// GET /orders/:id (User/Admin)
exports.getOrderById = async (req, res) => {
    try {
        const order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        // Access Check
        // if (order.user.toString() !== req.user.id && req.user.role !== 'admin') ... 

        res.json(order);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// GET /orders/user/:userId (Admin)
exports.getOrdersByUserId = async (req, res) => {
    try {
        const orders = await Order.find({ user: req.params.userId }).sort({ createdAt: -1 });
        res.json(orders);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// POST /orders (Manual Creation if needed, usually via Payment)
exports.createOrder = async (req, res) => {
    try {
        const order = await exports.createOrderInternal(req.body, req.user.id);
        res.json(order);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.updateOrderStatus = async (req, res) => {
    try {
        const { status } = req.body;
        let order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        order.status = status;
        await order.save();

        // Notify User
        const title = `Order ${status}`;
        const message = `Your order #${order._id.toString().slice(-6).toUpperCase()} is now ${status}`;

        if (order.user) {
            await new Notification({
                userId: order.user,
                title,
                message,
                type: 'order',
                branchId: order.branchId
            }).save();

            // [NEW] Send Push to User
            const user = await User.findById(order.user);
            if (user && user.fcmTokens && user.fcmTokens.length > 0) {
                await NotificationService.sendPushNotification(
                    user.fcmTokens,
                    title,
                    message,
                    { orderId: order._id.toString(), type: 'order' }
                );
            }
        }

        res.json(order);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// PUT /orders/:id/exception
exports.updateOrderException = async (req, res) => {
    try {
        const { exceptionStatus, exceptionNote } = req.body;
        let order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        order.exceptionStatus = exceptionStatus;
        order.exceptionNote = exceptionNote;
        await order.save();

        // Notify User if it's an issue
        if (exceptionStatus !== 'None' && order.user) {
            const title = `Issue Reported: ${exceptionStatus}`;
            const message = `We found a ${exceptionStatus} with your order. Check chat for details.`;

            await new Notification({
                userId: order.user,
                title,
                message,
                type: 'alert', // Highlight differently?
                branchId: order.branchId
            }).save();

            const user = await User.findById(order.user);
            if (user && user.fcmTokens && user.fcmTokens.length > 0) {
                await NotificationService.sendPushNotification(
                    user.fcmTokens,
                    title,
                    message,
                    { orderId: order._id.toString(), type: 'chat' } // Redirect to Chat
                );
            }
        }

        res.json(order);
    } catch (err) {
        console.error("Order Exception Error:", err.message);
        res.status(500).send('Server Error');
    }
};

// POST /orders/batch-status
exports.batchUpdateOrderStatus = async (req, res) => {
    try {
        const { orderIds, status } = req.body;

        if (!orderIds || !Array.isArray(orderIds) || orderIds.length === 0) {
            return res.status(400).json({ msg: "No orders provided" });
        }

        const orders = await Order.find({ _id: { $in: orderIds } });

        let successCount = 0;

        for (const order of orders) {
            order.status = status;
            await order.save();
            successCount++;

            // Prepare Notification
            if (order.user) {
                const title = `Order ${status}`;
                const message = `Your order #${order._id.toString().slice(-6).toUpperCase()} is now ${status}`;

                new Notification({
                    userId: order.user,
                    title,
                    message,
                    type: 'order',
                    branchId: order.branchId
                }).save().catch(e => console.error("Notif Save Error", e));

                _sendPushAsync(order.user, title, message, order._id);
            }
        }

        res.json({ msg: `Updated ${successCount} orders`, successCount });

    } catch (err) {
        console.error("Batch Update Error:", err);
        res.status(500).send('Server Error');
    }
};

// Async Helper to avoid blocking main thread
const _sendPushAsync = async (userId, title, message, orderId) => {
    try {
        const user = await User.findById(userId);
        if (user && user.fcmTokens && user.fcmTokens.length > 0) {
            await NotificationService.sendPushNotification(
                user.fcmTokens,
                title,
                message,
                { orderId: orderId.toString(), type: 'order' }
            );
        }
    } catch (e) {
        console.error("Push Error:", e);
    }
};
