const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const notificationController = require('../controllers/notificationController');

// GET / - Fetch user notifications
router.get('/', auth, notificationController.getNotifications);

// POST /mark-read - Mark all or specific as read
router.post('/mark-read', auth, notificationController.markAllRead);
router.post('/:id/read', auth, notificationController.markAsRead);
router.post('/mark-entity-read', auth, notificationController.markReadByEntity); // [NEW]

// POST /test - Diagnostic Endpoint
router.post('/test', auth, notificationController.sendTestNotification);

// --- PREFERENCES ---
router.get('/preferences', auth, notificationController.getPreferences);
router.put('/preferences', auth, notificationController.updatePreferences);

module.exports = router;
