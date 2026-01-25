const express = require('express');
const router = express.Router();
const categoryController = require('../controllers/categoryController');
const auth = require('../middleware/auth');
const admin = require('../middleware/admin');

// @route   GET api/categories
// @desc    Get all categories (Global)
// @access  Public
router.get('/', categoryController.getAllCategories);

// @route   POST api/categories
// @desc    Create category (Admin)
// @access  Admin
router.post('/', auth, admin, categoryController.createCategory);

// @route   DELETE api/categories/:id
// @desc    Delete category (Admin)
// @access  Admin
router.delete('/:id', auth, admin, categoryController.deleteCategory);

module.exports = router;
