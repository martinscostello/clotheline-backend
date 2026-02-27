const mongoose = require('mongoose');
const Order = require('../models/Order');
const Review = require('../models/Review');
const User = require('../models/User');
const NotificationService = require('../utils/notificationService');
const Notification = require('../models/Notification');

const sendReviewReminders = async () => {
    try {
        // Find orders completed between 24 and 48 hours ago
        const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
        const fortyEightHoursAgo = new Date(Date.now() - 48 * 60 * 60 * 1000);

        const orders = await Order.find({
            status: 'Completed',
            date: { $gte: fortyEightHoursAgo, $lte: twentyFourHoursAgo }
        }).populate('user');

        for (const order of orders) {
            if (!order.user) continue;

            // Filter for store items
            const storeItems = order.items.filter(item => item.itemType === 'Product');

            for (const item of storeItems) {
                // Check if review already exists
                const existingReview = await Review.findOne({
                    user: order.user._id,
                    product: item.itemId,
                    order: order._id
                });

                if (!existingReview) {
                    // Send notification
                    const title = 'Rate your purchase!';
                    const body = `How do you like your ${item.name}? Share your feedback with us!`;
                    const data = {
                        type: 'review_reminder',
                        productId: item.itemId.toString(),
                        productName: item.name, // Added
                        orderId: order._id.toString(),
                        click_action: 'FLUTTER_NOTIFICATION_CLICK'
                    };

                    if (order.user.fcmTokens && order.user.fcmTokens.length > 0) {
                        // [TARGETED] Only send to 'customer' app tokens
                        const customerTokens = order.user.fcmTokens
                            .filter(t => (typeof t === 'string') || (t.appType === 'customer'))
                            .map(t => typeof t === 'string' ? t : t.token);

                        if (customerTokens.length > 0) {
                            await NotificationService.sendPushNotification(customerTokens, title, body, data);
                        }

                        // Save to Notification model for in-app history
                        const notification = new Notification({
                            userId: order.user._id,
                            title,
                            message: body,
                            type: 'order', // Categorize as order related
                            metadata: {
                                orderId: order._id,
                                productId: item.itemId,
                                action: 'review'
                            }
                        });
                        await notification.save();

                        console.log(`Sent review reminder to user ${order.user.email} for product ${item.name}`);
                    }
                }
            }
        }
    } catch (error) {
        console.error('Error in sendReviewReminders:', error);
    }
};

module.exports = sendReviewReminders;
