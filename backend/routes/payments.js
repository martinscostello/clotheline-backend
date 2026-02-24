const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Payment = require('../models/Payment');
const Order = require('../models/Order');
const User = require('../models/User');
const axios = require('axios');

// Paystack Config
const PAYSTACK_SECRET = process.env.PAYSTACK_SECRET_KEY;
if (!PAYSTACK_SECRET) {
    console.warn("[Paystack] WARNING: PAYSTACK_SECRET_KEY is not defined in environment variables. Falling back to test key.");
}
const ACTUAL_SECRET = PAYSTACK_SECRET; // REMOVED hardcoded test key for production safety

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
        if (!scope || !['cart', 'bucket', 'combined', 'adjustment'].includes(scope)) {
            return res.status(400).json({ msg: 'Payment Scope (cart, bucket, combined, adjustment) is required.' });
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

        let finalTotal = itemsTotal;
        let deliveryFee = 0;
        let pickupFee = 0;
        let totalDiscount = 0;

        if (scope === 'adjustment') {
            if (!orderId) return res.status(400).json({ msg: 'orderId is required for adjustments' });
            const order = await Order.findById(orderId);
            if (!order) return res.status(404).json({ msg: 'Order not found' });
            if (!order.feeAdjustment || order.feeAdjustment.amount <= 0) {
                return res.status(400).json({ msg: 'No adjustment needed for this order' });
            }
            finalTotal = order.feeAdjustment.amount;
        } else if (req.body.fulfillmentMode === 'deployment' && req.body.quoteStatus === 'Pending') {
            // [CRITICAL] Inspection Fee Only. No VAT, No Discounts.
            finalTotal = Number(req.body.inspectionFee) || 0;
            if (finalTotal <= 0) {
                // Fallback to manual sum if field is missing but items have it
                finalTotal = req.body.items.reduce((sum, i) => sum + (Number(i.inspectionFee) || 0), 0);
            }
            // If still zero, use a default safety
            if (finalTotal <= 0) finalTotal = 10000;

            deliveryFee = 0;
            pickupFee = 0;
            totalDiscount = 0;
        } else {
            // Add Logistics Fees for normal orders
            deliveryFee = Number(req.body.deliveryFee) || 0;
            pickupFee = Number(req.body.pickupFee) || 0;

            // [FIX] Subtract Discounts
            const laundryDiscounts = req.body.discountBreakdown || {};
            const totalLaundryDiscount = Object.values(laundryDiscounts).reduce((a, b) => a + (Number(b) || 0), 0);
            const storeDiscountValue = Number(req.body.storeDiscount) || 0;
            totalDiscount = totalLaundryDiscount + storeDiscountValue;

            finalTotal = itemsTotal + deliveryFee + pickupFee - totalDiscount;

            // [New] Store discount in metadata for persistency
            req.metadata_discount = totalDiscount;
        }

        // Paystack Min Amount is 1 Naira (100 Kobo)
        if (finalTotal < 50) { // Safety buffer
            finalTotal = 100; // Force min amount if it's too small or zero
        }

        const amountKobo = Math.round(finalTotal * 100);

        const reference = `REF_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

        // Use User's email from DB or Request (Validation?)
        const user = await User.findById(userId);
        const email = user ? user.email : (req.body.email || 'user@clotheline.app');

        // 2. Initialize with Paystack DIRECTLY (Strip bulky fields to prevent 400 error)
        const metadata = {
            userId: userId,
            scope,
            branchId,
            items: calculationItems.map(i => ({
                itemId: i.itemId,
                name: i.name,
                itemType: i.itemType,
                quantity: i.quantity,
                price: i.price,
                variant: i.variant,
                serviceType: i.serviceType
            })),
            retryOrderId,
            deliveryFee,
            pickupFee,
            discountAmount: req.metadata_discount || 0, // Persist discount
            pickupOption: req.body.pickupOption,
            deliveryOption: req.body.deliveryOption,
            pickupAddress: req.body.pickupAddress,
            pickupPhone: req.body.pickupPhone,
            deliveryAddress: req.body.deliveryAddress,
            deliveryPhone: req.body.deliveryPhone,
            pickupLocation: req.body.pickupLocation,
            deliveryLocation: req.body.deliveryLocation,
            pickupCoordinates: req.body.pickupCoordinates,
            deliveryCoordinates: req.body.deliveryCoordinates,
            guestInfo: req.body.guestInfo,
            laundryNotes: req.body.laundryNotes
        };

        console.log(`[Paystack] Initializing: Email=${email}, Amount=${amountKobo}, Ref=${reference}`);

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
                    Authorization: `Bearer ${ACTUAL_SECRET}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        if (!paystackResponse.data.status) {
            return res.status(400).json({ msg: 'Paystack initialization failed: ' + (paystackResponse.data.message || '') });
        }

        const { authorization_url, access_code } = paystackResponse.data.data;

        // 3. RETURN URL. NO DB SAVES.
        res.json({
            authorization_url,
            reference,
            access_code
        });

    } catch (err) {
        console.error("Paystack Init Error [VERBOSE]:", {
            message: err.message,
            stack: err.stack,
            responseData: err.response?.data,
            requestBody: req.body ? { itemCount: req.body.items?.length, scope: req.body.scope, branchId: req.body.branchId } : 'No Body'
        });

        const errorMsg = err.response?.data?.message || err.message || 'An unknown error occurred';
        res.status(500).json({ msg: 'Payment Init Error: ' + errorMsg });
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
        console.log(`[VerifyTrigger] Attempting verification for Reference: ${reference}, User: ${req.user.id}`);

        const existingPayment = await Payment.findOne({ reference });
        if (existingPayment && existingPayment.status === 'success') {
            return res.json({ msg: 'Payment already verified', status: 'success', order: { _id: existingPayment.orderId } });
        }

        // 2. Verify with Provider
        let verifiedData = null;
        if (provider === 'paystack') {
            const response = await axios.get(`https://api.paystack.co/transaction/verify/${reference}`, {
                headers: { Authorization: `Bearer ${ACTUAL_SECRET}` }
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
        console.log(`[VerifyDebug] Metadata received:`, JSON.stringify(metadata, null, 2));
        const { retryOrderId, userId } = metadata;

        if (!userId) {
            console.error(`[VerifyError] Missing userId in metadata:`, metadata);
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

            // [NEW] Handle Fee Adjustment Success
            if (metadata.scope === 'adjustment') {
                order.feeAdjustment.status = 'Paid';
                order.feeAdjustment.paymentReference = reference;
                order.status = 'New'; // Return to processing

                // Update the locked totalAmount to include the extra fee now that it is paid
                const extra = order.feeAdjustment.amount || 0;
                order.totalAmount += extra;

                // Also update the delivery override to reflect the new total delivery fee
                const currentFee = order.isFeeOverridden ? (order.deliveryFeeOverride || 0) : (order.deliveryFee || 0);
                order.deliveryFeeOverride = currentFee + extra;
                order.isFeeOverridden = true;

                await order.save();
            } else {
                // [CRITICAL FIX] Lock in the Price
                // Ensure Order Total matches exactly what was paid.
                const paidAmountNaira = payment.amount / 100;

                // Allow small float diff (0.5), otherwise correct it.
                if (Math.abs(order.totalAmount - paidAmountNaira) > 1.0) {
                    console.warn(`[PriceCorrection] Order Total (${order.totalAmount}) diverged from Paid Amount (${paidAmountNaira}). Forcing correction.`);
                    order.totalAmount = paidAmountNaira;
                    // We could also adjust tax/subtotal proportionally, but ensures Total is paramount.
                    order.paymentStatus = 'Paid'; // Re-affirm
                    await order.save();
                }
            }
        }

        await payment.save();

        res.json({ status: 'success', msg: 'Payment verified', order });

    } catch (err) {
        console.error("Verification Error [VERBOSE]:", {
            message: err.message,
            stack: err.stack,
            responseData: err.response?.data,
            reference: req.body.reference
        });
        const errorMsg = err.response?.data?.message || err.message || 'Verification Error';
        res.status(500).json({ msg: 'Payment Verification Error: ' + errorMsg });
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
                        Authorization: `Bearer ${ACTUAL_SECRET}`,
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

// POST /refund-partial (Admin Only)
router.post('/refund-partial', auth, async (req, res) => {
    try {
        const requestor = await User.findById(req.user.id);
        if (!requestor || requestor.role !== 'admin') {
            return res.status(403).json({ msg: 'Access denied. Admins only.' });
        }

        const { orderId, refundedItemIds } = req.body; // Array of _id strings from items array

        if (!refundedItemIds || !Array.isArray(refundedItemIds) || refundedItemIds.length === 0) {
            return res.status(400).json({ msg: 'No items selected for refund.' });
        }

        const Order = require('../models/Order');
        const originalOrder = await Order.findById(orderId);
        if (!originalOrder) return res.status(404).json({ msg: 'Order not found' });

        const payment = await Payment.findOne({ orderId: orderId, status: 'success' });
        // NOTE: We allow partial refunds even if payment not found? No, must have paid to refund.
        if (!payment) return res.status(404).json({ msg: 'No successful payment found.' });

        // 1. Separate Items
        const itemsToRefund = [];
        const itemsRemaining = [];
        let refundAmount = 0;

        originalOrder.items.forEach(item => {
            // Check if this item is in the refund list (match ObjectIds)
            // item._id is likely an ObjectId, refundedItemIds are likely strings
            if (refundedItemIds.includes(item._id.toString())) {
                itemsToRefund.push(item);
                refundAmount += (item.price * item.quantity);
            } else {
                itemsRemaining.push(item);
            }
        });

        if (itemsToRefund.length === 0) {
            return res.status(400).json({ msg: 'Selected items not found in order.' });
        }

        // 2. Adjust Refund Amount (Add Tax?)
        // Calculate tax portion for these items
        // Simplified: (ItemTotal / Subtotal) * TaxAmount
        // Precision might be tricky. Let's re-calculate tax for the refund chunk.
        const settings = { taxRate: 7.5 }; // Should fetch from DB settings
        const refundTax = (refundAmount * settings.taxRate) / 100;
        const totalRefundValue = refundAmount + refundTax;

        // Convert to Kobo
        const refundAmountKobo = Math.round(totalRefundValue * 100);

        // 3. Process Refund with Paystack
        if (payment.provider === 'paystack') {
            try {
                const response = await axios.post('https://api.paystack.co/refund', {
                    transaction: payment.reference,
                    amount: refundAmountKobo,
                    customer_note: "Partial Refund for specific items",
                    merchant_note: `Partial refund of ${itemsToRefund.length} items`
                }, {
                    headers: {
                        Authorization: `Bearer ${ACTUAL_SECRET}`,
                        'Content-Type': 'application/json'
                    }
                });

                if (!response.data.status) {
                    return res.status(400).json({ msg: 'Paystack refund failed: ' + response.data.message });
                }

                // 4. Success! Now Split the Order.

                // A. Create New Order for Remaining Items (if any)
                let newOrder = null;
                if (itemsRemaining.length > 0) {
                    const { createOrderInternal } = require('../controllers/orderController');
                    // Re-construct order data
                    const orderData = {
                        branchId: originalOrder.branchId,
                        items: itemsRemaining,
                        pickupOption: originalOrder.pickupOption,
                        deliveryOption: originalOrder.deliveryOption,
                        pickupAddress: originalOrder.pickupAddress,
                        pickupPhone: originalOrder.pickupPhone,
                        deliveryAddress: originalOrder.deliveryAddress,
                        deliveryPhone: originalOrder.deliveryPhone,
                        guestInfo: originalOrder.guestInfo,
                        // Financials will be re-calculated by createOrderInternal
                    };

                    // We need to bypass Auth check if guest? createOrderInternal handles it.
                    // But originalOrder.user might be null.
                    newOrder = await createOrderInternal(orderData, originalOrder.user ? originalOrder.user.toString() : null);

                    // Carry over payment status
                    newOrder.paymentStatus = 'Paid';
                    // Inherit status from parent
                    newOrder.status = originalOrder.status;
                    await newOrder.save();
                }

                // B. Update Original Order to be the "Refunded" Record
                originalOrder.items = itemsToRefund; // Keep only refunded items
                originalOrder.status = 'Refunded';
                originalOrder.paymentStatus = 'Refunded';
                originalOrder.subtotal = refundAmount;
                originalOrder.taxAmount = refundTax;
                originalOrder.totalAmount = totalRefundValue;
                // Add reference to child
                if (newOrder) {
                    originalOrder.exceptionNote = `Split: Remaining items moved to Order #${newOrder._id.toString().slice(-6).toUpperCase()}`;
                }
                await originalOrder.save();

                // C. Update Payment Record
                payment.refundStatus = 'partial';
                payment.refundedAmount = (payment.refundedAmount || 0) + refundAmountKobo;
                await payment.save();

                // D. Notify User
                const Notification = require('../models/Notification');
                if (originalOrder.user) {
                    const message = newOrder
                        ? `Partial Refund: ${itemsToRefund.length} items refunded. Remaining items are processing in Order #${newOrder._id.toString().slice(-6).toUpperCase()}.`
                        : `Partial Refund for ${itemsToRefund.length} items processed.`;

                    await new Notification({
                        userId: originalOrder.user,
                        title: 'Partial Refund Processed',
                        message,
                        type: 'order',
                        branchId: originalOrder.branchId
                    }).save();
                }

                return res.json({
                    msg: 'Partial refund successful',
                    originalOrder, // Refunded part
                    newOrder // Active part
                });

            } catch (e) {
                console.error("Partial Refund API Error:", e.response?.data || e.message);
                return res.status(500).json({ msg: 'Refund API Failed' });
            }
        } else {
            return res.status(400).json({ msg: 'Provider not supported for auto-refund yet.' });
        }

    } catch (err) {
        console.error("Partial Refund Route Error:", err);
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
