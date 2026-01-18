const Category = require('../models/Category');

exports.getAllCategories = async (req, res) => {
    try {
        const categories = await Category.find({ isActive: true }).sort({ name: 1 });
        res.json(categories);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.createCategory = async (req, res) => {
    try {
        const { name, image } = req.body;
        let category = await Category.findOne({ name });
        if (category) {
            return res.status(400).json({ msg: 'Category already exists' });
        }

        category = new Category({ name, image });
        await category.save();
        res.json(category);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Helper to seed defaults if empty
exports.seedCategories = async () => {
    try {
        const count = await Category.countDocuments();
        if (count === 0) {
            const defaults = ["Cleaning", "Ironing", "Accessories", "Specials"];
            await Category.insertMany(defaults.map(name => ({ name })));
            console.log("Seeded Default Categories");
        }
    } catch (err) {
        console.error("Category Seed Error:", err);
    }
};
