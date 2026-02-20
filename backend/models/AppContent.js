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
        videoThumbnail: String,
        duration: { type: Number, default: 5000 }, // [NEW] Duration in MS
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
    promotionalTemplates: [{
        title: { type: String, required: true },
        message: { type: String, required: true }
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
    freeShippingThreshold: { type: Number, default: 25000 },
    deliveryAssurance: {
        text: { type: String, default: "Arrives in as little as [2 days]" },
        icon: { type: String, enum: ['van', 'bike', 'clock'], default: 'van' },
        active: { type: Boolean, default: true }
    }
}, { timestamps: true });

// Ensure we only have one config document
AppContentSchema.statics.getSingleton = async function () {
    let doc = await this.findOne();
    if (!doc) {
        doc = await this.create({
            heroCarousel: [],
            homeGridServices: [],
            productAds: [],
            promotionalTemplates: [
                { title: "Weekend Laundry Discount! 🎉", message: "Enjoy 20% off all laundry services this weekend! Tap here to book your pickup now and let us handle your dirty work." },
                { title: "Restock Your Cleaning Supplies 🧴", message: "Running low on your favorite detergents or fragrances? Order now from the Clotheline Store and get fast delivery right to your door." },
                { title: "Free Delivery Today Only! 🚚", message: "Don't miss out! We are offering FREE delivery on all laundry pickups and store orders placed today. Order now!" },
                { title: "Refresh Your Wardrobe ✨", message: "Got a special occasion coming up? Trust us to make your favorite outfits look brand new. Book a premium wash today." }
            ],
            brandText: "Premium Laundry Services",
            productCategories: ["Fragrances", "Softeners", "Household", "Cleaning", "Accesories", "Beddings", "Clothes", "Special"],
            deliveryAssurance: {
                text: "Arrives in as little as [2 days]",
                icon: "van",
                active: true
            }
        });
    }
    return doc;
};

module.exports = mongoose.model('AppContent', AppContentSchema);
