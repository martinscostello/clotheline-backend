const mongoose = require('mongoose');

const AppContentSchema = new mongoose.Schema({
    heroCarousel: [{
        imageUrl: { type: String, required: true },
        title: String,
        titleColor: { type: String, default: "0xFFFFFFFF" }, // Default white
        tagLine: String,
        tagLineColor: { type: String, default: "0xFFFFFFFF" },
        actionUrl: String,
        mediaType: { type: String, default: 'image', enum: ['image', 'video'] },
        active: { type: Boolean, default: true }
    }],
    homeGridServices: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Service'
    }],
    productAds: [{
        imageUrl: { type: String, required: true },
        targetScreen: String,
        active: { type: Boolean, default: true }
    }],
    brandText: {
        type: String,
        default: "Premium Laundry Services"
    },
    productCategories: {
        type: [String],
        default: ["Fragrances", "Softeners", "Household", "Cleaning", "Accesories", "Beddings", "Clothes", "Special"]
    },
    contactAddress: { type: String, default: "123 Laundry St, Lagos" },
    contactPhone: { type: String, default: "+234 800 000 0000" },
    freeShippingThreshold: { type: Number, default: 25000 }
}, { timestamps: true });

// Ensure we only have one config document
AppContentSchema.statics.getSingleton = async function () {
    let doc = await this.findOne();
    if (!doc) {
        doc = await this.create({
            heroCarousel: [],
            homeGridServices: [],
            productAds: [],
            brandText: "Premium Laundry Services",
            productCategories: ["Fragrances", "Softeners", "Household", "Cleaning", "Accesories", "Beddings", "Clothes", "Special"]
        });
    }
    return doc;
};

module.exports = mongoose.model('AppContent', AppContentSchema);
