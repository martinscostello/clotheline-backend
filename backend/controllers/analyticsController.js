const Order = require('../models/Order');

// GET /analytics/revenue
// Query Params: range (day, week, month, year), branchId (optional), fulfillmentMode (optional)
exports.getRevenueStats = async (req, res) => {
    try {
        const { range, branchId, fulfillmentMode } = req.query;

        // Date Filter
        const now = new Date();
        let startDate = new Date();

        if (range === 'day') startDate.setDate(now.getDate() - 1);

        let intervalFormat = '%Y-%m-%d';
        if (range === 'year') intervalFormat = '%Y-%m-01';

        if (range === 'week') startDate.setDate(now.getDate() - 7);
        else if (range === 'month') startDate.setDate(now.getDate() - 30);
        else if (range === 'year') startDate.setMonth(now.getMonth() - 12);
        else startDate.setDate(now.getDate() - 7); // Default week

        const matchStage = {
            date: { $gte: startDate },
            status: { $nin: ['Cancelled', 'Refunded'] }
        };

        if (branchId) {
            const mongoose = require('mongoose');
            matchStage.branchId = new mongoose.Types.ObjectId(branchId);
        } else if (req.adminUser && !req.adminUser.isMasterAdmin) {
            // [SECURE] Branch RBAC Enforcement for "All Branches"
            if (req.adminUser.assignedBranches && req.adminUser.assignedBranches.length > 0) {
                const mongoose = require('mongoose');
                matchStage.branchId = { $in: req.adminUser.assignedBranches.map(id => new mongoose.Types.ObjectId(id)) };
            } else {
                return res.json({ data: [], summary: { total: 0, count: 0 } });
            }
        }

        if (fulfillmentMode) {
            if (fulfillmentMode === 'logistics') {
                matchStage.fulfillmentMode = { $in: ['logistics', 'bulky'] };
            } else {
                matchStage.fulfillmentMode = fulfillmentMode;
            }
        }

        const aggregation = [
            { $match: matchStage },
            {
                $group: {
                    _id: { $dateToString: { format: intervalFormat, date: "$date" } },
                    totalRevenue: { $sum: "$totalAmount" },
                    count: { $sum: 1 }
                }
            },
            { $sort: { _id: 1 } }
        ];

        const stats = await Order.aggregate(aggregation);

        const totalAggregation = [
            { $match: matchStage },
            { $group: { _id: null, total: { $sum: "$totalAmount" }, count: { $sum: 1 } } }
        ];
        const summary = await Order.aggregate(totalAggregation);

        res.json({
            data: stats,
            summary: summary[0] || { total: 0, count: 0 }
        });

    } catch (err) {
        console.error("Analytics Revenue Error:", err);
        res.status(500).send('Server Error');
    }
};

// GET /analytics/top-items
exports.getTopItems = async (req, res) => {
    try {
        const { limit = 5, branchId, fulfillmentMode } = req.query;

        const matchStage = {
            status: { $nin: ['Cancelled', 'Refunded'] }
        };
        if (branchId) {
            const mongoose = require('mongoose');
            matchStage.branchId = new mongoose.Types.ObjectId(branchId);
        } else if (req.adminUser && !req.adminUser.isMasterAdmin) {
            // [SECURE] Branch RBAC Enforcement for "All Branches"
            if (req.adminUser.assignedBranches && req.adminUser.assignedBranches.length > 0) {
                const mongoose = require('mongoose');
                matchStage.branchId = { $in: req.adminUser.assignedBranches.map(id => new mongoose.Types.ObjectId(id)) };
            } else {
                return res.json([]);
            }
        }

        if (fulfillmentMode) {
            if (fulfillmentMode === 'logistics') {
                matchStage.fulfillmentMode = { $in: ['logistics', 'bulky'] };
            } else {
                matchStage.fulfillmentMode = fulfillmentMode;
            }
        }

        const stats = await Order.aggregate([
            { $match: matchStage },
            { $unwind: "$items" },
            {
                $group: {
                    _id: "$items.name",
                    totalSold: { $sum: "$items.quantity" },
                    totalRevenue: { $sum: { $multiply: ["$items.price", "$items.quantity"] } }
                }
            },
            { $sort: { totalSold: -1 } },
            { $limit: parseInt(limit) }
        ]);

        res.json(stats);
    } catch (err) {
        console.error("Analytics Top Items Error:", err);
        res.status(500).send('Server Error');
    }
};
