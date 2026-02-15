const Order = require('../models/Order');
const Payment = require('../models/Payment');
const ChatThread = require('../models/ChatThread');
const ChatMessage = require('../models/ChatMessage');
const User = require('../models/User');

// --- ORDERS ---

exports.deleteAllOrders = async (req, res) => {
    try {
        const result = await Order.deleteMany({});
        res.json({ msg: `Cleared all orders: ${result.deletedCount} removed.` });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.deleteSpecificOrder = async (req, res) => {
    try {
        const order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        await Order.findByIdAndDelete(req.params.id);
        res.json({ msg: 'Order deleted successfully' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// --- PAYMENTS & REVENUE ---

exports.deleteAllPayments = async (req, res) => {
    try {
        const result = await Payment.deleteMany({});
        res.json({ msg: `Cleared all payments: ${result.deletedCount} removed.` });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.deleteSpecificPayment = async (req, res) => {
    try {
        const payment = await Payment.findById(req.params.id);
        if (!payment) return res.status(404).json({ msg: 'Payment not found' });

        await Payment.findByIdAndDelete(req.params.id);
        res.json({ msg: 'Payment deleted successfully' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.clearRevenueData = async (req, res) => {
    try {
        // Clearing revenue usually means clearing all successful payment records
        const result = await Payment.deleteMany({});
        res.json({ msg: `Revenue data cleared (Payments removed: ${result.deletedCount}).` });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// --- CHAT HISTORY ---

exports.clearChatHistory = async (req, res) => {
    try {
        const msgs = await ChatMessage.deleteMany({});
        const threads = await ChatThread.deleteMany({});
        res.json({
            msg: 'Chat history cleared successfully',
            stats: {
                messagesRemoved: msgs.deletedCount,
                threadsRemoved: threads.deletedCount
            }
        });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};
