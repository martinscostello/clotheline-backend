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
    const { startDate, endDate, branchId, type } = req.query; // type: 'Laundry' | 'Store'
    let query = {};

    if (startDate && endDate) {
        query.createdAt = { $gte: new Date(startDate), $lte: new Date(endDate) };
    }

    // Business Type Filter: Laundry (Service) vs Store (Product)
    if (type && type !== 'All') {
        const itemType = type === 'Laundry' ? 'Service' : 'Product';
        query['items.itemType'] = itemType;
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

        // --- 1. REVENUE (Total Sales Value) ---
        // Aligned with Dashboard: Includes Pending + Paid, Excludes Cancelled/Refunded
        const revenuePipeline = [
            {
                $match: {
                    ...dateQuery,
                    status: { $nin: ['Cancelled', 'Refunded'] } // Matches Analytics Controller
                }
            }
        ];
        if (branchId) revenuePipeline.push({ $match: { branchId: new mongoose.Types.ObjectId(branchId) } });

        revenuePipeline.push({
            $group: {
                _id: null,
                total: { $sum: '$totalAmount' },
                count: { $sum: 1 },
                taxes: { $sum: '$taxAmount' },
                deliveryFees: { $sum: '$deliveryFee' },
                discounts: { $sum: { $add: ['$discountAmount', '$storeDiscount'] } },
                // Calculate Collected Cash separately if needed, but for "Revenue" we show Total Sales
                cashCollected: {
                    $sum: {
                        $cond: [{ $eq: ["$paymentStatus", "Paid"] }, "$totalAmount", 0]
                    }
                }
            }
        });

        const revenueAgg = await Order.aggregate(revenuePipeline);
        const totalRevenue = revenueAgg[0]?.total || 0; // Total Sales Value
        const cashCollected = revenueAgg[0]?.cashCollected || 0; // Actual Cash
        const txCount = revenueAgg[0]?.count || 0;
        const totalTaxes = revenueAgg[0]?.taxes || 0;
        const totalDelivery = revenueAgg[0]?.deliveryFees || 0;
        const totalDiscounts = revenueAgg[0]?.discounts || 0;

        // --- 2. OUTSTANDING PAYMENTS (Pending Payment, Not Cancelled) ---
        const outstandingPipeline = [
            {
                $match: {
                    ...dateQuery,
                    paymentStatus: 'Pending',
                    status: { $ne: 'Cancelled' }
                }
            }
        ];
        if (branchId) outstandingPipeline.push({ $match: { branchId: new mongoose.Types.ObjectId(branchId) } });
        outstandingPipeline.push({ $group: { _id: null, total: { $sum: '$totalAmount' }, count: { $sum: 1 } } });

        const outstandingAgg = await Order.aggregate(outstandingPipeline);
        const outstandingPayments = outstandingAgg[0]?.total || 0;
        const pendingCount = outstandingAgg[0]?.count || 0; // "Pending Orders" count

        // --- 3. REFUNDS ---
        // Refunds might be tracked in Payments or Orders. 
        // Order schema has 'status': 'Refunded', 'paymentStatus': 'Refunded'.
        const refundPipeline = [
            {
                $match: {
                    ...dateQuery,
                    $or: [{ status: 'Refunded' }, { paymentStatus: 'Refunded' }]
                }
            }
        ];
        if (branchId) {
            refundPipeline.push({ $match: { branchId: new mongoose.Types.ObjectId(branchId) } });
        }
        // Note: Order might not have 'refundedAmount' field in schema visible in step 229, 
        // but 'Payment' has. If we strictly use Order, we might assume full refund? 
        // Or checking Payment is safer for refunds. Let's stick to Payment for Refunds if possible, 
        // OR assume totalAmount if status is Refunded. 
        // Let's use Payment for refunds as it has 'refundedAmount'.

        let totalRefunds = 0;
        try {
            // Fallback to Payment for accurate refund amount
            const paymentRefundPipeline = [
                { $match: { ...dateQuery, refundStatus: { $in: ['processing', 'completed'] } } }
            ];
            // Filter payments by branch via lookup if needed, but for robustness let's just use what we have.
            // If Order-based refund is needed:
            refundPipeline.push({ $group: { _id: null, total: { $sum: '$totalAmount' } } });
            // Logic: If using Order, we take totalAmount. 
            const refundOrderAgg = await Order.aggregate(refundPipeline);
            totalRefunds = refundOrderAgg[0]?.total || 0;
        } catch (e) {
            console.log("Refund agg error", e);
        }

        // --- 4. EXPENSES ---
        let expenseQuery = {};
        if (dateQuery.createdAt) { // map createdAt to date
            expenseQuery.date = dateQuery.createdAt;
        }
        if (branchId) {
            expenseQuery.branchId = new mongoose.Types.ObjectId(branchId);
        }

        const expenseAgg = await Expense.aggregate([
            { $match: expenseQuery },
            { $group: { _id: null, total: { $sum: '$amount' } } }
        ]);
        // Convert Expense (Kobo) back to Naira to match Revenue unit
        const totalExpenses = (expenseAgg[0]?.total || 0) / 100;

        // --- 5. CALCULATIONS ---
        const grossProfit = totalRevenue - totalRefunds; // Pure Sales Margin
        const netProfit = grossProfit - totalExpenses;
        const averageOrderValue = txCount > 0 ? (totalRevenue / txCount) : 0;

        // --- 6. GOALS ---
        let goalQuery = { isActive: true, period: 'Monthly' };
        if (branchId) goalQuery.branchId = branchId;

        const currentGoal = await Goal.findOne(goalQuery).sort({ createdAt: -1 });

        // Projection
        let projectedRevenue = 0;
        if (startDate && endDate) {
            const start = new Date(startDate);
            const end = new Date(endDate);
            const now = new Date();
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
            averageOrderValue, // [NEW]
            outstandingPayments, // [NEW]
            taxesCollected: totalTaxes, // [NEW]
            pendingOrdersCount: pendingCount, // [NEW]
            breakdown: { // [NEW] Detailed Revenue Breakdown
                deliveryFees: totalDelivery,
                discounts: totalDiscounts,
                netMargin: netProfit
            },
            goal: currentGoal ? {
                target: currentGoal.targetAmount,
                progress: (totalRevenue / currentGoal.targetAmount) * 100
            } : null,
            projectedRevenue: Math.floor(projectedRevenue)
        });

    } catch (err) {
        console.error("Financials Error:", err);
        // Send safe error for debugging if needed, or 0s?
        // Let's return 0s to prevent UI crash, but log error.
        res.status(500).json({ error: err.message });
    }
});

