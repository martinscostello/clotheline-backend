const express = require('express');
const router = express.Router();
const { signup, login, getAllUsers, verifyToken } = require('../controllers/authController');
const auth = require('../middleware/auth');
const admin = require('../middleware/admin');

router.post('/signup', signup);
router.post('/login', login);
router.post('/verify-email', require('../controllers/authController').verifyEmail); // Matched to mobile app call /verify-email
router.post('/resend-otp', require('../controllers/authController').resendOtp);
router.get('/users', auth, admin, getAllUsers);
router.get('/verify-token', auth, verifyToken); // Renamed to /verify-token for clarity
router.put('/fcm-token', auth, require('../controllers/authController').updateFcmToken);

router.delete('/:userId', auth, admin, require('../controllers/authController').deleteUser);

module.exports = router;
