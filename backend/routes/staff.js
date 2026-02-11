const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const User = require('../models/User');
const {
    createStaff,
    getStaffByBranch,
    addWarning,
    archiveStaff,
    updateStaff,
    deleteStaff
} = require('../controllers/staffController');

// Middleware to check manageStaff permission
const checkStaffPermission = async (req, res, next) => {
    try {
        const user = await User.findById(req.user.id);
        if (user.isMasterAdmin || (user.role === 'admin' && user.permissions.manageStaff)) {
            next();
        } else {
            return res.status(403).json({ msg: 'Permission denied: manageStaff required' });
        }
    } catch (err) {
        res.status(500).send('Server Error');
    }
};

router.use(auth);
router.use(checkStaffPermission);

// @route   POST /api/staff
// @desc    Create a staff member
router.post('/', createStaff);

// @route   GET /api/staff
// @desc    Get staff for a branch
router.get('/', getStaffByBranch);

// @route   POST /api/staff/warning
// @desc    Add warning to staff
router.post('/warning', addWarning);

// @route   PUT /api/staff/:id/archive
// @desc    Archive staff
router.put('/:id/archive', archiveStaff);

// @route   PUT /api/staff/:id
// @desc    Update staff details
router.put('/:id', updateStaff);

// @route   DELETE /api/staff/:id
// @desc    Permanently delete staff
router.delete('/:id', deleteStaff);

module.exports = router;
