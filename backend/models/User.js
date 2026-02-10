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
    avatarId: {
        type: String,
        default: null
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
    savedAddresses: {
        type: [{
            label: { type: String, required: true }, // "Home", "Office", "Girlfriend's House"
            addressLabel: { type: String, required: true },
            lat: { type: Number, required: true },
            lng: { type: Number, required: true },
            city: { type: String, required: true }, // Benin, Abuja
            landmark: { type: String }
        }],
        validate: [arrayLimit, '{PATH} exceeds the limit of 3']
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
    adminNotificationPreferences: {
        newOrder: { type: Boolean, default: true },
        newChat: { type: Boolean, default: true },
        systemAlerts: { type: Boolean, default: true },
        quietHoursEnabled: { type: Boolean, default: false },
        quietHoursStart: { type: String, default: '22:00' },
        quietHoursEnd: { type: String, default: '07:00' },
        subscribedBranches: [{
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Branch'
        }]
    },
    permissions: {
        manageCMS: { type: Boolean, default: false }, // Home, Ads, Branding
        manageOrders: { type: Boolean, default: false },
        manageServices: { type: Boolean, default: false },
        manageProducts: { type: Boolean, default: false },
        manageUsers: { type: Boolean, default: false }, // Broadcast
        manageChat: { type: Boolean, default: false },
        manageSettings: { type: Boolean, default: false },
        manageAdmins: { type: Boolean, default: false },
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

function arrayLimit(val) {
    return val.length <= 3;
}

module.exports = mongoose.model('User', UserSchema);
