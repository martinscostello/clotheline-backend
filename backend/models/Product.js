const mongoose = require('mongoose');

const ProductSchema = new mongoose.Schema({
    name: { type: String, required: true },
    description: String,
    price: { type: Number, required: true },
    category: String,
    imageUrls: [String], // Array of image URLs
    variations: [{
        name: String,
        price: Number,
        originalPrice: Number
    }],
    isFreeShipping: { type: Boolean, default: false },
    discountPercentage: { type: Number, default: 0 },
    originalPrice: { type: Number }, // derived or set
    stock: { type: Number, default: 0 },
    soldCount: { type: Number, default: 0 },
    totalReviews: { type: Number, default: 0 },
    averageRating: { type: Number, default: 0 },
    brand: { type: String, default: "Generic" },
    legacyReviews: [{
        userName: String,
        rating: Number,
        comment: String,
        date: { type: Date, default: Date.now }
    }],
    isActive: { type: Boolean, default: true },

    // [STRICT BRANCH OWNERSHIP]
    // Every product belongs to exactly ONE branch.
    branchId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Branch',
        required: true
    }
});

module.exports = mongoose.model('Product', ProductSchema);
