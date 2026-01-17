const mongoose = require('mongoose');

const ServiceSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true
    },
    icon: {
        type: String,
        required: true // e.g., 'dry_cleaning', 'water_drop'
    },
    color: {
        type: String,
        required: true // e.g., '#448AFF'
    },
    description: {
        type: String
    },
    image: {
        type: String,
        default: 'assets/images/service_laundry.png'
    },
    // Global State
    isActive: {
        type: Boolean,
        default: true
    },
    // Global Lock (Deprecated for Branch logic, but kept for "System Wide Lock")
    isLocked: {
        type: Boolean,
        default: false
    },
    lockedLabel: {
        type: String, // e.g. "Coming Soon", "Under Maintenance"
        default: "Coming Soon"
    },

    // [NEW] Branch Specific Configuration (The Source of Truth for Branch State)
    branchConfig: [{
        branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' },
        isActive: { type: Boolean, default: true }, // Visibility
        isLocked: { type: Boolean, default: false }, // "Coming Soon" state
        lockedLabel: { type: String, default: "Coming Soon" },
        lastUpdated: { type: Date, default: Date.now }
    }],

    // Legacy / Deprecated (Mapped to branchConfig.isActive in logic if needed)
    branchAvailability: [{
        branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' },
        isActive: { type: Boolean, default: true }
    }],

    discountPercentage: {
        type: Number,
        default: 0
    },
    discountLabel: {
        type: String // e.g. "20% OFF"
    },
    // Sub-items (Cloth Types / Product Types)
    items: [{
        name: String, // e.g. "Shirt", "Trousers"
        price: Number, // Default/Base Price
        branchPricing: [{
            branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch' },
            price: Number,
            isActive: { type: Boolean, default: true }
        }]
    }],
    // Service Variants (e.g. "Wash & Iron", "Steam Only")
    serviceTypes: [{
        name: String,
        priceMultiplier: {
            type: Number,
            default: 1.0
        }
    }]
});

module.exports = mongoose.model('Service', ServiceSchema);
