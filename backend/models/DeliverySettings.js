const mongoose = require('mongoose');

const DeliveryZoneSchema = new mongoose.Schema({
    name: { type: String, required: true },
    description: { type: String },
    radiusKm: { type: Number, required: true },
    baseFee: { type: Number, required: true },
    color: { type: String, default: '4286f4' } // For UI visualization (Hex)
});

const DeliverySettingsSchema = new mongoose.Schema({
    laundryLocation: {
        lat: { type: Number, default: 6.303337 },
        lng: { type: Number, default: 5.5945522 }
    },
    freeDistanceKm: { type: Number, default: 3 },
    perKmCharge: { type: Number, default: 100 },
    zones: [DeliveryZoneSchema],
    isDistanceBillingEnabled: { type: Boolean, default: true },
    updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('DeliverySettings', DeliverySettingsSchema);
