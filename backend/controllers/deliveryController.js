const DeliverySettings = require('../models/DeliverySettings');

// Default Seed Data
// Default Seed Data (Concentric Distance Bands)
const DEFAULT_ZONES = [
    {
        name: "Zone A - Immediate",
        description: "0 - 2.5 km (Neighborhood)",
        radiusKm: 2.5, // Max distance for this band
        baseFee: 500,  // Low/Free
        color: '4CAF50' // Green
    },
    {
        name: "Zone B - Core City",
        description: "2.5 - 5.5 km (City Center)",
        radiusKm: 5.5,
        baseFee: 1000,
        color: 'FFC107' // Amber
    },
    {
        name: "Zone C - Extended",
        description: "5.5 - 9.0 km (Suburbs)",
        radiusKm: 9.0,
        baseFee: 1500,
        color: 'FF9800' // Orange
    },
    {
        name: "Zone D - Outskirts",
        description: "9.0 - 14.0 km (Far)",
        radiusKm: 14.0,
        baseFee: 2500,
        color: 'F44336' // Red
    }
];

// Get Settings (Seed if empty)
exports.getSettings = async (req, res) => {
    try {
        let settings = await DeliverySettings.findOne();
        if (!settings) {
            settings = new DeliverySettings({
                laundryLocation: { lat: 6.303337, lng: 5.5945522 },
                zones: DEFAULT_ZONES
            });
            await settings.save();
        }
        res.json(settings);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};

// Update Settings
exports.updateSettings = async (req, res) => {
    try {
        const { laundryLocation, freeDistanceKm, perKmCharge, zones, isDistanceBillingEnabled } = req.body;

        // Find the singleton document
        let settings = await DeliverySettings.findOne();
        if (!settings) {
            // Should exist from GET, but just in case
            settings = new DeliverySettings();
        }

        if (laundryLocation) settings.laundryLocation = laundryLocation;
        if (freeDistanceKm !== undefined) settings.freeDistanceKm = freeDistanceKm;
        if (perKmCharge !== undefined) settings.perKmCharge = perKmCharge;
        if (zones) settings.zones = zones;
        if (isDistanceBillingEnabled !== undefined) settings.isDistanceBillingEnabled = isDistanceBillingEnabled;

        settings.updatedAt = Date.now();
        await settings.save();

        res.json(settings);

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
};
