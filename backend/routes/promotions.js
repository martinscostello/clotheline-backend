const express = require('express');
const router = express.Router();
const Promotion = require('../models/Promotion');
const auth = require('../middleware/auth');
const admin = require('../middleware/admin'); // Assuming you have an admin middleware

// --- PUBLIC / USER ---

// Validate Promo Code
router.post('/validate', auth, async (req, res) => {
    try {
        const { code, branchId, cartTotal } = req.body;

        if (!code || !branchId) {
            return res.status(400).json({ isValid: false, message: 'Code and Branch ID are required' });
        }

        const promo = await Promotion.findOne({
            code: code.toUpperCase(),
            isActive: true
        });

        if (!promo) {
            return res.status(404).json({ isValid: false, message: 'Invalid or expired code' });
        }

        // 1. Check Date
        const now = new Date();
        if (promo.validFrom && now < promo.validFrom) return res.status(400).json({ isValid: false, message: 'Promotion not yet active' });
        if (promo.validTo && now > promo.validTo) return res.status(400).json({ isValid: false, message: 'Promotion expired' });

        // 2. Check Branch Scope (Strict)
        // If promo.branchId is set, it MUST match req.branchId
        if (promo.branchId && promo.branchId.toString() !== branchId) {
            return res.status(400).json({ isValid: false, message: 'This code is not valid for your current branch' });
        }
        // Note: If promo.branchId is null, it is Global, so it applies to ALL branches.

        // 3. Check Order Amount
        if (cartTotal < promo.minOrderAmount) {
            return res.status(400).json({ isValid: false, message: `Minimum order of ${promo.minOrderAmount} required` });
        }

        // 4. Check Usage Limit
        if (promo.usageLimit !== null && promo.usedCount >= promo.usageLimit) {
            return res.status(400).json({ isValid: false, message: 'Promotion usage limit reached' });
        }

        // 5. Calculate Discount
        let discountAmount = 0;
        if (promo.type === 'percentage') {
            discountAmount = (cartTotal * promo.value) / 100;
            if (promo.maxDiscountAmount && discountAmount > promo.maxDiscountAmount) {
                discountAmount = promo.maxDiscountAmount;
            }
        } else {
            discountAmount = promo.value;
        }

        // Ensure discount doesn't exceed total
        if (discountAmount > cartTotal) discountAmount = cartTotal;

        res.json({
            isValid: true,
            code: promo.code,
            type: promo.type,
            value: promo.value,
            discountAmount,
            promoId: promo._id,
            message: 'Promotion applied successfully'
        });

    } catch (err) {
        console.error(err);
        res.status(500).json({ isValid: false, message: 'Server error validating promotion' });
    }
});

// --- ADMIN ---

// Prepare Admin Auth Middleware
// const admin = require('../middleware/admin'); // Ensure this imports correctly from your codebase

// Create Promo
router.post('/', [auth, admin], async (req, res) => {
    try {
        const { code, type, value, branchId, validFrom, validTo, minOrderAmount, usageLimit, description } = req.body;

        // Check dupe
        const existing = await Promotion.findOne({ code: code.toUpperCase() });
        if (existing) return res.status(400).json({ msg: 'Promotion code already exists' });

        const newPromo = new Promotion({
            code, type, value, branchId, validFrom, validTo, minOrderAmount, usageLimit, description,
            createdBy: req.user.id
        });

        await newPromo.save();
        res.json(newPromo);
    } catch (err) {
        console.log(err);
        res.status(500).send('Server Error');
    }
});

// Get All Promos (Filter by Branch optional)
router.get('/', [auth, admin], async (req, res) => {
    try {
        const { branchId } = req.query;
        let query = {};
        if (branchId) {
            // Return Global + Specific Branch
            query = { $or: [{ branchId: null }, { branchId: branchId }] };
        }
        const promos = await Promotion.find(query).sort({ createdAt: -1 }).populate('branchId', 'name');
        res.json(promos);
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

// Toggle Active
router.put('/:id/toggle', [auth, admin], async (req, res) => {
    try {
        const promo = await Promotion.findById(req.params.id);
        if (!promo) return res.status(404).send('Promo not found');

        promo.isActive = !promo.isActive;
        await promo.save();
        res.json(promo);
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

// Delete
router.delete('/:id', [auth, admin], async (req, res) => {
    try {
        await Promotion.findByIdAndDelete(req.params.id);
        res.json({ msg: 'Promo removed' });
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

module.exports = router;
