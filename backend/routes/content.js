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

        if (req.body.heroCarousel) content.heroCarousel = req.body.heroCarousel;
        if (req.body.homeGridServices) content.homeGridServices = req.body.homeGridServices;
        if (req.body.productAds) content.productAds = req.body.productAds;
        if (req.body.brandText) content.brandText = req.body.brandText;

        // [NEW] Added support for new fields
        if (req.body.contactAddress) content.contactAddress = req.body.contactAddress;
        if (req.body.contactPhone) content.contactPhone = req.body.contactPhone;
        if (req.body.freeShippingThreshold !== undefined) content.freeShippingThreshold = req.body.freeShippingThreshold;

        const updatedContent = await content.save();
        res.json(updatedContent);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

module.exports = router;
