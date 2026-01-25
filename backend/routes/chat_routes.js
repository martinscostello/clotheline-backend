const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const ChatThread = require('../models/ChatThread');
const ChatMessage = require('../models/ChatMessage');
const Notification = require('../models/Notification');
const User = require('../models/User');
const Broadcast = require('../models/Broadcast');


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
        const { threadId, messageText, orderId, clientMessageId } = req.body;
        const thread = await ChatThread.findById(threadId);
        if (!thread) return res.status(404).json({ msg: 'Thread not found' });

        // Idempotency Check
        if (clientMessageId) {
            const existing = await ChatMessage.findOne({
                threadId,
                senderId: req.user.id,
                clientMessageId
            });
            if (existing) return res.json(existing);
        }

        const user = await User.findById(req.user.id);
        const isAdmin = user.role === 'admin';

        if (!isAdmin && thread.userId.toString() !== req.user.id) {
            return res.status(403).json({ msg: 'Access denied' });
        }

        const newMessage = new ChatMessage({
            threadId,
            senderType: isAdmin ? 'admin' : 'user',
            senderId: req.user.id,
            messageText,
            orderId: orderId || null,
            clientMessageId: clientMessageId || null
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

                // Fetch Branch Name for context
                const Branch = require('../models/Branch');
                let branchName = "Unknown Branch";
                if (thread.branchId) {
                    const branch = await Branch.findById(thread.branchId);
                    if (branch) branchName = branch.name;
                }
                const senderName = req.user.name || "Customer";

                const adminNotifications = admins.map(adm => ({
                    userId: adm._id,
                    title: "New Message",
                    message: `(New Message from ${branchName} | ${senderName})`,
                    type: 'chat',
                    branchId: thread.branchId,
                    metadata: { threadId: thread._id }
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

// GET /admin/thread-for-user - Admin finding or creating thread for specific customer
router.get('/admin/thread-for-user', auth, async (req, res) => {
    try {
        const { userId, branchId } = req.query;
        if (!userId || !branchId) return res.status(400).json({ msg: 'User ID and Branch ID are required' });

        const adminUser = await User.findById(req.user.id);
        if (adminUser.role !== 'admin') return res.status(403).json({ msg: 'Admins only' });

        let thread = await ChatThread.findOne({ userId, branchId });
        if (!thread) {
            thread = new ChatThread({ userId, branchId });
            await thread.save();
        }
        res.json(thread);
    } catch (err) {
        console.error(err.message);
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

// POST /admin/broadcast - Send message to all/selected users in branch
router.post('/admin/broadcast', auth, async (req, res) => {
    try {
        const { branchId, messageText, audienceType, targetUserIds } = req.body; // audienceType: 'all' | 'selected'
        const user = await User.findById(req.user.id);
        if (user.role !== 'admin') return res.status(403).json({ msg: 'Admins only' });

        if (!branchId || !messageText) return res.status(400).json({ msg: 'Branch ID and Message are required' });

        // 1. Identify Target Users
        let finalUserIds = [];
        if (audienceType === 'selected' && targetUserIds) {
            finalUserIds = targetUserIds;
        } else {
            // "All" = Everyone who has a thread in this branch OR has interacted?
            // Let's target all users who have an existing ChatThread for this branch
            const threads = await ChatThread.find({ branchId }).select('userId');
            finalUserIds = threads.map(t => t.userId);
        }

        if (finalUserIds.length === 0) return res.status(200).json({ msg: 'No target users found', count: 0 });

        // 2. Save Broadcast Record
        const broadcast = new Broadcast({
            adminId: req.user.id,
            branchId,
            messageText,
            targetUserIds: finalUserIds,
            audienceType
        });
        await broadcast.save();

        // 3. Insert ChatMessage entries for each user thread
        // This makes it appear in their history
        for (const targetUserId of finalUserIds) {
            let thread = await ChatThread.findOne({ userId: targetUserId, branchId });
            if (!thread) {
                thread = new ChatThread({ userId: targetUserId, branchId });
            }

            const newMessage = new ChatMessage({
                threadId: thread._id,
                senderType: 'admin',
                senderId: req.user.id,
                messageText: `📢 ANNOUNCEMENT: ${messageText}`,
                isRead: false
            });
            await newMessage.save();

            thread.lastMessageText = `📢 ${messageText}`;
            thread.lastMessageAt = Date.now();
            thread.unreadCountUser += 1;
            await thread.save();

            // 4. Send Push Notification
            try {
                await new Notification({
                    userId: targetUserId,
                    title: "Announcement",
                    message: messageText,
                    type: 'chat',
                    branchId: branchId
                }).save();
            } catch (e) { }
        }

        res.json({ msg: 'Broadcast sent', count: finalUserIds.length });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

module.exports = router;
