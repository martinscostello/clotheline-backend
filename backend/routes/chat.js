const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const ChatThread = require('../models/ChatThread');
const ChatMessage = require('../models/ChatMessage');
const Notification = require('../models/Notification');
const User = require('../models/User');

// GET / - Get or Create thread for User + Branch
router.get('/', auth, async (req, res) => {
    try {
        const { branchId } = req.query;
        if (!branchId) return res.status(400).json({ msg: 'Branch ID is required' });

        let thread = await ChatThread.findOne({ userId: req.user.id, branchId });
        if (!thread) {
            thread = new ChatThread({ userId: req.user.id, branchId });
            await thread.save();
        }
        res.json(thread);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// GET /messages/:threadId - Get message history
router.get('/messages/:threadId', auth, async (req, res) => {
    try {
        const thread = await ChatThread.findById(req.params.threadId);
        if (!thread) return res.status(404).json({ msg: 'Thread not found' });

        const user = await User.findById(req.user.id);
        if (user.role !== 'admin' && thread.userId.toString() !== req.user.id) {
            return res.status(403).json({ msg: 'Access denied' });
        }

        const messages = await ChatMessage.find({ threadId: req.params.threadId }).sort({ createdAt: 1 });

        // Reset unread count
        if (user.role === 'admin') {
            thread.unreadCountAdmin = 0;
        } else {
            thread.unreadCountUser = 0;
        }
        await thread.save();

        res.json(messages);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// POST /send - Send message
router.post('/send', auth, async (req, res) => {
    try {
        const { threadId, messageText } = req.body;
        const thread = await ChatThread.findById(threadId);
        if (!thread) return res.status(404).json({ msg: 'Thread not found' });

        const user = await User.findById(req.user.id);
        const isAdmin = user.role === 'admin';

        if (!isAdmin && thread.userId.toString() !== req.user.id) {
            return res.status(403).json({ msg: 'Access denied' });
        }

        const newMessage = new ChatMessage({
            threadId,
            senderType: isAdmin ? 'admin' : 'user',
            senderId: req.user.id,
            messageText
        });

        await newMessage.save();

        thread.lastMessageText = messageText;
        thread.lastMessageAt = Date.now();
        if (isAdmin) {
            thread.unreadCountUser += 1;
        } else {
            thread.unreadCountAdmin += 1;
        }
        await thread.save();

        // Push Alert
        try {
            if (!isAdmin) {
                const admins = await User.find({ role: 'admin' }).select('_id');
                const adminNotifications = admins.map(adm => ({
                    userId: adm._id,
                    title: "New Message",
                    message: "New message from customer",
                    type: 'chat',
                    branchId: thread.branchId
                }));
                if (adminNotifications.length > 0) await Notification.insertMany(adminNotifications);
            } else {
                await new Notification({
                    userId: thread.userId,
                    title: "Support Replied",
                    message: "New message from support",
                    type: 'chat',
                    branchId: thread.branchId
                }).save();
            }
        } catch (e) { }

        res.json(newMessage);
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

// ADMIN Routes
router.get('/admin/threads', auth, async (req, res) => {
    try {
        const { branchId, status } = req.query;
        const user = await User.findById(req.user.id);
        if (user.role !== 'admin') return res.status(403).json({ msg: 'Admins only' });

        const query = { branchId };
        if (status && status !== 'All') query.status = status.toLowerCase();

        const threads = await ChatThread.find(query)
            .populate('userId', 'name email')
            .sort({ lastMessageAt: -1 });
        res.json(threads);
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

router.put('/admin/status/:threadId', auth, async (req, res) => {
    try {
        const { status } = req.body;
        const user = await User.findById(req.user.id);
        if (user.role !== 'admin') return res.status(403).json({ msg: 'Admins only' });

        const thread = await ChatThread.findById(req.params.threadId);
        if (!thread) return res.status(404).json({ msg: 'Thread not found' });

        thread.status = status;
        await thread.save();
        res.json(thread);
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

module.exports = router;
