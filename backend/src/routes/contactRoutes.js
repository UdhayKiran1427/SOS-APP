const express = require('express');
const { body, param } = require('express-validator');
const contactController = require('../controllers/contactController');
const authMiddleware = require('../middleware/authMiddleware');
const validationMiddleware = require('../middleware/validationMiddleware');

const router = express.Router();

// All contact routes require JWT authentication
router.use(authMiddleware);

router.get('/', contactController.getContacts);

router.post(
  '/',
  [
    body('name').trim().notEmpty().withMessage('Contact name is required').isLength({ max: 100 }).withMessage('Name too long'),
    body('phone_e164').trim().notEmpty().withMessage('Phone number is required').matches(/^\+?[0-9]{7,15}$/).withMessage('Valid phone number with country code is required (e.g. +919876543210)'),
    body('priority').optional().isInt({ min: 1, max: 100 }).withMessage('Priority must be an integer between 1 and 100'),
    body('is_active').optional().isBoolean().withMessage('is_active must be a boolean'),
    validationMiddleware
  ],
  contactController.addContact
);

router.put(
  '/:id',
  [
    param('id').isInt().withMessage('Invalid contact ID'),
    body('name').optional().trim().notEmpty().withMessage('Contact name cannot be empty').isLength({ max: 100 }),
    body('phone_e164').optional().trim().matches(/^\+?[0-9]{7,15}$/).withMessage('Valid phone number is required'),
    body('priority').optional().isInt({ min: 1, max: 100 }).withMessage('Priority must be between 1 and 100'),
    body('is_active').optional().isBoolean().withMessage('is_active must be a boolean'),
    validationMiddleware
  ],
  contactController.updateContact
);

router.delete(
  '/:id',
  [
    param('id').isInt().withMessage('Invalid contact ID'),
    validationMiddleware
  ],
  contactController.deleteContact
);

module.exports = router;

