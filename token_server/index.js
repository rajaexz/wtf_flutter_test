require('dotenv').config();
const http = require('http');
const jwt = require('jsonwebtoken');

const APP_ACCESS_KEY = process.env.APP_ACCESS_KEY;
const APP_SECRET = process.env.APP_SECRET;
const PORT = parseInt(process.env.PORT || '3000', 10);

const ROLE_PERMISSIONS = {
  trainer: {
    publishAudio: true,
    publishVideo: true,
    subscribeToRoles: ['trainer', 'member'],
    canEndRoom: true,
  },
  member: {
    publishAudio: true,
    publishVideo: true,
    subscribeToRoles: ['trainer', 'member'],
    canEndRoom: false,
  },
};

function generateToken(userId, role) {
  if (!APP_ACCESS_KEY || !APP_SECRET) {
    return generateMockToken(userId, role);
  }

  const payload = {
    access_key: APP_ACCESS_KEY,
    room_id: '*',
    user_id: userId,
    role: role,
    type: 'app',
    version: 2,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 86400,
  };

  return jwt.sign(payload, APP_SECRET, { algorithm: 'HS256' });
}

function generateMockToken(userId, role) {
  console.warn('[TOKEN_SERVER] No 100ms credentials — returning mock token');
  return `mock.${Buffer.from(JSON.stringify({ userId, role, iat: Date.now() })).toString('base64')}.mock`;
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);

  if (url.pathname !== '/token') {
    res.writeHead(404);
    res.end(JSON.stringify({ error: 'Not found' }));
    return;
  }

  const userId = url.searchParams.get('userId');
  const role = url.searchParams.get('role');

  if (!userId || !role) {
    res.writeHead(400);
    res.end(JSON.stringify({ error: 'userId and role are required' }));
    return;
  }

  if (!ROLE_PERMISSIONS[role]) {
    res.writeHead(400);
    res.end(JSON.stringify({ error: `Unknown role: ${role}. Use 'trainer' or 'member'` }));
    return;
  }

  try {
    const token = generateToken(userId, role);
    console.log(`[TOKEN_SERVER] token issued for userId=${userId} role=${role}`);
    res.writeHead(200);
    res.end(JSON.stringify({ token }));
  } catch (err) {
    console.error('[TOKEN_SERVER] error:', err.message);
    res.writeHead(500);
    res.end(JSON.stringify({ error: 'Token generation failed' }));
  }
});

server.listen(PORT, () => {
  console.log(`[TOKEN_SERVER] running on http://localhost:${PORT}`);
  console.log(`[TOKEN_SERVER] GET /token?userId=<id>&role=<trainer|member>`);
  if (!APP_ACCESS_KEY || !APP_SECRET) {
    console.warn('[TOKEN_SERVER] WARNING: APP_ACCESS_KEY / APP_SECRET not set — mock tokens only');
  }
});
