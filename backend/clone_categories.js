const mongoose = require('mongoose');
require('dotenv').config();
const Category = require('./models/Category');

// CORRECT Branch IDs
const ABUJA_ID = '696a84765d0f23566dbc6e61';
const BENIN_ID = '696a84765d0f23566dbc6e5d';

async function cloneCategories() {
    try {
        await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/clotheline');
        console.log("Connected to DB. Cloning Product Categories...");

        // 1. Find the "Legacy/Global" categories (branchId is null or missing)
        const globalCats = await Category.find({
            $or: [{ branchId: { $exists: false } }, { branchId: null }]
        });

        console.log(`Found ${globalCats.length} global categories to clone.`);

        for (let cat of globalCats) {
            // Clone for Abuja
            const existsAbuja = await Category.findOne({ name: cat.name, branchId: ABUJA_ID });
            if (!existsAbuja) {
                const abujaCat = new Category({
                    name: cat.name,
                    image: cat.image,
                    isActive: true,
                    branchId: ABUJA_ID
                });
                await abujaCat.save();
                console.log(`Cloned "${cat.name}" to Abuja.`);
            }

            // Clone for Benin
            const existsBenin = await Category.findOne({ name: cat.name, branchId: BENIN_ID });
            if (!existsBenin) {
                const beninCat = new Category({
                    name: cat.name,
                    image: cat.image,
                    isActive: true,
                    branchId: BENIN_ID
                });
                await beninCat.save();
                console.log(`Cloned "${cat.name}" to Benin.`);
            }

            // Deactivate global one so it doesn't cause "spill" for legacy apps?
            // Actually, better to just let the strict isolation handle it.
            // But let's keep it active but "Hidden" if we want.
            // For now, let's leave the global ones as they are.
        }

        console.log("Cloning Complete! 🛡️");
    } catch (err) {
        console.error("Cloning Error:", err);
    } finally {
        mongoose.connection.close();
    }
}

cloneCategories();
