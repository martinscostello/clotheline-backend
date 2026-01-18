const mongoose = require("mongoose");
require("dotenv").config();

const uri = process.env.MONGO_URI;

mongoose.connect(uri).then(async () => {
    console.log("Connected. Clearing orders...");
    await mongoose.connection.db.collection("orders").deleteMany({});
    console.log("All orders cleared successfully.");
    process.exit(0);
}).catch(e => {
    console.error("Error:", e);
    process.exit(1);
});
