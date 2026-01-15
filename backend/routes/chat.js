const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Chat = require('../models/Chat');

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
        const { text } = req.body;

        let chat = await Chat.findOne({ userId: req.user.userId });
        if (!chat) {
            chat = new Chat({ userId: req.user.userId, messages: [] });
        }

        chat.messages.push({
            sender: 'user',
            text
        });
        chat.lastUpdated = Date.now();

        // SIMULATED ADMIN RESPONSE (For Demo)
        // In real app, Admin would reply via Admin Panel
        if (text.toLowerCase().includes('help')) {
            setTimeout(async () => {
                chat.messages.push({
                    sender: 'admin',
                    text: "Hi there! An agent will be with you shortly. How can I help?",
                    timestamp: new Date()
                });
                await chat.save();
            }, 1000);
        }

        await chat.save();
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
