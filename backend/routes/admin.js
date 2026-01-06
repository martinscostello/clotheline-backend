const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { createAdmin, getAllAdmins, updateAdmin } = require('../controllers/adminController');

// All routes are protected
router.use(auth);

// Create Admin
router.post('/create-admin', createAdmin);

// Get All Admins
router.get('/', getAllAdmins);

// Update Admin (Permissions / Revoke)
router.put('/:id', updateAdmin);

module.exports = router;
