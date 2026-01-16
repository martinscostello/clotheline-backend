const mongoose = require('mongoose');

const promotionSchema = new mongoose.Schema({
    code: { type: String, required: true, unique: true, uppercase: true, trim: true },
    description: { type: String },
    type: { type: String, enum: ['percentage', 'fixed'], required: true },
    value: { type: Number, required: true }, // % or Fixed Amount

    // Scope
    branchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Branch', default: null }, // Null = Global

    // Constraints
    minOrderAmount: { type: Number, default: 0 },
    maxDiscountAmount: { type: Number }, // For percentage caps
    usageLimit: { type: Number, default: null }, // Global limit
    usedCount: { type: Number, default: 0 },

    // Validity
    isActive: { type: Boolean, default: true },
    validFrom: { type: Date, default: Date.now },
    validTo: { type: Date },

    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
}, { timestamps: true });

module.exports = mongoose.model('Promotion', promotionSchema);
