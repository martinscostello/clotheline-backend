const User = require('../models/User');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const sendEmail = require('../utils/sendEmail');

// Helper: Rate Limit Check
const checkRateLimit = (user, type) => {
    const limits = { resend: 5 }; // Max 5 resends per window (e.g. 1 hour)
    const windowMs = 60 * 60 * 1000; // 1 Hour

    if (!user.otpLastSentAt) return true; // First time is always ok

    const timeDiff = Date.now() - new Date(user.otpLastSentAt).getTime();

    // Cooldown check (60s absolute)
    if (timeDiff < 60 * 1000) return 'Please wait 60 seconds before trying again.';

    // Window limit check
    if (timeDiff > windowMs) {
        // Reset window
        user.otpResendCount = 0;
        return true;
    }

    if (user.otpResendCount >= limits.resend) {
        return 'Too many attempts. Please try again in an hour.';
    }

    return true;
};

exports.signup = async (req, res) => {
    try {
        console.log('Signup Request Body:', req.body);
        let { name, email, password, phone, role, branchId } = req.body;

        // [FIX] Normalize Inputs
        if (email) email = email.trim().toLowerCase();
        if (name) name = name.trim();
        if (phone) phone = phone.trim();

        // Validation (Basic)
        if (!email || !password || !name) return res.status(400).json({ msg: "Please fill all fields" });

        // 1. Check if user exists
        let existingUser = await User.findOne({ email });

        if (existingUser) {
            if (existingUser.isVerified) {
                return res.status(400).json({ msg: 'Account already exists' });
            }

            // Existing Unverified -> Treat as Resend
            console.log(`[Auth] Unverified user ${email} found. treating as Reflow/Resend.`);

            // Rate Limit Check
            const canProceed = checkRateLimit(existingUser, 'resend');
            if (canProceed !== true) return res.status(429).json({ msg: canProceed });

            const otp = Math.floor(100000 + Math.random() * 900000).toString();
            existingUser.otp = otp;
            existingUser.otpExpires = new Date(Date.now() + 10 * 60 * 1000); // 10m
            existingUser.otpLastSentAt = Date.now();
            existingUser.otpResendCount = (existingUser.otpResendCount || 0) + 1;

            // Update info if provided
            if (password) {
                const salt = await bcrypt.genSalt(10);
                existingUser.password = await bcrypt.hash(password, salt);
            }
            if (name) existingUser.name = name;
            if (phone) existingUser.phone = phone;

            await existingUser.save();

            try {
                await sendEmail({
                    email: existingUser.email,
                    subject: 'Clotheline: Your New Verification Code',
                    message: `Your new verification code is: ${otp}`
                });
                return res.json({ msg: 'Verification code sent', email: existingUser.email });
            } catch (emailErr) {
                console.error("[Auth] Resend Email Failed:", emailErr);
                // In Strict Mode, we might want to error out, 
                // but since user exists, let's allow Debug OTP fallback for now to avoid total block
                return res.status(200).json({
                    msg: 'Email service error. Use Debug Code.',
                    debug_otp: otp
                });
            }
        }

        // 2. New User - Generate Credential Data
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);
        const otp = Math.floor(100000 + Math.random() * 900000).toString();

        // 3. ATTEMPT EMAIL FIRST (Strict Transaction)
        try {
            console.log(`[Auth] Attempting to send OTP email to ${email}...`);
            await sendEmail({
                email: email,
                subject: 'Clotheline: Verification Code',
                message: `Welcome to Clotheline! Your verification code is: ${otp}. Expires in 10 minutes.`
            });
            console.log(`[Auth] OTP Email sent successfully to ${email}`);
        } catch (emailErr) {
            console.error("[Auth] FATAL: Email failed before creation:", emailErr);
            // STRICT: Abort Signup. No Ghost User Created.
            return res.status(500).json({
                msg: 'Failed to send verification email. Please check your address or try again.',
                error: emailErr.message
            });
        }

        // 4. Create User (Only if Email Succeeded)
        const newUser = new User({
            name,
            email,
            password: hashedPassword,
            phone,
            role: role || 'user',
            otp,
            otpExpires: new Date(Date.now() + 10 * 60 * 1000),
            otpLastSentAt: Date.now(),
            otpResendCount: 1,
            isVerified: false,
            preferredBranch: branchId || undefined // Save City preference
        });

        await newUser.save();
        res.json({ msg: 'Verification code sent', email: newUser.email });

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.resendOtp = async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) return res.status(400).json({ msg: "Email required" });

        const user = await User.findOne({ email });
        if (!user) return res.status(404).json({ msg: "User not found" });
        if (user.isVerified) return res.status(400).json({ msg: "Account already verified. Please login." });

        // Rate Limit
        const canProceed = checkRateLimit(user, 'resend');
        if (canProceed !== true) return res.status(429).json({ msg: canProceed });

        // Generate
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        user.otp = otp;
        user.otpExpires = new Date(Date.now() + 10 * 60 * 1000);
        user.otpLastSentAt = Date.now();
        user.otpResendCount = (user.otpResendCount || 0) + 1;

        await user.save();

        // Send
        try {
            await sendEmail({
                email: user.email,
                subject: 'Clotheline: Your New Verification Code',
                message: `Your new verification code is: ${otp}`
            });
            res.json({ msg: 'Code resent successfully' });
        } catch (err) {
            console.error("[Auth] Resend Failed:", err);
            // Allow Debug Fallback
            return res.status(200).json({
                msg: 'Email failed. Use Debug OTP.',
                debug_otp: otp
            });
        }

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.verifyEmail = async (req, res) => {
    try {
        const { email, otp } = req.body;

        let user = await User.findOne({ email });
        if (!user) return res.status(400).json({ msg: 'Invalid Email/Account not found' });

        if (user.otp !== otp) {
            // Potential: Increment failed attempts counter here if blocking brute force
            return res.status(400).json({ msg: 'Invalid Code' });
        }

        if (user.otpExpires < Date.now()) {
            return res.status(400).json({ msg: 'Code Expired. Please resend.' });
        }

        // Verify Success
        user.isVerified = true;
        user.otp = undefined;
        user.otpExpires = undefined;
        user.otpResendCount = 0; // Reset limits on success
        await user.save();

        // Login (Generate Token)
        const payload = {
            user: {
                id: user.id,
                role: user.role
            }
        };

        jwt.sign(payload, process.env.JWT_SECRET || 'secret123', { expiresIn: '7d' }, (err, token) => {
            if (err) throw err;
            res.json({ token, user: { id: user.id, name: user.name, email: user.email, role: user.role, preferredBranch: user.preferredBranch } });
        });

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.login = async (req, res) => {
    try {
        let { email, password } = req.body;

        // [FIX] Normalize Inputs
        if (email) email = email.trim().toLowerCase();
        if (password) password = password.trim();

        console.log(`[Auth] Attempting Login for: '${email}'`);

        let user = await User.findOne({ email });
        if (!user) {
            console.warn(`[Auth] Login Failed: User '${email}' not found.`);
            return res.status(400).json({ msg: 'Invalid Credentials (User not found)' });
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            console.warn(`[Auth] Login Failed: Password mismatch for '${email}'.`);
            return res.status(400).json({ msg: 'Invalid Credentials' });
        }

        // Strict Verification Check (Exempt Admins)
        if (!user.isVerified && user.role !== 'admin') {
            return res.status(403).json({
                msg: 'Email not verified. Please verify your account.',
                requiresVerification: true,
                email: user.email
            });
        }

        if (user.isRevoked) {
            return res.status(403).json({ msg: 'Access Revoked. Contact Support.' });
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
                    email: user.email,
                    role: user.role,
                    isMasterAdmin: user.isMasterAdmin,
                    permissions: user.permissions,
                    preferredBranch: user.preferredBranch // Return preference
                }
            });
        });

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.verifyToken = async (req, res) => {
    try {
        const user = await User.findById(req.user.id).select('-password');
        if (!user) {
            return res.status(404).json({ msg: 'User not found' });
        }
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
                permissions: user.permissions || {},
                preferredBranch: user.preferredBranch
            }
        });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.deleteUser = async (req, res) => {
    try {
        const user = await User.findById(req.params.userId);
        if (!user) return res.status(404).json({ msg: 'User not found' });

        // Prevent deleting master admin (safety)
        if (user.isMasterAdmin) return res.status(403).json({ msg: 'Cannot delete Master Admin' });

        await User.deleteOne({ _id: req.params.userId });
        res.json({ msg: 'User deleted successfully' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.getAllUsers = async (req, res) => {
    try {
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
                },
                isVerified: true
            });
            await admin.save();
            console.log('Master Admin Seeded');
        } else {
            // [FIX] Repair Legacy Admin (e.g. if unverified)
            if (!admin.isVerified || !admin.isMasterAdmin) {
                console.log('Repairing Master Admin State...');
                admin.isVerified = true;
                admin.isMasterAdmin = true;
                // Ensure permissions exist
                if (!admin.permissions) {
                    admin.permissions = {
                        manageOrders: true, manageUsers: true, manageCMS: true,
                        manageServices: true, manageProducts: true, manageDelivery: true
                    };
                }
                await admin.save();
                console.log('Master Admin Repaired');
            }
        }
    } catch (err) {
        console.error('User Seeding Error:', err);
    }
};

exports.updateFcmToken = async (req, res) => {
    try {
        const { token } = req.body;
        if (!token) return res.status(400).json({ msg: 'Token is required' });

        // Use $addToSet to atomically add the token only if it doesn't already exist
        await User.findByIdAndUpdate(
            req.user.id,
            { $addToSet: { fcmTokens: token } },
            { new: true }
        );

        res.json({ msg: 'Token updated' });
    } catch (err) {
        console.error("[Auth] Token Update Error:", err.message);
        res.status(500).send('Server Error');
    }
};
exports.updateAvatar = async (req, res) => {
    try {
        const { avatarId } = req.body;
        if (!avatarId) return res.status(400).json({ msg: 'Avatar ID is required' });

        await User.findByIdAndUpdate(
            req.user.id,
            { avatarId },
            { new: true }
        );

        res.json({ msg: 'Avatar updated successfully', avatarId });
    } catch (err) {
        console.error("[Auth] Avatar Update Error:", err.message);
        res.status(500).send('Server Error');
    }
};
