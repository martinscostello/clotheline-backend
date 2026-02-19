const mongoose = require('mongoose');

const ExpenseSchema = new mongoose.Schema({
    branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch', required: true },
    title: { type: String, required: true },
    amount: { type: Number, required: true }, // in Kobo
    category: {
        type: String,
        enum: ['Salaries', 'Utilities', 'Rent', 'Maintenance', 'Supplies', 'Marketing', 'Logistics', 'Other'],
        default: 'Other'
    },
    description: String,
    date: { type: Date, default: Date.now },
    recordedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    isRecurring: { type: Boolean, default: false },
    recurrenceInterval: { type: String, enum: ['Daily', 'Weekly', 'Monthly', 'Yearly'] },
    attachments: [String] // URLs to receipts/invoices
}, { timestamps: true });

module.exports = mongoose.model('Expense', ExpenseSchema);
