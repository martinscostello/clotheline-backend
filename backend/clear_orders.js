const mongoose = require("mongoose");
require("dotenv").config();

const uri = process.env.MONGO_URI;

mongoose.connect(uri).then(async () => {
    console.log("Connected. Starting cleanup...");

    const collections = ["orders", "payments", "notifications", "chatmessages", "chatthreads"];

    for (const collectionName of collections) {
        try {
            const result = await mongoose.connection.db.collection(collectionName).deleteMany({});
            console.log(`Cleared ${collectionName}: ${result.deletedCount} items removed.`);
        } catch (err) {
            console.warn(`Could not clear ${collectionName} (might not exist):`, err.message);
        }
    }

    console.log("Database cleared successfully for real data tracking.");
    process.exit(0);
}).catch(e => {
    console.error("Error:", e);
    process.exit(1);
});
