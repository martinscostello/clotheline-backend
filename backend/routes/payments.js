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
        const { orderId, provider = 'paystack' } = req.body;

        const order = await Order.findById(orderId);
        if (!order) return res.status(404).json({ msg: 'Order not found' });

        if (order.user.toString() !== req.user.userId) {
            return res.status(403).json({ msg: 'Unauthorized' });
        }

        // Amount in Kobo
        const amountKobo = Math.round(order.totalAmount * 100);
        const reference = `REF_${Date.now()}_${order._id}`;
        const email = order.guestInfo?.email || 'user@example.com';

        // 1. Initialize with Paystack (Server-Side)
        // This keeps the SECRET_KEY on the server.
        // We get back an authorization_url to send to the client.

        const paystackResponse = await axios.post(
            'https://api.paystack.co/transaction/initialize',
            {
                email: email,
                amount: amountKobo,
                reference: reference,
                currency: 'NGN',
                callback_url: 'https://standard.paystack.co/close', // Or your deep link scheme
                metadata: {
                    order_id: order._id.toString(),
                    custom_fields: [
                        {
                            display_name: "Order ID",
                            variable_name: "order_id",
                            value: order._id.toString()
                        }
                    ]
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

        // 2. Create Payment Record (Pending)
        const payment = new Payment({
            orderId: order._id,
            userId: req.user.userId,
            amount: amountKobo,
            currency: 'NGN',
            provider: provider,
            reference: reference, // Our internal ref (also sent to Paystack)
            accessCode: access_code,
            status: 'pending'
        });

        await payment.save();

        // 3. Return URL to Client (No Secrets!)
        res.json({
            authorization_url: authorization_url, // Client opens this
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
            // Server-Server Verification
            try {
                const response = await axios.get(`https://api.paystack.co/transaction/verify/${reference}`, {
                    headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` }
                });

                const data = response.data.data;
                if (data.status === 'success') {
                    // Check amount matches
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
            await payment.save();

            // Update Order
            await Order.findByIdAndUpdate(payment.orderId, {
                paymentStatus: 'Paid',
                status: 'New' // Move to New if it was Pending? Or Keep New. Prompt says "Order must NOT move to InProgress". 'New' is fine.
            });

            // Trigger Notification (Reuse existing logic or event bus)
            // Notify user & Admin (TODO)

            return res.json({ status: 'success', msg: 'Payment verified successfully' });
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
