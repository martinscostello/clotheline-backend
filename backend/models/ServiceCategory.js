const mongoose = require('mongoose');

const ServiceItemSchema = new mongoose.Schema({
    name: { type: String, required: true }, // e.g., "T-Shirt", "Duvet (King)"
    basePrice: { type: Number, required: true },
});

const ServiceCategorySchema = new mongoose.Schema({
    name: { type: String, required: true }, // e.g., "Regular Laundry", "Rug Cleaning"
    description: String,
    imageUrl: String, // URL for the glass card
    items: [ServiceItemSchema], // List of specific items under this category
    serviceTypes: [{ type: String }], // e.g., ["Wash & Fold", "Iron Only"]
    isActive: { type: Boolean, default: true }
});

module.exports = mongoose.model('ServiceCategory', ServiceCategorySchema);
