const dotenv = require('dotenv');
const path = require('path');

// Load environment variables before anything else
dotenv.config({ path: path.join(__dirname, '../.env') });

const app = require('./app');
const pool = require('./config/db');

const PORT = parseInt(process.env.PORT, 10) || 3000;

// Start listening immediately so cloud host port check passes without delay
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`===============================================`);
  console.log(` AU APP SOS API Server running on port ${PORT}`);
  console.log(` Local:   http://localhost:${PORT}`);
  console.log(` Health:  http://localhost:${PORT}/health`);
  console.log(`===============================================`);
});

// Asynchronously verify database connection
(async () => {
  try {
    const connection = await pool.getConnection();
    console.log(`Connected to MySQL database [${process.env.DB_NAME || 'defaultdb'}] successfully.`);
    connection.release();
  } catch (err) {
    console.error('MySQL connection warning (retrying in background):', err.message);
  }
})();
