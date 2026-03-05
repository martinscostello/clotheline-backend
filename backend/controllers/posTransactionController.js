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
            totalVolume += t.amount;
            totalCharges += (t.charges || 0);
            totalProviderFees += (t.providerFee || 0);

            if (t.status === 'resolved') {
                totalNetProfit += (t.netProfit || 0);
            }

            if (t.transactionType === 'Deposit') totalDeposits += t.amount;
            if (t.transactionType === 'Withdrawal' || t.transactionType === 'Transfer') totalWithdrawals += t.amount;
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
        const { branchId, transactionType, amount, charges, providerFee, netProfit, status, notes } = req.body;

        if (!branchId || !transactionType || !amount) {
            return res.status(400).json({ msg: 'Please enter all required fields' });
        }

        if (!checkBranchAccess(req, branchId)) {
            return res.status(403).json({ msg: 'Not authorized for this branch' });
        }

        const branch = await Branch.findById(branchId);
        if (!branch || !branch.isPosTerminalEnabled) {
            return res.status(400).json({ msg: 'POS Terminal is not enabled for this branch' });
        }

        const newTx = new POSTransaction({
            branchId,
            transactionType,
            amount,
            charges: charges || 0,
            providerFee: providerFee || 0,
            netProfit: netProfit || 0,
            status: status || 'resolved',
            notes,
            enteredBy: req.user.id
        });

        await newTx.save();

        const populatedTx = await POSTransaction.findById(newTx._id).populate('enteredBy', 'name email role');
        res.json(populatedTx);
    } catch (err) {
        console.error("Error creating POS transaction:", err);
        res.status(500).send('Server Error');
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

        const { transactionType, amount, charges, providerFee, netProfit, status, notes } = req.body;

        if (transactionType) tx.transactionType = transactionType;
        if (amount !== undefined) tx.amount = amount;
        if (charges !== undefined) tx.charges = charges;
        if (providerFee !== undefined) tx.providerFee = providerFee;
        if (netProfit !== undefined) tx.netProfit = netProfit;
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
