const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '.env') });

const Service = require('./models/Service');
const Order = require('./models/Order');

async function migrate() {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('Connected to MongoDB');

        const serviceResult = await Service.updateMany(
            { fulfillmentMode: { $exists: false } },
            { $set: { fulfillmentMode: 'logistics', requiresTermsAcceptance: false } }
        );
        console.log(`Updated ${serviceResult.modifiedCount} services`);

        const orderResult = await Order.updateMany(
            { fulfillmentMode: { $exists: false } },
            { $set: { fulfillmentMode: 'logistics' } }
        );
        console.log(`Updated ${orderResult.modifiedCount} orders`);

        process.exit(0);
    } catch (err) {
        console.error('Migration failed:', err);
        process.exit(1);
    }
}

migrate();
