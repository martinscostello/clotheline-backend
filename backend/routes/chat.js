const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Chat = require('../models/Chat');
const Notification = require('../models/Notification');
const User = require('../models/User');

// GET / - Get my chat history
router.get('/', auth, async (req, res) => {
    try {
        let chat = await Chat.findOne({ userId: req.user.userId });
        if (!chat) {
            // Create empty chat if none exists
            chat = new Chat({ userId: req.user.userId, messages: [] });
            await chat.save();
        }
        res.json(chat);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// POST / - Send message
router.post('/', auth, async (req, res) => {
    try {
        const { text, sender, branchId } = req.body; // Accept branchId from client
        const senderRole = sender || 'user';

        let chat = await Chat.findOne({ userId: req.user.userId });
        if (!chat) {
            chat = new Chat({ userId: req.user.userId, branchId, messages: [] });
        } else if (branchId && !chat.branchId) {
            chat.branchId = branchId;
        }

        chat.messages.push({
            sender: senderRole,
            text
        });
        chat.lastUpdated = Date.now();
        await chat.save();

        // --- NOTIFICATION TRIGGERS ---
        if (senderRole === 'user') {
            // Notify Admins
            const admins = await User.find({ role: 'admin' }).select('_id');
            const adminNotifications = admins.map(admin => ({
                userId: admin._id,
                title: "New Customer Message",
                message: `User sent: "${text.substring(0, 30)}${text.length > 30 ? '...' : ''}"`,
                title: "New Customer Message",
                message: `User sent: "${text.substring(0, 30)}${text.length > 30 ? '...' : ''}"`,
                type: 'chat', // Should direct to chat
                branchId: chat.branchId // Tag with Branch
            }));
            if (adminNotifications.length > 0) {
                await Notification.insertMany(adminNotifications);
            }

            // SIMULATED ADMIN RESPONSE (For Demo)
            if (text.toLowerCase().includes('help')) {
                setTimeout(async () => {
                    chat.messages.push({
                        sender: 'admin',
                        text: "Hi there! An agent will be with you shortly. How can I help?",
                        timestamp: new Date()
                    });
                    await chat.save();

                    // Notify User of Reply
                    await new Notification({
                        userId: req.user.userId, // The original user
                        title: "New Message",
                        message: "Clotheline Support sent you a message.",
                        type: 'chat'
                    }).save();

                }, 1000);
            }

        } else if (senderRole === 'admin') {
            // If an Admin sends via this route (not typical, but possible if they login as themselves but acting on user chat?)
            // Usually Admin has a separate route or uses userId param. 
            // Assuming this route is for the currently logged in user context.
            // If admin is talking to themselves? Unlikely. 
            // Skipping this case for valid User->Admin flow primarily.
        }

        res.json(chat);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// GET /admin/:userId - Get chat for specific user (For Admin)
// Needs Admin Middleware ideally
router.get('/admin/:userId', auth, async (req, res) => {
    try {
        const chat = await Chat.findOne({ userId: req.params.userId });
        res.json(chat || { messages: [] });
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

module.exports = router;
