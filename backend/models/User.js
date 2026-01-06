const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true
    },
    email: {
        type: String,
        required: true,
        unique: true
    },
    password: {
        type: String,
        required: true
    },
    phone: {
        type: String,
        required: true
    },
    role: {
        type: String,
        enum: ['user', 'admin'],
        default: 'user'
    },
    // Admin Specific Fields
    isMasterAdmin: {
        type: Boolean,
        default: false
    },
    isRevoked: {
        type: Boolean,
        default: false
    },
    permissions: {
        manageCMS: { type: Boolean, default: false }, // Home, Ads, Branding
        manageOrders: { type: Boolean, default: false },
        manageServices: { type: Boolean, default: false },
        manageProducts: { type: Boolean, default: false },
        manageUsers: { type: Boolean, default: false }, // Broadcast
    },
    createdAt: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('User', UserSchema);
