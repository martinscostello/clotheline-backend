const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const admin = require('../middleware/admin');
const analyticsController = require('../controllers/analyticsController');

// All Analytics routes require Admin
router.get('/revenue', auth, admin, analyticsController.getRevenueStats);
router.get('/top-items', auth, admin, analyticsController.getTopItems);

module.exports = router;
