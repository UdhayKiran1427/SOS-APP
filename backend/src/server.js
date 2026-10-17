const dotenv = require('dotenv');
const path = require('path');

// Load environment variables before anything else
dotenv.config({ path: path.join(__dirname, '../.env') });

const app = require('./app');
const pool = require('./config/db');

const PORT = parseInt(process.env.PORT, 10) || 3000;

async function startServer() {
  try {
    // Verify MySQL connection
    const connection = await pool.getConnection();
    console.log(`Connected to MySQL database [${process.env.DB_NAME || 'dailykit_db'}] successfully.`);
    connection.release();

    app.listen(PORT, '0.0.0.0', () => {
      console.log(`===============================================`);
      console.log(` DailyKit SOS API Server running on port ${PORT}`);
      console.log(` Local:   http://localhost:${PORT}`);
      console.log(` Health:  http://localhost:${PORT}/health`);
      console.log(`===============================================`);
    });
  } catch (err) {
    console.error('Failed to start server:', err.message);
    process.exit(1);
  }
}

startServer();

