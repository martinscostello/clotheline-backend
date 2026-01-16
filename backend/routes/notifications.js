const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Notification = require('../models/Notification');

// GET / - Fetch user notifications
router.get('/', auth, async (req, res) => {
    try {
        const notifications = await Notification.find({ userId: req.user.userId })
            .sort({ createdAt: -1 });
        res.json(notifications);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// POST /mark-read - Mark all or specific as read
router.post('/mark-read', auth, async (req, res) => {
    try {
        await Notification.updateMany(
            { userId: req.user.userId, isRead: false },
            { $set: { isRead: true } }
        );
        res.json({ msg: 'Notifications marked as read' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// POST /create (Internal/Admin use mostly)
router.post('/create', auth, async (req, res) => {
    try {
        const { userId, title, message, type } = req.body;

        const newNotification = new Notification({
            userId,
            title,
            message,
            type
        });

        await newNotification.save();
        res.json(newNotification);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// --- PREFERENCES ---

const User = require('../models/User');

// GET /preferences
router.get('/preferences', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.userId).select('notificationPreferences');
        if (!user) return res.status(404).json({ msg: 'User not found' });

        // Return defaults if not set (fallback)
        const prefs = user.notificationPreferences || {
            email: true, push: true, orderUpdates: true,
            chatMessages: true, adminBroadcasts: true, bucketUpdates: true
        };
        res.json(prefs);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// PUT /preferences
router.put('/preferences', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.userId);
        if (!user) return res.status(404).json({ msg: 'User not found' });

        // Merge existing with new updates
        const current = user.notificationPreferences || {};
        const updates = req.body;

        user.notificationPreferences = { ...current, ...updates };
        await user.save();

        res.json(user.notificationPreferences);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

module.exports = router;
