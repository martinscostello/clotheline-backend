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

        // Ensure only admin or system creates (skip check for now for testing)

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

module.exports = router;