// GET /analytics
router.get('/analytics', auth, async (req, res) => {
    try {
        const { dateQuery, branchId } = buildQuery(req);

        // Base Match for Paid Orders
        const matchStage = {
            ...dateQuery,
            paymentStatus: 'Paid',
            status: { $ne: 'Cancelled' }
        };
        if (branchId) matchStage.branchId = new mongoose.Types.ObjectId(branchId);

        // 1. Revenue Chart
        const chartPipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
                    amount: { $sum: "$totalAmount" }
                }
            },
            { $sort: { _id: 1 } }
        ];
        const revenueChart = await Order.aggregate(chartPipeline);

        // 2. Breakdown (Items - Laundry vs Store)
        const categoryPipeline = [
            { $match: matchStage },
            { $unwind: "$items" },
            {
                $group: {
                    _id: "$items.itemType", // 'Service' vs 'Product'
                    total: { $sum: { $multiply: ["$items.price", "$items.quantity"] } }
                }
            }
        ];
        const categorySplit = await Order.aggregate(categoryPipeline);

        // 3. Payment Methods
        const methodPipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: "$paymentMethod",
                    total: { $sum: "$totalAmount" },
                    count: { $sum: 1 }
                }
            }
        ];
        const paymentMethods = await Order.aggregate(methodPipeline);

        // 4. Staff Performance [NEW]
        const staffPipeline = [
            { $match: matchStage },
            { $match: { createdByAdmin: { $ne: null } } }, // Only staff-created orders
            {
                $lookup: {
                    from: 'users',
                    localField: 'createdByAdmin',
                    foreignField: '_id',
                    as: 'staff'
                }
            },
            { $unwind: '$staff' },
            {
                $group: {
                    _id: '$staff.name',
                    count: { $sum: 1 },
                    revenue: { $sum: '$totalAmount' }
                }
            },
            { $sort: { revenue: -1 } },
            { $limit: 10 }
        ];
        const staffPerformance = await Order.aggregate(staffPipeline);

        // 5. Tax Breakdown (Monthly) [NEW]
        const taxPipeline = [
            { $match: { ...matchStage, taxAmount: { $gt: 0 } } },
            {
                $group: {
                    _id: { $dateToString: { format: "%Y-%m", date: "$createdAt" } },
                    taxCollected: { $sum: "$taxAmount" },
                    salesSubjectToTax: { $sum: "$subtotal" } // Estimate
                }
            },
            { $sort: { _id: 1 } }
        ];
        const taxBreakdown = await Order.aggregate(taxPipeline);

        res.json({
            chart: revenueChart,
            categories: categorySplit,
            paymentMethods: paymentMethods,
            staffPerformance, // [NEW]
            taxBreakdown // [NEW]
        });

    } catch (err) {
        console.error("Analytics Error:", err);
        res.status(500).json({ error: err.message });
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
