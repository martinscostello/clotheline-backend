const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
        trim: true
    },
    email: {
        type: String,
        required: true,
        unique: true,
        trim: true,
        lowercase: true
    },
    password: {
        type: String,
        required: true,
        trim: true
    },
    phone: {
        type: String,
        required: true,
        trim: true
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
    // Location Preference
    preferredBranch: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Branch'
    },
    isRevoked: {
        type: Boolean,
        default: false
    },
    notificationPreferences: {
        email: { type: Boolean, default: true },
        push: { type: Boolean, default: true },
        orderUpdates: { type: Boolean, default: true },
        chatMessages: { type: Boolean, default: true },
        adminBroadcasts: { type: Boolean, default: true },
        bucketUpdates: { type: Boolean, default: true }
    },
    permissions: {
        manageCMS: { type: Boolean, default: false }, // Home, Ads, Branding
        manageOrders: { type: Boolean, default: false },
        manageServices: { type: Boolean, default: false },
        manageProducts: { type: Boolean, default: false },
        manageUsers: { type: Boolean, default: false }, // Broadcast
    },
    // Device Tokens for Notifications
    fcmTokens: [{
        type: String
    }],
    // OTP / Verification
    otp: { type: String },
    otpExpires: { type: Date },
    otpResendCount: { type: Number, default: 0 },
    otpLastSentAt: { type: Date },
    isVerified: { type: Boolean, default: false },
    createdAt: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('User', UserSchema);
