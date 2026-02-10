const express = require('express');
const router = express.Router();
const { getAllServices, createService, updateService, deleteService, reorderServices } = require('../controllers/serviceController');

// Public route to get services
router.get('/', getAllServices);

// Admin routes
router.post('/', createService);
router.put('/reorder', reorderServices); // [NEW] Bulk reorder
router.put('/:id', updateService);
router.delete('/:id', deleteService);

module.exports = router;
