const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Branch = require('../models/Branch');
const User = require('../models/User');

// --- SEED DATA ---
const BENIN_DATA = {
    name: "Benin",
    address: "4 Princess Ezomo Street, Airport Road, Opposite First Bank, Benin",
    phone: "08000000000", // Default
    location: { lat: 6.3033777, lng: 5.5944979 },
    isDefault: true,
    deliveryZones: [
        { name: "Zone A", description: "0-3km", radiusKm: 3, baseFee: 500 },
        { name: "Zone B", description: "3-8km", radiusKm: 8, baseFee: 1000 },
        { name: "Zone C", description: "8-15km", radiusKm: 15, baseFee: 2000 }
    ]
};

const ABUJA_DATA = {
    name: "Abuja",
    address: "44 Ebitu Ukiwe Street, Suite B2 Busymart Plaza, Jabi, Abuja",
    phone: "08000000000", // Default
    location: { lat: 9.0667295, lng: 7.4301391 },
    isDefault: false,
    deliveryZones: [
        { name: "Zone A", description: "Central Area (0-5km)", radiusKm: 5, baseFee: 1000 },
        { name: "Zone B", description: "Metro (5-12km)", radiusKm: 12, baseFee: 2000 },
        { name: "Zone C", description: "Outskirts (12-25km)", radiusKm: 25, baseFee: 3500 }
    ]
};

// POST /branches/seed (Admin) - Force Create Defaults
router.post('/seed', auth, async (req, res) => {
    try {
        const benin = new Branch(BENIN_DATA);
        const abuja = new Branch(ABUJA_DATA);
        await benin.save();
        await abuja.save();
        res.json([benin, abuja]);
    } catch (err) {
        console.error("Seeding Error:", err);
        res.status(500).send('Server Error: ' + err.message);
    }
});

// GET /branches (Public)
router.get('/', async (req, res) => {
    try {
        const branches = await Branch.find({ isActive: true });
        // Removed auto-seed logic here to avoid magic behavior confusion. 
        // Admin should click "Initialize" if empty.
        res.json(branches);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// POST /branches (Admin) - Create New
router.post('/', auth, async (req, res) => {
    try {
        // Enforce Admin is implied by logic usage, but strictly:
        const requestor = await User.findById(req.user.userId);
        if (!requestor || requestor.role !== 'admin') {
            return res.status(403).json({ msg: 'Admins only' });
        }

        const branch = new Branch(req.body);
        await branch.save();
        res.json(branch);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// GET /branches/:id
router.get('/:id', async (req, res) => {
    try {
        const branch = await Branch.findById(req.params.id);
        if (!branch) return res.status(404).json({ msg: 'Branch not found' });
        res.json(branch);
    } catch (err) {
        res.status(500).send('Server Error');
    }
});


module.exports = router;
