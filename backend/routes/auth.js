const express = require('express');
const router = express.Router();
const { signup, login, getAllUsers, verifyToken } = require('../controllers/authController');
const auth = require('../middleware/auth');
const admin = require('../middleware/admin');

router.post('/signup', signup);
router.post('/login', login);
router.post('/verify-email', require('../controllers/authController').verifyEmail); // Matched to mobile app call /verify-email
router.post('/resend-otp', require('../controllers/authController').resendOtp);
router.post('/forgot-password', require('../controllers/authController').forgotPassword);
router.post('/reset-password', require('../controllers/authController').resetPassword);
router.put('/change-password', auth, require('../controllers/authController').changePassword);
router.get('/users', auth, admin, getAllUsers);
router.get('/verify', auth, verifyToken); // [FIX] Match mobile app route '/verify'
router.post('/logout', auth, logout);
router.put('/fcm-token', auth, require('../controllers/authController').updateFcmToken);

router.delete('/delete-account', auth, require('../controllers/authController').deleteAccount);
router.delete('/:userId', auth, admin, require('../controllers/authController').deleteUser);
router.put('/avatar', auth, require('../controllers/authController').updateAvatar);
router.put('/admin-notification-preferences', auth, require('../controllers/authController').updateAdminNotificationPreferences);
router.post('/violation-log', auth, (req, res) => res.json({ msg: 'Violation logged' }));

module.exports = router;
