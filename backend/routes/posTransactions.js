const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const adminAuth = require('../middleware/adminAuth'); // Ensure admin privileges
const { check, validationResult } = require('express-validator');

// Import Controller
const posController = require('../controllers/posTransactionController');

// Helper middleware to validate requests
const validateRequest = (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    next();
};

// @route   GET /api/pos-transactions
// @desc    Get all POS transactions with branch and date filters
// @access  Private (Admin only)
router.get('/', [auth, adminAuth], posController.getTransactions);

// @route   GET /api/pos-transactions/metrics
// @desc    Get aggregated POS transaction metrics for the dashboard
// @access  Private (Admin only)
router.get('/metrics', [auth, adminAuth], posController.getMetrics);

// @route   POST /api/pos-transactions
// @desc    Create a new POS transaction
// @access  Private (Admin only)
router.post('/', [
    auth, adminAuth,
    check('branchId', 'Branch ID is required').not().isEmpty(),
    check('transactionType', 'Transaction Type must be Withdrawal, Transfer, Deposit, Airtime, or Other')
        .isIn(['Withdrawal', 'Transfer', 'Deposit', 'Airtime', 'Other']),
    check('amount', 'Amount is required and must be numeric').isNumeric()
], validateRequest, posController.createTransaction);

// @route   PUT /api/pos-transactions/:id
// @desc    Update a POS transaction (limited to 24 hours)
// @access  Private (Admin only)
router.put('/:id', [auth, adminAuth], posController.updateTransaction);

// @route   DELETE /api/pos-transactions/:id
// @desc    Delete a POS transaction (Master Admin only)
// @access  Private (Master Admin only)
router.delete('/:id', [auth, adminAuth], posController.deleteTransaction);

module.exports = router;
