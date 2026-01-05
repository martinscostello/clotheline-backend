const Service = require('../models/Service');

exports.getAllServices = async (req, res) => {
    try {
        const services = await Service.find({ isActive: true });
        res.json(services);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.createService = async (req, res) => {
    try {
        const { name, icon, color, description, discountPercentage, discountLabel } = req.body;
        const newService = new Service({
            name, icon, color, description,
            discountPercentage: discountPercentage || 0,
            discountLabel: discountLabel || ''
        });
        const service = await newService.save();
        res.json(service);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.updateService = async (req, res) => {
    try {
        const { name, icon, color, description, discountPercentage, discountLabel, isActive } = req.body;

        let service = await Service.findById(req.params.id);
        if (!service) return res.status(404).json({ msg: 'Service not found' });

        if (name) service.name = name;
        if (icon) service.icon = icon;
        if (color) service.color = color;
        if (description) service.description = description;
        if (discountPercentage !== undefined) service.discountPercentage = discountPercentage;
        if (discountLabel !== undefined) service.discountLabel = discountLabel;
        if (isActive !== undefined) service.isActive = isActive;

        await service.save();
        res.json(service);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.deleteService = async (req, res) => {
    try {
        // Soft delete
        let service = await Service.findById(req.params.id);
        if (!service) return res.status(404).json({ msg: 'Service not found' });

        service.isActive = false;
        await service.save();
        res.json({ msg: 'Service removed' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Seeding function called on server start
exports.seedServices = async () => {
    try {
        const count = await Service.countDocuments();
        if (count === 0) {
            console.log('Seeding Services...');
            const services = [
                { name: 'Regular & Bulk Laundry', icon: 'dry_cleaning', color: '0xFF448AFF', description: 'Wash & Fold' },
                { name: 'Footwears', icon: 'do_not_step', color: '0xFFFF4081', description: 'Sneaker Cleaning' },
                { name: 'Rug Cleaning', icon: 'water_drop', color: '0xFF00E676', description: 'Deep Clean' },
                { name: 'Home/Office Cleaning', icon: 'house', color: '0xFFFF6D00', description: 'On-site service' }
            ];
            await Service.insertMany(services);
            console.log('Services Seeded');
        }
    } catch (err) {
        console.error('Seeding Error:', err);
    }
};
