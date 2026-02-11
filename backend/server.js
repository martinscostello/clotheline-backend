const path = require('path');
const fs = require('fs');



const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 5001;

const morgan = require('morgan');

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use(morgan('dev')); // Log requests to console

// Initial Routes (Moving all to after connectDB for consistency)
// Last Deployment Fix: 2026-02-11 17:15 (FORCE REDEPLOY)

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

        if (process.env.EMAIL_USER && process.env.EMAIL_PASS) {
            console.log(`✅ Email Service: Enabled (${process.env.EMAIL_USER})`);
        } else {
            console.log(`⚠️  Email Service: Mock Mode (Missing Credentials) - CHECK .ENV`);
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
    require('./controllers/categoryController').seedCategories();
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
app.use('/api/chat', require('./routes/chat_routes'));
app.use('/api/broadcast', require('./routes/broadcast'));
app.use('/api/payments', require('./routes/payments'));
app.use('/api/reports', require('./routes/reports'));
app.use('/api/settings', require('./routes/settings'));
app.use('/api/branches', require('./routes/branches'));
app.use('/api/staff', require('./routes/staff'));
app.use('/api/users', require('./routes/users'));
app.use('/api/promotions', require('./routes/promotions'));
app.use('/api/reviews', require('./routes/reviews'));
app.use('/api/analytics', require('./routes/analytics'));

// Make uploads folder static
app.use('/uploads', express.static('uploads'));

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);

    // Background Cleanup: Auto-delete 'resolved' chat threads after 3 days
    setInterval(async () => {
        try {
            const ChatThread = require('./models/ChatThread');
            const ChatMessage = require('./models/ChatMessage');
            const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);

            const threadsToDelete = await ChatThread.find({
                status: 'resolved',
                resolvedAt: { $lt: threeDaysAgo }
            }).select('_id');

            if (threadsToDelete.length > 0) {
                const ids = threadsToDelete.map(t => t._id);
                await ChatMessage.deleteMany({ threadId: { $in: ids } });
                await ChatThread.deleteMany({ _id: { $in: ids } });
                console.log(`[Cleanup] Deleted ${ids.length} resolved threads + messages.`);
            }
        } catch (e) {
            console.error("[Cleanup Error]", e);
        }
    }, 24 * 60 * 60 * 1000); // Run once a day
});
