const express = require('express');
const router = express.Router();
const { getAllServices, createService, updateService, deleteService } = require('../controllers/serviceController');

// Public route to get services
router.get('/', getAllServices);

// Admin routes
router.post('/', createService);
router.put('/:id', updateService);
router.delete('/:id', deleteService);

module.exports = router;
