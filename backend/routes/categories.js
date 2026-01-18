const express = require('express');
const router = express.Router();
const categoryController = require('../controllers/categoryController');

// @route   GET api/categories
// @desc    Get all categories (Global)
// @access  Public
router.get('/', categoryController.getAllCategories);

// @route   POST api/categories
// @desc    Create category (Admin)
// @access  Public (Should be Admin, but keeping simple for now/internal)
router.post('/', categoryController.createCategory);

module.exports = router;
