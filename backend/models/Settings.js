const mongoose = require('mongoose');

const SettingsSchema = new mongoose.Schema({
    // Tax Configuration
    taxEnabled: { type: Boolean, default: true },
    taxRate: { type: Number, default: 7.5 }, // Percentage
    taxName: { type: String, default: 'VAT' },

    // Future extensible settings can go here
    updatedAt: { type: Date, default: Date.now }
});

// Singleton pattern: We essentially only need one document
module.exports = mongoose.model('Settings', SettingsSchema);
