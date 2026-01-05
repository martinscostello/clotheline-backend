const express = require('express');
const router = express.Router();
const { seedUsers } = require('../controllers/devController');

// @route   GET /api/dev/seed
// @desc    Seed test users
// @access  Public (Dev only)
router.get('/seed', seedUsers);

module.exports = router;
