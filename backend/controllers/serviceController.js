const Service = require('../models/Service');

exports.getAllServices = async (req, res) => {
    try {
        const { branchId, includeHidden } = req.query;

        let query = {};
        if (branchId) {
            query = {
                $or: [
                    { branchId },
                    { branchId: { $exists: false } },
                    { branchId: null }
                ]
            };
        }

        let services = await Service.find(query).sort({ order: 1 });

        if (branchId) {
            const processedServices = [];

            for (let s of services) {
                let configIndex = s.branchConfig.findIndex(b => b.branchId.toString() === branchId);

                if (configIndex === -1) {
                    // Lazy init if missing
                    s.branchConfig.push({
                        branchId,
                        isActive: s.isActive,
                        isLocked: s.isLocked,
                        lockedLabel: s.lockedLabel || "Coming Soon",
                        items: s.items.map(i => ({ name: i.name, price: i.price, isActive: true })),
                        serviceTypes: s.serviceTypes.map(t => ({ name: t.name, priceMultiplier: t.priceMultiplier }))
                    });
                    configIndex = s.branchConfig.length - 1;
                    await s.save();
                }

                const config = s.branchConfig[configIndex];
                if (!config.isActive && includeHidden !== 'true') continue;

                const serviceObj = s.toObject();
                serviceObj.name = config.customName || s.name;
                serviceObj.image = config.customImage || s.image;
                serviceObj.description = config.customDescription || s.description;
                serviceObj.isLocked = config.isLocked;
                serviceObj.lockedLabel = config.lockedLabel;
                serviceObj.isActive = config.isActive;
                serviceObj.items = config.items;
                serviceObj.serviceTypes = config.serviceTypes;
                serviceObj.branchConfig = undefined;

                processedServices.push(serviceObj);
            }
            return res.json(processedServices);

        } else {
            // BACK TO GLOBAL VIEW (RESTORES BENIN/ABUJA LEGACY)
            if (includeHidden !== 'true') {
                services = services.filter(s => s.isActive);
            }
            res.json(services);
        }

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.createService = async (req, res) => {
    try {
        const { name, icon, color, description, image, discountPercentage, discountLabel, order, branchId } = req.body;
        const newService = new Service({
            name, icon, color, description,
            image: image || 'assets/images/service_laundry.png',
            discountPercentage: discountPercentage || 0,
            discountLabel: discountLabel || '',
            order: order || 0,
            branchId // [NEW]
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
            name, icon, color, description, image,
            discountPercentage, discountLabel, isActive,
            isLocked, lockedLabel, items, serviceTypes,
            branchId, order // [NEW] Context & Order
        } = req.body;

        console.log(`UPDATE SERVICE: ${req.params.id} | Branch: ${branchId || 'Global'}`);

        let service = await Service.findById(req.params.id);
        if (!service) return res.status(404).json({ msg: 'Service not found' });

        // --- BRANCH SCOPED UPDATE ---
        if (branchId) {

            // 1. Update/Find Branch Config
            let configIndex = service.branchConfig.findIndex(b => b.branchId.toString() === branchId);
            if (configIndex === -1) {
                // Init config from global defaults if missing
                service.branchConfig.push({
                    branchId,
                    isActive: true,
                    isLocked: false,
                    lockedLabel: "Coming Soon"
                });
                configIndex = service.branchConfig.length - 1;
            }

            // 2. Update States (If provided)
            if (isActive !== undefined) service.branchConfig[configIndex].isActive = isActive;

            // CRITICAL FIX: Locking does NOT affect isActive (Visibility)
            if (isLocked !== undefined) service.branchConfig[configIndex].isLocked = isLocked;
            if (lockedLabel !== undefined) service.branchConfig[configIndex].lockedLabel = lockedLabel;

            // [BRANCH OVERRIDES UPDATE]
            if (name) service.branchConfig[configIndex].customName = name;
            if (image) service.branchConfig[configIndex].customImage = image; // [FIX] Update Branch Image
            if (description) service.branchConfig[configIndex].customDescription = description;
            if (discountPercentage !== undefined) service.branchConfig[configIndex].discountPercentage = discountPercentage;
            if (discountLabel !== undefined) service.branchConfig[configIndex].discountLabel = discountLabel;

            // Update Service Types for Branch
            if (serviceTypes && Array.isArray(serviceTypes)) {
                service.branchConfig[configIndex].serviceTypes = serviceTypes;
            }

            service.branchConfig[configIndex].lastUpdated = Date.now();


            // 3. Update Items (STRICT INDEPENDENCE)
            // We now accept the FULL list of items from the frontend and replace the branch's item list.
            if (items && Array.isArray(items)) {
                // Map frontend items to Schema structure
                // We trust the frontend list as the "New Truth" for this branch.
                service.branchConfig[configIndex].items = items.map(i => ({
                    // Generate new ID if missing (Mongoose might do this auto, but let's be safe if needed, though usually subdoc array handles it)
                    name: i.name,
                    price: i.price,
                    isActive: i.isActive !== undefined ? i.isActive : true
                }));
            }

        } else {
            // --- GLOBAL UPDATE ---
            if (name) service.name = name;
            if (icon) service.icon = icon;
            if (color) service.color = color;
            if (description) service.description = description;
            if (image) service.image = image;
            if (discountPercentage !== undefined) service.discountPercentage = discountPercentage;
            if (discountLabel !== undefined) service.discountLabel = discountLabel;
            if (isActive !== undefined) service.isActive = isActive;
            if (isLocked !== undefined) service.isLocked = isLocked;
            if (lockedLabel) service.lockedLabel = lockedLabel;
            if (order !== undefined) service.order = order;

            // Handle Items (Global Base Price Update)
            if (items) {
                const mergedItems = items.map(newItem => {
                    const existing = service.items.find(i => i.name === newItem.name);
                    if (existing) {
                        return {
                            ...newItem,
                            branchPricing: existing.branchPricing // Preserve Branch Overrides
                        };
                    }
                    return newItem;
                });
                service.items = mergedItems;
            }

            if (serviceTypes) service.serviceTypes = serviceTypes;
        }

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

        await Service.findByIdAndDelete(req.params.id);
        res.json({ msg: 'Service permanently deleted' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.reorderServices = async (req, res) => {
    try {
        const { orders } = req.body; // Array of { id: string, order: number }
        if (!orders || !Array.isArray(orders)) {
            return res.status(400).json({ msg: 'Invalid request data' });
        }

        const updatePromises = orders.map(item =>
            Service.findByIdAndUpdate(item.id, { $set: { order: item.order } })
        );

        await Promise.all(updatePromises);
        res.json({ msg: 'Order updated successfully' });
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
                    image: 'assets/images/service_laundry.png',
                    items: [
                        { name: 'Shirt', price: 500 },
                        { name: 'Trousers', price: 600 },
                        { name: 'Gown', price: 800 },
                        { name: 'Suit (2pc)', price: 2000 },
                        { name: 'Duvet (Large)', price: 3500 },
                        { name: 'Bed Sheet', price: 1000 }
                    ],
                    serviceTypes: [
                        { name: 'Wash & Iron', priceMultiplier: 1.5 },
                        { name: 'Wash Only', priceMultiplier: 1.0 },
                        { name: 'Iron Only', priceMultiplier: 0.8 },
                        { name: 'Starch & Iron', priceMultiplier: 2.0 }
                    ]
                },
                {
                    name: 'Footwears',
                    icon: 'do_not_step',
                    color: '0xFFFF4081',
                    description: 'Sneaker & Shoe Cleaning',
                    image: 'assets/images/service_shoes.png',
                    items: [
                        { name: 'Sneakers', price: 1500 },
                        { name: 'Boots', price: 2000 },
                        { name: 'Canvas', price: 1000 },
                        { name: 'Slippers', price: 500 }
                    ],
                    serviceTypes: [
                        { name: 'Standard Clean', priceMultiplier: 1.0 },
                        { name: 'Deep Clean (Soles)', priceMultiplier: 1.5 }
                    ]
                },
                {
                    name: 'Rug Cleaning',
                    icon: 'water_drop',
                    color: '0xFF00E676',
                    description: 'Deep Clean & Vacuum',
                    image: 'assets/images/service_rug.png',
                    items: [
                        { name: 'Small Rug', price: 3000 },
                        { name: 'Medium Rug', price: 5000 },
                        { name: 'Large Rug', price: 8000 },
                        { name: 'Extra Large', price: 12000 }
                    ],
                    serviceTypes: [
                        { name: 'General Wash', priceMultiplier: 1.0 },
                        { name: 'Stain Removal', priceMultiplier: 1.5 }
                    ]
                },
                {
                    name: 'Home/Office Cleaning',
                    icon: 'house',
                    color: '0xFFFF6D00',
                    description: 'Professional On-site service',
                    image: 'assets/images/service_house_cleaning.png',
                    items: [
                        { name: '1 Bedroom Flat', price: 15000 },
                        { name: '2 Bedroom Flat', price: 25000 },
                        { name: 'Office Space (Small)', price: 20000 },
                        { name: 'Office Space (Large)', price: 40000 }
                    ],
                    serviceTypes: [
                        { name: 'Regular Clean', priceMultiplier: 1.0 },
                        { name: 'Deep Clean', priceMultiplier: 1.5 },
                        { name: 'Post-Construction', priceMultiplier: 2.0 }
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
