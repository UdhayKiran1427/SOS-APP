const http = require('http');

const PORT = 3000;
const BASE_URL = `http://localhost:${PORT}`;

function request(method, path, data = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const headers = {
      'Content-Type': 'application/json'
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const payload = data ? JSON.stringify(data) : null;
    if (payload) {
      headers['Content-Length'] = Buffer.byteLength(payload);
    }

    const req = http.request(
      url,
      {
        method,
        headers
      },
      res => {
        let body = '';
        res.on('data', chunk => (body += chunk));
        res.on('end', () => {
          let parsed;
          try {
            parsed = JSON.parse(body);
          } catch {
            parsed = body;
          }
          resolve({ status: res.statusCode, body: parsed });
        });
      }
    );

    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function runTests() {
  console.log('--- Starting DailyKit SOS Backend API Tests ---');

  // 1. Health check
  console.log('\n1. Testing GET /health');
  const healthRes = await request('GET', '/health');
  console.log('Status:', healthRes.status, 'Body:', healthRes.body);
  if (healthRes.status !== 200 || healthRes.body.status !== 'ok') {
    throw new Error('Health check failed');
  }

  // 2. Auth Register
  const testEmail = `sos_test_${Date.now()}@dailykit.local`;
  console.log(`\n2. Testing POST /auth/register with ${testEmail}`);
  const regRes = await request('POST', '/auth/register', {
    name: 'Test Emergency User',
    email: testEmail,
    password: 'password123'
  });
  console.log('Status:', regRes.status, 'Response:', regRes.body);
  if (regRes.status !== 201 || !regRes.body.token) {
    throw new Error('Register failed');
  }

  const token = regRes.body.token;
  const userId = regRes.body.user.id;

  // 3. Auth Login
  console.log('\n3. Testing POST /auth/login');
  const loginRes = await request('POST', '/auth/login', {
    email: testEmail,
    password: 'password123'
  });
  console.log('Status:', loginRes.status, 'User:', loginRes.body.user);
  if (loginRes.status !== 200 || !loginRes.body.token) {
    throw new Error('Login failed');
  }

  // 4. Auth Me
  console.log('\n4. Testing GET /auth/me');
  const meRes = await request('GET', '/auth/me', null, token);
  console.log('Status:', meRes.status, 'Profile:', meRes.body);
  if (meRes.status !== 200) throw new Error('/auth/me failed');

  // 5. Add Contact
  console.log('\n5. Testing POST /contacts');
  const addContactRes = await request(
    'POST',
    '/contacts',
    {
      name: 'Dr. Jane Smith',
      phone_e164: '+919876543210',
      is_active: true,
      priority: 1
    },
    token
  );
  console.log('Status:', addContactRes.status, 'Created Contact:', addContactRes.body);
  if (addContactRes.status !== 201) throw new Error('Add contact failed');
  const contactId = addContactRes.body.contact.id;

  // 6. Get Contacts
  console.log('\n6. Testing GET /contacts');
  const getContactsRes = await request('GET', '/contacts', null, token);
  console.log('Status:', getContactsRes.status, 'Count:', getContactsRes.body.count, 'Contacts:', getContactsRes.body.contacts);
  if (getContactsRes.status !== 200 || getContactsRes.body.contacts.length === 0) {
    throw new Error('Get contacts failed');
  }

  // 7. Update Contact
  console.log(`\n7. Testing PUT /contacts/${contactId}`);
  const updateContactRes = await request(
    'PUT',
    `/contacts/${contactId}`,
    {
      name: 'Dr. Jane Smith (Updated)',
      priority: 2
    },
    token
  );
  console.log('Status:', updateContactRes.status, 'Updated:', updateContactRes.body.contact);
  if (updateContactRes.status !== 200) throw new Error('Update contact failed');

  // 8. Log SOS Alert
  console.log('\n8. Testing POST /sos/log');
  const logAlertRes = await request(
    'POST',
    '/sos/log',
    {
      latitude: 12.971598,
      longitude: 77.594562,
      accuracy: 14.2,
      location_source: 'live',
      message: 'I need help. My location: https://maps.google.com/?q=12.971598,77.594562',
      triggered_at: new Date().toISOString(),
      sent_count: 1,
      failed_count: 0,
      recipients: [
        {
          contact_id: contactId,
          phone: '+919876543210',
          status: 'sent',
          error: null
        }
      ]
    },
    token
  );
  console.log('Status:', logAlertRes.status, 'Alert ID:', logAlertRes.body.alert_id);
  if (logAlertRes.status !== 201) throw new Error('Log SOS Alert failed');

  // 9. Get SOS History
  console.log('\n9. Testing GET /sos/history');
  const historyRes = await request('GET', '/sos/history', null, token);
  console.log('Status:', historyRes.status, 'Total Alerts:', historyRes.body.total);
  console.log('First alert recipients:', historyRes.body.alerts[0]?.recipients);
  if (historyRes.status !== 200 || historyRes.body.alerts.length === 0) {
    throw new Error('Get SOS history failed');
  }

  // 10. Delete Contact
  console.log(`\n10. Testing DELETE /contacts/${contactId}`);
  const delContactRes = await request('DELETE', `/contacts/${contactId}`, null, token);
  console.log('Status:', delContactRes.status, 'Message:', delContactRes.body.message);
  if (delContactRes.status !== 200) throw new Error('Delete contact failed');

  console.log('\n=== ALL API TESTS PASSED SUCCESSFULLY! ===\n');
}

runTests().catch(err => {
  console.error('\nTest failed with error:', err);
  process.exit(1);
});

