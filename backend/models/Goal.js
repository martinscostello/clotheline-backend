const mongoose = require('mongoose');

const GoalSchema = new mongoose.Schema({
    branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch', required: false }, // If null, applies to All Branches (Global Goal)
    type: { type: String, enum: ['Revenue', 'Orders', 'NewCustomers'], default: 'Revenue' },
    targetAmount: { type: Number, required: true },
    period: { type: String, enum: ['Monthly', 'Annual'], required: true },
    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true },
    isActive: { type: Boolean, default: true },
    setBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
}, { timestamps: true });

module.exports = mongoose.model('Goal', GoalSchema);
