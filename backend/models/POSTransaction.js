const mongoose = require('mongoose');

const posTransactionSchema = new mongoose.Schema({
    branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch', required: true },
    transactionType: {
        type: String,
        enum: ['Withdrawal', 'Transfer', 'Deposit', 'Airtime', 'Other'],
        required: true
    },
    amount: { type: Number, required: true },
    charges: { type: Number, default: 0 },
    providerFee: { type: Number, default: 0 },
    netProfit: { type: Number, default: 0 },
    status: {
        type: String,
        enum: ['resolved', 'unresolved'],
        default: 'resolved'
    },
    notes: { type: String },
    enteredBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
}, { timestamps: true });

module.exports = mongoose.model('POSTransaction', posTransactionSchema);
