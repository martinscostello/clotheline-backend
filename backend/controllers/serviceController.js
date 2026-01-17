const Service = require('../models/Service');

exports.getAllServices = async (req, res) => {
    try {
        const { branchId, includeHidden } = req.query;

        // 1. Fetch ALL Services (Global Record)
        // We do NOT filter by 'isActive' here because:
        // - Admin needs to see inactive services to manage them.
        // - Branch logic might override 'isActive'.
        let services = await Service.find();

        if (branchId) {
            // STRICT BRANCH PROJECTION
            services = services.reduce((acc, service) => {
                const s = service.toObject();

                // 2. Resolve Branch State
                let branchIsActive = true;
                let branchIsLocked = false;
                let branchLockedLabel = s.lockedLabel || "Coming Soon";

                if (s.branchConfig && s.branchConfig.length > 0) {
                    const config = s.branchConfig.find(b => b.branchId.toString() === branchId);
                    if (config) {
                        branchIsActive = config.isActive;
                        branchIsLocked = config.isLocked;
                        if (config.lockedLabel) branchLockedLabel = config.lockedLabel;

                        // [PROJECT OVERRIDES]
                        if (config.customName) s.name = config.customName;
                        if (config.customDescription) s.description = config.customDescription;
                        if (config.discountPercentage !== undefined) s.discountPercentage = config.discountPercentage;
                        if (config.discountLabel) s.discountLabel = config.discountLabel;

                        // Service Types Override (Complete Replacement)
                        if (config.serviceTypes && config.serviceTypes.length > 0) {
                            s.serviceTypes = config.serviceTypes;
                        }
                    }
                }

                // 3. User App Visibility Rule
                // If NOT Admin (includeHidden != true) AND Service is Inactive for Branch -> Hide it.
                if (!branchIsActive && includeHidden !== 'true') {
                    return acc;
                }

                // 4. Apply State
                s.isLocked = branchIsLocked;
                s.lockedLabel = branchLockedLabel;
                s.isActive = branchIsActive; // Reflect logical state

                // 5. Project Pricing (Strict)
                if (s.items && s.items.length > 0) {
                    s.items = s.items.map(item => {
                        let finalPrice = item.price;

                        if (item.branchPricing && item.branchPricing.length > 0) {
                            const bPrice = item.branchPricing.find(bp => bp.branchId.toString() === branchId);
                            if (bPrice) {
                                finalPrice = bPrice.price;
                            }
                        }
                        return { ...item, price: finalPrice, branchPricing: undefined };
                    });
                }

                acc.push(s);
                return acc;
            }, []);
        } else {
            // Global List (No Branch)
            // If User App (includeHidden != true), only show globally active services.
            if (includeHidden !== 'true') {
                services = services.filter(s => s.isActive);
            }
        }

        res.json(services);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

exports.createService = async (req, res) => {
    try {
        const { name, icon, color, description, image, discountPercentage, discountLabel } = req.body;
        const newService = new Service({
            name, icon, color, description,
            image: image || 'assets/images/service_laundry.png',
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
            name, icon, color, description, image,
            discountPercentage, discountLabel, isActive,
            isLocked, lockedLabel, items, serviceTypes,
            branchId // [NEW] Context
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
            if (description) service.branchConfig[configIndex].customDescription = description;
            if (discountPercentage !== undefined) service.branchConfig[configIndex].discountPercentage = discountPercentage;
            if (discountLabel !== undefined) service.branchConfig[configIndex].discountLabel = discountLabel;

            // Update Service Types for Branch
            if (serviceTypes && Array.isArray(serviceTypes)) {
                service.branchConfig[configIndex].serviceTypes = serviceTypes;
            }

            service.branchConfig[configIndex].lastUpdated = Date.now();


            // 3. Update Item Pricing (Strictly for this branch)
            if (items && Array.isArray(items)) {
                items.forEach(reqItem => {
                    // Identify existing item by ID or Name
                    const dbItem = service.items.find(i =>
                        (reqItem._id && i._id.toString() === reqItem._id) ||
                        i.name === reqItem.name
                    );

                    if (dbItem) {
                        // We are updating the PRICE for this branch.
                        if (reqItem.price !== undefined) {
                            const priceIndex = dbItem.branchPricing.findIndex(bp => bp.branchId.toString() === branchId);
                            if (priceIndex > -1) {
                                dbItem.branchPricing[priceIndex].price = reqItem.price;
                            } else {
                                dbItem.branchPricing.push({
                                    branchId,
                                    price: reqItem.price,
                                    isActive: true
                                });
                            }
                        }
                    }
                });
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
