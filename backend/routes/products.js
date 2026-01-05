const express = require('express');
const router = express.Router();
const {
    getAllProducts,
    createProduct,
    updateProduct,
    deleteProduct,
    getCategories
} = require('../controllers/productController');

// Public/Admin shared routes
router.get('/', getAllProducts);
router.get('/categories', getCategories);

// Admin routes
router.post('/', createProduct);
router.put('/:id', updateProduct);
router.delete('/:id', deleteProduct);

module.exports = router;
