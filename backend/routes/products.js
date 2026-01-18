const express = require('express');
const router = express.Router();
const {
    getAllProducts,
    createProduct,
    updateProduct,
    deleteProduct,
    getCategories,
    migrateLegacyProducts // Added
} = require('../controllers/productController');

// Public/Admin shared routes
router.get('/', getAllProducts);
router.get('/categories', getCategories);
router.get('/migrate/fix', migrateLegacyProducts); // Clean Migration Route

// Admin routes
router.post('/', createProduct);
router.put('/:id', updateProduct);
router.delete('/:id', deleteProduct);

module.exports = router;
