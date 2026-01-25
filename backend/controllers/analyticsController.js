const Order = require('../models/Order');

// GET /analytics/revenue
// Query Params: range (day, week, month, year), branchId (optional)
exports.getRevenueStats = async (req, res) => {
    try {
        const { range, branchId } = req.query;

        // Date Filter
        const now = new Date();
        let startDate = new Date();

        if (range === 'day') startDate.setDate(now.getDate() - 1); // Last 24h? or Today? Let's say last 7 days for graph usually.
        // Usually charts show a trend. Let's assume request is for "Trend Data" over X time.
        // If range='week', show last 7 days.
        // If range='month', show last 30 days.
        // If range='year', show last 12 months.

        let intervalFormat = '%Y-%m-%d';
        if (range === 'year') intervalFormat = '%Y-%m-01';

        if (range === 'week') startDate.setDate(now.getDate() - 7);
        else if (range === 'month') startDate.setDate(now.getDate() - 30);
        else if (range === 'year') startDate.setMonth(now.getMonth() - 12);
        else startDate.setDate(now.getDate() - 7); // Default week

        const matchStage = {
            createdAt: { $gte: startDate },
            status: { $nin: ['Cancelled', 'Refunded'] }, // Exclude cancelled
            paymentStatus: { $in: ['Paid'] } // Only actual revenue? Or all "valid" orders? 
            // Revenue usually implies Paid.
        };

        if (branchId) {
            const mongoose = require('mongoose');
            matchStage.branchId = new mongoose.Types.ObjectId(branchId);
        }

        const aggregation = [
            { $match: matchStage },
            {
                $group: {
                    _id: { $dateToString: { format: intervalFormat, date: "$createdAt" } },
                    totalRevenue: { $sum: "$totalAmount" },
                    count: { $sum: 1 }
                }
            },
            { $sort: { _id: 1 } } // Sort by date ascending
        ];

        const stats = await Order.aggregate(aggregation);

        // Fill in missing dates? (Optional, Frontend can handle or we do it here)
        // For MVP, return sparse data.

        // Total Summary
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
        const { limit = 5, branchId } = req.query;

        const matchStage = {
            status: { $nin: ['Cancelled', 'Refunded'] }
        };
        if (branchId) {
            const mongoose = require('mongoose');
            matchStage.branchId = new mongoose.Types.ObjectId(branchId);
        }

        const stats = await Order.aggregate([
            { $match: matchStage },
            { $unwind: "$items" },
            {
                $group: {
                    _id: "$items.name", // or itemId if consistent
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
