const Product = require('../models/Product');

exports.getAllProducts = async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 0;
        const products = await Product.find({ isActive: true })
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
        const categories = await Product.distinct('category', { isActive: true });
        res.json(categories.filter(c => c)); // Filter nulls
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
            stock, originalPrice, brand
        } = req.body;

        const newProduct = new Product({
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
            originalPrice: originalPrice || price, // Default to price if not set
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
        // Note: For arrays (variations, imageUrls), this replaces them entirely. 
        // Frontend should send the full updated list.
        Object.keys(fields).forEach(key => {
            product[key] = fields[key];
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
            const products = [
                // Laundry Essentials
                {
                    name: 'Ariel Detergent (2kg)',
                    price: 4500,
                    category: 'Cleaning',
                    description: 'Tough stain removal for bright whites.',
                    stock: 50,
                    imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Ariel+Detergent']
                },
                {
                    name: 'Comfort Softener (Blue)',
                    price: 2800,
                    category: 'Softeners',
                    description: 'Long lasting fragrance and softness.',
                    stock: 30,
                    imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Comfort+Softener']
                },

                // Perfumes
                {
                    name: 'Savage Dior Elixir',
                    price: 45000,
                    category: 'Fragrances',
                    description: 'Concentrated perfume with spicy, woody notes.',
                    stock: 10,
                    imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Savage+Dior']
                },
                {
                    name: 'Creed Aventus',
                    price: 120000,
                    category: 'Fragrances',
                    description: 'The best-selling men\'s fragrance in the history of the House of Creed.',
                    stock: 5,
                    discountPercentage: 5,
                    imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Creed+Aventus']
                },
                {
                    name: 'Baccarat Rouge 540',
                    price: 150000,
                    category: 'Fragrances',
                    description: 'Luminous and sophisticated, Baccarat Rouge 540 lays on the skin like an amber, floral and woody breeze.',
                    stock: 8,
                    imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Baccarat+Rouge']
                },

                // Body Sprays
                {
                    name: 'Nivea Men Fresh Active',
                    price: 3500,
                    category: 'Fragrances',
                    description: '48h effective anti-perspirant protection.',
                    stock: 100,
                    imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Nivea+Men']
                },
                {
                    name: 'Sure Invisible Ice',
                    price: 3200,
                    category: 'Fragrances',
                    description: 'Anti-perspirant deodorant spray.',
                    stock: 80,
                    imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Sure+Invisible']
                },
                {
                    name: 'Rexona MotionSense',
                    price: 3000,
                    category: 'Fragrances',
                    description: 'Workout intensity deodorant.',
                    stock: 80,
                    imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Rexona']
                },

                // Roll-ons
                {
                    name: 'Nivea Pearl & Beauty Roll-on',
                    price: 1500,
                    category: 'Fragrances',
                    description: 'For smooth and beautiful underarms.',
                    stock: 200,
                    imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Nivea+Pearl']
                },
                {
                    name: 'Dove Men+Care Roll-on',
                    price: 1800,
                    category: 'Fragrances',
                    description: 'Clean Comfort anti-perspirant.',
                    stock: 150,
                    imageUrls: ['https://placehold.co/600x600/101010/ffffff/png?text=Dove+Men']
                }
            ];

            await Product.insertMany(products);
            console.log('Products Seeded with Perfumes & Essentials');
        }
    } catch (err) {
        console.error('Product Seeding Error:', err);
    }
};
