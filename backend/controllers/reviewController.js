const Review = require('../models/Review');
const Product = require('../models/Product');
const Order = require('../models/Order');

// Submit a review
exports.submitReview = async (req, res) => {
    try {
        const { productId, orderId, rating, comment, images } = req.body;
        const userId = req.user.id;
        const mongoose = require('mongoose');

        console.log(`[ReviewSubmit] Attempting review. User: ${userId}, Order: ${orderId}, Product: ${productId}`);

        // 1. Eligibility Check: Order must be completed
        const order = await Order.findOne({
            _id: new mongoose.Types.ObjectId(orderId),
            user: new mongoose.Types.ObjectId(userId),
            status: 'Completed'
        });

        if (!order) {
            console.log(`[ReviewSubmit] Eligibility Failed. Order not found or not completed for user.`);
            // Debug: check if order exists at all without the user/status filter
            try {
                const basicOrder = await Order.findById(orderId);
                if (basicOrder) {
                    console.log(`[ReviewSubmit] Found basic order ${orderId}. DB User: ${basicOrder.user}, DB Status: ${basicOrder.status}`);
                } else {
                    console.log(`[ReviewSubmit] Order ${orderId} not found in DB at all.`);
                }
            } catch (err) {
                console.log(`[ReviewSubmit] Error searching for basic order: ${err.message}`);
            }
            return res.status(403).json({ message: 'You can only review products from completed orders.' });
        }

        // 2. Eligibility Check: Product must be in the order
        const hasProduct = order.items.some(item => item.itemType === 'Product' && item.itemId.toString() === productId);
        if (!hasProduct) {
            return res.status(403).json({ message: 'Product not found in this order.' });
        }

        // 3. Prevent duplicate reviews for same order + product
        const existingReview = await Review.findOne({ user: userId, product: productId, order: orderId });
        if (existingReview) {
            return res.status(400).json({ message: 'You have already reviewed this product for this order.' });
        }

        // 4. Create Review
        const review = new Review({
            user: userId,
            product: productId,
            order: orderId,
            rating,
            comment,
            images
        });

        await review.save();

        // 5. Update Product Aggregates
        const reviews = await Review.find({ product: productId, isHidden: false });
        const totalReviews = reviews.length;
        const averageRating = totalReviews > 0
            ? reviews.reduce((sum, r) => sum + r.rating, 0) / totalReviews
            : 0;

        await Product.findByIdAndUpdate(productId, {
            totalReviews,
            averageRating
        });

        res.status(201).json({ message: 'Review submitted successfully', review });
    } catch (error) {
        console.error('Error submitting review:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get reviews for a product
exports.getProductReviews = async (req, res) => {
    try {
        const { productId } = req.params;
        const reviews = await Review.find({ product: productId, isHidden: false })
            .populate('user', 'name')
            .sort({ createdAt: -1 });

        // Anonymize user names (first name only)
        const anonymizedReviews = reviews.map(r => {
            const reviewObj = r.toObject();
            if (reviewObj.isAdminGenerated && reviewObj.userName) {
                // Admin-generated review - use stored name
                return reviewObj;
            }
            if (reviewObj.user && reviewObj.user.name) {
                reviewObj.user.name = reviewObj.user.name.split(' ')[0];
            }
            return reviewObj;
        });

        res.json(anonymizedReviews);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};

// Admin: Get all reviews
exports.getAllReviewsAdmin = async (req, res) => {
    try {
        const reviews = await Review.find()
            .populate('user', 'name email')
            .populate('product', 'name')
            .sort({ createdAt: -1 });
        res.json(reviews);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};

// Admin: Hide/Show review
exports.toggleReviewVisibility = async (req, res) => {
    try {
        const { reviewId } = req.params;
        const review = await Review.findById(reviewId);
        if (!review) return res.status(404).json({ message: 'Review not found' });

        review.isHidden = !review.isHidden;
        await review.save();

        // Re-calculate product aggregates
        const productId = review.product;
        const reviews = await Review.find({ product: productId, isHidden: false });
        const totalReviews = reviews.length;
        const averageRating = totalReviews > 0
            ? reviews.reduce((sum, r) => sum + r.rating, 0) / totalReviews
            : 0;

        await Product.findByIdAndUpdate(productId, {
            totalReviews,
            averageRating
        });

        res.json({ message: `Review ${review.isHidden ? 'hidden' : 'shown'} successfully`, review });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};

// Admin: Create an "illusion" review
exports.createAdminReview = async (req, res) => {
    try {
        const { productId, rating, comment, images, userName } = req.body;

        // Security: Check if user is Master Admin
        const User = require('../models/User');
        const adminUser = await User.findById(req.user.id);
        if (!adminUser || !adminUser.isMasterAdmin) {
            return res.status(403).json({ message: 'Only Master Admins can create illusion reviews.' });
        }

        const review = new Review({
            product: productId,
            rating,
            comment,
            images,
            userName: userName || 'Customer',
            isAdminGenerated: true,
            isHidden: false
        });

        await review.save();

        // Update Product Aggregates
        const reviews = await Review.find({ product: productId, isHidden: false });
        const totalReviews = reviews.length;
        const averageRating = totalReviews > 0
            ? reviews.reduce((sum, r) => sum + r.rating, 0) / totalReviews
            : 0;

        await Product.findByIdAndUpdate(productId, {
            totalReviews,
            averageRating
        });

        res.status(201).json({ message: 'Admin review created successfully', review });
    } catch (error) {
        console.error('Error creating admin review:', error);
        res.status(500).json({ message: 'Server error' });
    }
};
