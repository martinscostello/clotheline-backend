const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5001;

const morgan = require('morgan');

// Middleware
app.use(cors());
app.use(express.json());
app.use(morgan('dev')); // Log requests to console

// Routes
app.use('/api/auth', require('./routes/auth'));

// Basic Route
app.get('/', (req, res) => {
    res.send('Laundry App Backend is running');
});

const connectDB = async () => {
    try {
        let mongoUri = process.env.MONGO_URI;

        if (!mongoUri) {
            console.log("No MONGO_URI found, starting In-Memory MongoDB...");
            const { MongoMemoryServer } = require('mongodb-memory-server');
            const mongod = await MongoMemoryServer.create();
            mongoUri = mongod.getUri();
            console.log(`In-Memory MongoDB started at ${mongoUri}`);
        } else {
            console.log(`Connecting to MongoDB at ${mongoUri}`);
        }

        await mongoose.connect(mongoUri);
        console.log('MongoDB connected');
    } catch (err) {
        console.error('MongoDB connection error:', err);
    }
};

connectDB().then(() => {
    require('./controllers/serviceController').seedServices();
    require('./controllers/productController').seedProducts();
    require('./controllers/authController').seedUsers();
});

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/services', require('./routes/services'));
app.use('/api/products', require('./routes/products'));
app.use('/api/dev', require('./routes/dev'));
app.use('/api/content', require('./routes/content'));
app.use('/api/upload', require('./routes/upload'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/delivery', require('./routes/delivery'));
app.use('/api/categories', require('./routes/categories'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/chat', require('./routes/chat'));
app.use('/api/broadcast', require('./routes/broadcast'));
app.use('/api/payments', require('./routes/payments'));
app.use('/api/reports', require('./routes/reports'));
app.use('/api/settings', require('./routes/settings'));
app.use('/api/branches', require('./routes/branches'));
app.use('/api/promotions', require('./routes/promotions'));

// Make uploads folder static
app.use('/uploads', express.static('uploads'));

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
