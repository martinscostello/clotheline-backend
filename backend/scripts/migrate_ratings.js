const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const Staff = require('../models/Staff');

const migrate = async () => {
    try {
        console.log("Connecting to DB:", process.env.MONGO_URI);
        await mongoose.connect(process.env.MONGO_URI);
        console.log("Connected to DB");

        const staffList = await Staff.find({});
        console.log(`Found ${staffList.length} staff members.`);

        for (const staff of staffList) {
            let changed = false;

            // Log current state
            console.log(`Checking ${staff.name}: Rating=${staff.performance?.rating}, IDCard=${staff.idCardImage ? 'YES' : 'NO'}`);

            // Fix Rating
            if (!staff.performance || staff.performance.rating === 0 || staff.performance.rating === undefined) {
                if (!staff.performance) staff.performance = { rating: 5.0, log: [] };
                staff.performance.rating = 5.0;
                changed = true;
                console.log(`-> Updated rating for ${staff.name} to 5.0`);
            }

            if (changed) {
                await staff.save();
                console.log(`-> Saved ${staff.name}`);
            }
        }
        console.log("Migration Complete");
        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
};

migrate();
