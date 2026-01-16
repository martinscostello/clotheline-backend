const Order = require('../models/Order');
const Notification = require('../models/Notification');
const User = require('../models/User'); // For finding admins
const Branch = require('../models/Branch'); // [New]

const Settings = require('../models/Settings');

exports.createOrder = async (req, res) => {
    try {
        const {
            items,
            branchId, // New Field
            // totalAmount, // Recalculate on server for security
            pickupOption, deliveryOption,
            pickupAddress, pickupPhone,
            deliveryAddress, deliveryPhone,
            guestInfo
        } = req.body;

        // 1. Fetch Tax Settings
        const settings = await Settings.findOne() || { taxEnabled: true, taxRate: 7.5 };

        // 2. Calculate Totals
        let subtotal = 0;
        items.forEach(item => {
            subtotal += (item.price * item.quantity);
        });

        let taxRate = 0;
        let taxAmount = 0;

        if (settings.taxEnabled) {
            taxRate = settings.taxRate;
            taxAmount = Math.round(subtotal * (taxRate / 100));
        }

        const totalAmount = subtotal + taxAmount;

        // [New] Fetch Branch for Coordinate Snapshot
        let branchCenterCoordinates = null;
        if (branchId) {
            const branch = await Branch.findById(branchId);
            if (branch && branch.location) {
                branchCenterCoordinates = {
                    lat: branch.location.lat,
                    lng: branch.location.lng
                };
            }
        }

        const newOrder = new Order({
            user: req.user ? req.user.id : null,
            branchId,
            branchCenterCoordinates, // [New]
            guestInfo,
            items,
            subtotal,
            taxRate,
            taxAmount,
            totalAmount,
            pickupOption,
            deliveryOption,
            pickupAddress,
            pickupPhone,
            deliveryAddress,
            deliveryPhone
        });

        const order = await newOrder.save();

        // --- NOTIFICATION TRIGGERS ---

        // 1. Notify User (if logged in)
        if (req.user && req.user.id) {
            await new Notification({
                userId: req.user.id,
                title: "Order Placed",
                message: `Order #${order._id.toString().slice(-6).toUpperCase()} is awaiting confirmation.`,
                type: 'order',
                branchId: order.branchId // Tag with Branch
            }).save();
        }

        // 2. Notify Admins
        const admins = await User.find({ role: 'admin' }).select('_id');

        let branchName = "Online";
        if (branchId) {
            const b = await Branch.findById(branchId);
            if (b) branchName = b.name;
        }

        const adminNotifications = admins.map(admin => ({
            userId: admin._id,
            title: `New Order · ${branchName}`, // [Branch Name]
            message: `New order #${order._id.toString().slice(-6).toUpperCase()} received. Amount: ₦${totalAmount.toLocaleString()}`,
            type: 'order',
            branchId: order.branchId
        }));
        if (adminNotifications.length > 0) {
            await Notification.insertMany(adminNotifications);
        }

        res.json(order);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.getAllOrders = async (req, res) => {
    try {
        const orders = await Order.find().sort({ date: -1 });
        res.json(orders);
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

        const oldStatus = order.status;
        order.status = status;
        await order.save();

        // --- NOTIFICATION TRIGGERS ---
        if (order.user) { // Only notify if it's a registered user
            let title = "";
            let message = "";
            const orderRef = `#${order._id.toString().slice(-6).toUpperCase()}`;

            if (status === 'InProgress' && oldStatus === 'New') {
                title = "Order Confirmed";
                message = `Your order ${orderRef} is being processed.`;
            } else if (status === 'Ready') {
                if (order.pickupOption === 'Pickup') {
                    title = "Order Ready";
                    message = `Your order ${orderRef} is ready for pickup!`;
                } else {
                    title = "Order Ready";
                    message = `Your order ${orderRef} is ready for delivery.`;
                }
            } else if (status === 'Completed') {
                if (order.pickupOption === 'Pickup') {
                    title = "Order Picked Up";
                    message = `Thank you! Order ${orderRef} has been picked up.`;
                } else {
                    title = "Order Delivered";
                    message = `Order ${orderRef} has been delivered. Enjoy!`;
                }
            } else if (status === 'Cancelled') {
                title = "Order Cancelled";
                message = `Your order ${orderRef} has been cancelled. Contact support for details.`;
            }

            if (title && message) {
                await new Notification({
                    userId: order.user,
                    title,
                    message,
                    type: 'order',
                    branchId: order.branchId // Tag with Branch
                }).save();
            }
        }

        res.json(order);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};
