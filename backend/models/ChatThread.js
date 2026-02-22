const mongoose = require('mongoose');

const ChatThreadSchema = new mongoose.Schema({
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    branchId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Branch',
        required: true
    },
    status: {
        type: String,
        enum: ['open', 'picked_up', 'resolved'],
        default: 'open'
    },
    assignedToAdminId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        default: null
    },
    assignedToAdminName: {
        type: String,
        default: null
    },
    assignedAt: {
        type: Date,
        default: null
    },
    resolvedAt: {
        type: Date,
        default: null
    },
    unreadCountUser: {
        type: Number,
        default: 0
    },
    unreadCountAdmin: {
        type: Number,
        default: 0
    },
    lastMessageText: {
        type: String,
        default: ''
    },
    lastMessageAt: {
        type: Date,
        default: Date.now
    },
    createdAt: {
        type: Date,
        default: Date.now
    },
    isHiddenFromAdmin: {
        type: Boolean,
        default: false
    },
    autoResponseSent: {
        type: Boolean,
        default: false
    },
    // SLA / Performance Tracking
    firstResponseAt: {
        type: Date,
        default: null
    },
    lastAdminReplyAt: {
        type: Date,
        default: null
    },
    resolutionTime: {
        type: Number, // in minutes/seconds
        default: null
    }
});

// One thread per user per branch
ChatThreadSchema.index({ userId: 1, branchId: 1 }, { unique: true });

module.exports = mongoose.model('ChatThread', ChatThreadSchema);
