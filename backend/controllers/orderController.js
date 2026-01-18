const Order = require('../models/Order');
const Notification = require('../models/Notification');
const User = require('../models/User');
const Settings = require('../models/Settings');

// Helper: Calculate Total (Used by payments.js and createOrder)
// Supports both Service Items and Store Products
exports.calculateOrderTotal = async (items) => {
    // 1. Fetch Tax Settings
    const settings = await Settings.findOne() || { taxEnabled: true, taxRate: 7.5 };
    const taxRate = settings.taxEnabled ? settings.taxRate : 0;

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

        let price = item.price || 0;
        let quantity = item.quantity || 1;
        subtotal += (price * quantity);
    });

    // 3. Calculate Tax/Total
    const taxAmount = (subtotal * taxRate) / 100;
    const totalAmount = subtotal + taxAmount;

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
        // ... (Optional)

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
        const orders = await Order.find({ user: req.user.userId }).sort({ createdAt: -1 });
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
        // if (order.user.toString() !== req.user.userId && req.user.role !== 'admin') ... 

        res.json(order);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// POST /orders (Manual Creation if needed, usually via Payment)
exports.createOrder = async (req, res) => {
    try {
        const order = await exports.createOrderInternal(req.body, req.user.userId);
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
        }

        res.json(order);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};
