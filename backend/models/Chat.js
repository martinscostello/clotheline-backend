const mongoose = require('mongoose');

const ChatSchema = new mongoose.Schema({
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        unique: true // One chat thread per user for now
    },
    messages: [
        {
            sender: {
                type: String, // 'user' or 'admin'
                required: true
            },
            text: {
                type: String,
                required: true
            },
            timestamp: {
                type: Date,
                default: Date.now
            }
        }
    ],
    lastUpdated: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('Chat', ChatSchema);
