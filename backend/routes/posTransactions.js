const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const adminAuth = require('../middleware/admin'); // Ensure admin privileges

// Import Controller
const posController = require('../controllers/posTransactionController');

// @route   POST /api/pos-transactions
// @desc    Create a new POS transaction
// @access  Private (Admin only)
router.post('/', [
    auth, adminAuth
], posController.createTransaction);

// @route   PUT /api/pos-transactions/:id
// @desc    Update a POS transaction (limited to 24 hours)
// @access  Private (Admin only)
router.put('/:id', [auth, adminAuth], posController.updateTransaction);

// @route   DELETE /api/pos-transactions/:id
// @desc    Delete a POS transaction (Master Admin only)
// @access  Private (Master Admin only)
router.delete('/:id', [auth, adminAuth], posController.deleteTransaction);

module.exports = router;
