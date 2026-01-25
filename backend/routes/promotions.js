const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const promotionController = require('../controllers/promotionController');

router.post('/', auth, promotionController.createPromotion);
router.get('/', auth, promotionController.getPromotions);
router.delete('/:id', auth, promotionController.deletePromotion);
router.post('/validate', auth, promotionController.validatePromotion); // Auth optional? Usually Auth required for cart.

module.exports = router;
