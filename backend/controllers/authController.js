const User = require('../models/User');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

exports.signup = async (req, res) => {
    try {
        const { name, email, password, phone, role } = req.body;

        // Check if user exists
        let user = await User.findOne({ email });
        if (user) {
            return res.status(400).json({ msg: 'User already exists' });
        }

        // Hash password
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Create user (Allow sending 'role' for now for testing, but typically restricted)
        user = new User({
            name,
            email,
            password: hashedPassword,
            phone,
            role: role || 'user'
        });

        await user.save();

        // Return JWT
        const payload = {
            user: {
                id: user.id,
                role: user.role
            }
        };

        jwt.sign(payload, process.env.JWT_SECRET || 'secret123', { expiresIn: '7d' }, (err, token) => {
            if (err) throw err;
            res.json({ token, user: { id: user.id, name: user.name, role: user.role } });
        });

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.login = async (req, res) => {
    try {
        const { email, password } = req.body;

        let user = await User.findOne({ email });
        if (!user) {
            return res.status(400).json({ msg: 'Invalid Credentials' });
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ msg: 'Invalid Credentials' });
        }

        if (user.isRevoked) {
            return res.status(403).json({ msg: 'Your access has been Revoked: Contact Master Admin for assistance' });
        }

        const payload = {
            user: {
                id: user.id,
                role: user.role
            }
        };

        jwt.sign(payload, process.env.JWT_SECRET || 'secret123', { expiresIn: '7d' }, (err, token) => {
            if (err) throw err;
            res.json({
                token,
                user: {
                    id: user.id,
                    name: user.name,
                    role: user.role,
                    isMasterAdmin: user.isMasterAdmin,
                    permissions: user.permissions
                }
            });
        });

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Verify Token & Return Fresh User Data
exports.verifyToken = async (req, res) => {
    try {
        const user = await User.findById(req.user.userId).select('-password');
        if (!user) {
            return res.status(404).json({ msg: 'User not found' });
        }

        // Role-based revocation check
        if (user.role === 'admin' && user.isRevoked) {
            return res.status(403).json({ msg: 'Access Revoked' });
        }

        res.json({
            user: {
                id: user._id,
                name: user.name,
                email: user.email,
                role: user.role,
                isMasterAdmin: user.isMasterAdmin || false,
                permissions: user.permissions || {}
            }
        });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.getAllUsers = async (req, res) => {
    try {
        // Fetch all users, excluding password
        const users = await User.find().select('-password').sort({ date: -1 });
        res.json(users);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.seedUsers = async () => {
    try {
        const adminEmail = 'admin@clotheline.com';
        let admin = await User.findOne({ email: adminEmail });

        if (!admin) {
            console.log('Seeding Master Admin...');
            const salt = await bcrypt.genSalt(10);
            const hashedPassword = await bcrypt.hash('admin123', salt);

            admin = new User({
                name: 'Master Admin',
                email: adminEmail,
                password: hashedPassword,
                phone: '0000000000',
                role: 'admin',
                isMasterAdmin: true,
                permissions: {
                    manageOrders: true,
                    manageUsers: true,
                    manageCMS: true,
                    manageServices: true,
                    manageProducts: true,
                    manageDelivery: true
                }
            });

            await admin.save();
            console.log('Master Admin Seeded/Restored: admin@clotheline.com / admin123');
        } else {
            // Optional: Ensure it has master permissions if it exists?
            // For now, just logging.
            // console.log('Master Admin already exists.');
        }
    } catch (err) {
        console.error('User Seeding Error:', err);
    }
};
