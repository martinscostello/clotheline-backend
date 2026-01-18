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
// POST /initialize
// Stateless Payment Initialization
router.post('/initialize', async (req, res) => {
    try {
        // [CRITICAL USER MANDATE] NO DB WRITES. NO USER ID REQUIREMENT.
        const { items, branchId, orderId, provider = 'paystack', guestInfo, deliveryOption, deliveryAddress } = req.body;

        let calculationItems = items;
        let retryOrderId = null;

        // [RETRY FLOW] If orderId provided, we fetch just to get the items/pricing.
        // We do NOT write to DB.
        if (orderId) {
            const existingOrder = await Order.findById(orderId);
            if (!existingOrder) return res.status(404).json({ msg: 'Order not found' });
            calculationItems = existingOrder.items;
            retryOrderId = existingOrder._id.toString();
        }

        // 1. Calculate Amount Securely
        const { calculateOrderTotal } = require('../controllers/orderController');
        const { totalAmount } = await calculateOrderTotal(calculationItems);
        const amountKobo = Math.round(totalAmount * 100);

        const reference = `REF_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

        // Resolve Email (Guest or User - passed from frontend or default)
        // Since we removed Auth middleware requirement for strict statelessness?
        // User said "Remove userId requirement".
        // We will try to use provided email, else "guest@clotheline.com"
        const email = guestInfo?.email || req.body.email || 'guest@clotheline.app';

        // 2. Initialize with Paystack DIRECTLY
        // We embed all critical order info in METADATA so we can reconstruct it on verify.

        // [Sanitization] Ensure userId is null if not provided or empty string
        let validUserId = null;
        if (req.body.userId && req.body.userId.length > 0) {
            validUserId = req.body.userId;
        } else if (req.user && req.user.userId) {
            validUserId = req.user.userId;
        }

        const metadata = {
            ...req.body,
            retryOrderId,
            // Ensure items are included for reconstruction
            items: calculationItems,
            userId: validUserId
        };

        const paystackResponse = await axios.post(
            'https://api.paystack.co/transaction/initialize',
            {
                email,
                amount: amountKobo,
                reference,
                currency: 'NGN',
                callback_url: 'https://standard.paystack.co/close',
                metadata
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

        // 3. RETURN URL. NO DB SAVES.
        res.json({
            authorization_url,
            reference,
            access_code
        });

    } catch (err) {
        console.error("Paystack Init Error:", err.response?.data || err.message);
        res.status(500).send('Server Error');
    }
});

// POST /verify
// Verifies & Creates Order
router.post('/verify', async (req, res) => {
    try {
        const { reference, provider = 'paystack' } = req.body;

        // 1. Check if we already processed this reference locally?
        // User mandate: "ONLY THEN create payment record".
        // So we might not have it. We check to avoid duplicates.
        const existingPayment = await Payment.findOne({ reference });
        if (existingPayment && existingPayment.status === 'success') {
            return res.json({ msg: 'Payment already verified', status: 'success', order: { _id: existingPayment.orderId } });
        }

        // 2. Verify with Provider
        let verifiedData = null;
        if (provider === 'paystack') {
            const response = await axios.get(`https://api.paystack.co/transaction/verify/${reference}`, {
                headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` }
            });
            if (response.data.status && response.data.data.status === 'success') {
                verifiedData = response.data.data;
            }
        }

        if (!verifiedData) {
            return res.status(400).json({ msg: 'Verification failed via provider' });
        }

        // 3. RECONSTRUCT CONTEXT from Metadata
        const metadata = verifiedData.metadata || {};
        const { retryOrderId, userId } = metadata;

        // 4. Create Payment Record (NOW we save)
        const payment = new Payment({
            userId: userId, // extracted from metadata
            amount: verifiedData.amount,
            currency: 'NGN',
            provider,
            reference,
            accessCode: null, // Not needed really
            status: 'success',
            verifiedAt: Date.now(),
            metadata
        });

        let order;

        // 5. Create or Update Order
        if (retryOrderId) {
            const Order = require('../models/Order');
            order = await Order.findById(retryOrderId);
            if (order) {
                order.paymentStatus = 'Paid';
                order.status = 'New';
                await order.save();
            }
        } else {
            const { createOrderInternal } = require('../controllers/orderController');
            // We pass the metadata as orderData.
            // createOrderInternal handles DB creation.
            try {
                // If metadata missing items, we fail.
                order = await createOrderInternal(metadata, userId);
                order.paymentStatus = 'Paid';
                await order.save();
            } catch (e) {
                console.error("Order Create Failed:", e);
                // Payment is saved, but order failed.
                payment.status = 'flagged'; // partial success
                await payment.save();
                return res.status(500).json({ msg: 'Payment successful but Order creation failed', reference });
            }
        }

        if (order) {
            payment.orderId = order._id;
        }

        await payment.save();

        res.json({ status: 'success', msg: 'Payment verified', order });

    } catch (err) {
        console.error("Verification Error:", err);
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
