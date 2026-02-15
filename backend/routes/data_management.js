const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const User = require('../models/User');
const {
    deleteAllOrders,
    deleteSpecificOrder,
    deleteAllPayments,
    deleteSpecificPayment,
    clearRevenueData,
    clearChatHistory
} = require('../controllers/dataManagementController');

// Middleware to strictly enforce isMasterAdmin
const masterAdminOnly = async (req, res, next) => {
    try {
        const user = await User.findById(req.user.id);
        if (!user || !user.isMasterAdmin) {
            return res.status(403).json({ msg: 'Access Denied: Master Admin Only' });
        }
        next();
    } catch (err) {
        res.status(500).send('Server Error in MasterAdmin middleware');
    }
};

// All routes require auth AND master admin check
router.use(auth);
router.use(masterAdminOnly);

// Orders
router.delete('/orders/all', deleteAllOrders);
router.delete('/orders/:id', deleteSpecificOrder);

// Payments
router.delete('/payments/all', deleteAllPayments);
router.delete('/payments/:id', deleteSpecificPayment);

// Revenue
router.delete('/revenue/clear', clearRevenueData);

// Chat
router.delete('/chat/clear', clearChatHistory);

module.exports = router;
