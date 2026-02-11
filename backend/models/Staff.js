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
    staffId: { type: String, unique: true }, // Auto-generated ID
    name: { type: String, required: true },
    email: { type: String },
    phone: { type: String, required: true },
    address: { type: String },
    position: {
        type: String,
        required: true,
        enum: ['Manager', 'Supervisor', 'Secretary', 'POS Attendant', 'Laundry Worker', 'Dispatch']
    },
    passportPhoto: { type: String }, // URL/Path to image
    idCardImage: { type: String }, // Staff ID Card image
    signature: { type: String }, // Base64 or URL
    employmentDate: { type: Date, default: Date.now },
    branchId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Branch',
        required: true
    },
    // Account Details
    bankDetails: {
        bankName: String,
        accountNumber: String,
        accountName: String
    },
    // Guarantor Details
    guarantor: {
        name: String,
        phone: String,
        address: String,
        relationship: String,
        occupation: String,
        idImage: String
    },
    // Salary System
    salary: {
        grade: { type: String, default: 'Level 1' },
        baseSalary: { type: Number, default: 0 },
        cycle: { type: String, enum: ['Monthly', 'Weekly'], default: 'Monthly' },
        lastPaidDate: Date,
        nextPaymentDueDate: Date,
        status: { type: String, enum: ['Paid', 'Pending', 'Overdue'], default: 'Pending' }
    },
    paymentHistory: [{
        amount: Number,
        date: { type: Date, default: Date.now },
        reference: String,
        status: String
    }],
    // Performance
    performance: {
        rating: { type: Number, default: 5.0, min: 0, max: 5 },
        notes: String,
        log: [{
            date: { type: Date, default: Date.now },
            note: String,
            rating: Number
        }]
    },
    // Probation
    probation: {
        durationMonths: { type: Number, default: 3 },
        status: { type: String, enum: ['On Probation', 'Completed', 'Extended'], default: 'On Probation' }
    },
    warnings: [WarningSchema],
    status: {
        type: String,
        enum: ['Active', 'Suspended', 'Resigned', 'Dismissed'],
        default: 'Active'
    },
    isSuspended: { type: Boolean, default: false },
    isArchived: { type: Boolean, default: false },
    archiveReason: { type: String },
    createdAt: { type: Date, default: Date.now }
}, { timestamps: true });

// Auto-generate Staff ID before saving
StaffSchema.pre('save', async function () {
    if (!this.staffId) {
        try {
            const lastStaff = await this.constructor.findOne({}, {}, { sort: { 'createdAt': -1 } });
            let nextId = 1;
            if (lastStaff && lastStaff.staffId) {
                const lastIdNum = parseInt(lastStaff.staffId.split('-')[1]);
                if (!isNaN(lastIdNum)) {
                    nextId = lastIdNum + 1;
                }
            }
            this.staffId = `CL-${nextId.toString().padStart(4, '0')}`;
        } catch (err) {
            console.error("Staff ID generation error:", err);
            // Fallback to timestamp if something goes wrong
            this.staffId = `CL-${Date.now().toString().slice(-4)}`;
        }
    }
});

module.exports = mongoose.model('Staff', StaffSchema);
