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
            res.json({ token, user: { id: user.id, name: user.name, email: user.email, role: user.role, preferredBranch: user.preferredBranch, avatarId: user.avatarId } });
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
                    assignedBranches: user.assignedBranches, // NEW
                    preferredBranch: user.preferredBranch, // Return preference
                    avatarId: user.avatarId // [FIX] Return avatarId
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
                preferredBranch: user.preferredBranch,
                avatarId: user.avatarId // [FIX] Return avatarId
            }
        });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.deleteUser = async (req, res) => {
    try {
        // [STRICT] Only Master Admin can delete other users
        const requester = await User.findById(req.user.id);
        if (!requester || !requester.isMasterAdmin) {
            return res.status(403).json({ msg: 'Action restricted to Master Admin only' });
        }

        const user = await User.findById(req.params.userId);
        if (!user) return res.status(404).json({ msg: 'User not found' });

        // Prevent deleting another master admin (safety)
        if (user.isMasterAdmin) return res.status(403).json({ msg: 'Cannot delete a Master Admin' });

        await User.deleteOne({ _id: req.params.userId });
        res.json({ msg: 'User wiped from the face of the app successfully' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.getAllUsers = async (req, res) => {
    try {
        const { branchId } = req.query;
        // [STRICT] Only show real customers/users here. Admins are in the Config section.
        let query = { role: 'user' };

        if (branchId && branchId !== 'null' && branchId !== 'undefined') {
            // [SMART FILTER] Allow fallback to city-based filtering for legacy users
            const Branch = require('../models/Branch');
            const branch = await Branch.findById(branchId);

            if (branch) {
                query.$or = [
                    { preferredBranch: branchId },
                    { 'savedAddresses.city': { $regex: new RegExp(`^${branch.name}$`, 'i') } }
                ];
            } else {
                query.preferredBranch = branchId;
            }
        }

        const users = await User.find(query).select('-password').sort({ createdAt: -1 });
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

        // [SECURITY] Enforce Single-User Token Association
        // Remove this token from ANY other user record to prevent leakage
        // (Scenario: Admin logs out, User/Guest logs in on same device)
        await User.updateMany(
            { fcmTokens: token, _id: { $ne: req.user.id } },
            { $pull: { fcmTokens: token } }
        );

        // Add to current user
        await User.findByIdAndUpdate(
            req.user.id,
            { $addToSet: { fcmTokens: token } },
            { new: true }
        );

        res.json({ msg: 'Token updated and deduplicated' });
    } catch (err) {
        console.error("[Auth) Token Update Error:", err.message);
        res.status(500).send('Server Error');
    }
};

exports.logout = async (req, res) => {
    try {
        const { token } = req.body;

        // Pull token from the authenticated user
        if (token) {
            await User.findByIdAndUpdate(
                req.user.id,
                { $pull: { fcmTokens: token } }
            );
            console.log(`[Auth] FCM Token pulled for user logout: ${req.user.id}`);
        }

        res.json({ msg: 'Logged out and token removed' });
    } catch (err) {
        console.error("[Auth] Logout Error:", err.message);
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

exports.deleteAccount = async (req, res) => {
    try {
        const { password } = req.body;
        if (!password) return res.status(400).json({ msg: 'Password is required to delete account' });

        const userId = req.user.id;
        const user = await User.findById(userId);
        if (!user) return res.status(404).json({ msg: 'User not found' });

        if (user.isMasterAdmin) return res.status(403).json({ msg: 'Master Admin cannot delete account via this endpoint' });

        // Password Verification
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ msg: 'Invalid password. Account deletion aborted.' });
        }

        await User.deleteOne({ _id: userId });
        res.json({ msg: 'Account deleted successfully' });
    } catch (err) {
        console.error("[Auth] Delete Account Error:", err.message);
        res.status(500).send('Server Error');
    }
};

exports.forgotPassword = async (req, res) => {
    try {
        const { email } = req.body;
        const normalizedEmail = email.trim().toLowerCase();
        const user = await User.findOne({ email: normalizedEmail });

        if (!user) {
            // Security: Don't reveal if user exists, but we'll be helpful for now
            return res.status(404).json({ msg: 'No user found with this email' });
        }

        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        user.otp = otp;
        user.otpExpires = new Date(Date.now() + 10 * 60 * 1000); // 10 mins
        await user.save();

        try {
            await sendEmail({
                email: user.email,
                subject: 'Clotheline: Password Reset OTP',
                message: `Your OTP for password reset is: ${otp}. It expires in 10 minutes.`
            });
            res.json({ msg: 'Reset OTP sent to email' });
        } catch (err) {
            console.error(err);
            res.status(500).json({ msg: 'Email could not be sent', debug_otp: otp });
        }
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
};

exports.resetPassword = async (req, res) => {
    try {
        const { email, otp, newPassword } = req.body;
        const user = await User.findOne({
            email: email.trim().toLowerCase(),
            otp,
            otpExpires: { $gt: Date.now() }
        });

        if (!user) {
            return res.status(400).json({ msg: 'Invalid or expired OTP' });
        }

        const salt = await bcrypt.genSalt(10);
        user.password = await bcrypt.hash(newPassword, salt);
        user.otp = undefined;
        user.otpExpires = undefined;
        await user.save();

        res.json({ msg: 'Password reset successful. You can now login.' });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
};

exports.changePassword = async (req, res) => {
    try {
        const { currentPassword, newPassword } = req.body;
        const user = await User.findById(req.user.id);

        if (!user) return res.status(404).json({ msg: 'User not found' });

        const isMatch = await bcrypt.compare(currentPassword, user.password);
        if (!isMatch) {
            return res.status(400).json({ msg: 'Incorrect current password' });
        }

        const salt = await bcrypt.genSalt(10);
        user.password = await bcrypt.hash(newPassword, salt);
        await user.save();

        res.json({ msg: 'Password updated successfully' });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
};

exports.updateAdminNotificationPreferences = async (req, res) => {
    try {
        const { preferences } = req.body;
        if (!preferences) return res.status(400).json({ msg: 'Preferences required' });

        const user = await User.findByIdAndUpdate(
            req.user.id,
            { adminNotificationPreferences: preferences },
            { new: true }
        ).select('-password');

        res.json({ msg: 'Admin notification preferences updated', user });
    } catch (err) {
        console.error("[Auth] Admin Prefs Update Error:", err.message);
        res.status(500).send('Server Error');
    }
};

