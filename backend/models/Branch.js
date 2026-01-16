const mongoose = require('mongoose');

const DeliveryZoneSchema = new mongoose.Schema({
    name: { type: String, required: true },
    description: { type: String },
    radiusKm: { type: Number, required: true },
    baseFee: { type: Number, required: true },
    color: { type: String, default: '4286f4' }
});

const BranchSchema = new mongoose.Schema({
    name: { type: String, required: true }, // "Benin City", "Abuja"
    address: { type: String, required: true },
    phone: { type: String, required: true },

    // Geo Center for Delivery Calculations
    location: {
        lat: { type: Number, required: true },
        lng: { type: Number, required: true }
    },
    locationLastUpdated: { type: Date, default: Date.now },

    deliveryZones: [DeliveryZoneSchema],

    // Config
    isActive: { type: Boolean, default: true },
    isDefault: { type: Boolean, default: false }, // Fallback if no branch selected

    createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Branch', BranchSchema);
