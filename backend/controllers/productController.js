const Product = require('../models/Product');

const Branch = require('../models/Branch');

exports.getAllProducts = async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 0;
        const { branchId, category } = req.query;

        let query = { isActive: true };
        if (branchId) query.branchId = branchId;
        if (category) query.category = category;

        let products = await Product.find(query)
            .sort({ createdAt: -1 })
            .limit(limit);

        res.json(products);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.getCategories = async (req, res) => {
    try {
        const { branchId } = req.query;
        if (!branchId) return res.json([]);

        const categories = await Product.distinct('category', { isActive: true, branchId });
        res.json(categories.filter(c => c));
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.createProduct = async (req, res) => {
    try {
        const {
            name, price, category, imageUrls, variations,
            description, isFreeShipping, discountPercentage,
            stock, originalPrice, brand, branchId,
            salesBanner, detailBanner // [NEW] Explicitly extract
        } = req.body;

        if (!branchId) {
            return res.status(400).json({ msg: "Branch ID is required" });
        }

        // [PRESET LOGIC] 
        // If banners are not provided or isEnabled is explicitly false but we want to "remember" last settings,
        // we fetch the most recent product from this branch.
        let defaultSalesBanner = salesBanner;
        let defaultDetailBanner = detailBanner;

        // Note: Even if incoming is {isEnabled: false}, we might want the TEXT/COLORS from last time
        // so the admin doesn't have to re-type them if they decide to toggle it on.
        const lastProduct = await Product.findOne({ branchId }).sort({ createdAt: -1 });

        if (lastProduct) {
            // Merge defaults from last product if current values are missing or are "default starters"
            if (!salesBanner || !salesBanner.primaryText || salesBanner.primaryText === 'SPECIAL SALE') {
                // If the app didn't send a customized banner, use the last one
                defaultSalesBanner = lastProduct.salesBanner;
            }
            if (!detailBanner || !detailBanner.primaryText || detailBanner.primaryText === 'STUNNING QUALITY. AMAZING SERVICE.') {
                defaultDetailBanner = lastProduct.detailBanner;
            }
        }

        const newProduct = new Product({
            branchId,
            name,
            brand: brand || "Generic",
            price,
            category,
            imageUrls: imageUrls || [],
            variations: variations || [],
            description,
            isFreeShipping: isFreeShipping || false,
            discountPercentage: discountPercentage || 0,
            stock: stock || 0,
            originalPrice: originalPrice || price,
            salesBanner: defaultSalesBanner, // [FIXED]
            detailBanner: defaultDetailBanner, // [FIXED]
            isActive: true
        });

        const product = await newProduct.save();
        res.json(product);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.updateProduct = async (req, res) => {
    try {
        const fields = req.body;
        let product = await Product.findById(req.params.id);
        if (!product) return res.status(404).json({ msg: 'Product not found' });

        // Update fields dynamically
        // Use set() for nested objects to ensure sub-document validation and persistence
        Object.keys(fields).forEach(key => {
            if (typeof fields[key] === 'object' && fields[key] !== null && !Array.isArray(fields[key])) {
                // Handle nested banner objects carefully
                product[key] = { ...product[key], ...fields[key] };
            } else {
                product[key] = fields[key];
            }
        });

        await product.save();
        res.json(product);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.deleteProduct = async (req, res) => {
    try {
        let product = await Product.findById(req.params.id);
        if (!product) return res.status(404).json({ msg: 'Product not found' });

        product.isActive = false;
        await product.save();
        res.json({ msg: 'Product removed' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.seedProducts = async () => {
    try {
        const count = await Product.countDocuments();
        if (count === 0) {
            console.log('Seeding Products...');
            // Find a master branch to seed into
            const branch = await Branch.findOne();
            if (!branch) {
                console.log("No branches found, skipping product seed.");
                return;
            }

            const products = [
                // Laundry Essentials
                {
                    name: 'Ariel Detergent (2kg)',
                    price: 4500,
                    category: 'Cleaning',
                    description: 'Tough stain removal for bright whites.',
                    stock: 50,
                    imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Ariel+Detergent'],
                    branchId: branch._id
                },
                // ... (abridged for brevity, logic applies same way)
            ];
            // Just seeding one for demo
            const demoProduct = {
                name: 'Ariel Detergent (2kg)',
                price: 4500,
                category: 'Cleaning',
                description: 'Tough stain removal for bright whites.',
                stock: 50,
                imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Ariel+Detergent'],
                branchId: branch._id
            };

            await Product.create(demoProduct);
            console.log(`Products Seeded into Branch: ${branch.name}`);
        }
    } catch (err) {
        console.error('Product Seeding Error:', err);
    }
};
exports.migrateLegacyProducts = async (req, res) => {
    try {
        // 1. Find Benin Branch
        // We look for a branch with name containing "Benin"
        const branch = await Branch.findOne({ name: { $regex: "Benin", $options: "i" } });
        if (!branch) {
            return res.status(404).json({ msg: "Benin branch not found for migration." });
        }

        // 2. Update all products without branchId
        const result = await Product.updateMany(
            { branchId: { $exists: false } },
            { $set: { branchId: branch._id } }
        );

        res.json({
            msg: "Migration Complete",
            movedCount: result.modifiedCount,
            targetBranch: branch.name
        });
    } catch (err) {
        console.error(err);
        res.status(500).send("Migration Error");
    }
};
