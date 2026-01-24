const Notification = require('../models/Notification');
const User = require('../models/User');
const NotificationService = require('../utils/notificationService');

exports.getNotifications = async (req, res) => {
    try {
        const notifications = await Notification.find({ userId: req.user.id }).sort({ createdAt: -1 }).limit(50);
        res.json(notifications);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.markAsRead = async (req, res) => {
    try {
        const notification = await Notification.findById(req.params.id);
        if (!notification) return res.status(404).json({ msg: 'Notification not found' });

        if (notification.userId.toString() !== req.user.id) {
            return res.status(401).json({ msg: 'Not authorized' });
        }

        notification.isRead = true;
        await notification.save();
        res.json(notification);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.markAllRead = async (req, res) => {
    try {
        await Notification.updateMany({ userId: req.user.id, isRead: false }, { $set: { isRead: true } });
        res.json({ msg: 'All marked as read' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.getPreferences = async (req, res) => {
    try {
        const user = await User.findById(req.user.id).select('notificationPreferences');
        res.json(user.notificationPreferences);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.updatePreferences = async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        if (req.body) {
            user.notificationPreferences = { ...user.notificationPreferences, ...req.body };
            await user.save();
        }
        res.json(user.notificationPreferences);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// [DIAGNOSTIC] Verification Endpoint
exports.sendTestNotification = async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        if (!user || !user.fcmTokens || user.fcmTokens.length === 0) {
            return res.status(400).json({
                msg: 'No FCM Tokens found for user.',
                userTokens: user ? user.fcmTokens : 'User Not Found'
            });
        }

        console.log(`[TestNotif] Sending to ${user.email} with tokens:`, user.fcmTokens);

        await NotificationService.sendPushNotification(
            user.fcmTokens,
            "Test Notification",
            "This is a test message to verify push delivery.",
            { type: "test", click_action: "FLUTTER_NOTIFICATION_CLICK" }
        );

        res.json({
            msg: 'Test Notification Triggered',
            tokenCount: user.fcmTokens.length,
            targetTokens: user.fcmTokens
        });

    } catch (err) {
        console.error("[TestNotif] Error:", err);
        res.status(500).json({ msg: 'Failed to send test', error: err.message });
    }
};
