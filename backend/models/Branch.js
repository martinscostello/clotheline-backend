const mongoose = require('mongoose');

const DeliveryZoneSchema = new mongoose.Schema({
    name: { type: String, required: true },
    description: { type: String },
    radiusKm: { type: Number, required: true },
    baseFee: { type: Number, required: true },
    color: { type: String, default: '4286f4' }
});

const BranchSchema = new mongoose.Schema({
    name: { type: String, required: true }, // "Benin City", "Abuja"
    address: { type: String, required: true },
    phone: { type: String, required: true },

    // Geo Center for Delivery Calculations
    location: {
        lat: { type: Number, required: true },
        lng: { type: Number, required: true }
    },
    locationLastUpdated: { type: Date, default: Date.now },

    deliveryZones: [DeliveryZoneSchema],

    // Config
    isActive: { type: Boolean, default: true },
    isDefault: { type: Boolean, default: false }, // Fallback if no branch selected
    isPosTerminalEnabled: { type: Boolean, default: false }, // [NEW] feature toggle

    // POS Configuration [NEW]
    posConfig: {
        terminalDisplayName: { type: String },
        charges: {
            withdrawal: { type: Number, default: 0 },
            transfer: { type: Number, default: 0 },
            deliveryDeposit: { type: Number, default: 0 },
            opayTier: { type: String, enum: ['Platinum', 'Gold', 'Regular'], default: 'Regular' },
            enableSmartTiers: { type: Boolean, default: false },
            smartTiers: [{
                min: Number,
                max: Number,
                charge: Number
            }]
        },
        profitTarget: {
            enabled: { type: Boolean, default: false },
            amount: { type: Number, default: 0 }
        },
        security: {
            lockAfter24h: { type: Boolean, default: false },
            masterAdminOnly: { type: Boolean, default: false },
            requireReconciliation: { type: Boolean, default: false },
            requireDeleteConfirmation: { type: Boolean, default: true }
        },
        defaultOpeningCash: { type: Number, default: 0 },
        transactionTypes: {
            type: [{
                name: { type: String, required: true },
                hasProviderFee: { type: Boolean, default: true },
                hasCustomerCharge: { type: Boolean, default: true },
                hasTransferFlatFee: { type: Boolean, default: false }
            }],
            default: [
                { name: 'Withdrawal', hasProviderFee: true, hasCustomerCharge: true },
                { name: 'Transfer', hasProviderFee: true, hasCustomerCharge: true },
                { name: 'Deposit', hasProviderFee: true, hasCustomerCharge: true },
                { name: 'Airtime', hasProviderFee: false, hasCustomerCharge: true },
                { name: 'Electricity', hasProviderFee: false, hasCustomerCharge: true }
            ]
        }
    },

    categorySortOrder: {
        type: String,
        enum: ['alphabetical', 'newest', 'oldest'],
        default: 'alphabetical'
    },
    createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Branch', BranchSchema);
