const express = require('express');
const router = express.Router();
const { signup, login, getAllUsers, verifyToken } = require('../controllers/authController');
const auth = require('../middleware/auth');

router.post('/signup', signup);
router.post('/login', login);
router.post('/verify', require('../controllers/authController').verifyEmail); // Renamed to /verify to match Frontend
router.post('/resend-otp', require('../controllers/authController').resendOtp);
router.get('/users', getAllUsers);
router.get('/verify-token', auth, verifyToken); // Renamed to /verify-token for clarity

module.exports = router;
