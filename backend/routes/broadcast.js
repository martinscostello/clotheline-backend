const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const User = require('../models/User');
const Notification = require('../models/Notification');

const Order = require('../models/Order');

// POST /api/broadcast - Send a broadcast message to all users
router.post('/', auth, async (req, res) => {
    try {
        // Enforce Admin Access
        const requestor = await User.findById(req.user.userId);
        if (!requestor || requestor.role !== 'admin') {
            return res.status(403).json({ msg: 'Access denied. Admins only.' });
        }

        const { title, message, targetAudience } = req.body; // targetAudience: 'all', 'active_orders'
        if (!title || !message) {
            return res.status(400).json({ msg: 'Title and message are required' });
        }

        let query = { role: 'user' };

        // Filter by Audience
        if (targetAudience === 'active_orders') {
            // Find users with active orders
            const activeOrders = await Order.find({
                status: { $in: ['New', 'InProgress', 'Ready'] }
            }).distinct('userId'); // Get unique user IDs

            query._id = { $in: activeOrders };
        }
        // else 'all' implies default query

        const users = await User.find(query).select('_id notificationPreferences');

        if (users.length === 0) {
            return res.json({ msg: 'No users found for this audience.' });
        }

        // Filter out users who opted out of Broadcasts
        const recipients = users.filter(u => {
            const prefs = u.notificationPreferences || {};
            // Default to true if not set
            return prefs.adminBroadcasts !== false;
        });

        if (recipients.length === 0) {
            return res.json({ msg: 'All target users have opted out of broadcasts.' });
        }

        // Create Notifications
        const notifications = recipients.map(user => ({
            userId: user._id,
            title: title,
            message: message,
            type: 'broadcast',
            isRead: false,
            createdAt: new Date()
        }));

        await Notification.insertMany(notifications);

        res.json({
            msg: 'Broadcast sent successfully',
            count: notifications.length,
            audience: targetAudience || 'all'
        });

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

module.exports = router;
