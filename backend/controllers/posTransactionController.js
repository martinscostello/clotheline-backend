const POSTransaction = require('../models/POSTransaction');
const Branch = require('../models/Branch');

// Helper to authenticate branch access
const checkBranchAccess = (req, branchId) => {
    if (req.adminUser.isMasterAdmin) return true;
    if (req.adminUser.assignedBranches && req.adminUser.assignedBranches.includes(branchId)) return true;
    return false;
};

// GET /api/pos-transactions
exports.getTransactions = async (req, res) => {
    try {
        const { branchId, startDate, endDate } = req.query;
        let filter = {};

        if (req.adminUser && !req.adminUser.isMasterAdmin) {
            if (req.adminUser.assignedBranches && req.adminUser.assignedBranches.length > 0) {
                if (branchId && branchId !== 'all') {
                    if (!req.adminUser.assignedBranches.includes(branchId)) {
                        return res.status(403).json({ msg: 'Not authorized for this branch' });
                    }
                    filter.branchId = branchId;
                } else {
                    filter.branchId = { $in: req.adminUser.assignedBranches };
                }
            } else {
                return res.json([]);
            }
        } else if (branchId && branchId !== 'all') {
            filter.branchId = branchId;
        }

        if (startDate && endDate) {
            filter.createdAt = {
                $gte: new Date(startDate),
                $lte: new Date(endDate)
            };
        }

        const transactions = await POSTransaction.find(filter)
            .sort({ createdAt: -1 })
            .populate('enteredBy', 'name email role');

        res.json(transactions);
    } catch (err) {
        console.error("Error getting POS transactions:", err);
        res.status(500).send('Server Error');
    }
};

// GET /api/pos-transactions/metrics
exports.getMetrics = async (req, res) => {
    try {
        const { branchId, startDate, endDate } = req.query;
        let filter = {};

        if (req.adminUser && !req.adminUser.isMasterAdmin) {
            if (req.adminUser.assignedBranches && req.adminUser.assignedBranches.length > 0) {
                if (branchId && branchId !== 'all') {
                    if (!req.adminUser.assignedBranches.includes(branchId)) {
                        return res.status(403).json({ msg: 'Not authorized for this branch' });
                    }
                    filter.branchId = branchId;
                } else {
                    filter.branchId = { $in: req.adminUser.assignedBranches };
                }
            } else {
                return res.json({ totalTransactions: 0, totalVolume: 0, totalCharges: 0, avgCharge: 0 });
            }
        } else if (branchId && branchId !== 'all') {
            filter.branchId = branchId;
        }

        const transactions = await POSTransaction.find(filter);

        let totalTransactions = transactions.length;
        let totalVolume = 0;
        let totalCharges = 0;
        let totalProviderFees = 0;
        let totalNetProfit = 0;

        let totalDeposits = 0;
        let totalWithdrawals = 0;

        transactions.forEach(t => {
            const withdrawalAmount = t.withdrawalAmount || t.amount || 0;
            const customerCharge = t.customerCharge || t.charges || 0;
            const providerFee = t.providerFee || 0;
            const terminalAmount = t.terminalAmount || t.amount || 0;

            totalVolume += t.amount; // terminalAmount
            totalCharges += customerCharge;
            totalProviderFees += providerFee;

            if (t.status === 'resolved') {
                totalNetProfit += (customerCharge - providerFee);
            }

            if (t.transactionType === 'Deposit') totalDeposits += terminalAmount;
            if (t.transactionType === 'Withdrawal' || t.transactionType === 'Transfer') {
                totalWithdrawals += terminalAmount;
            }
        });

        let avgCharge = totalTransactions > 0 ? (totalCharges / totalTransactions) : 0;

        res.json({
            totalTransactions,
            totalVolume,
            totalCharges,
            totalProviderFees,
            netProfit: totalNetProfit,
            avgCharge,
            totalDeposits,
            totalWithdrawals
        });
    } catch (err) {
        console.error("Error getting POS metrics:", err);
        res.status(500).send('Server Error');
    }
};

