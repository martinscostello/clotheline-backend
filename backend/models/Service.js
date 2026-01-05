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
    isActive: {
        type: Boolean,
        default: true
    },
    discountPercentage: {
        type: Number,
        default: 0
    },
    discountLabel: {
        type: String // e.g. "20% OFF"
    }
});

module.exports = mongoose.model('Service', ServiceSchema);
