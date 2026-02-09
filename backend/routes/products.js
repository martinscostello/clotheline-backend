const express = require('express');
const router = express.Router();
const {
    getAllProducts,
    createProduct,
    updateProduct,
    deleteProduct,
    getCategories,
    migrateLegacyProducts,
    getLatestPresets // [NEW]
} = require('../controllers/productController');

// Public/Admin shared routes
router.get('/', getAllProducts);
router.get('/categories', getCategories);
router.get('/presets', getLatestPresets); // [NEW]
router.get('/migrate/fix', migrateLegacyProducts);

// Admin routes
router.post('/', createProduct);
router.put('/:id', updateProduct);
router.delete('/:id', deleteProduct);

module.exports = router;
