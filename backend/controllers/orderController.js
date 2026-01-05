const Order = require('../models/Order');

exports.createOrder = async (req, res) => {
    try {
        const {
            items, totalAmount,
            pickupOption, deliveryOption,
            pickupAddress, pickupPhone,
            deliveryAddress, deliveryPhone,
            guestInfo
        } = req.body;

        const newOrder = new Order({
            // user: req.user.id, // If auth middleware used
            guestInfo,
            items,
            totalAmount,
            pickupOption,
            deliveryOption,
            pickupAddress,
            pickupPhone,
            deliveryAddress,
            deliveryPhone
        });

        const order = await newOrder.save();
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

        order.status = status;
        await order.save();
        res.json(order);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};
