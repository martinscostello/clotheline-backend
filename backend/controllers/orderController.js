const Order = require('../models/Order');
const Notification = require('../models/Notification');
const User = require('../models/User');
const Settings = require('../models/Settings');
const StoreProduct = require('../models/Product');
const NotificationService = require('../utils/notificationService');
const Service = require('../models/Service');
const mongoose = require('mongoose');

// Helper: Calculate Total (Used by payments.js and createOrder)
// Supports both Service Items and Store Products
exports.calculateOrderTotal = async (items, discount = 0) => {
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
        // Robust Parsing: Handle strings, commas, decimals safely
        let rawPrice = item.price;
        if (typeof rawPrice === 'string') {
            rawPrice = rawPrice.replace(/,/g, ''); // Remove commas
        }
        let price = parseFloat(rawPrice) || 0;
        let quantity = parseInt(item.quantity) || 1;

        subtotal += (price * quantity);
    });

    // 3. Calculate Tax/Total (Apply Discount BEFORE Tax)
    const netSubtotal = Math.max(0, subtotal - discount);
    const taxAmount = (netSubtotal * taxRate) / 100;
    const totalAmount = netSubtotal + taxAmount;

    console.log(`[PriceDebug] Subtotal: ${subtotal}, Discount: ${discount}, Net: ${netSubtotal}, TaxRate: ${taxRate}%, TaxAmt: ${taxAmount}, Total: ${totalAmount}. Items: ${items.length}`);
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
            promoCode,
            taxAmount,
            totalAmount,
            fulfillmentMode,

            // [NEW] POS Fields
            isWalkIn,
            paymentMethod,
            paymentStatus: manualPaymentStatus,

            // [New] Rich Location Support
            deliveryLocation,
            pickupLocation,
            deliveryFeeOverride,
            isFeeOverridden,

            // Logistics [FIXED: Added missing fields]
            deliveryFee,
            pickupFee,
            pickupOption,
            deliveryOption,
            pickupAddress,
            pickupPhone,
            deliveryAddress,
            deliveryPhone,
            pickupCoordinates,
            deliveryCoordinates,

            // Guest
            guestInfo,

            // [NEW] Special Care
            laundryNotes
        } = orderData;

        // [NEW] Sanitize & Validate Notes (Remove HTML/Excessive Spaces)
        let sanitizedNotes = laundryNotes;
        if (sanitizedNotes) {
            sanitizedNotes = sanitizedNotes.replace(/<[^>]*>?/gm, ''); // Remove HTML
            sanitizedNotes = sanitizedNotes.trim().substring(0, 300);
        }

        // Recalculate to be safe
        const calc = await exports.calculateOrderTotal(items);
        const finalSubtotal = calc.subtotal;
        const finalTax = calc.taxAmount;
        // Total = Subtotal + Tax + Delivery + Pickup - Discount
        const finalDelivery = Number(deliveryFee) || 0;
        const finalPickup = Number(pickupFee) || 0;
        const finalDiscount = Number(discountAmount) || 0;
        const finalTotal = finalSubtotal + finalTax + finalDelivery + finalPickup - finalDiscount;

        // [TRACKING] Log order creation attempt
        console.log(`[OrderTrigger] Creating Order for User: ${userId}, Branch: ${branchId}, Total: ${finalTotal}`);

        // [STRICT AUTH]
        // For POS/Walk-in, we allow missing userId if created by Admin
        if (!userId && !isWalkIn) {
            throw new Error("Order creation failed: Missing Authenticated User ID");
        }

        // [VISIBILITY FIX] Explicitly cast to ObjectId
        const userObjectId = (userId && !isWalkIn)
            ? ((typeof userId === 'string') ? new mongoose.Types.ObjectId(userId) : userId)
            : null;

        const adminObjectId = (isWalkIn && userId)
            ? ((typeof userId === 'string') ? new mongoose.Types.ObjectId(userId) : userId)
            : null;

        const newOrder = new Order({
            user: userObjectId,
            branchId,
            fulfillmentMode: fulfillmentMode || 'logistics',
            items: Array.isArray(items) ? items : [],

            // Financials
            subtotal: finalSubtotal,
            taxAmount: finalTax, // [FIXED] Mismatched field name
            deliveryFee: finalDelivery,
            pickupFee: finalPickup,
            discountAmount: finalDiscount, // [FIXED] Mismatched field name
            promoCode: promoCode || null,
            totalAmount: finalTotal,

            // Status
            status: 'New',
            paymentStatus: manualPaymentStatus || (isWalkIn ? 'Paid' : 'Pending'),

            // [NEW] POS Logic
            isWalkIn: isWalkIn || false,
            paymentMethod: paymentMethod || (isWalkIn ? 'cash' : 'paystack'),
            createdByAdmin: adminObjectId,

            // Logistics
            pickupOption: pickupOption || 'None',
            deliveryOption: deliveryOption || 'None',
            pickupAddress: pickupAddress || (pickupLocation ? pickupLocation.addressLabel : null),
            pickupPhone: pickupPhone || (pickupLocation ? pickupLocation.phone : null),
            deliveryAddress: deliveryAddress || (deliveryLocation ? deliveryLocation.addressLabel : null),
            deliveryPhone: deliveryPhone || (deliveryLocation ? deliveryLocation.phone : null),
            pickupCoordinates: pickupCoordinates || (pickupLocation ? { lat: pickupLocation.lat, lng: pickupLocation.lng } : null),
            deliveryCoordinates: deliveryCoordinates || (deliveryLocation ? { lat: deliveryLocation.lat, lng: deliveryLocation.lng } : null),

            // [New] Extended Location Data
            deliveryLocation,
            pickupLocation,
            deliveryFeeOverride: isFeeOverridden ? deliveryFeeOverride : null,
            isFeeOverridden: isFeeOverridden || false,

            // Guest
            guestInfo: guestInfo,

            // [NEW] Special Care
            laundryNotes: sanitizedNotes,

            createdAt: Date.now()
        });

        await newOrder.save();

        // [NEW] Update Stock Counter (Atomic Auto-OOS)
        try {
            for (const item of items) {
                if (item.itemType === 'Product' && item.itemId) {
                    const product = await StoreProduct.findByIdAndUpdate(
                        item.itemId,
                        { $inc: { stock: -item.quantity, soldCount: item.quantity } },
                        { new: true }
                    );

                    if (product && product.stock <= 0) {
                        product.isOutOfStock = true;
                        await product.save();
                        console.log(`[Inventory] Product ${product.name} automatically marked OUT OF STOCK.`);
                    }
                }
            }
        } catch (stockErr) {
            console.error("Stock Update Error:", stockErr);
        }

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
            const admins = await User.find({ role: 'admin' });

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

                // [FIX] Aggregated and Deduplicated Admin Tokens
                let adminTokensRaw = [];
                admins.forEach(admin => {
                    if (admin.fcmTokens && Array.isArray(admin.fcmTokens)) {
                        adminTokensRaw = adminTokensRaw.concat(admin.fcmTokens);
                    }
                });

                const adminTokens = [...new Set(adminTokensRaw.filter(t => t))];

                if (adminTokens.length > 0) {
                    try {
                        console.log(`[OrderNotif] Sending to ${admins.length} admins (${adminTokens.length} tokens). Order: ${newOrder._id}`);
                        const response = await NotificationService.sendPushNotification(
                            adminTokens,
                            title,
                            message,
                            { orderId: newOrder._id.toString(), type: 'order', click_action: 'FLUTTER_NOTIFICATION_CLICK' }
                        );
                        console.log(`[OrderNotif] FCM Success: ${response?.successCount || 0}/${adminTokens.length}`);
                    } catch (pushErr) {
                        console.error(`[OrderNotif] FCM Failed for Admin Push:`, pushErr);
                    }
                }
            }
        } catch (notifErr) {
            console.error("Admin Order Notification Flow Failed:", notifErr);
        }

        return newOrder;
    } catch (err) {
        console.error("createOrderInternal Error Detail:", {
            message: err.message,
            stack: err.stack,
            validationErrors: err.errors ? Object.keys(err.errors).map(k => `${k}: ${err.errors[k].message}`) : 'None'
        });
        throw err;
    }
};

