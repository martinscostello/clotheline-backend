const express = require('express');
const router = express.Router();
const Category = require('../models/Category');
const auth = require('../middleware/auth');



// GET all categories
router.get('/', async (req, res) => {
    try {
        const categories = await Category.find({ isActive: true }).sort({ name: 1 });
        // Return simple list of names for now to match current frontend expectation, 
        // OR return full objects and update frontend to handle them.
        // Frontend currently expects ["All", "Fragrance", ...].
        // But for Admin we need objects (id, name, image).
        // Let's return objects. Frontend StoreService needs update.
        res.json(categories);
    } catch (err) {
        res.status(500).json({ msg: 'Server Error' });
    }
});

// POST create category (Admin only)
router.post('/', auth, async (req, res) => {
    try {
        const { name, image } = req.body;

        let category = await Category.findOne({ name });
        if (category) {
            return res.status(400).json({ msg: 'Category already exists' });
        }

        category = new Category({
            name,
            image
        });

        await category.save();
        res.json(category);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// PUT update category
router.put('/:id', auth, async (req, res) => {
    try {
        const { name, image } = req.body;
        let category = await Category.findById(req.params.id);
        if (!category) return res.status(404).json({ msg: 'Category not found' });

        if (name) category.name = name;
        if (image !== undefined) category.image = image;

        await category.save();
        res.json(category);
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

// DELETE category
router.delete('/:id', auth, async (req, res) => {
    try {
        await Category.findByIdAndDelete(req.params.id);
        res.json({ msg: 'Category removed' });
    } catch (err) {
        res.status(500).send('Server Error');
    }
});

module.exports = router;
