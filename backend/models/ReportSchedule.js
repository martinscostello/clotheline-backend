const mongoose = require('mongoose');

const ReportScheduleSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, // Who setup the report
    frequency: { type: String, enum: ['Daily', 'Weekly', 'Monthly'], required: true },
    recipients: [{ type: String }], // Email addresses
    branches: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Branch' }], // Specific branches or empty for all
    includeCharts: { type: Boolean, default: true },
    includeRawData: { type: Boolean, default: false }, // CSV attachment
    lastSentAt: Date,
    nextRunAt: Date,
    isActive: { type: Boolean, default: true }
}, { timestamps: true });

module.exports = mongoose.model('ReportSchedule', ReportScheduleSchema);
