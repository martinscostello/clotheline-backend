const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');

// Configure Storage
const storage = multer.diskStorage({
    destination: './uploads/',
    filename: function (req, file, cb) {
        // Create unique filename: fieldname-timestamp.ext
        cb(null, file.fieldname + '-' + Date.now() + path.extname(file.originalname));
    }
});

// Init Upload
const upload = multer({
    storage: storage,
    limits: { fileSize: 5000000 }, // 5MB limit
    fileFilter: function (req, file, cb) {
        checkFileType(file, cb);
    }
}).single('image'); // 'image' is the field name we expect

// Check File Type
function checkFileType(file, cb) {
    const filetypes = /jpeg|jpg|png|gif/;
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = filetypes.test(file.mimetype);

    if (mimetype && extname) {
        return cb(null, true);
    } else {
        cb('Error: Images Only!');
    }
}

// Upload Route
router.post('/', (req, res) => {
    upload(req, res, (err) => {
        if (err) {
            res.status(400).json({ message: err });
        } else {
            if (req.file == undefined) {
                res.status(400).json({ message: 'No file selected!' });
            } else {
                // Return the public URL
                // Assuming server runs on localhost:5001 or similar, we return relative path
                // Frontend or Backend logic should prepend base URL if needed.
                // Here we return full relative path that can be served statically
                const fileUrl = `/uploads/${req.file.filename}`;
                res.json({
                    message: 'File Uploaded!',
                    filePath: fileUrl
                });
            }
        }
    });
});

module.exports = router;
