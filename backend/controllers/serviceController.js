const Service = require('../models/Service');

exports.getAllServices = async (req, res) => {
    try {
        const { branchId } = req.query;
        let services = await Service.find({ isActive: true });

        if (branchId) {
            // Filter and Project for Branch
            services = services.reduce((acc, service) => {
                const s = service.toObject();

                // 1. Check Service Availability for Branch
                if (s.branchAvailability && s.branchAvailability.length > 0) {
                    const branchAvail = s.branchAvailability.find(b => b.branchId.toString() === branchId);
                    if (branchAvail && !branchAvail.isActive) {
                        return acc; // Skip inactive service for this branch
                    }
                }

                // 2. Project Item Prices
                if (s.items && s.items.length > 0) {
                    s.items = s.items.reduce((itemAcc, item) => {
                        let finalItem = { ...item };

                        if (item.branchPricing && item.branchPricing.length > 0) {
                            const bPrice = item.branchPricing.find(bp => bp.branchId.toString() === branchId);
                            if (bPrice) {
                                if (!bPrice.isActive) return itemAcc; // Skip inactive item
                                finalItem.price = bPrice.price; // Override price
                            }
                        }
                        itemAcc.push(finalItem);
                        return itemAcc;
                    }, []);
                }

                acc.push(s);
                return acc;
            }, []);
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

        console.log('--- UPDATE SERVICE DEBUG ---');
        console.log('Service ID:', req.params.id);
        console.log('Branch Context:', branchId ? branchId : 'Global/Base');

        let service = await Service.findById(req.params.id);
        if (!service) return res.status(404).json({ msg: 'Service not found' });

        // IF BRANCH CONTEXT EXISTS -> ONLY UPDATE BRANCH SPECIFIC DATA
        if (branchId) {
            console.log(`Scoped Update for Branch: ${branchId}`);

            // 1. Update Top-Level Availability for Branch
            if (isActive !== undefined) {
                const availIndex = service.branchAvailability.findIndex(b => b.branchId.toString() === branchId);
                if (availIndex > -1) {
                    service.branchAvailability[availIndex].isActive = isActive;
                } else {
                    service.branchAvailability.push({ branchId, isActive });
                }
            } else if (isLocked !== undefined) {
                // [FIX] Map "Lock" (Frontend) to "Inactive" (Backend) for Branch
                const activeState = !isLocked;
                const availIndex = service.branchAvailability.findIndex(b => b.branchId.toString() === branchId);
                if (availIndex > -1) {
                    service.branchAvailability[availIndex].isActive = activeState;
                } else {
                    service.branchAvailability.push({ branchId, isActive: activeState });
                }
            }

            // 2. Update Items Pricing (Scoped)
            if (items && Array.isArray(items)) {
                items.forEach(updatedItem => {
                    // Find matching item in DB (by ID if possible, else Name)
                    // Note: verifying by ID is safer if frontend sends it
                    let dbItem = service.items.find(i =>
                        (updatedItem._id && i._id.toString() === updatedItem._id) ||
                        i.name === updatedItem.name
                    );

                    if (dbItem) {
                        // We strictly update ONLY the pricing for this branch
                        // We do NOT update the name or base price here

                        const newPrice = updatedItem.price; // Admin sent this as "the price"

                        const priceIndex = dbItem.branchPricing.findIndex(bp => bp.branchId.toString() === branchId);
                        if (priceIndex > -1) {
                            if (updatedItem.isActive !== undefined) dbItem.branchPricing[priceIndex].isActive = updatedItem.isActive;
                            if (newPrice !== undefined) dbItem.branchPricing[priceIndex].price = newPrice;
                        } else {
                            // Create new override
                            dbItem.branchPricing.push({
                                branchId,
                                price: newPrice !== undefined ? newPrice : dbItem.price, // Fallback to base if undefined, but unlikely
                                isActive: updatedItem.isActive ?? true
                            });
                        }
                    }
                });
            }

            // [NOTE] serviceTypes currently don't have branch scoping in schema (priceMultiplier is global).
            // If needed, schema update required. For now, we assume Multipliers are Global.

        } else {
            // GLOBAL UPDATE (Default Behavior) - Updates Base Values
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

            // For items, we replace/update logic needs care to not wipe branch pricing
            // Simple approach: If items sent, we update basic fields, preserving branchPricing
            if (items) {
                // Check if we are replacing list or updating.
                // Mongoose might replace existing array if we just do service.items = items;
                // But newly sent items won't have branchPricing data usually.

                // Smart Merge for Global Update:
                // Map new items to existing to preserve branchPricing
                const mergedItems = items.map(newItem => {
                    const existing = service.items.find(i => i.name === newItem.name); // Match by name or ID
                    if (existing) {
                        return {
                            ...newItem,
                            branchPricing: existing.branchPricing // PRESERVE THIS
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
