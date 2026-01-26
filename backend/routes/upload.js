const express = require('express');
const router = express.Router();
const multer = require('multer');
const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');

// Configure Multer to use memory storage
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 50 * 1024 * 1024 }, // 50MB limit
}).single('image');

// Upload Route
router.post('/', (req, res) => {
    upload(req, res, async (err) => {
        if (err) {
            console.error("===== Upload Execution Error =====");
            console.error("Error Code:", err.code);
            console.error("Error Message:", err.message);
            console.error("==================================");

            return res.status(400).json({
                message: err.message || 'Upload failed',
                error: err.code || 'UPLOAD_ERROR'
            });
        }

        if (!req.file) {
            return res.status(400).json({ message: 'No file selected!' });
        }

        try {
            const bucket = admin.storage().bucket();
            const fileName = `clotheline_uploads/${uuidv4()}-${req.file.originalname}`;
            const file = bucket.file(fileName);

            const stream = file.createWriteStream({
                metadata: {
                    contentType: req.file.mimetype,
                }
            });

            stream.on('error', (error) => {
                console.error("Firebase Upload Stream Error:", error);
                res.status(500).json({ message: 'Failed to upload to Firebase' });
            });

            stream.on('finish', async () => {
                // Make the file public (Simple approach for public access)
                await file.makePublic();

                // Construct public URL
                const publicUrl = `https://storage.googleapis.com/${bucket.name}/${file.name}`;

                res.json({
                    message: 'File Uploaded to Firebase!',
                    filePath: publicUrl
                });
            });

            stream.end(req.file.buffer);

        } catch (error) {
            console.error("Firebase Storage Error:", error);
            res.status(500).json({ message: 'Storage error' });
        }
    });
});

module.exports = router;
