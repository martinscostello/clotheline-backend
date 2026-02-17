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
        const requestor = await User.findById(req.user.id);
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
            const activeOrders = await Order.find({
                status: { $in: ['New', 'InProgress', 'Ready'] }
            }).distinct('userId');
            query._id = { $in: activeOrders };
        } else if (targetAudience === 'cancelled_orders') {
            const cancelledOrders = await Order.find({
                status: 'Cancelled'
            }).distinct('userId');
            query._id = { $in: cancelledOrders };
        } else if (targetAudience === 'zero_orders') {
            const allOrderUsers = await Order.find().distinct('userId');
            query._id = { $not: { $in: allOrderUsers } };
        } else if (targetAudience === 'benin' || targetAudience === 'abuja') {
            query['savedAddresses.city'] = { $regex: new RegExp(targetAudience, 'i') };
        } else if (targetAudience === 'guests') {
            // [NEW] Target Guests (Unverified users)
            query = { isVerified: false, role: { $ne: 'admin' } };
        } else if (targetAudience === 'all_including_guests') {
            // [NEW] Target Everyone (except admins)
            query = { role: { $ne: 'admin' } };
        }
        // else 'all' implies default query { role: 'user' }

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
