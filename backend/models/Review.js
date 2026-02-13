const mongoose = require('mongoose');

const ReviewSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: false
    },
    product: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Product',
        required: true
    },
    order: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Order',
        required: false
    },
    rating: {
        type: Number,
        required: true,
        min: 1,
        max: 5
    },
    comment: {
        type: String,
        required: function () {
            return this.rating <= 3;
        }
    },
    images: [String], // Array of Cloudinary URLs
    isHidden: {
        type: Boolean,
        default: false
    },
    createdAt: {
        type: Date,
        default: Date.now
    },
    isAdminGenerated: {
        type: Boolean,
        default: false
    },
    userName: {
        type: String // Fallback for illusion reviews
    }
});

// [DISABLED] Admin-generated reviews don't need unique user/product/order constraints
// ReviewSchema.index({ user: 1, product: 1, order: 1 }, { unique: true });

module.exports = mongoose.model('Review', ReviewSchema);
