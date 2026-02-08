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
    isOutOfStock: { type: Boolean, default: false },

    // [STRICT BRANCH OWNERSHIP]
    // Every product belongs to exactly ONE branch.
    branchId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Branch',
        required: true
    },

    // [NEW] Marketing Sales Banner
    salesBanner: {
        isEnabled: { type: Boolean, default: false },
        style: { type: Number, default: 1 }, // 1 to 6
        primaryColor: { type: String, default: '#7C4DFF' }, // Deep Purple
        secondaryColor: { type: String, default: '#FFD600' }, // Yellow
        accentColor: { type: String, default: '#2979FF' }, // Blue
        primaryText: { type: String, default: 'SPECIAL SALE' },
        secondaryText: { type: String, default: 'UP TO' },
        discountText: { type: String, default: '50% OFF' }
    }
}, { timestamps: true });

module.exports = mongoose.model('Product', ProductSchema);