// POST /api/pos-transactions
exports.createTransaction = async (req, res) => {
    try {
        const {
            branchId,
            transactionType,
            amount,
            withdrawalAmount,
            customerCharge,
            chargeMode,
            terminalAmount,
            providerFee,
            status,
            notes
        } = req.body;

        console.log("Create POS Transaction Request Body:", JSON.stringify(req.body, null, 2));

        if (!branchId || !transactionType || (amount === undefined && terminalAmount === undefined)) {
            return res.status(400).json({ msg: 'Please enter all required fields' });
        }

        if (!checkBranchAccess(req, branchId)) {
            return res.status(403).json({ msg: 'Not authorized for this branch' });
        }

        const branch = await Branch.findById(branchId);
        if (!branch || !branch.isPosTerminalEnabled) {
            return res.status(400).json({ msg: 'POS Terminal is not enabled for this branch' });
        }

        const calculatedNetProfit = (customerCharge || 0) - (providerFee || 0);

        const newTx = new POSTransaction({
            branchId,
            transactionType,
            amount: terminalAmount || amount, // Legacy fallback
            charges: customerCharge || 0, // Legacy fallback
            withdrawalAmount: withdrawalAmount || amount,
            customerCharge: customerCharge || 0,
            chargeMode: chargeMode || 'Included',
            terminalAmount: terminalAmount || amount,
            providerFee: providerFee || 0,
            netProfit: calculatedNetProfit,
            status: status || 'resolved',
            notes,
            enteredBy: req.user.id
        });

        await newTx.save();

        const populatedTx = await POSTransaction.findById(newTx._id).populate('enteredBy', 'name email role');
        res.json(populatedTx);
    } catch (err) {
        console.error("Error creating POS transaction:", err);
        if (err.name === 'ValidationError') {
            const messages = Object.values(err.errors).map(val => val.message);
            return res.status(400).json({ msg: messages.join(', '), error: err.errors });
        }
        res.status(500).json({ msg: 'Server Error', error: err.message });
    }
};

// PUT /api/pos-transactions/:id
exports.updateTransaction = async (req, res) => {
    try {
        const tx = await POSTransaction.findById(req.params.id);
        if (!tx) return res.status(404).json({ msg: 'Transaction not found' });

        if (!checkBranchAccess(req, tx.branchId.toString())) {
            return res.status(403).json({ msg: 'Not authorized for this branch' });
        }

        // 24 Hour Lock Rule
        const hoursSinceCreation = (Date.now() - new Date(tx.createdAt)) / (1000 * 60 * 60);
        if (hoursSinceCreation > 24 && !req.adminUser.isMasterAdmin) {
            return res.status(403).json({ msg: 'Transactions cannot be edited after 24 hours unless Master Admin' });
        }

        const {
            transactionType,
            amount,
            withdrawalAmount,
            customerCharge,
            chargeMode,
            terminalAmount,
            providerFee,
            status,
            notes
        } = req.body;

        if (transactionType) tx.transactionType = transactionType;
        if (amount !== undefined) tx.amount = amount;
        if (withdrawalAmount !== undefined) tx.withdrawalAmount = withdrawalAmount;
        if (customerCharge !== undefined) {
            tx.customerCharge = customerCharge;
            tx.charges = customerCharge; // Sync legacy
        }
        if (chargeMode) tx.chargeMode = chargeMode;
        if (terminalAmount !== undefined) {
            tx.terminalAmount = terminalAmount;
            tx.amount = terminalAmount; // Sync legacy
        }
        if (providerFee !== undefined) tx.providerFee = providerFee;

        // Recalculate netProfit if charge or fee changed
        if (customerCharge !== undefined || providerFee !== undefined) {
            tx.netProfit = (tx.customerCharge || 0) - (tx.providerFee || 0);
        }

        if (status) tx.status = status;
        if (notes !== undefined) tx.notes = notes;

        await tx.save();
        const populatedTx = await POSTransaction.findById(tx._id).populate('enteredBy', 'name email role');
        res.json(populatedTx);
    } catch (err) {
        console.error("Error updating POS transaction:", err);
        res.status(500).send('Server Error');
    }
};

// DELETE /api/pos-transactions/:id
exports.deleteTransaction = async (req, res) => {
    try {
        const tx = await POSTransaction.findById(req.params.id);
        if (!tx) return res.status(404).json({ msg: 'Transaction not found' });

        if (!checkBranchAccess(req, tx.branchId.toString())) {
            return res.status(403).json({ msg: 'Not authorized for this branch' });
        }

        // Only Master Admin can delete (User Request implies strict auditing)
        if (!req.adminUser.isMasterAdmin) {
            return res.status(403).json({ msg: 'Only Master Admin can delete POS transactions' });
        }

        await POSTransaction.findByIdAndDelete(req.params.id);
        res.json({ msg: 'Transaction deleted' });
    } catch (err) {
        console.error("Error deleting POS transaction:", err);
        res.status(500).send('Server Error');
    }
};
