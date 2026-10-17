const pool = require('../config/db');

exports.logAlert = async (req, res, next) => {
  const connection = await pool.getConnection();
  try {
    const userId = req.user.id;
    const {
      latitude = null,
      longitude = null,
      accuracy = null,
      location_source = 'live',
      message,
      triggered_at = new Date(),
      sent_count = 0,
      failed_count = 0,
      recipients = []
    } = req.body;

    const formattedTriggeredAt = new Date(triggered_at)
      .toISOString()
      .slice(0, 19)
      .replace('T', ' ');

    await connection.beginTransaction();

    // 1. Insert alert record
    const [alertResult] = await connection.execute(
      `INSERT INTO sos_alerts 
       (user_id, latitude, longitude, accuracy, location_source, message, triggered_at, sent_count, failed_count)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        userId,
        latitude !== null && latitude !== undefined ? latitude : null,
        longitude !== null && longitude !== undefined ? longitude : null,
        accuracy !== null && accuracy !== undefined ? accuracy : null,
        location_source === 'last_known' ? 'last_known' : 'live',
        message || 'SOS Emergency Alert',
        formattedTriggeredAt,
        parseInt(sent_count, 10) || 0,
        parseInt(failed_count, 10) || 0
      ]
    );

    const alertId = alertResult.insertId;

    // 2. Insert alert recipients
    if (Array.isArray(recipients) && recipients.length > 0) {
      for (const rec of recipients) {
        let contactId = rec.contact_id ? parseInt(rec.contact_id, 10) : null;

        // If contact_id is provided, verify it actually exists to avoid FK error
        if (contactId) {
          const [contactCheck] = await connection.execute(
            'SELECT id FROM emergency_contacts WHERE id = ? LIMIT 1',
            [contactId]
          );
          if (contactCheck.length === 0) {
            contactId = null;
          }
        }

        await connection.execute(
          `INSERT INTO sos_alert_recipients
           (alert_id, contact_id, phone, status, error)
           VALUES (?, ?, ?, ?, ?)`,
          [
            alertId,
            contactId,
            rec.phone || '',
            rec.status === 'failed' ? 'failed' : 'sent',
            rec.error ? String(rec.error).substring(0, 255) : null
          ]
        );
      }
    }

    await connection.commit();

    return res.status(201).json({
      success: true,
      message: 'SOS alert logged successfully.',
      alert_id: alertId
    });
  } catch (err) {
    await connection.rollback();
    next(err);
  } finally {
    connection.release();
  }
};

exports.getHistory = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const offset = (page - 1) * limit;

    // Count total alerts
    const [countResult] = await pool.execute(
      'SELECT COUNT(*) as total FROM sos_alerts WHERE user_id = ?',
      [userId]
    );
    const total = countResult[0].total;

    // Fetch alerts
    const [alerts] = await pool.query(
      `SELECT id, user_id, latitude, longitude, accuracy, location_source,
              message, triggered_at, sent_count, failed_count, created_at
       FROM sos_alerts
       WHERE user_id = ?
       ORDER BY triggered_at DESC
       LIMIT ? OFFSET ?`,
      [userId, limit, offset]
    );

    if (alerts.length === 0) {
      return res.status(200).json({
        success: true,
        page,
        limit,
        total,
        alerts: []
      });
    }

    // Fetch recipients for these alerts
    const alertIds = alerts.map(a => a.id);
    const placeholders = alertIds.map(() => '?').join(',');
    const [recipients] = await pool.query(
      `SELECT r.id, r.alert_id, r.contact_id, r.phone, r.status, r.error, c.name as contact_name
       FROM sos_alert_recipients r
       LEFT JOIN emergency_contacts c ON r.contact_id = c.id
       WHERE r.alert_id IN (${placeholders})
       ORDER BY r.id ASC`,
      alertIds
    );

    // Map recipients to respective alerts
    const recipientsByAlert = {};
    for (const rec of recipients) {
      if (!recipientsByAlert[rec.alert_id]) {
        recipientsByAlert[rec.alert_id] = [];
      }
      recipientsByAlert[rec.alert_id].push({
        id: rec.id,
        contact_id: rec.contact_id,
        contact_name: rec.contact_name || null,
        phone: rec.phone,
        status: rec.status,
        error: rec.error
      });
    }

    const detailedAlerts = alerts.map(alert => ({
      ...alert,
      recipients: recipientsByAlert[alert.id] || []
    }));

    return res.status(200).json({
      success: true,
      page,
      limit,
      total,
      alerts: detailedAlerts
    });
  } catch (err) {
    next(err);
  }
};

