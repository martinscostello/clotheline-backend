const express = require('express');
const router = express.Router();
const orderController = require('../controllers/orderController');
const auth = require('../middleware/auth');
const admin = require('../middleware/admin');

// Helper to simulate auth if needed, but for now open
router.post('/', auth, orderController.createOrder); // Secure order creation
router.post('/batch-status', auth, admin, orderController.batchUpdateOrderStatus);
router.get('/', auth, admin, orderController.getAllOrders); // Secure list
router.get('/user/:userId', auth, orderController.getOrdersByUserId);
router.get('/:id', auth, orderController.getOrderById);
router.put('/:id/status', auth, admin, orderController.updateOrderStatus);
router.put('/:id/exception', auth, admin, orderController.updateOrderException);
router.put('/:id/override-fee', auth, admin, orderController.overrideDeliveryFee); // New Override Route
router.put('/:id/confirm-fee', auth, orderController.confirmFeeAdjustment); // New Consent Route

module.exports = router;
