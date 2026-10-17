const mysql = require('mysql2/promise');
const dotenv = require('dotenv');
const { URL } = require('url');

dotenv.config();

function getPoolConfig() {
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
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0,
        charset: 'utf8mb4',
        ssl: {
          rejectUnauthorized: false
        }
      };
    } catch (e) {
      console.warn('Could not parse DATABASE_URL, falling back to individual variables:', e.message);
    }
  }

  const isSsl = process.env.DB_SSL === 'true' || process.env.DB_HOST?.includes('aivencloud.com');
  return {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'defaultdb',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    charset: 'utf8mb4',
    ...(isSsl && {
      ssl: {
        rejectUnauthorized: false
      }
    })
  };
}

const pool = mysql.createPool(getPoolConfig());

module.exports = pool;
