const express = require('express');
const router = express.Router();
const AppContent = require('../models/AppContent');

// Get Content
router.get('/', async (req, res) => {
    try {
        const content = await AppContent.getSingleton();
        // Populate services for the grid
        await content.populate('homeGridServices');
        res.json(content);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// Update Content
router.put('/', async (req, res) => {
    try {
        let content = await AppContent.getSingleton();

        if (req.body.heroCarousel) {
            content.heroCarousel = req.body.heroCarousel;
            content.markModified('heroCarousel');
        }
        if (req.body.homeGridServices) {
            content.homeGridServices = req.body.homeGridServices;
            content.markModified('homeGridServices');
        }
        if (req.body.productAds) {
            content.productAds = req.body.productAds;
            content.markModified('productAds');
        }
        if (req.body.brandText) content.brandText = req.body.brandText;
        if (req.body.productCategories) content.productCategories = req.body.productCategories;

        // [NEW] Added support for new fields
        if (req.body.contactAddress) content.contactAddress = req.body.contactAddress;
        if (req.body.contactPhone) content.contactPhone = req.body.contactPhone;
        if (req.body.freeShippingThreshold !== undefined) content.freeShippingThreshold = req.body.freeShippingThreshold;
        if (req.body.deliveryAssurance) {
            content.deliveryAssurance = req.body.deliveryAssurance;
            content.markModified('deliveryAssurance');
        }

        const updatedContent = await content.save();
        res.json(updatedContent);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

module.exports = router;
