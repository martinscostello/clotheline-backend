const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const analyticsController = require('../controllers/analyticsController');

// All Analytics routes require Admin
// We should add an admin middleware check here ideally
router.get('/revenue', auth, analyticsController.getRevenueStats);
router.get('/top-items', auth, analyticsController.getTopItems);

module.exports = router;