// --- HTTP CONTROLLERS ---

exports.getUserOrders = async (req, res) => {
    try {
        const orders = await Order.find({ user: req.user.id }).sort({ createdAt: -1 });
        res.json(orders);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.getAllOrders = async (req, res) => {
    try {
        const orders = await Order.find()
            .sort({ createdAt: -1 })
            .populate('user', 'name email');
        res.json(orders);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.getOrderById = async (req, res) => {
    try {
        const order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });
        res.json(order);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.getOrdersByUserId = async (req, res) => {
    try {
        const orders = await Order.find({ user: req.params.userId }).sort({ createdAt: -1 });
        res.json(orders);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.createOrder = async (req, res) => {
    try {
        const order = await exports.createOrderInternal(req.body, req.user.id);
        res.json(order);
    } catch (err) {
        console.error("HTTP createOrder Error:", err.message);
        res.status(500).json({
            msg: 'Server Error',
            error: err.message,
            stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
        });
    }
};

exports.updateOrderStatus = async (req, res) => {
    try {
        const { status } = req.body;
        let order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        order.status = status;
        await order.save();

        // [TRACKING] Log status update
        console.log(`[OrderUpdate] Order ${order._id} status changed to ${status}`);

        // [MODIFIED] Custom Status Messages
        const getStatusMessage = (s, id) => {
            const shortId = id.toString().slice(-6).toUpperCase();
            switch (s) {
                case 'New': return { title: 'Order Confirmed', msg: `Your order #${shortId} has been confirmed` };
                case 'InProgress': return { title: 'Order Processing', msg: `Your order #${shortId} is now Processing` };
                case 'Ready': return { title: 'Order Ready', msg: `Your order #${shortId} is now Ready` };
                case 'Completed': return { title: 'Order Delivered', msg: `Your order #${shortId} has been Delivered` };
                case 'Cancelled': return { title: 'Order Cancelled', msg: `Your order #${shortId} has been Cancelled` };
                case 'Refunded': return { title: 'Order Refunded', msg: `Your order #${shortId} has been Refunded` };
                case 'Inspecting': return { title: 'Personnel Despatched', msg: `Our personnel have been despatched for inspection of order #${shortId}` };
                case 'PendingUserConfirmation': return { title: 'Quote Ready', msg: `A quote has been prepared for order #${shortId}. Please make payment.` };
                default: return { title: `Order ${s}`, msg: `Your order #${shortId} is now ${s}` };
            }
        };

        const statusData = getStatusMessage(status, order._id);
        const title = statusData.title;
        const message = statusData.msg;

        if (order.user) {
            await new Notification({
                userId: order.user,
                title,
                message,
                type: 'order',
                branchId: order.branchId
            }).save();

            const user = await User.findById(order.user);
            if (user && user.fcmTokens && user.fcmTokens.length > 0) {
                // notificationService handles deduplication internally now
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

exports.updateOrderException = async (req, res) => {
    try {
        const { exceptionStatus, exceptionNote } = req.body;
        let order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        order.exceptionStatus = exceptionStatus;
        order.exceptionNote = exceptionNote;
        await order.save();

        if (exceptionStatus !== 'None' && order.user) {
            const title = `Issue Reported: ${exceptionStatus}`;
            const message = `We found a ${exceptionStatus} with your order. Check chat for details.`;

            await new Notification({
                userId: order.user,
                title,
                message,
                type: 'alert',
                branchId: order.branchId
            }).save();

            const user = await User.findById(order.user);
            if (user && user.fcmTokens && Array.isArray(user.fcmTokens)) {
                await NotificationService.sendPushNotification(
                    user.fcmTokens,
                    title,
                    message,
                    { orderId: order._id.toString(), type: 'chat' }
                );
            }
        }

        res.json(order);
    } catch (err) {
        console.error("Order Exception Error:", err.message);
        res.status(500).send('Server Error');
    }
};

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

            if (order.user) {
                const getStatusMessage = (s, id) => {
                    const shortId = id.toString().slice(-6).toUpperCase();
                    switch (s) {
                        case 'New': return { title: 'Order Confirmed', msg: `Your order #${shortId} has been confirmed` };
                        case 'InProgress': return { title: 'Order Processing', msg: `Your order #${shortId} is now Processing` };
                        case 'Ready': return { title: 'Order Ready', msg: `Your order #${shortId} is now Ready` };
                        case 'Completed': return { title: 'Order Delivered', msg: `Your order #${shortId} has been Delivered` };
                        case 'Cancelled': return { title: 'Order Cancelled', msg: `Your order #${shortId} has been Cancelled` };
                        case 'Refunded': return { title: 'Order Refunded', msg: `Your order #${shortId} has been Refunded` };
                        default: return { title: `Order ${s}`, msg: `Your order #${shortId} is now ${s}` };
                    }
                };

                const statusData = getStatusMessage(status, order._id);
                const title = statusData.title;
                const message = statusData.msg;

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

const _sendPushAsync = async (userId, title, message, orderId) => {
    try {
        const user = await User.findById(userId);
        if (user && user.fcmTokens && Array.isArray(user.fcmTokens)) {
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

exports.overrideDeliveryFee = async (req, res) => {
    try {
        const { fee } = req.body;
        if (fee === undefined) return res.status(400).json({ msg: 'Fee value is required' });

        let order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        const currentFee = order.isFeeOverridden ? order.deliveryFeeOverride : (order.deliveryFee || 0);

        // [New Flow] If order is already paid and fee is increasing, require consent
        if (order.paymentStatus === 'Paid' && fee > currentFee) {
            const extra = fee - currentFee;
            order.status = 'PendingUserConfirmation';
            order.feeAdjustment = {
                amount: extra,
                status: 'Pending',
                notified: true
            };
            // Note: We don't update totalAmount yet to avoid breaking original accounting
            // The totalAmount on the record remains what was paid.
        } else {
            // Standard override (if not paid, or if decreasing/same)
            const baseTotal = order.totalAmount - currentFee;
            order.deliveryFeeOverride = fee;
            order.isFeeOverridden = true;
            order.totalAmount = baseTotal + fee;
        }

        await order.save();

        // Notify User
        if (order.user) {
            const title = "Delivery Fee Updated";
            const message = fee > currentFee && order.paymentStatus === 'Paid'
                ? `An additional delivery fee of ₦${fee - currentFee} is required for order #${order._id.toString().slice(-6).toUpperCase()}. Please confirm.`
                : `The delivery fee for your order #${order._id.toString().slice(-6).toUpperCase()} has been adjusted to ₦${fee}.`;

            await new Notification({
                userId: order.user,
                title,
                message,
                type: 'order',
                branchId: order.branchId,
                metadata: { orderId: order._id }
            }).save();

            _sendPushAsync(order.user, title, message, order._id);
        }

        res.json({ msg: 'Delivery fee adjusted', order });
    } catch (err) {
        console.error("Override Fee Error:", err);
        res.status(500).send('Server Error');
    }
};

exports.confirmFeeAdjustment = async (req, res) => {
    try {
        const { choice } = req.body; // 'PayOnDelivery' (Manual)
        let order = await Order.findById(req.params.id);

        if (!order) return res.status(404).json({ msg: 'Order not found' });
        if (order.status !== 'PendingUserConfirmation') {
            return res.status(400).json({ msg: 'Order does not require confirmation' });
        }

        if (choice === 'PayOnDelivery') {
            const extra = order.feeAdjustment.amount || 0;
            order.feeAdjustment.status = 'PayOnDelivery';
            order.status = 'New'; // Return to processing

            // Update totalAmount and delivery override even for Pay on Delivery
            // so that total reflects the full cost, even if partially paid.
            const currentFee = order.isFeeOverridden ? (order.deliveryFeeOverride || 0) : (order.deliveryFee || 0);
            order.deliveryFeeOverride = currentFee + extra;
            order.isFeeOverridden = true;
            order.totalAmount += extra;

            await order.save();

            // Notify Admins
            const title = "Fee Confirmed (On Delivery)";
            const message = `User confirmed additional ₦${order.feeAdjustment.amount} for Order #${order._id.toString().slice(-6).toUpperCase()} to be paid on delivery.`;

            const admins = await User.find({ role: 'admin' });
            admins.forEach(admin => {
                new Notification({
                    userId: admin._id,
                    title,
                    message,
                    type: 'order',
                    branchId: order.branchId,
                    metadata: { orderId: order._id }
                }).save();
            });

            return res.json({ msg: 'Confirmation recorded', order });
        }

        res.status(400).json({ msg: 'Invalid choice' });
    } catch (err) {
        console.error("Confirm Fee Error:", err);
        res.status(500).send('Server Error');
    }
};
exports.despatchOrder = async (req, res) => {
    try {
        let order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        order.status = 'Inspecting';
        await order.save();

        // [MODIFIED] Check if already notified by status watcher
        // Usually, we want one clear message for Despatch
        const shortId = order._id.toString().slice(-6).toUpperCase();
        const title = 'Personnel Despatched';
        const message = `Our personnel have been despatched for inspection of order #${shortId}`;

        if (order.user) {
            // [FIX] Use unique title to avoid duplicate confusion if status watcher fired
            await new Notification({
                userId: order.user,
                title,
                message,
                type: 'order',
                branchId: order.branchId,
                metadata: { orderId: order._id }
            }).save();

            _sendPushAsync(order.user, title, message, order._id);
        }

        res.json({ msg: 'Order status updated to Inspecting. Personnel despatched.', order });
    } catch (err) {
        console.error("Despatch Order Error:", err);
        res.status(500).send('Server Error');
    }
};

exports.adjustOrderPricing = async (req, res) => {
    try {
        const { newPrice, notes } = req.body;
        if (newPrice === undefined) return res.status(400).json({ msg: 'New price is required' });

        let order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        // Calculate new totals
        const settings = await Settings.findOne() || { taxEnabled: true, taxRate: 7.5 };
        const taxRate = settings.taxEnabled ? settings.taxRate : 0;

        // [NEW] Discount Re-validation Logic
        let discountAmount = 0;
        let discountLabel = "";

        // 1. Identify primary service for discount re-validation
        const serviceItem = order.items.find(i => i.itemType === 'Service');
        if (serviceItem) {
            const serviceDoc = await Service.findById(serviceItem.itemId);
            if (serviceDoc) {
                // Check branch-specific discount first
                const branchConf = (serviceDoc.branchConfig || []).find(b => b.branchId.toString() === order.branchId.toString());
                const activeDiscountPercent = (branchConf && branchConf.discountPercentage !== undefined)
                    ? branchConf.discountPercentage
                    : (serviceDoc.discountPercentage || 0);

                if (activeDiscountPercent > 0) {
                    discountAmount = (newPrice * activeDiscountPercent) / 100;
                    discountLabel = (branchConf && branchConf.discountLabel) ? branchConf.discountLabel : serviceDoc.discountLabel;
                    console.log(`[AdjustPricing] Re-applying ${activeDiscountPercent}% discount (₦${discountAmount})`);
                }
            }
        }

        const subtotalAfterDiscount = newPrice - discountAmount;
        const taxAmount = (subtotalAfterDiscount * taxRate) / 100;

        // Final Total = New Price + Tax + Logistics - Discounts
        order.subtotal = newPrice;
        order.discountAmount = discountAmount;
        order.discountLabel = discountLabel;
        order.taxRate = taxRate; // [FIX] Persist taxRate for frontend label
        order.taxAmount = taxAmount;
        order.totalAmount = subtotalAfterDiscount + taxAmount + (order.deliveryFee || 0) + (order.pickupFee || 0);
        order.status = 'PendingUserConfirmation';
        order.exceptionNote = notes || order.exceptionNote;

        // [STABILITY FIX] Also update the items array prices to match the new subtotal
        // This prevents "jumping" prices where logic sums items and gets a different total than subtotal.
        if (order.items && order.items.length > 0) {
            const serviceItems = order.items.filter(i => i.itemType === 'Service');
            if (serviceItems.length === 1) {
                serviceItems[0].price = newPrice;
            } else if (serviceItems.length > 1) {
                serviceItems[0].price = newPrice / serviceItems.length; // Approximate split if multiple
            }
        }

        // Prepare fee adjustment for payment tracking
        // Balance = Final Total - Inspection Fee
        const extraDue = Math.max(0, order.totalAmount - (order.inspectionFee || 0));
        order.feeAdjustment = {
            amount: extraDue,
            status: 'Pending',
            notified: true
        };

        await order.save();

        const shortId = order._id.toString().slice(-6).toUpperCase();
        const title = 'Order Pricing Updated';
        const message = `A new price of ₦${newPrice} has been set for your order #${shortId}. Please review and make payment.`;

        if (order.user) {
            await new Notification({
                userId: order.user,
                title,
                message,
                type: 'order',
                branchId: order.branchId,
                metadata: { orderId: order._id }
            }).save();

            _sendPushAsync(order.user, title, message, order._id);
        }

        res.json({ msg: 'Pricing adjusted and user notified', order });
    } catch (err) {
        console.error("Adjust Pricing Error:", err);
        res.status(500).send('Server Error');
    }
};

exports.triggerPaymentNotification = async (req, res) => {
    try {
        let order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        const shortId = order._id.toString().slice(-6).toUpperCase();
        const title = 'Payment Required';
        const message = `Please finalize payment for your order #${shortId} to proceed.`;

        if (order.user) {
            await new Notification({
                userId: order.user,
                title,
                message,
                type: 'order',
                branchId: order.branchId,
                metadata: { orderId: order._id }
            }).save();

            _sendPushAsync(order.user, title, message, order._id);
        }

        res.json({ msg: 'Payment notification sent' });
    } catch (err) {
        console.error("Trigger Payment Error:", err);
        res.status(500).send('Server Error');
    }
};

exports.convertOrderToDeployment = async (req, res) => {
    try {
        const Order = require('../models/Order');
        const order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        order.fulfillmentMode = 'deployment';
        // If it was Paid but now is deployment, it might need to be Pending for balance
        if (order.paymentStatus === 'Paid') {
            order.paymentStatus = 'Pending';
        }

        await order.save();
        res.json(order);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.markOrderAsPaid = async (req, res) => {
    try {
        const { method, reference } = req.body;
        let order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        order.paymentStatus = 'Paid';
        order.paymentMethod = method || 'other';
        if (reference) order.paymentReference = reference;

        // If it was pending adjustment, clear it
        if (order.feeAdjustment) {
            order.feeAdjustment.status = 'Paid';
        }

        await order.save();

        // Notify user
        if (order.user) {
            const shortId = order._id.toString().slice(-6).toUpperCase();
            const title = "Payment Confirmed";
            const message = `Your payment for order #${shortId} has been manually confirmed.`;

            await new Notification({
                userId: order.user,
                title,
                message,
                type: 'order',
                branchId: order.branchId,
                metadata: { orderId: order._id }
            }).save();

            _sendPushAsync(order.user, title, message, order._id);
        }

        res.json({ msg: 'Order marked as paid', order });
    } catch (err) {
        console.error("Mark as Paid Error:", err);
        res.status(500).send('Server Error');
    }
};
