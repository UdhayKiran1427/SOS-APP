const mysql = require('mysql2/promise');
const dotenv = require('dotenv');
const { URL } = require('url');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../../.env') });

function getConnectionConfig() {
  const databaseUrl = process.env.DATABASE_URL;

  if (databaseUrl) {
    try {
      const parsed = new URL(databaseUrl);
      return {
        host: parsed.hostname,
        port: parseInt(parsed.port || '3306', 10),
        user: decodeURIComponent(parsed.username),
        password: decodeURIComponent(parsed.password),
        database: parsed.pathname ? parsed.pathname.replace(/^\//, '') : 'defaultdb',
        ssl: {
          rejectUnauthorized: false
        }
      };
    } catch (e) {
      console.warn('Could not parse DATABASE_URL, using individual variables');
    }
  }

  const isSsl = process.env.DB_SSL === 'true' || process.env.DB_HOST?.includes('aivencloud.com');
  return {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '1234',
    database: process.env.DB_NAME || 'defaultdb',
    ...(isSsl && {
      ssl: {
        rejectUnauthorized: false
      }
    })
  };
}

const tableQueries = [
  {
    name: 'users',
    sql: `CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(100) NOT NULL,
      email VARCHAR(191) NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_users_email (email),
      INDEX idx_users_created_at (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
  },
  {
    name: 'emergency_contacts',
    sql: `CREATE TABLE IF NOT EXISTS emergency_contacts (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      name VARCHAR(100) NOT NULL,
      phone_e164 VARCHAR(20) NOT NULL,
      is_active TINYINT(1) NOT NULL DEFAULT 1,
      priority INT NOT NULL DEFAULT 1,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_user_phone (user_id, phone_e164),
      INDEX idx_contacts_user_id (user_id),
      INDEX idx_contacts_user_active (user_id, is_active),
      CONSTRAINT fk_contacts_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
  },
  {
    name: 'sos_alerts',
    sql: `CREATE TABLE IF NOT EXISTS sos_alerts (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      latitude DECIMAL(10, 8) NULL,
      longitude DECIMAL(11, 8) NULL,
      accuracy FLOAT NULL,
      location_source ENUM('live', 'last_known') NOT NULL DEFAULT 'live',
      message TEXT NOT NULL,
      triggered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      sent_count INT NOT NULL DEFAULT 0,
      failed_count INT NOT NULL DEFAULT 0,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_alerts_user_id (user_id),
      INDEX idx_alerts_triggered_at (triggered_at),
      CONSTRAINT fk_alerts_user
        FOREIGN KEY (user_id) REFERENCES users (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
  },
  {
    name: 'sos_alert_recipients',
    sql: `CREATE TABLE IF NOT EXISTS sos_alert_recipients (
      id INT AUTO_INCREMENT PRIMARY KEY,
      alert_id INT NOT NULL,
      contact_id INT NULL,
      phone VARCHAR(20) NOT NULL,
      status ENUM('sent', 'failed') NOT NULL DEFAULT 'sent',
      error VARCHAR(255) NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_recipients_alert_id (alert_id),
      INDEX idx_recipients_contact_id (contact_id),
      INDEX idx_recipients_status (status),
      CONSTRAINT fk_recipients_alert
        FOREIGN KEY (alert_id) REFERENCES sos_alerts (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
      CONSTRAINT fk_recipients_contact
        FOREIGN KEY (contact_id) REFERENCES emergency_contacts (id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
  }
];

async function initDatabase() {
  const config = getConnectionConfig();
  console.log(`Connecting to Aiven MySQL host: ${config.host}:${config.port}, database: [${config.database}]...`);

  const connection = await mysql.createConnection(config);

  try {
    for (const item of tableQueries) {
      console.log(`Creating/Verifying table: [${item.name}]...`);
      await connection.query(item.sql);
    }

    console.log(`\nAll tables initialized successfully in [${config.database}] on Aiven Cloud!`);
  } catch (err) {
    console.error('Error executing schema:', err.message);
    process.exit(1);
  } finally {
    await connection.end();
  }
}

initDatabase();
