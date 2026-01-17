const mongoose = require('mongoose');

const PaymentSchema = new mongoose.Schema({
    orderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Order', required: false }, // Optional initially (Order Intent)
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    amount: { type: Number, required: true }, // in Kobo (or base currency unit)
    currency: { type: String, default: 'NGN' },
    provider: { type: String, enum: ['paystack', 'flutterwave'], default: 'paystack' },
    reference: { type: String, required: true, unique: true },
    status: {
        type: String,
        enum: ['pending', 'success', 'failed', 'cancelled'],
        default: 'pending'
    },
    refundStatus: {
        type: String,
        enum: ['none', 'processing', 'completed', 'failed'],
        default: 'none'
    },
    refundedAmount: { type: Number, default: 0 },
    refundReference: { type: String },
    metadata: { type: mongoose.Schema.Types.Mixed },
    createdAt: { type: Date, default: Date.now },
    verifiedAt: { type: Date }
});

module.exports = mongoose.model('Payment', PaymentSchema);
