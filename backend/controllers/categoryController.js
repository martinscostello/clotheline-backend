const Category = require('../models/Category');

exports.getAllCategories = async (req, res) => {
    try {
        const { branchId } = req.query;
        let query = { isActive: true };

        if (branchId) {
            query.branchId = branchId;
        } else {
            // STRICT ISOLATION FOR LEGACY APPS
            // If no branchId is passed, only return "Global" categories
            query.$or = [
                { branchId: { $exists: false } },
                { branchId: null }
            ];
        }

        const categories = await Category.find(query).sort({ name: 1 });
        res.json(categories);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.createCategory = async (req, res) => {
    try {
        const { name, image, branchId } = req.body;

        // Find if category already exists IN THIS BRANCH
        let query = { name };
        if (branchId) query.branchId = branchId;

        let category = await Category.findOne(query);
        if (category) {
            return res.status(400).json({ msg: 'Category already exists in this branch' });
        }

        category = new Category({ name, image, branchId });
        await category.save();
        res.json(category);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.deleteCategory = async (req, res) => {
    try {
        const category = await Category.findById(req.params.id);
        if (!category) return res.status(404).json({ msg: 'Category not found' });

        await Category.deleteOne({ _id: req.params.id });
        res.json({ msg: 'Category removed' });
    } catch (err) {
        console.error(err.message);
        if (err.kind === 'ObjectId') return res.status(404).json({ msg: 'Category not found' });
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
