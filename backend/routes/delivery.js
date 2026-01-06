const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { getSettings, updateSettings } = require('../controllers/deliveryController');

// Public or User accessible? User needs to calculate fee, so GET should be open or user-authenticated
// For now, let's allow authenticated users to view, but only Admins to update.
// Actually, checkout needs this data, so public GET is easiest, or User role.

router.get('/', getSettings);
router.put('/', auth, updateSettings); // Add admin check logic inside if strictly restricted

module.exports = router;
