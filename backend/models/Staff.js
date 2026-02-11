const mongoose = require('mongoose');

const WarningSchema = new mongoose.Schema({
    reason: { type: String, required: true },
    severity: {
        type: String,
        enum: ['Low', 'Medium', 'Severe'],
        default: 'Low'
    },
    notes: { type: String },
    issuedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    sentViaWhatsApp: { type: Boolean, default: false },
    timestamp: { type: Date, default: Date.now }
});

const StaffSchema = new mongoose.Schema({
    name: { type: String, required: true },
    email: { type: String },
    phone: { type: String, required: true },
    position: { type: String, required: true },
    branchId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Branch',
        required: true
    },
    warnings: [WarningSchema],
    salaryNotes: { type: String },
    isArchived: { type: Boolean, default: false },
    archiveReason: { type: String },
    createdAt: { type: Date, default: Date.now }
}, { timestamps: true });

module.exports = mongoose.model('Staff', StaffSchema);
