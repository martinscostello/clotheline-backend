const Product = require('../models/Product');

exports.getAllProducts = async (req, res) => {
    try {
        const products = await Product.find({ isActive: true });
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
            stock, originalPrice
        } = req.body;

        const newProduct = new Product({
            name,
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
                    imageUrls: ['https://images.unsplash.com/photo-1626806775351-538068b2f4fa?auto=format&fit=crop&q=80&w=500']
                },
                {
                    name: 'Comfort Softener (Blue)',
                    price: 2800,
                    category: 'Softeners',
                    description: 'Long lasting fragrance and softness.',
                    stock: 30,
                    imageUrls: ['https://images.unsplash.com/photo-1585838012675-b669ba8c6428?auto=format&fit=crop&q=80&w=500']
                },

                // Perfumes
                {
                    name: 'Savage Dior Elixir',
                    price: 45000,
                    category: 'Fragrances',
                    description: 'Concentrated perfume with spicy, woody notes.',
                    stock: 10,
                    imageUrls: ['https://images.unsplash.com/photo-1523293188086-b469999be957?auto=format&fit=crop&q=80&w=500']
                },
                {
                    name: 'Creed Aventus',
                    price: 120000,
                    category: 'Fragrances',
                    description: 'The best-selling men\'s fragrance in the history of the House of Creed.',
                    stock: 5,
                    discountPercentage: 5,
                    imageUrls: ['https://images.unsplash.com/photo-1594035910387-fea4779426e9?auto=format&fit=crop&q=80&w=500']
                },
                {
                    name: 'Baccarat Rouge 540',
                    price: 150000,
                    category: 'Fragrances',
                    description: 'Luminous and sophisticated, Baccarat Rouge 540 lays on the skin like an amber, floral and woody breeze.',
                    stock: 8,
                    imageUrls: ['https://images.unsplash.com/photo-1592945403244-b3fbafd7f539?auto=format&fit=crop&q=80&w=500']
                },

                // Body Sprays
                {
                    name: 'Nivea Men Fresh Active',
                    price: 3500,
                    category: 'Fragrances',
                    description: '48h effective anti-perspirant protection.',
                    stock: 100,
                    imageUrls: ['https://images.unsplash.com/photo-1619451334792-150fd785ee74?auto=format&fit=crop&q=80&w=500']
                },
                {
                    name: 'Sure Invisible Ice',
                    price: 3200,
                    category: 'Fragrances',
                    description: 'Anti-perspirant deodorant spray.',
                    stock: 80,
                    imageUrls: ['https://images.unsplash.com/photo-1620916566398-39f1143ab7be?auto=format&fit=crop&q=80&w=500']
                },
                {
                    name: 'Rexona MotionSense',
                    price: 3000,
                    category: 'Fragrances',
                    description: 'Workout intensity deodorant.',
                    stock: 80,
                    imageUrls: ['https://images.unsplash.com/photo-1571781565036-d3f75af02a9d?auto=format&fit=crop&q=80&w=500']
                },

                // Roll-ons
                {
                    name: 'Nivea Pearl & Beauty Roll-on',
                    price: 1500,
                    category: 'Fragrances',
                    description: 'For smooth and beautiful underarms.',
                    stock: 200,
                    imageUrls: ['https://images.unsplash.com/photo-1608248597279-f99d160bfbc8?auto=format&fit=crop&q=80&w=500']
                },
                {
                    name: 'Dove Men+Care Roll-on',
                    price: 1800,
                    category: 'Fragrances',
                    description: 'Clean Comfort anti-perspirant.',
                    stock: 150,
                    imageUrls: ['https://images.unsplash.com/photo-1616782528148-15cf4bc8b8ec?auto=format&fit=crop&q=80&w=500']
                }
            ];

            await Product.insertMany(products);
            console.log('Products Seeded with Perfumes & Essentials');
        }
    } catch (err) {
        console.error('Product Seeding Error:', err);
    }
};
