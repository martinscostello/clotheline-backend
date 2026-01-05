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
        const {
            name, icon, color, description,
            discountPercentage, discountLabel, isActive,
            isLocked, lockedLabel, items, serviceTypes
        } = req.body;

        let service = await Service.findById(req.params.id);
        if (!service) return res.status(404).json({ msg: 'Service not found' });

        if (name) service.name = name;
        if (icon) service.icon = icon;
        if (color) service.color = color;
        if (description) service.description = description;
        if (discountPercentage !== undefined) service.discountPercentage = discountPercentage;
        if (discountLabel !== undefined) service.discountLabel = discountLabel;
        if (isActive !== undefined) service.isActive = isActive;

        // New Fields
        if (isLocked !== undefined) service.isLocked = isLocked;
        if (lockedLabel) service.lockedLabel = lockedLabel;
        if (items) service.items = items;
        if (serviceTypes) service.serviceTypes = serviceTypes;

        await service.save();
        res.json(service);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.deleteService = async (req, res) => {
    try {
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
                {
                    name: 'Regular & Bulk Laundry',
                    icon: 'local_laundry_service',
                    color: '0xFF448AFF',
                    description: 'Wash & Fold, Ironing',
                    items: [
                        { name: 'Shirt', price: 500 },
                        { name: 'Trousers', price: 600 },
                        { name: 'Gown', price: 800 },
                        { name: 'Suit (2pc)', price: 2000 },
                        { name: 'Duvet (Large)', price: 3500 },
                        { name: 'Bed Sheet', price: 1000 }
                    ],
                    serviceTypes: [
                        { name: 'Wash & Iron' },
                        { name: 'Wash Only' },
                        { name: 'Iron Only' },
                        { name: 'Starch & Iron' }
                    ]
                },
                {
                    name: 'Footwears',
                    icon: 'do_not_step',
                    color: '0xFFFF4081',
                    description: 'Sneaker & Shoe Cleaning',
                    items: [
                        { name: 'Sneakers', price: 1500 },
                        { name: 'Boots', price: 2000 },
                        { name: 'Canvas', price: 1000 },
                        { name: 'Slippers', price: 500 }
                    ],
                    serviceTypes: [
                        { name: 'Standard Clean' },
                        { name: 'Deep Clean (Soles)' }
                    ]
                },
                {
                    name: 'Rug Cleaning',
                    icon: 'water_drop',
                    color: '0xFF00E676',
                    description: 'Deep Clean & Vacuum',
                    items: [
                        { name: 'Small Rug', price: 3000 },
                        { name: 'Medium Rug', price: 5000 },
                        { name: 'Large Rug', price: 8000 },
                        { name: 'Extra Large', price: 12000 }
                    ],
                    serviceTypes: [
                        { name: 'General Wash' },
                        { name: 'Stain Removal' }
                    ]
                },
                {
                    name: 'Home/Office Cleaning',
                    icon: 'house',
                    color: '0xFFFF6D00',
                    description: 'Professional On-site service',
                    items: [
                        { name: '1 Bedroom Flat', price: 15000 },
                        { name: '2 Bedroom Flat', price: 25000 },
                        { name: 'Office Space (Small)', price: 20000 },
                        { name: 'Office Space (Large)', price: 40000 }
                    ],
                    serviceTypes: [
                        { name: 'Regular Clean' },
                        { name: 'Deep Clean' },
                        { name: 'Post-Construction' }
                    ]
                }
            ];
            await Service.insertMany(services);
            console.log('Services Seeded');
        }
    } catch (err) {
        console.error('Seeding Error:', err);
    }
};
