const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Payment = require('../models/Payment');
const Order = require('../models/Order');
const Expense = require('../models/Expense');
const Goal = require('../models/Goal');
const PDFDocument = require('pdfkit');
const mongoose = require('mongoose');

// Helper to build date/branch query
const buildQuery = (req) => {
    const { startDate, endDate, branchId } = req.query;
    let query = {};

    if (startDate && endDate) {
        query.createdAt = { $gte: new Date(startDate), $lte: new Date(endDate) };
    }

    // Branch filtering is often collection-specific, so we return the base date query
    // and let specific aggregations handle the lookup/match for branch.
    return { dateQuery: query, branchId, startDate, endDate };
};

// GET /financials
// Returns aggregated financial data (High-level Card Metrics)
router.get('/financials', auth, async (req, res) => {
    try {
        const { dateQuery, branchId, startDate, endDate } = buildQuery(req);

        // --- 1. REVENUE (Payments) ---
        const revenuePipeline = [{ $match: { ...dateQuery, status: 'success' } }];

        if (branchId) {
            revenuePipeline.push(
                { $lookup: { from: 'orders', localField: 'orderId', foreignField: '_id', as: 'order' } },
                { $unwind: { path: '$order', preserveNullAndEmptyArrays: false } },
                { $match: { 'order.branchId': new mongoose.Types.ObjectId(branchId) } }
            );
        }

        revenuePipeline.push({ $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } });
        const revenueAgg = await Payment.aggregate(revenuePipeline);
        const totalRevenue = revenueAgg[0]?.total || 0; // Kobo
        const txCount = revenueAgg[0]?.count || 0;

        // --- 2. REFUNDS ---
        const refundPipeline = [{ $match: { ...dateQuery, refundStatus: { $in: ['processing', 'completed'] } } }];
        if (branchId) {
            refundPipeline.push(
                { $lookup: { from: 'orders', localField: 'orderId', foreignField: '_id', as: 'order' } },
                { $unwind: { path: '$order', preserveNullAndEmptyArrays: false } }, // only matched orders
                { $match: { 'order.branchId': new mongoose.Types.ObjectId(branchId) } }
            );
        }
        refundPipeline.push({ $group: { _id: null, total: { $sum: '$refundedAmount' }, count: { $sum: 1 } } });
        const refundAgg = await Payment.aggregate(refundPipeline);
        const totalRefunds = refundAgg[0]?.total || 0;

        // --- 3. EXPENSES ---
        // Expenses have a direct branchId field
        let expenseQuery = { ...dateQuery };
        if (dateQuery.createdAt) { // Map createdAt to date field in Expenses if needed, but Expense uses 'date' or 'createdAt'. Let's use 'date' for business logic if schema has it, else createdAt. Schema has 'date'.
            // fix: map dateQuery.createdAt to expense.date
            expenseQuery = { date: dateQuery.createdAt };
        }

        if (branchId) {
            expenseQuery.branchId = new mongoose.Types.ObjectId(branchId);
        }

        const expenseAgg = await Expense.aggregate([
            { $match: expenseQuery },
            { $group: { _id: null, total: { $sum: '$amount' } } }
        ]);
        const totalExpenses = expenseAgg[0]?.total || 0;

        // --- 4. NET CALC ---
        const grossProfit = totalRevenue - totalRefunds;
        const netProfit = grossProfit - totalExpenses;

        // --- 5. GOALS & PROJECTIONS ---
        // Fetch active goal
        let goalQuery = { isActive: true, period: 'Monthly' }; // Default to Monthly for now
        if (branchId) goalQuery.branchId = branchId;

        const currentGoal = await Goal.findOne(goalQuery).sort({ createdAt: -1 }); // Get latest

        // Simple Linear Projection (if date range is "This Month")
        let projectedRevenue = 0;
        if (startDate && endDate) {
            const start = new Date(startDate);
            const end = new Date(endDate);
            const now = new Date();

            // If viewing current month
            if (end > now && start <= now) {
                const daysPassed = Math.max(1, (now - start) / (1000 * 60 * 60 * 24));
                const dailyAvg = totalRevenue / daysPassed;
                const totalDays = (end - start) / (1000 * 60 * 60 * 24);
                projectedRevenue = dailyAvg * totalDays;
            }
        }

        res.json({
            revenue: totalRevenue,
            refunds: totalRefunds,
            expenses: totalExpenses,
            grossProfit,
            netProfit,
            txCount,
            goal: currentGoal ? {
                target: currentGoal.targetAmount,
                progress: (totalRevenue / currentGoal.targetAmount) * 100
            } : null,
            projectedRevenue: Math.floor(projectedRevenue)
        });

    } catch (err) {
        console.error("Financials Error:", err);
        res.status(500).send('Server Error');
    }
});

