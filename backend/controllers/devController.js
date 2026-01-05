const User = require('../models/User');
const bcrypt = require('bcryptjs');

exports.seedUsers = async (req, res) => {
    try {
        // Check if users exist to avoid duplicates if DB persisted (unlikely in memory, but good practice)
        await User.deleteMany({}); // Clear existing for fresh seed

        const salt = await bcrypt.genSalt(10);

        // 1. Create Regular User
        const userPassword = await bcrypt.hash('password123', salt);
        const user = new User({
            name: 'Test User',
            email: 'user@test.com',
            password: userPassword,
            phone: '1234567890',
            role: 'user'
        });
        await user.save();

        // 2. Create Admin User
        const adminPassword = await bcrypt.hash('password123', salt);
        const admin = new User({
            name: 'Admin User',
            email: 'admin@test.com',
            password: adminPassword,
            phone: '0987654321',
            role: 'admin'
        });
        await admin.save();

        res.json({
            msg: 'Users Seeded Successfully',
            accounts: [
                { email: 'user@test.com', password: 'password123', role: 'user' },
                { email: 'admin@test.com', password: 'password123', role: 'admin' }
            ]
        });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};
const Product = require('../models/Product');
const { seedProducts } = require('./productController');

const Service = require('../models/Service');
const { seedServices } = require('./serviceController');

exports.resetProducts = async (req, res) => {
    try {
        await Product.deleteMany({});
        await seedProducts();
        res.json({ msg: 'Products Reset and Seeded' });
    } catch (e) {
        res.status(500).send(e.message);
    }
};

exports.resetServices = async (req, res) => {
    try {
        await Service.deleteMany({});
        await seedServices();
        res.json({ msg: 'Services Reset and Seeded' });
    } catch (e) {
        res.status(500).send(e.message);
    }
};
