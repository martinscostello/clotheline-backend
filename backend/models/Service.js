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
    isActive: {
        type: Boolean,
        default: true
    },
    isLocked: {
        type: Boolean,
        default: false
    },
    lockedLabel: {
        type: String, // e.g. "Coming Soon", "Under Maintenance"
        default: "Coming Soon"
    },
    // Branch Specific Availability (Top Level)
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
