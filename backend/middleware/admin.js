const User = require('../models/User');

module.exports = async function (req, res, next) {
    try {
        // Auth middleware should have already run and populated req.user
        if (!req.user) {
            return res.status(401).json({ msg: 'Unauthorized: No User Found' });
        }

        // Fetch full user to check role (or rely on token payload if trusted)
        // Ideally rely on req.user.role if token has it, but DB check is safer for Admin
        const user = await User.findById(req.user.id);

        if (!user || user.role !== 'admin') {
            return res.status(403).json({ msg: 'Access Denied: Admins Only' });
        }

        next();
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error in Admin Middleware');
    }
};
