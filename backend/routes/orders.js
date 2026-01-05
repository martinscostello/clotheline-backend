const express = require('express');
const router = express.Router();
const orderController = require('../controllers/orderController');

// Helper to simulate auth if needed, but for now open
router.post('/', orderController.createOrder);
router.get('/', orderController.getAllOrders);
router.put('/:id/status', orderController.updateOrderStatus);

module.exports = router;
