const mongoose = require('mongoose');
const Order = require('./models/Order');
const User = require('./models/User');

const MONGO_URI = 'mongodb+srv://clotheline_admin:YkEm5z7HBhmQbVPT@cluster0.mfrdlw7.mongodb.net/clotheline_db?appName=Cluster0';
const Settings = require('./models/Settings');

const debugOrder = async () => {
    try {
        await mongoose.connect(MONGO_URI);
        console.log("Connected to DB - Checking Settings");

        const settingsCount = await Settings.countDocuments();
        console.log(`Total Settings Docs: ${settingsCount}`);

        const allSettings = await Settings.find();
        allSettings.forEach((s, i) => {
            console.log(`Setting #${i + 1}: TaxRate=${s.taxRate}, Enabled=${s.taxEnabled}, ID=${s._id}`);
        });

        // Fetch latest order too
        const order = await Order.findOne().sort({ createdAt: -1 });

        if (order) console.log(`Latest Order Total: ${order.totalAmount} (Sub: ${order.subtotal})`);

        process.exit();
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
};

debugOrder();
