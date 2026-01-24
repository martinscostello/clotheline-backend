
const jwt = require('jsonwebtoken');

module.exports = async function (req, res, next) {
    // Get token from header
    const token = req.header('x-auth-token');

    // Check if not token
    if (!token) {
        return res.status(401).json({ msg: 'No token, authorization denied' });
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'secret123');
        req.user = decoded.user;

        // Check revocation status from DB (Optional: Caching recommended for scale)
        const User = require('../models/User');
        const user = await User.findById(req.user.id);
        if (user && user.isRevoked) {
            return res.status(403).json({ msg: 'Your access has been Revoked: Contact Master Admin for assistance' });
        }

        // [CRITICAL FIX] Ensure User exists in DB
        if (!user) {
            return res.status(401).json({ msg: 'User not found in database. Please login again.' });
        }

        // Pass fresh user data if needed
        if (user) {
            req.user.permissions = user.permissions;
            req.user.isMasterAdmin = user.isMasterAdmin;
        }

        next();
    } catch (err) {
        res.status(401).json({ msg: 'Token is not valid' });
    }
};