// GET /analytics
// Detailed charts and breakdowns
router.get('/analytics', auth, async (req, res) => {
    try {
        const { dateQuery, branchId } = buildQuery(req);

        // 1. Revenue Over Time (Daily/Weekly points)
        // Group by day
        const chartPipeline = [{ $match: { ...dateQuery, status: 'success' } }];
        if (branchId) {
            chartPipeline.push(
                { $lookup: { from: 'orders', localField: 'orderId', foreignField: '_id', as: 'order' } },
                { $unwind: '$order' },
                { $match: { 'order.branchId': new mongoose.Types.ObjectId(branchId) } }
            );
        }
        chartPipeline.push({
            $group: {
                _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
                amount: { $sum: "$amount" }
            }
        });
        chartPipeline.push({ $sort: { _id: 1 } });
        const revenueChart = await Payment.aggregate(chartPipeline);

        // 2. Breakdown by Service/Product Type (Logic: look at Order Items)
        // This is heavy. usage: Unwind Order Items -> Group by Item Name/Category.
        // Optimizing: Just do "Payment Method" breakdown for now as it's easier and requested.
        // User requested: Laundry vs Store.
        // We need lookup orders -> unwind items -> group by itemType.
        const categoryPipeline = [{ $match: { ...dateQuery, status: 'success' } }];
        if (branchId) {
            categoryPipeline.push(
                { $lookup: { from: 'orders', localField: 'orderId', foreignField: '_id', as: 'order' } },
                { $unwind: '$order' },
                { $match: { 'order.branchId': new mongoose.Types.ObjectId(branchId) } }
            );
        } else {
            categoryPipeline.push(
                { $lookup: { from: 'orders', localField: 'orderId', foreignField: '_id', as: 'order' } },
                { $unwind: '$order' }
            );
        }

        /* 
           Complex Aggregation for Store vs Laundry Revenue:
           Since Payment is total for order, we must split it ratio-wise or just sum OrderSubtotals if we trust Order data.
           Let's sum Order Items directly for this breakdown, assuming paid orders.
        */
        categoryPipeline.push({ $unwind: '$order.items' });
        categoryPipeline.push({
            $group: {
                _id: '$order.items.itemType', // 'Service' vs 'Product'
                total: { $sum: { $multiply: ['$order.items.price', '$order.items.quantity'] } }
            }
        });
        const categorySplit = await Payment.aggregate(categoryPipeline); // Note: This uses Payment as entry but calculates from Order Items. 
        // Warning: If partial payment, this assumes full order value. Acceptable for "Sales" report.

        // 3. Payment Methods
        const methodPipeline = [{ $match: { ...dateQuery, status: 'success' } }];
        // Flatten branch filter if needed (same as revenue)
        if (branchId) {
            methodPipeline.push(
                { $lookup: { from: 'orders', localField: 'orderId', foreignField: '_id', as: 'order' } },
                { $unwind: '$order' },
                { $match: { 'order.branchId': new mongoose.Types.ObjectId(branchId) } }
            );
        }
        methodPipeline.push({
            $group: {
                _id: '$provider', // or order.paymentMethod if we prefer that. Payment.provider is 'paystack' etc.
                total: { $sum: '$amount' },
                count: { $sum: 1 }
            }
        });
        const paymentMethods = await Payment.aggregate(methodPipeline);

        res.json({
            chart: revenueChart,
            categories: categorySplit,
            paymentMethods: paymentMethods
        });

    } catch (err) {
        console.error("Analytics Error:", err);
        res.status(500).send('Server Error');
    }
});

// --- EXPENSES ---

router.get('/expenses', auth, async (req, res) => {
    try {
        const { dateQuery, branchId } = buildQuery(req);
        let query = {};
        if (dateQuery.createdAt) query.date = dateQuery.createdAt;
        if (branchId) query.branchId = branchId;

        const expenses = await Expense.find(query).sort({ date: -1 }).populate('recordedBy', 'name');
        res.json(expenses);
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

router.post('/expenses', auth, async (req, res) => {
    try {
        const { branchId, title, amount, category, date } = req.body;
        const expense = new Expense({
            branchId,
            title,
            amount,
            category,
            date: date || new Date(),
            recordedBy: req.user.id
        });
        await expense.save();
        res.json(expense);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

router.delete('/expenses/:id', auth, async (req, res) => {
    try {
        await Expense.findByIdAndDelete(req.params.id);
        res.json({ msg: 'Deleted' });
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

// --- GOALS ---

router.get('/goals', auth, async (req, res) => {
    try {
        const { branchId } = req.query;
        let query = {};
        if (branchId) query.branchId = branchId;

        const goals = await Goal.find(query).sort({ createdAt: -1 });
        res.json(goals);
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

router.post('/goals', auth, async (req, res) => {
    try {
        const { branchId, targetAmount, period, startDate, endDate } = req.body;
        const goal = new Goal({
            branchId,
            targetAmount,
            period,
            startDate,
            endDate,
            setBy: req.user.id
        });
        await goal.save();
        res.json(goal);
    } catch (err) {
        res.status(500).send(err.message);
    }
});


// GET /invoice/:orderId (Legacy kept intact)
router.get('/invoice/:orderId', auth, async (req, res) => {
    try {
        const order = await Order.findById(req.params.orderId);
        if (!order) return res.status(404).send('Order not found');

        const doc = new PDFDocument({ margin: 50 });
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename=invoice_${order._id}.pdf`);
        doc.pipe(res);

        doc.fontSize(20).text('CLOTHELINE', { align: 'left' });
        doc.moveDown();
        doc.fontSize(16).text('INVOICE', { align: 'right' });
        doc.fontSize(12).text(order._id.toString(), { align: 'right' });

        doc.moveDown();
        doc.text(`Amount: NGN ${(order.totalAmount).toLocaleString()}`);
        doc.text(`Date: ${new Date(order.createdAt).toDateString()}`);

        doc.end();
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

module.exports = router;
