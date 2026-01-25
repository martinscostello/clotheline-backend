const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Payment = require('../models/Payment');
const Order = require('../models/Order');
const PDFDocument = require('pdfkit');

// GET /financials
// Returns aggregated financial data
router.get('/financials', auth, async (req, res) => {
    try {
        // Verify Admin
        // (Simulate Admin Check or use middleware if configured with roles)
        // req.user.role check needed if auth middleware doesn't enforce it

        const { startDate, endDate, branchId } = req.query;
        const mongoose = require('mongoose');

        let dateQuery = {};
        if (startDate && endDate) {
            dateQuery = { createdAt: { $gte: new Date(startDate), $lte: new Date(endDate) } };
        }

        // Helper to build pipeline
        const buildPipeline = (initialMatch) => {
            const pipeline = [{ $match: { ...initialMatch, ...dateQuery } }];

            if (branchId) {
                pipeline.push(
                    { $lookup: { from: 'orders', localField: 'orderId', foreignField: '_id', as: 'order' } },
                    { $unwind: { path: '$order', preserveNullAndEmptyArrays: false } }, // only matched orders
                    { $match: { 'order.branchId': new mongoose.Types.ObjectId(branchId) } }
                );
            }
            return pipeline;
        };

        // 1. Total Revenue (Success Payments)
        const revenueWithBranchWrapper = [
            ...buildPipeline({ status: 'success' }),
            { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } }
        ];
        const revenueAgg = await Payment.aggregate(revenueWithBranchWrapper);

        // 2. Refunds
        const refundWithBranchWrapper = [
            ...buildPipeline({ refundStatus: { $in: ['processing', 'completed'] } }),
            { $group: { _id: null, total: { $sum: '$refundedAmount' }, count: { $sum: 1 } } }
        ];
        const refundAgg = await Payment.aggregate(refundWithBranchWrapper);

        // 3. Pending Payments
        // countDocuments doesn't support aggregation lookup easily. Use aggregate.
        const pendingWrapper = [
            ...buildPipeline({ status: 'pending' }),
            { $count: 'count' }
        ];
        const pendingRes = await Payment.aggregate(pendingWrapper);
        const pendingCount = pendingRes[0]?.count || 0;

        // 4. Group by Provider (Revenue)
        const providerWrapper = [
            ...buildPipeline({ status: 'success' }),
            { $group: { _id: '$provider', total: { $sum: '$amount' }, count: { $sum: 1 } } }
        ];
        const providerAgg = await Payment.aggregate(providerWrapper);

        const totalRevenue = revenueAgg[0]?.total || 0;
        const totalRefunds = refundAgg[0]?.total || 0;

        res.json({
            revenue: totalRevenue, // Kobo
            netRevenue: totalRevenue - totalRefunds,
            refunds: totalRefunds,
            transactionVolume: revenueAgg[0]?.count || 0,
            refundCount: refundAgg[0]?.count || 0,
            pendingCount,
            byProvider: providerAgg
        });

    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// GET /invoice/:orderId
// Streaming PDF Response
router.get('/invoice/:orderId', auth, async (req, res) => {
    try {
        const order = await Order.findById(req.params.orderId);
        if (!order) return res.status(404).send('Order not found');

        // Fetch Payment (optional, for reference)
        const payment = await Payment.findOne({ orderId: order._id, status: 'success' });

        // Create PDF
        const doc = new PDFDocument({ margin: 50 });

        // Stream to response
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename=invoice_${order._id}.pdf`);
        doc.pipe(res);

        // --- PDF CONTENT ---

        // Header
        doc.fontSize(20).text('CLOTHELINE', { align: 'left' });
        doc.fontSize(10).text('123 Laundry Lane, Lagos, Nigeria', { align: 'left' });
        doc.moveDown();

        doc.fontSize(20).text('INVOICE', { align: 'right' });
        doc.fontSize(10).text(`Invoice #: INV-${order._id.toString().substring(0, 6).toUpperCase()}`, { align: 'right' });
        doc.text(`Date: ${new Date().toDateString()}`, { align: 'right' });
        doc.moveDown();

        // Billed To
        doc.text(`Billed To: ${order.guestInfo?.name || 'Customer'}`, { align: 'left' });
        doc.text(`Phone: ${order.guestInfo?.phone || order.pickupPhone || ''}`);
        doc.moveDown();

        // Table Header
        const tableTop = 250;
        doc.font('Helvetica-Bold');
        doc.text('Item', 50, tableTop);
        doc.text('Qty', 300, tableTop);
        doc.text('Price (NGN)', 350, tableTop);
        doc.text('Total', 450, tableTop);
        doc.font('Helvetica');

        let y = tableTop + 25;

        order.items.forEach(item => {
            const price = item.price;
            const total = price * item.quantity;

            doc.text(item.name, 50, y);
            doc.text(item.quantity.toString(), 300, y);
            doc.text(price.toLocaleString(), 350, y);
            doc.text(total.toLocaleString(), 450, y);
            y += 20;
        });

        doc.moveDown();
        doc.moveTo(50, y).lineTo(550, y).stroke();
        y += 10;

        // Totals
        doc.font('Helvetica-Bold');
        const subtotal = order.subtotal || order.totalAmount; // Fallback for old orders
        const taxVal = order.taxAmount || 0;
        const totalVal = order.totalAmount;

        doc.text(`Subtotal: NGN ${subtotal.toLocaleString()}`, 350, y, { align: 'left' });
        y += 15;
        if (taxVal > 0) {
            doc.text(`VAT (${order.taxRate}%): NGN ${taxVal.toLocaleString()}`, 350, y, { align: 'left' });
            y += 15;
        }
        doc.text(`Total: NGN ${totalVal.toLocaleString()}`, 350, y, { align: 'left' });

        // Status
        y += 30;
        const statusColor = order.paymentStatus === 'Paid' ? 'green' : 'red';
        doc.fillColor(statusColor).text(order.paymentStatus?.toUpperCase() || 'UNPAID', 50, y);
        doc.fillColor('black');

        // Footer
        doc.fontSize(10).text('Thank you for your business!', 50, 700, { align: 'center', width: 500 });

        doc.end();

    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

module.exports = router;
