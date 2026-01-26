const User = require('../models/User');

// GET /api/users/addresses
exports.getSavedAddresses = async (req, res) => {
    try {
        const user = await User.findById(req.user.id).select('savedAddresses');
        if (!user) return res.status(404).json({ msg: 'User not found' });
        res.json(user.savedAddresses);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// POST /api/users/addresses
exports.addSavedAddress = async (req, res) => {
    try {
        const { label, addressLabel, lat, lng, city, landmark } = req.body;

        const user = await User.findById(req.user.id);
        if (!user) return res.status(404).json({ msg: 'User not found' });

        // Enrollment check is handled by model validation (arrayLimit)
        // But we can do a preemptive check here for better error message
        if (user.savedAddresses.length >= 3) {
            return res.status(400).json({ msg: 'Limit reached. You can only save up to 3 addresses.' });
        }

        user.savedAddresses.push({ label, addressLabel, lat, lng, city, landmark });
        await user.save();

        res.json(user.savedAddresses);
    } catch (err) {
        console.error(err.message);
        if (err.name === 'ValidationError') {
            return res.status(400).json({ msg: err.message });
        }
        res.status(500).send('Server Error');
    }
};

// DELETE /api/users/addresses/:addressId
exports.deleteSavedAddress = async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        if (!user) return res.status(404).json({ msg: 'User not found' });

        user.savedAddresses = user.savedAddresses.filter(
            (addr) => addr._id.toString() !== req.params.addressId
        );

        await user.save();
        res.json(user.savedAddresses);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};
