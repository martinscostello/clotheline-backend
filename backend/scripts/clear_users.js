const mongoose = require('mongoose');
require('dotenv').config({ path: '../.env' }); // Adjust path if running from scripts folder
const User = require('../models/User');

const clearUsers = async () => {
    try {
        let mongoUri = process.env.MONGO_URI;
        if (!mongoUri) {
            console.error("MONGO_URI not found in .env");
            process.exit(1);
        }

        await mongoose.connect(mongoUri);
        console.log('MongoDB Connected.');

        // 1. Delete All Users (except maybe admin? User asked to "delete all user data login data")
        // "delete all" implies clean slate.
        const result = await User.deleteMany({});
        console.log(`Deleted ${result.deletedCount} users.`);

        // Optional: Reset specific collections if needed, but user just asked for login data.

        console.log('User data cleared successfully.');
        process.exit();
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
};

clearUsers();
