const pool = require('../config/db');

// Helper to normalize phone to E.164 if missing leading +
function normalizePhone(phone, defaultCountryCode = '+91') {
  if (!phone) return '';
  let cleaned = phone.replace(/[\s\-\(\)]/g, '');
  if (cleaned.startsWith('00')) {
    cleaned = '+' + cleaned.substring(2);
  } else if (!cleaned.startsWith('+')) {
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    cleaned = defaultCountryCode + cleaned;
  }
  return cleaned;
}

exports.getContacts = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const [contacts] = await pool.execute(
      `SELECT id, user_id, name, phone_e164, is_active, priority, created_at, updated_at
       FROM emergency_contacts
       WHERE user_id = ?
       ORDER BY priority ASC, id ASC`,
      [userId]
    );

    return res.status(200).json({
      success: true,
      count: contacts.length,
      contacts: contacts.map(c => ({
        ...c,
        is_active: Boolean(c.is_active)
      }))
    });
  } catch (err) {
    next(err);
  }
};

exports.addContact = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { name, phone_e164, is_active = true, priority = 1 } = req.body;

    const normalizedPhone = normalizePhone(phone_e164);
    const activeValue = is_active ? 1 : 0;
    const priorityValue = parseInt(priority, 10) || 1;

    // Check if phone already registered for this user
    const [existing] = await pool.execute(
      'SELECT id FROM emergency_contacts WHERE user_id = ? AND phone_e164 = ? LIMIT 1',
      [userId, normalizedPhone]
    );

    if (existing.length > 0) {
      // Update existing instead or notify conflict
      return res.status(409).json({
        success: false,
        message: 'This phone number is already in your emergency contacts.',
        contact_id: existing[0].id
      });
    }

    const [result] = await pool.execute(
      `INSERT INTO emergency_contacts (user_id, name, phone_e164, is_active, priority)
       VALUES (?, ?, ?, ?, ?)`,
      [userId, name.trim(), normalizedPhone, activeValue, priorityValue]
    );

    const newContact = {
      id: result.insertId,
      user_id: userId,
      name: name.trim(),
      phone_e164: normalizedPhone,
      is_active: Boolean(activeValue),
      priority: priorityValue
    };

    return res.status(201).json({
      success: true,
      message: 'Emergency contact added successfully.',
      contact: newContact
    });
  } catch (err) {
    next(err);
  }
};

exports.updateContact = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const contactId = parseInt(req.params.id, 10);
    const { name, phone_e164, is_active, priority } = req.body;

    // Verify contact belongs to user
    const [existing] = await pool.execute(
      'SELECT id, name, phone_e164, is_active, priority FROM emergency_contacts WHERE id = ? AND user_id = ? LIMIT 1',
      [contactId, userId]
    );

    if (existing.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found or does not belong to you.'
      });
    }

    const current = existing[0];
    const updatedName = name !== undefined ? name.trim() : current.name;
    const updatedPhone = phone_e164 !== undefined ? normalizePhone(phone_e164) : current.phone_e164;
    const updatedActive = is_active !== undefined ? (is_active ? 1 : 0) : current.is_active;
    const updatedPriority = priority !== undefined ? parseInt(priority, 10) : current.priority;

    // Check duplicate if phone is changed
    if (updatedPhone !== current.phone_e164) {
      const [dup] = await pool.execute(
        'SELECT id FROM emergency_contacts WHERE user_id = ? AND phone_e164 = ? AND id != ? LIMIT 1',
        [userId, updatedPhone, contactId]
      );
      if (dup.length > 0) {
        return res.status(409).json({
          success: false,
          message: 'Another contact with this phone number already exists.'
        });
      }
    }

    await pool.execute(
      `UPDATE emergency_contacts
       SET name = ?, phone_e164 = ?, is_active = ?, priority = ?
       WHERE id = ? AND user_id = ?`,
      [updatedName, updatedPhone, updatedActive, updatedPriority, contactId, userId]
    );

    return res.status(200).json({
      success: true,
      message: 'Emergency contact updated successfully.',
      contact: {
        id: contactId,
        user_id: userId,
        name: updatedName,
        phone_e164: updatedPhone,
        is_active: Boolean(updatedActive),
        priority: updatedPriority
      }
    });
  } catch (err) {
    next(err);
  }
};

exports.deleteContact = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const contactId = parseInt(req.params.id, 10);

    const [result] = await pool.execute(
      'DELETE FROM emergency_contacts WHERE id = ? AND user_id = ?',
      [contactId, userId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'Contact not found or does not belong to you.'
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Emergency contact removed successfully.'
    });
  } catch (err) {
    next(err);
  }
};

