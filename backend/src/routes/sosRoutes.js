const express = require('express');
const { body, query } = require('express-validator');
const sosController = require('../controllers/sosController');
const authMiddleware = require('../middleware/authMiddleware');
const validationMiddleware = require('../middleware/validationMiddleware');

const router = express.Router();

// All SOS routes require JWT authentication
router.use(authMiddleware);

router.post(
  '/log',
  [
    body('message').trim().notEmpty().withMessage('SOS alert message is required'),
    body('location_source').optional().isIn(['live', 'last_known']).withMessage('location_source must be live or last_known'),
    body('latitude').optional({ nullable: true }).isFloat({ min: -90, max: 90 }).withMessage('Latitude must be between -90 and 90'),
    body('longitude').optional({ nullable: true }).isFloat({ min: -180, max: 180 }).withMessage('Longitude must be between -180 and 180'),
    body('accuracy').optional({ nullable: true }).isFloat({ min: 0 }).withMessage('Accuracy must be positive'),
    body('sent_count').optional().isInt({ min: 0 }).withMessage('sent_count must be non-negative integer'),
    body('failed_count').optional().isInt({ min: 0 }).withMessage('failed_count must be non-negative integer'),
    body('recipients').optional().isArray().withMessage('recipients must be an array'),
    body('recipients.*.phone').optional().trim().notEmpty().withMessage('Recipient phone is required'),
    body('recipients.*.status').optional().isIn(['sent', 'failed']).withMessage('Recipient status must be sent or failed'),
    validationMiddleware
  ],
  sosController.logAlert
);

router.get(
  '/history',
  [
    query('page').optional().isInt({ min: 1 }).withMessage('Page must be >= 1'),
    query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
    validationMiddleware
  ],
  sosController.getHistory
);

module.exports = router;

