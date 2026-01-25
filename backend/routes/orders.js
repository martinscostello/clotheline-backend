const express = require('express');
const router = express.Router();
const orderController = require('../controllers/orderController');

// Helper to simulate auth if needed, but for now open
router.post('/', orderController.createOrder);
router.post('/batch-status', orderController.batchUpdateOrderStatus); // Place specific POST before generic if any (none here, but safe)
router.get('/', orderController.getAllOrders);
router.get('/user/:userId', orderController.getOrdersByUserId);
router.get('/:id', orderController.getOrderById); // [Fix] Missing ID route
router.put('/:id/status', orderController.updateOrderStatus);
router.put('/:id/exception', orderController.updateOrderException);

module.exports = router;
