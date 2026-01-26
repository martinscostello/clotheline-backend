const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { getSavedAddresses, addSavedAddress, deleteSavedAddress } = require('../controllers/userController');

// All routes require auth
router.use(auth);

router.get('/addresses', getSavedAddresses);
router.post('/addresses', addSavedAddress);
router.delete('/addresses/:addressId', deleteSavedAddress);

module.exports = router;
