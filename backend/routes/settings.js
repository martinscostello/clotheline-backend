const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Settings = require('../models/Settings');
const User = require('../models/User');

// Helper to get or create settings
const getSettings = async () => {
    let settings = await Settings.findOne();
    if (!settings) {
        settings = new Settings();
        await settings.save();
    }

    // [FIX] Auto-Correct Abnormal Tax Rates (Prevent 10x Error)
    if (settings.taxRate > 50) {
        console.warn(`[Settings] Abnormal TaxRate ${settings.taxRate}% detected. Resetting to 7.5%.`);
        settings.taxRate = 7.5;
        await settings.save();
    }

    return settings;
};

// GET /settings (Public/Auth for Cart)
router.get('/', async (req, res) => {
    try {
        const settings = await getSettings();
        res.json(settings);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// POST /settings (Admin Only)
router.post('/', auth, async (req, res) => {
    try {
        // Enforce Admin
        const requestor = await User.findById(req.user.id);
        if (!requestor || requestor.role !== 'admin') {
            return res.status(403).json({ msg: 'Access denied. Admins only.' });
        }

        const { taxEnabled, taxRate, taxName } = req.body;

        let settings = await getSettings();

        if (taxEnabled !== undefined) settings.taxEnabled = taxEnabled;
        if (taxRate !== undefined) {
            // [FIX] Convert to number and Enforce Cap
            let rate = Number(taxRate);
            if (rate > 50) rate = 50; // Cap at 50%
            if (rate < 0) rate = 0;
            settings.taxRate = rate;
        }
        if (taxName !== undefined) settings.taxName = taxName;

        settings.updatedAt = Date.now();
        await settings.save();

        res.json(settings);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

module.exports = router;
