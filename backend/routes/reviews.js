const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const admin = require('../middleware/admin');
const reviewController = require('../controllers/reviewController');

// User routes
router.post('/', auth, reviewController.submitReview);
router.get('/product/:productId', reviewController.getProductReviews);

// Admin routes
router.get('/admin/all', [auth, admin], reviewController.getAllReviewsAdmin);
router.post('/admin/create-illusion', [auth, admin], reviewController.createAdminReview);
router.patch('/admin/:reviewId/toggle-visibility', [auth, admin], reviewController.toggleReviewVisibility);

module.exports = router;
