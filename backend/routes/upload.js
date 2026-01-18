const express = require('express');
const router = express.Router();
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');
require('dotenv').config();

// Configure Cloudinary
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

// Configure Storage
const storage = new CloudinaryStorage({
    cloudinary: cloudinary,
    params: {
        folder: 'clotheline_uploads', // Folder in Cloudinary
        allowed_formats: ['jpg', 'png', 'jpeg', 'gif', 'mp4', 'mov', 'avi'],
        resource_type: 'auto', // Auto-detect image vs video
        public_id: (req, file) => file.fieldname + '-' + Date.now(), // Unique filename
    },
});

// Init Upload
const upload = multer({
    storage: storage,
    limits: { fileSize: 50000000 }, // 50MB limit
}).single('image');

// Upload Route
router.post('/', (req, res) => {
    upload(req, res, (err) => {
        if (err) {
            console.error("Upload Error:", err);
            return res.status(400).json({ message: err.message || err });
        }

        if (!req.file) {
            return res.status(400).json({ message: 'No file selected!' });
        }

        // Return the Cloudinary URL
        // req.file.path contains the secure URL from Cloudinary
        res.json({
            message: 'File Uploaded to Cloud!',
            filePath: req.file.path
        });
    });
});

module.exports = router;
