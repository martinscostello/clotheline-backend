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
