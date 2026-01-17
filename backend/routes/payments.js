const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Payment = require('../models/Payment');
const Order = require('../models/Order');
const axios = require('axios');

// Paystack Config
const PAYSTACK_SECRET = process.env.PAYSTACK_SECRET_KEY || 'sk_test_xxxx'; // Fallback for dev

// POST /initialize
// Initializes a transaction Securely via Paystack API
router.post('/initialize', auth, async (req, res) => {
    try {
        const { items, branchId, orderId, provider = 'paystack' } = req.body;

        let calculationItems = items;
        let retryOrderId = null;

        // [RETRY FLOW] If orderId provided, fetch items from existing order
        if (orderId) {
            const existingOrder = await Order.findById(orderId);
            if (!existingOrder) return res.status(404).json({ msg: 'Order to pay not found' });

            // Check if already paid
            if (existingOrder.paymentStatus === 'Paid') {
                return res.status(400).json({ msg: 'Order already paid' });
            }

            calculationItems = existingOrder.items;
            retryOrderId = existingOrder._id.toString();
        }

        // 1. Calculate Amount Securely
        const { calculateOrderTotal } = require('../controllers/orderController');
        const { totalAmount } = await calculateOrderTotal(calculationItems);

        // Amount in Kobo
        const amountKobo = Math.round(totalAmount * 100);
        const reference = `REF_${Date.now()}`; // Unique ref

        // Resolve Email
        let email = req.body.guestInfo?.email;
        if (!email && req.user) {
            const User = require('../models/User');
            const user = await User.findById(req.user.userId);
            if (user) email = user.email;
        }
        if (!email) email = 'user@example.com';

        // 2. Initialize with Paystack
        const paystackResponse = await axios.post(
            'https://api.paystack.co/transaction/initialize',
            {
                email: email,
                amount: amountKobo,
                reference: reference,
                currency: 'NGN',
                callback_url: 'https://standard.paystack.co/close',
                metadata: {
                    custom_fields: []
                }
            },
            {
                headers: {
                    Authorization: `Bearer ${PAYSTACK_SECRET}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        if (!paystackResponse.data.status) {
            return res.status(400).json({ msg: 'Paystack initialization failed' });
        }

        const { authorization_url, access_code } = paystackResponse.data.data;

        // 3. Create Payment Record
        const payment = new Payment({
            userId: req.user.userId,
            amount: amountKobo,
            currency: 'NGN',
            provider: provider,
            reference: reference,
            accessCode: access_code,
            status: 'pending',
            metadata: {
                ...req.body, // New Order Data
                retryOrderId: retryOrderId // [CRITICAL] Store if this is a retry
            }
        });

        await payment.save();

        res.json({
            authorization_url: authorization_url,
            reference: reference,
            access_code: access_code
        });

    } catch (err) {
        console.error("Paystack Init Error:", err.response?.data || err.message);
        res.status(500).send('Server Error');
    }
});

// POST /verify
// Verifies a transaction reference with Paystack
router.post('/verify', auth, async (req, res) => {
    try {
        const { reference, provider = 'paystack' } = req.body;

        const payment = await Payment.findOne({ reference });
        if (!payment) return res.status(404).json({ msg: 'Payment not found' });

        if (payment.status === 'success') {
            return res.json({ msg: 'Payment already verified', status: 'success' });
        }

        let verified = false;

        if (provider === 'paystack') {
            try {
                const response = await axios.get(`https://api.paystack.co/transaction/verify/${reference}`, {
                    headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` }
                });

                const data = response.data.data;
                if (data.status === 'success') {
                    // Check amount matches (allow small diff for float errors if needed, but kobo should be exact)
                    if (data.amount >= payment.amount) {
                        verified = true;
                    }
                }
            } catch (e) {
                console.error("Paystack Verification Error:", e.response?.data || e.message);
                return res.status(400).json({ msg: 'Verification failed via provider' });
            }
        }

        if (verified) {
            payment.status = 'success';
            payment.verifiedAt = new Date();

            let order;

            // CHECK IF RETRY
            if (payment.metadata && payment.metadata.retryOrderId) {
                // [RETRY FLOW] Update existing order
                const Order = require('../models/Order');
                order = await Order.findById(payment.metadata.retryOrderId);
                if (order) {
                    order.paymentStatus = 'Paid';
                    // Reset status to New if it was Pending/Failed?
                    // Usually retries are on Pending orders.
                    order.status = 'New';
                    await order.save();
                }
            } else {
                // [NEW ORDER FLOW] Create Order
                const { createOrderInternal } = require('../controllers/orderController');
                const orderData = payment.metadata;
                try {
                    order = await createOrderInternal(orderData, payment.userId);
                    // Set to Paid
                    order.paymentStatus = 'Paid';
                    await order.save();
                } catch (err) {
                    console.error("Order Creation Failed after Payment:", err);
                    return res.status(500).json({ msg: 'Payment successful but Order creation failed. Contact Support.', reference });
                }
            }

            // Link Order to Payment
            if (order) {
                payment.orderId = order._id;
                await payment.save();
                return res.json({ status: 'success', msg: 'Payment verified', order });
            } else {
                // Edge case: Retry order not found?
                return res.status(404).json({ msg: 'Payment verified but Retry Order not found' });
            }

        } else {
            payment.status = 'failed';
            await payment.save();
            return res.json({ status: 'failed', msg: 'Payment verification failed' });
        }

    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});
// POST /refund (Admin Only)
router.post('/refund', auth, async (req, res) => {
    try {
        // Enforce Admin
        const requestor = await User.findById(req.user.userId);
        if (!requestor || requestor.role !== 'admin') {
            return res.status(403).json({ msg: 'Access denied. Admins only.' });
        }

        const { orderId, amount } = req.body; // Optional amount for partial 

        const payment = await Payment.findOne({ orderId: orderId, status: 'success' });
        if (!payment) return res.status(404).json({ msg: 'No successful payment found for this order.' });

        if (payment.refundStatus === 'completed' || payment.refundStatus === 'processing') {
            return res.status(400).json({ msg: 'Refund already in progress or completed.' });
        }

        // Amount to refund (Kobo)
        const refundAmount = amount ? Math.round(amount * 100) : payment.amount;

        if (refundAmount > payment.amount) {
            return res.status(400).json({ msg: 'Refund amount exceeds payment amount.' });
        }

        if (payment.provider === 'paystack') {
            try {
                // Call Paystack Refund API
                const response = await axios.post('https://api.paystack.co/refund', {
                    transaction: payment.reference,
                    amount: refundAmount,
                    merchant_note: "Admin initiated refund"
                }, {
                    headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` }
                });


                if (response.data.status) {
                    payment.refundStatus = 'processing'; // Paystack refunds are not instant
                    payment.refundedAmount = refundAmount;
                    payment.refundReference = response.data.data.reference; // Refund reference? (Check API)
                    await payment.save();

                    // Update Order Status?
                    // "Refunded orders remain Cancelled or Completed (with refund tag)"
                    // Keep Order status as is, but maybe add a flag?
                    // For now, relying on Payment Status.

                    return res.json({ msg: 'Refund initiated successfully', refund: response.data.data });
                } else {
                    return res.status(400).json({ msg: 'Paystack refund failed: ' + response.data.message });
                }

            } catch (e) {
                console.error("Refund API Error:", e.response?.data || e.message);
                return res.status(500).json({ msg: 'Refund API Error' });
            }
        } else {
            return res.status(400).json({ msg: 'Provider not supported for auto-refund yet.' });
        }

    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// GET /status/:orderId
router.get('/status/:orderId', auth, async (req, res) => {
    try {
        const payment = await Payment.findOne({ orderId: req.params.orderId });
        if (!payment) return res.json({ status: 'unpaid' });
        res.json({
            status: payment.status,
            refundStatus: payment.refundStatus,
            amount: payment.amount,
            refundedAmount: payment.refundedAmount
        });
    } catch (err) {
        res.status(500).send('Server Error');
    }
});
// GET / (Admin)
router.get('/', auth, async (req, res) => {
    // Check Admin
    // ...
    res.json([]); // Placeholder
});

module.exports = router;
