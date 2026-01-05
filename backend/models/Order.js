const mongoose = require('mongoose');

const OrderSchema = new mongoose.Schema({
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // Optional if guest checkout allowed, but typically required
    guestInfo: { // If no user account
        name: String,
        email: String,
        phone: String
    },

    // Items can be Mixed? Or separate arrays for Laundry vs Store?
    // Let's use a flexible structure.
    items: [{
        itemType: { type: String, enum: ['Service', 'Product'], required: true },
        itemId: { type: String, required: true }, // Service ID or Product ID
        name: String,
        variant: String, // For Products
        serviceType: String, // For Services (Wash & Fold, etc)
        quantity: { type: Number, default: 1 },
        price: { type: Number, required: true }
    }],

    totalAmount: { type: Number, required: true },

    status: {
        type: String,
        enum: ['New', 'InProgress', 'Ready', 'Completed', 'Cancelled'],
        default: 'New'
    },

    paymentStatus: { type: String, enum: ['Pending', 'Paid'], default: 'Pending' },

    // Logistics
    pickupOption: { type: String, enum: ['Pickup', 'Dropoff'], required: true },
    deliveryOption: { type: String, enum: ['Deliver', 'Pickup'], required: true },

    pickupAddress: String,
    pickupPhone: String,

    deliveryAddress: String,
    deliveryPhone: String,

    date: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Order', OrderSchema);
