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
    return settings;
};

// GET /settings (Admin Only, or Public for Cart calculation?)
// Probably need public access for Cart to see Tax Rate, but maybe restricted edit.
// Let's make GET public (or user auth) so app can calculate tax. Post is Admin only.

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
        const requestor = await User.findById(req.user.userId);
        if (!requestor || requestor.role !== 'admin') {
            return res.status(403).json({ msg: 'Access denied. Admins only.' });
        }

        const { taxEnabled, taxRate, taxName } = req.body;

        let settings = await getSettings();

        if (taxEnabled !== undefined) settings.taxEnabled = taxEnabled;
        if (taxRate !== undefined) settings.taxRate = taxRate;
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
