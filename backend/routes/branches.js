const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Branch = require('../models/Branch');
const User = require('../models/User');

// --- SEED DATA ---
const BENIN_DATA = {
    name: "Benin",
    address: "4 Princess Ezomo Street, Airport Road, Opposite First Bank, Benin City",
    phone: "08123242359",
    location: { lat: 6.3033777, lng: 5.5944979 },
    isDefault: true,
    deliveryZones: [ // Zone A-E
        { name: "Zone A: Immediate Coverage", description: "0 - 2.5 km", radiusKm: 2.5, baseFee: 500, color: '#4CAF50' },
        { name: "Zone B: Core City", description: "2.5 - 5.5 km", radiusKm: 5.5, baseFee: 1000, color: '#2196F3' },
        { name: "Zone C: Extended City", description: "5.5 - 9 km", radiusKm: 9, baseFee: 2000, color: '#FFC107' },
        { name: "Zone D: Outskirts", description: "9 - 14 km", radiusKm: 14, baseFee: 3000, color: '#FF5722' },
        { name: "Zone E: Outside Service Area", description: "> 14 km", radiusKm: 9999, baseFee: 99999, color: '#9E9E9E' } // 99999 fee indicates "Out of Range"
    ]
};

const ABUJA_DATA = {
    name: "Abuja",
    address: "44 Ebitu Ukiwe Street, Suite B2, Busymart Plaza, Jabi, Abuja",
    phone: "07060827325",
    location: { lat: 9.0667295, lng: 7.4301391 },
    isDefault: false,
    deliveryZones: [
        { name: "Zone A: Immediate Coverage", description: "0 - 2.5 km", radiusKm: 2.5, baseFee: 1000, color: '#4CAF50' },
        { name: "Zone B: Core City", description: "2.5 - 5.5 km", radiusKm: 5.5, baseFee: 2000, color: '#2196F3' },
        { name: "Zone C: Extended City", description: "5.5 - 9 km", radiusKm: 9, baseFee: 3500, color: '#FFC107' },
        { name: "Zone D: Outskirts", description: "9 - 14 km", radiusKm: 14, baseFee: 5000, color: '#FF5722' },
        { name: "Zone E: Outside Service Area", description: "> 14 km", radiusKm: 9999, baseFee: 99999, color: '#9E9E9E' }
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

// PUT /branches/:id (Admin) - Update Branch
router.put('/:id', auth, async (req, res) => {
    try {
        // Enforce Admin
        const requestor = await User.findById(req.user.id);
        if (!requestor || requestor.role !== 'admin') {
            return res.status(403).json({ msg: 'Admins only' });
        }

        const { name, address, phone, location, deliveryZones } = req.body;

        // Find and Update
        const branch = await Branch.findById(req.params.id);
        if (!branch) return res.status(404).json({ msg: 'Branch not found' });

        if (name) branch.name = name;
        if (address) branch.address = address;
        if (phone) branch.phone = phone;
        if (location) branch.location = location;
        if (deliveryZones) branch.deliveryZones = deliveryZones;

        branch.locationLastUpdated = Date.now();

        await branch.save();
        res.json(branch);
    } catch (err) {
        console.error("Update Error:", err);
        res.status(500).send('Server Error');
    }
});


module.exports = router;
