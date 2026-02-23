const express = require('express');
const router = express.Router();
const AppContent = require('../models/AppContent');

// Get Content
router.get('/', async (req, res) => {
    try {
        const { branchId } = req.query;
        let content = await AppContent.getSingleton();
        await content.populate('homeGridServices');

        // Convert to plain object to allow modification
        let contentObj = content.toObject();

        // 1. Handle Branch Overrides if branchId provided
        if (branchId && content.branchOverrides && content.branchOverrides.length > 0) {
            const override = content.branchOverrides.find(b => b.branchId && b.branchId.toString() === branchId);
            if (override) {
                // Merge Carousel (Replace if not empty)
                if (override.heroCarousel && override.heroCarousel.length > 0) {
                    contentObj.heroCarousel = override.heroCarousel;
                }
                // Merge Ads (Replace if not empty)
                if (override.productAds && override.productAds.length > 0) {
                    contentObj.productAds = override.productAds;
                }
            }
        }

        // Return the merged object
        res.json(contentObj);
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
        if (req.body.promotionalTemplates) {
            content.promotionalTemplates = req.body.promotionalTemplates;
            content.markModified('promotionalTemplates');
        }

        const updatedContent = await content.save();
        res.json(updatedContent);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// --- Branch Override Routes ---

// GET: Fetch a single branch's override
router.get('/branch-override/:branchId', async (req, res) => {
    try {
        const content = await AppContent.getSingleton();
        const override = content.branchOverrides.find(b => b.branchId && b.branchId.toString() === req.params.branchId);
        if (!override) return res.json({ branchId: req.params.branchId, heroCarousel: [], productAds: [] });
        res.json(override);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

// PUT: Upsert (create or update) a branch override
router.put('/branch-override', async (req, res) => {
    try {
        const { branchId, heroCarousel, productAds } = req.body;
        if (!branchId) return res.status(400).json({ message: 'branchId is required' });

        let content = await AppContent.getSingleton();
        const idx = content.branchOverrides.findIndex(b => b.branchId && b.branchId.toString() === branchId);

        if (idx === -1) {
            // Create new override
            content.branchOverrides.push({ branchId, heroCarousel: heroCarousel || [], productAds: productAds || [] });
        } else {
            // Update existing
            if (heroCarousel !== undefined) content.branchOverrides[idx].heroCarousel = heroCarousel;
            if (productAds !== undefined) content.branchOverrides[idx].productAds = productAds;
        }

        content.markModified('branchOverrides');
        const saved = await content.save();
        const updated = saved.branchOverrides.find(b => b.branchId && b.branchId.toString() === branchId);
        res.json(updated);
    } catch (err) {
        res.status(400).json({ message: err.message });
    }
});

// DELETE: Remove a branch override completely (reverts to global)
router.delete('/branch-override/:branchId', async (req, res) => {
    try {
        let content = await AppContent.getSingleton();
        const before = content.branchOverrides.length;
        content.branchOverrides = content.branchOverrides.filter(b => !b.branchId || b.branchId.toString() !== req.params.branchId);
        if (content.branchOverrides.length !== before) {
            content.markModified('branchOverrides');
            await content.save();
        }
        res.json({ success: true, message: 'Branch override removed. Falls back to global content.' });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
});

module.exports = router;

