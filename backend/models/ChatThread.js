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
        enum: ['open', 'resolved'],
        default: 'open'
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
    }
});

// One thread per user per branch
ChatThreadSchema.index({ userId: 1, branchId: 1 }, { unique: true });

module.exports = mongoose.model('ChatThread', ChatThreadSchema);
