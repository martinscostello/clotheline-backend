const express = require('express');
const router = express.Router();
const { signup, login, getAllUsers, verifyToken } = require('../controllers/authController');
const auth = require('../middleware/auth');

router.post('/signup', signup);
router.post('/login', login);
router.get('/users', getAllUsers);
router.get('/verify', auth, verifyToken);

module.exports = router;
