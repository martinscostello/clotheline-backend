const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const admin = require('../middleware/admin');
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

// GET /my-threads - Get all threads for current user
router.get('/my-threads', auth, async (req, res) => {
    try {
        const threads = await ChatThread.find({ userId: req.user.id })
            .populate('branchId', 'name location')
            .sort({ lastMessageAt: -1 });
        res.json(threads);
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

        const messages = await ChatMessage.find({ threadId: req.params.threadId })
            .populate('senderId', 'avatarId')
            .sort({ createdAt: 1 });

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
            // SLA Tracking
            thread.lastAdminReplyAt = Date.now();
            if (!thread.firstResponseAt) thread.firstResponseAt = Date.now();
        } else {
            thread.unreadCountAdmin += 1;
            // Reopen OR preserve assignment
            if (thread.status === 'resolved') {
                thread.status = 'open';
                thread.resolvedAt = null;
                thread.assignedToAdminId = null;
                thread.assignedToAdminName = null;
                thread.assignedAt = null;
                thread.autoResponseSent = false;
            } else if (thread.status === 'picked_up' && thread.assignedToAdminId) {
                // Keep it picked up! Do not reset.
            } else {
                thread.status = 'open'; // Safety for any other states
            }

            // [AUTO-RESPONSE LOGIC] - Only send if NEW thread (not picked up)
            if (!thread.autoResponseSent && thread.status !== 'picked_up') {
                const autoReplyText = "Your ticket has been created, an agent will respond to you shortly. 🤖";
                const systemAdmin = await User.findOne({ role: 'admin' });
                if (systemAdmin) {
                    const autoMessage = new ChatMessage({
                        threadId,
                        senderType: 'admin',
                        senderId: systemAdmin._id,
                        messageText: autoReplyText
                    });
                    await autoMessage.save();
                    thread.lastMessageText = autoReplyText;
                    thread.lastMessageAt = Date.now();
                    thread.unreadCountUser += 1;
                    thread.autoResponseSent = true;
                }
            }
        }
        thread.isHiddenFromAdmin = false;
        await thread.save();

        // Push Alert Consolidation
        try {
            const NotificationService = require('../utils/notificationService');
            if (!isAdmin) {
                // 1. Determine target admins (Branch-Aware & Owner-Aware)
                let targetAdmins = [];
                if (thread.assignedToAdminId) {
                    // Send ONLY to the assigned admin
                    targetAdmins = await User.find({ _id: thread.assignedToAdminId }).select('_id fcmTokens');
                } else {
                    // Send to all admins associated with this branch (assignedBranches or subscribedBranches)
                    targetAdmins = await User.find({
                        role: 'admin',
                        $or: [
                            { assignedBranches: thread.branchId },
                            { 'adminNotificationPreferences.subscribedBranches': thread.branchId },
                            { isMasterAdmin: true } // Master admins see everything
                        ]
                    }).select('_id fcmTokens');
                }

                if (targetAdmins.length > 0) {
                    // Fetch Branch Name for context
                    const Branch = require('../models/Branch');
                    let branchName = "Unknown Branch";
                    if (thread.branchId) {
                        const branch = await Branch.findById(thread.branchId);
                        if (branch) branchName = branch.name;
                    }
                    const senderName = req.user.name || "Customer";

                    // Insert database notification logs for each target admin
                    const adminNotifications = targetAdmins.map(adm => ({
                        userId: adm._id,
                        title: "New Message",
                        message: `(New Message from ${branchName} | ${senderName})`,
                        type: 'chat',
                        branchId: thread.branchId,
                        metadata: { threadId: thread._id }
                    }));
                    await Notification.insertMany(adminNotifications);

                    // Consolidate TARGETED tokens and fire push
                    let adminTokensRaw = [];
                    targetAdmins.forEach(adm => {
                        if (adm.fcmTokens && Array.isArray(adm.fcmTokens)) {
                            adm.fcmTokens.forEach(t => {
                                // Only include tokens tagged as 'admin'
                                if (typeof t === 'object' && t.appType === 'admin') {
                                    adminTokensRaw.push(t.token);
                                } else if (typeof t === 'string' && adm.role === 'admin') {
                                    // Fallback for legacy admin tokens
                                    adminTokensRaw.push(t);
                                }
                            });
                        }
                    });
                    const adminTokens = [...new Set(adminTokensRaw.filter(t => t))];

                    if (adminTokens.length > 0) {
                        await NotificationService.sendPushNotification(
                            adminTokens,
                            "New Customer Message",
                            `New message from ${senderName} at ${branchName}`,
                            { threadId: thread._id.toString(), type: 'chat', click_action: 'FLUTTER_NOTIFICATION_CLICK' }
                        );
                    }
                }
            } else {
                // Notify User
                await new Notification({
                    userId: thread.userId,
                    title: "Support Replied",
                    message: "New message from support",
                    type: 'chat',
                    branchId: thread.branchId
                }).save();

                const customer = await User.findById(thread.userId).select('fcmTokens');
                if (customer && customer.fcmTokens && customer.fcmTokens.length > 0) {
                    // [TARGETED] Only send to 'customer' app tokens
                    const customerTokens = customer.fcmTokens
                        .filter(t => (typeof t === 'string') || (t.appType === 'customer'))
                        .map(t => typeof t === 'string' ? t : t.token);

                    if (customerTokens.length > 0) {
                        await NotificationService.sendPushNotification(
                            customerTokens,
                            "Support Replied",
                            "You have a new message from Support.",
                            { threadId: thread._id.toString(), type: 'chat', click_action: 'FLUTTER_NOTIFICATION_CLICK' }
                        );
                    }
                }
            }
        } catch (e) {
            console.error("Chat Push Notification Error:", e);
        }

        res.json(newMessage);
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

// GET /admin/thread-for-user - Admin finding or creating thread for specific customer
router.get('/admin/thread-for-user', auth, admin, async (req, res) => {
    try {
        const { userId, branchId } = req.query;
        if (!userId || !branchId) return res.status(400).json({ msg: 'User ID and Branch ID are required' });

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

        const query = { branchId, isHiddenFromAdmin: { $ne: true } };
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
        if (status === 'resolved') {
            thread.resolvedAt = Date.now();
            // Calculate resolution time in minutes
            if (thread.createdAt) {
                const diffMs = thread.resolvedAt - thread.createdAt;
                thread.resolutionTime = Math.round(diffMs / 60000); // Minutes
            }
        } else {
            thread.resolvedAt = null;
            // We don't necessarily clear resolutionTime unless we want to "reset" metrics
        }
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

// [NEW] DELETE /admin/thread/:threadId - Admin-only hard hide
router.delete('/admin/thread/:threadId', auth, admin, async (req, res) => {
    try {
        const thread = await ChatThread.findById(req.params.threadId);
        if (!thread) return res.status(404).json({ msg: 'Thread not found' });

        thread.isHiddenFromAdmin = true;
        thread.unreadCountAdmin = 0; // Reset counters
        await thread.save();

        res.json({ msg: 'Thread removed from admin view' });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// POST /admin/pickup/:threadId - Admin picking up a chat
router.post('/admin/pickup/:threadId', auth, admin, async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        if (!user.permissions.manageChat && !user.permissions.canPickupChats) {
            return res.status(403).json({ msg: 'No permission to pickup chats' });
        }

        // Atomic update: only pick up if it's not already assigned
        const thread = await ChatThread.findOneAndUpdate(
            { _id: req.params.threadId, assignedToAdminId: null },
            {
                assignedToAdminId: req.user.id,
                assignedToAdminName: req.user.name,
                assignedAt: Date.now(),
                status: 'picked_up'
            },
            { new: true }
        ).populate('userId', 'name email');

        if (!thread) {
            return res.status(400).json({ msg: 'Conversation already assigned or not found' });
        }

        res.json(thread);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// POST /admin/transfer/:threadId - Transfering chat to another admin
router.post('/admin/transfer/:threadId', auth, admin, async (req, res) => {
    try {
        const { targetAdminId } = req.body;
        const currentUser = await User.findById(req.user.id);
        if (!currentUser.permissions.manageChat && !currentUser.permissions.canPickupChats) {
            return res.status(403).json({ msg: 'No permission to transfer chats' });
        }

        const targetAdmin = await User.findById(targetAdminId);
        if (!targetAdmin || targetAdmin.role !== 'admin') {
            return res.status(400).json({ msg: 'Invalid target admin' });
        }

        const thread = await ChatThread.findByIdAndUpdate(
            req.params.threadId,
            {
                assignedToAdminId: targetAdmin._id,
                assignedToAdminName: targetAdmin.name,
                assignedAt: Date.now(),
                status: 'picked_up'
            },
            { new: true }
        ).populate('userId', 'name email');

        if (!thread) return res.status(404).json({ msg: 'Thread not found' });

        // Notify the new admin (TARGETED)
        const NotificationService = require('../utils/notificationService');
        if (targetAdmin.fcmTokens && targetAdmin.fcmTokens.length > 0) {
            const adminTokens = targetAdmin.fcmTokens
                .filter(t => (typeof t === 'object' && t.appType === 'admin') || (typeof t === 'string'))
                .map(t => typeof t === 'string' ? t : t.token);

            if (adminTokens.length > 0) {
                const customerName = thread.userId?.name || "a customer";
                await NotificationService.sendPushNotification(
                    adminTokens,
                    "Chat Transferred",
                    `A conversation with ${customerName} was transferred to you.`,
                    { threadId: thread._id.toString(), type: 'chat', click_action: 'FLUTTER_NOTIFICATION_CLICK' }
                );
            }
        }

        res.json(thread);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

module.exports = router;
