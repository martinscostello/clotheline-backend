const User = require('../models/User');
const bcrypt = require('bcryptjs');

// Create a new Admin
exports.createAdmin = async (req, res) => {
    try {
        const { name, email, password, phone, permissions, isMasterAdmin, avatarId } = req.body;

        let user = await User.findOne({ email });
        if (user) {
            return res.status(400).json({ msg: 'User already exists' });
        }

        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        user = new User({
            name,
            email,
            password: hashedPassword,
            phone,
            role: 'admin',
            avatarId: avatarId || null,
            isVerified: true, // [FIX] Admins created by Master Admin are auto-verified
            isMasterAdmin: isMasterAdmin || false,
            permissions: permissions || {}
        });

        await user.save();
        res.json(user);

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Get All Admins
exports.getAllAdmins = async (req, res) => {
    try {
        const admins = await User.find({ role: 'admin' }).select('-password').sort({ date: -1 });
        res.json(admins);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Update Admin (Permissions & Revocation)
exports.updateAdmin = async (req, res) => {
    try {
        const { name, email, phone, permissions, isRevoked, avatarId } = req.body;

        // Find user by ID
        let user = await User.findById(req.params.id);
        if (!user) return res.status(404).json({ msg: 'User not found' });

        // Prevent revoking Master Admin
        if (user.isMasterAdmin && isRevoked) {
            return res.status(400).json({ msg: 'Cannot revoke Master Admin access' });
        }

        if (name) user.name = name;
        if (email) user.email = email;
        if (phone) user.phone = phone;
        if (avatarId !== undefined) user.avatarId = avatarId;
        if (isRevoked !== undefined) user.isRevoked = isRevoked;

        if (permissions) {
            user.permissions = permissions;
            user.markModified('permissions');
        }

        await user.save();
        res.json(user);

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Database Backup (JSON Export)
exports.getDatabaseBackup = async (req, res) => {
    try {
        const Order = require('../models/Order');
        const Service = require('../models/Service');
        const Product = require('../models/Product');
        const Branch = require('../models/Branch');

        const orders = await Order.find();
        const services = await Service.find();
        const products = await Product.find();
        const users = await User.find().select('-password');
        const branches = await Branch.find();

        const backupData = {
            exportDate: new Date().toISOString(),
            data: {
                orders,
                services,
                products,
                users,
                branches
            }
        };

        res.json(backupData);
    } catch (err) {
        console.error("[Admin] Backup Error:", err.message);
        res.status(500).send('Server Error');
    }
};
