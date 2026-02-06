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
router.get('/verify', auth, verifyToken); // [FIX] Match mobile app route '/verify'
router.put('/fcm-token', auth, require('../controllers/authController').updateFcmToken);

router.delete('/delete-account', auth, require('../controllers/authController').deleteAccount);
router.delete('/:userId', auth, admin, require('../controllers/authController').deleteUser);
router.put('/avatar', auth, require('../controllers/authController').updateAvatar);

module.exports = router;
