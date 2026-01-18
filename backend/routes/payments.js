const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Payment = require('../models/Payment');
const Order = require('../models/Order');
const User = require('../models/User');
const axios = require('axios');

// Paystack Config
const PAYSTACK_SECRET = process.env.PAYSTACK_SECRET_KEY || 'sk_test_xxxx'; // Fallback for dev

// POST /initialize
// Initializes a transaction Securely via Paystack API
// POST /initialize
// Stateless Payment Initialization
// POST /initialize
// Initializes a transaction Securely via Paystack API
router.post('/initialize', auth, async (req, res) => {
    try {
        // [CRITICAL AUTH] User must be logged in.
        if (!req.user || !req.user.id) {
            return res.status(401).json({ msg: 'Authentication required for payment' });
        }
        const userId = req.user.id;

        const { items, scope, branchId, orderId, provider = 'paystack', deliveryOption, deliveryAddress } = req.body;

        // [STRICT SCOPE ENFORCEMENT]
        if (!scope || !['cart', 'bucket', 'combined'].includes(scope)) {
            return res.status(400).json({ msg: 'Payment Scope (cart, bucket, combined) is required.' });
        }

        let calculationItems = items;

        // Filter based on Scope
        if (scope === 'bucket') {
            // Laundry Only
            calculationItems = items.filter(i => i.itemType === 'Service');
        } else if (scope === 'cart') {
            // Store Only
            calculationItems = items.filter(i => i.itemType === 'Product');
        }
        // 'combined' takes all items safely.

        let retryOrderId = null;

        // [RETRY FLOW]
        if (orderId) {
            const existingOrder = await Order.findById(orderId);
            if (!existingOrder) return res.status(404).json({ msg: 'Order not found' });
            // Ensure user owns this order
            if (existingOrder.user.toString() !== userId) {
                return res.status(403).json({ msg: 'Access denied to this order' });
            }
            calculationItems = existingOrder.items;
            retryOrderId = existingOrder._id.toString();
        }

        // 1. Calculate Amount Securely
        const { calculateOrderTotal } = require('../controllers/orderController');
        const { totalAmount: itemsTotal } = await calculateOrderTotal(calculationItems);

        // Add Logistics Fees
        const deliveryFee = Number(req.body.deliveryFee) || 0;
        const pickupFee = Number(req.body.pickupFee) || 0;
        const finalTotal = itemsTotal + deliveryFee + pickupFee;

        const amountKobo = Math.round(finalTotal * 100);

        const reference = `REF_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

        // Use User's email from DB or Request (Validation?)
        const user = await User.findById(userId);
        const email = user ? user.email : (req.body.email || 'user@clotheline.app');

        // 2. Initialize with Paystack DIRECTLY
        const metadata = {
            ...req.body,
            retryOrderId,
            items: calculationItems,
            userId: userId // STRICT: From Auth Token
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
router.post('/verify', auth, async (req, res) => {
    try {
        if (!req.user || !req.user.id) {
            return res.status(401).json({ msg: 'Authentication required for verification' });
        }
        // Strict: Logged in user should match the one who initiated? 
        // We will trust the metadata's userId but ensure valid context.

        const { reference, provider = 'paystack' } = req.body;

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

        if (!userId) {
            return res.status(400).json({ msg: 'Invalid Transaction: Missing User Context' });
        }

        // 4. Create Payment Record
        const payment = new Payment({
            userId: userId,
            amount: verifiedData.amount,
            currency: 'NGN',
            provider,
            reference,
            accessCode: null,
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
            try {
                // Strict: Pass userId explicitly
                order = await createOrderInternal(metadata, userId);
                order.paymentStatus = 'Paid';
                await order.save();
            } catch (e) {
                console.error("Order Create Failed:", e);
                payment.status = 'flagged';
                await payment.save();
                return res.status(500).json({ msg: 'Payment successful but Order creation failed', error: e.message });
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
        // [FIX] req.user.id is the standard from auth middleware
        const requestor = await User.findById(req.user.id);

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
                    customer_note: "Admin initiated refund",
                    merchant_note: "Admin initiated refund via dashboard"
                }, {
                    headers: {
                        Authorization: `Bearer ${PAYSTACK_SECRET}`,
                        'Content-Type': 'application/json'
                    }
                });


                if (response.data.status) {
                    payment.refundStatus = 'processing'; // Paystack refunds are not instant
                    payment.refundedAmount = refundAmount;
                    payment.refundReference = response.data.data.reference;
                    await payment.save();

                    // Update Order Status
                    const Order = require('../models/Order');
                    const order = await Order.findById(payment.orderId || orderId);
                    if (order) {
                        order.status = 'Refunded';
                        order.paymentStatus = 'Refunded'; // [NEW] Sync payment status
                        await order.save();

                        // Notify User via App Notification
                        const Notification = require('../models/Notification');
                        await new Notification({
                            userId: order.user,
                            title: 'Order Refunded',
                            message: `Your order #${order._id.toString().slice(-6).toUpperCase()} has been refunded.`,
                            type: 'order',
                            branchId: (order.branchId || order.branch)?.toString()
                        }).save();

                        // Notify User via Email (Instant)
                        try {
                            const sendEmail = require('../utils/sendEmail');
                            const user = await User.findById(order.user);
                            if (user) {
                                await sendEmail({
                                    email: user.email,
                                    subject: 'Clotheline: Order Refunded',
                                    message: `Your order #${order._id.toString().slice(-6).toUpperCase()} has been refunded successfully. The amount should reflect in your account shortly.`
                                });
                            }
                        } catch (emailErr) {
                            console.error("Refund Email Failed:", emailErr);
                        }
                    }

                    return res.json({ msg: 'Refund initiated successfully', refund: response.data.data });
                } else {
                    return res.status(400).json({ msg: 'Paystack refund failed: ' + response.data.message });
                }

            } catch (e) {
                console.error("Refund API Error details:", e.response?.data || e.message);
                const errorMsg = e.response?.data?.message || 'Refund API Error';
                return res.status(500).json({ msg: errorMsg });
            }
        } else {
            return res.status(400).json({ msg: 'Provider not supported for auto-refund yet.' });
        }

    } catch (err) {
        console.error("Refund Route Error:", err);
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
