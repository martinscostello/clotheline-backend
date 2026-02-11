const Staff = require('../models/Staff');
const User = require('../models/User');

// Create Staff
exports.createStaff = async (req, res) => {
    try {
        const {
            name, email, phone, address, position, branchId,
            passportPhoto, idCardImage, signature, bankDetails, guarantor,
            salary, probation, employmentDate
        } = req.body;

        const staff = new Staff({
            name,
            email,
            phone,
            address,
            position,
            branchId,
            passportPhoto,
            idCardImage,
            signature,
            bankDetails,
            guarantor,
            salary,
            probation,
            employmentDate
        });

        await staff.save();
        res.json(staff);
    } catch (err) {
        console.error("===== CREATE STAFF ERROR =====");
        console.error(err);
        if (err.name === 'ValidationError') {
            return res.status(400).json({ msg: `Validation Error: ${Object.values(err.errors).map(e => e.message).join(', ')}` });
        }
        res.status(500).send(`Server Error: ${err.message}`);
    }
};

// Get Staff by Branch
exports.getStaffByBranch = async (req, res) => {
    try {
        const { branchId } = req.query;
        let query = { isArchived: false };

        if (branchId && branchId !== 'null') {
            query.branchId = branchId;
        }

        const staff = await Staff.find(query).populate('warnings.issuedBy', 'name').sort({ name: 1 });
        res.json(staff);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Add Warning
exports.addWarning = async (req, res) => {
    try {
        const { staffId, reason, severity, notes, sentViaWhatsApp } = req.body;

        const staff = await Staff.findById(staffId);
        if (!staff) return res.status(404).json({ msg: 'Staff not found' });

        const warning = {
            reason,
            severity,
            notes,
            sentViaWhatsApp,
            issuedBy: req.user.id, // From auth middleware
            timestamp: new Date()
        };

        staff.warnings.push(warning);

        // Dynamic Performance Calculation
        const deductions = { 'Low': 0.25, 'Medium': 0.5, 'Severe': 0.75 };
        const penalty = deductions[severity] || 0;

        // Ensure rating doesn't go below 0
        if (staff.performance && staff.performance.rating !== undefined) {
            let newRating = staff.performance.rating - penalty;
            staff.performance.rating = Math.max(0, newRating);
        }

        await staff.save();

        res.json(staff);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Archive Staff
exports.archiveStaff = async (req, res) => {
    try {
        const { archiveReason } = req.body;
        const staff = await Staff.findById(req.params.id);

        if (!staff) return res.status(404).json({ msg: 'Staff not found' });

        staff.isArchived = true;
        staff.archiveReason = archiveReason || 'No reason provided';

        await staff.save();
        res.json({ msg: 'Staff archived successfully' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Update Staff
exports.updateStaff = async (req, res) => {
    try {
        const staff = await Staff.findByIdAndUpdate(
            req.params.id,
            { $set: req.body },
            { new: true }
        );
        res.json(staff);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Permanent Delete Staff
exports.deleteStaff = async (req, res) => {
    try {
        const staff = await Staff.findById(req.params.id);
        if (!staff) return res.status(404).json({ msg: 'Staff not found' });

        await Staff.findByIdAndDelete(req.params.id);
        res.json({ msg: 'Staff permanently removed' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Remove Warning & Restore Performance
exports.removeWarning = async (req, res) => {
    try {
        const { staffId, warningId } = req.body;

        const staff = await Staff.findById(staffId);
        if (!staff) return res.status(404).json({ msg: 'Staff not found' });

        const warningIndex = staff.warnings.findIndex(w => w._id.toString() === warningId);
        if (warningIndex === -1) return res.status(404).json({ msg: 'Warning not found' });

        const warning = staff.warnings[warningIndex];

        // Restore Performance
        const deductions = { 'Low': 0.25, 'Medium': 0.5, 'Severe': 0.75 };
        const restoreAmount = deductions[warning.severity] || 0;

        if (staff.performance && staff.performance.rating !== undefined) {
            let newRating = staff.performance.rating + restoreAmount;
            staff.performance.rating = Math.min(5, newRating); // Cap at 5
        }

        staff.warnings.splice(warningIndex, 1);
        await staff.save();

        res.json(staff);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Record Salary Payment
exports.recordPayment = async (req, res) => {
    try {
        const { staffId, amount, paymentDate, method, reference } = req.body;

        const staff = await Staff.findById(staffId);
        if (!staff) return res.status(404).json({ msg: 'Staff not found' });

        // Ensure arrays exist
        if (!staff.paymentHistory) staff.paymentHistory = [];
        if (!staff.salary) staff.salary = {};

        // Add to history
        staff.paymentHistory.unshift({
            amount,
            date: paymentDate || new Date(),
            reference: reference || `PAY-${Date.now()}`,
            status: 'Paid'
        });

        // Update Salary Status
        staff.salary.lastPaidDate = paymentDate || new Date();
        staff.salary.status = 'Paid';

        // Calculate Next Due Date (Simple +1 month logic for now)
        const lastPaid = new Date(staff.salary.lastPaidDate);
        if (staff.salary.cycle === 'Weekly') {
            lastPaid.setDate(lastPaid.getDate() + 7);
        } else {
            lastPaid.setMonth(lastPaid.getMonth() + 1);
        }
        staff.salary.nextPaymentDueDate = lastPaid;

        await staff.save();
        res.json(staff);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};
