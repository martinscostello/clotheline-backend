const mongoose = require('mongoose');

const posTransactionSchema = new mongoose.Schema({
    branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch', required: true },
    transactionType: {
        type: String,
        required: true
    },
    amount: { type: Number, required: true }, // Legacy field (terminalAmount)
    withdrawalAmount: { type: Number, default: 0 },
    customerCharge: { type: Number, default: 0 },
    chargeMode: {
        type: String,
        enum: ['Included', 'Cash'],
        default: 'Included'
    },
    terminalAmount: { type: Number, default: 0 },
    providerFee: { type: Number, default: 0 },
    netProfit: { type: Number, default: 0 },
    status: {
        type: String,
        enum: ['pending', 'resolved', 'unresolved', 'cancelled'],
        default: 'pending'
    },
    notes: { type: String },
    enteredBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
}, { timestamps: true });

module.exports = mongoose.model('POSTransaction', posTransactionSchema);
