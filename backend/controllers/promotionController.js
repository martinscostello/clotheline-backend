const Promotion = require('../models/Promotion');

// POST /promotions (Admin)
exports.createPromotion = async (req, res) => {
    try {
        const { code, type, value, branchId, minOrderAmount, maxDiscountAmount, usageLimit, validTo } = req.body;

        const promotion = new Promotion({
            code,
            type,
            value,
            branchId: branchId || null,
            minOrderAmount,
            maxDiscountAmount,
            usageLimit,
            validTo,
            createdBy: req.user.id
        });

        await promotion.save();
        res.json(promotion);
    } catch (err) {
        if (err.code === 11000) return res.status(400).json({ msg: 'Promotion code already exists' });
        console.error(err);
        res.status(500).send('Server Error');
    }
};

// GET /promotions (Admin)
exports.getPromotions = async (req, res) => {
    try {
        // Filter?
        const promotions = await Promotion.find().sort({ createdAt: -1 });
        res.json(promotions);
    } catch (err) {
        res.status(500).send('Server Error');
    }
};

// DELETE /promotions/:id (Admin)
exports.deletePromotion = async (req, res) => {
    try {
        await Promotion.findByIdAndDelete(req.params.id);
        res.json({ msg: 'Promotion deleted' });
    } catch (err) {
        res.status(500).send('Server Error');
    }
};

// POST /promotions/validate (Public/User)
exports.validatePromotion = async (req, res) => {
    try {
        const { code, orderTotal, branchId } = req.body;

        const promo = await Promotion.findOne({ code, isActive: true });

        if (!promo) {
            return res.status(400).json({ msg: 'Invalid promotion code' });
        }

        // 1. Expiry
        if (promo.validTo && new Date() > promo.validTo) {
            return res.status(400).json({ msg: 'Promotion has expired' });
        }

        // 2. Start Date
        if (new Date() < promo.validFrom) {
            return res.status(400).json({ msg: 'Promotion not yet active' });
        }

        // 3. Branch Scope
        if (promo.branchId && branchId && promo.branchId.toString() !== branchId) {
            return res.status(400).json({ msg: 'Promotion not valid for this branch' });
        }

        // 4. Min Spend
        if (orderTotal < promo.minOrderAmount) {
            return res.status(400).json({ msg: `Minimum spend of ₦${promo.minOrderAmount} required` });
        }

        // 5. Usage Limit (Global)
        if (promo.usageLimit !== null && promo.usedCount >= promo.usageLimit) {
            return res.status(400).json({ msg: 'Promotion usage limit reached' });
        }

        // Calculate Discount
        let discount = 0;
        if (promo.type === 'percentage') {
            discount = (orderTotal * promo.value) / 100;
            if (promo.maxDiscountAmount && discount > promo.maxDiscountAmount) {
                discount = promo.maxDiscountAmount;
            }
        } else {
            discount = promo.value;
        }

        // Ensure discount doesn't exceed total key
        if (discount > orderTotal) discount = orderTotal; // Or cap at regular total

        res.json({
            valid: true,
            discountAmount: discount,
            promoId: promo._id,
            code: promo.code,
            description: promo.description,
            // Metadata for Frontend Recalculation
            type: promo.type,
            value: promo.value,
            maxDiscountAmount: promo.maxDiscountAmount,
            minOrderAmount: promo.minOrderAmount
        });

    } catch (err) {
        console.error("Promo Validation Error:", err);
        res.status(500).send('Server Error');
    }
};
