const express = require('express');
const cors = require('cors');
const morgan = require('morgan');

const authRoutes = require('./routes/authRoutes');
const contactRoutes = require('./routes/contactRoutes');
const sosRoutes = require('./routes/sosRoutes');

const app = express();

// Global Middlewares
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// Welcome / Root endpoint for browser visits
app.get('/', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'AU APP Emergency SOS REST API is running live!',
    version: '1.0.0',
    status: 'online',
    healthCheck: '/health',
    endpoints: {
      auth: ['POST /auth/register', 'POST /auth/login', 'GET /auth/me'],
      contacts: ['GET /contacts', 'POST /contacts', 'PUT /contacts/:id', 'DELETE /contacts/:id'],
      sos: ['POST /sos/log', 'GET /sos/history']
    },
    timestamp: new Date().toISOString()
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'AU APP Emergency SOS REST API',
    timestamp: new Date().toISOString()
  });
});

// API Routes
app.use('/auth', authRoutes);
app.use('/contacts', contactRoutes);
app.use('/sos', sosRoutes);

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Cannot ${req.method} ${req.originalUrl}`
  });
});

// Central Error Handler
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err);
  const status = err.status || 500;
  res.status(status).json({
    success: false,
    message: err.message || 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

module.exports = app;
