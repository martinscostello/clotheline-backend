const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { createAdmin, getAllAdmins, updateAdmin, getDatabaseBackup } = require('../controllers/adminController');

// All routes are protected
router.use(auth);

// Backup Route
router.get('/backup', getDatabaseBackup);

// Create Admin
router.post('/create-admin', createAdmin);

// Get All Admins
router.get('/', getAllAdmins);

// Update Admin (Permissions / Revoke)
router.put('/:id', updateAdmin);

module.exports = router;
