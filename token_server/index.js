require('dotenv').config();
const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

const APP_ACCESS_KEY = process.env.APP_ACCESS_KEY || '';
const APP_SECRET = process.env.APP_SECRET || '';
const TEMPLATE_ID = process.env.TEMPLATE_ID || '';
const PORT = parseInt(process.env.PORT || '3000', 10);

const ROLE_MAP = {
  trainer: process.env.HMS_ROLE_TRAINER || 'host',
  member: process.env.HMS_ROLE_MEMBER || 'guest',
};

const roomCache = new Map();
const fcmTokens = new Map();
const chatStorePath = path.join(__dirname, 'chat_store.json');

function loadChatMessages() {
  try {
    if (fs.existsSync(chatStorePath)) {
      return JSON.parse(fs.readFileSync(chatStorePath, 'utf8'));
    }
  } catch (_) {}
  return [];
}

function saveChatMessages(messages) {
  try {
    fs.writeFileSync(chatStorePath, JSON.stringify(messages, null, 2));
  } catch (e) {
    console.warn('[TOKEN_SERVER] chat save failed:', e.message);
  }
}

let chatMessages = loadChatMessages(); // array of message objects

async function pushToUser(userId, title, body, data) {
  const deviceToken = fcmTokens.get(userId);
  if (!deviceToken || !firebaseReady) return null;
  try {
    const dataPayload = {};
    if (data && typeof data === 'object') {
      for (const [k, v] of Object.entries(data)) {
        dataPayload[k] = String(v);
      }
    }
    return await getMessaging().send({
      token: deviceToken,
      notification: { title, body: body || '' },
      data: dataPayload,
      android: {
        priority: 'high',
        notification: { channelId: 'wtf_calls' },
      },
    });
  } catch (e) {
    console.warn('[TOKEN_SERVER] push failed:', e.message);
    return null;
  }
}

const serviceAccountPath =
  process.env.FIREBASE_SERVICE_ACCOUNT ||
  path.join(__dirname, 'firebase-adminsdk.json');

let firebaseReady = false;
if (fs.existsSync(serviceAccountPath)) {
  try {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    if (getApps().length === 0) {
      initializeApp({
        credential: cert(serviceAccount),
      });
    }
    firebaseReady = true;
    console.log(`[TOKEN_SERVER] Firebase Admin ready (project: ${serviceAccount.project_id})`);
  } catch (e) {
    console.warn('[TOKEN_SERVER] Firebase Admin init failed:', e.message);
  }
} else {
  console.warn('[TOKEN_SERVER] No firebase-adminsdk.json — remote FCM disabled');
}

function hasRealCreds() {
  if (!APP_ACCESS_KEY || !APP_SECRET) return false;
  if (APP_ACCESS_KEY.includes('your_100ms')) return false;
  if (APP_SECRET.includes('your_100ms')) return false;
  return true;
}

function managementToken() {
  const payload = {
    access_key: APP_ACCESS_KEY,
    type: 'management',
    version: 2,
    iat: Math.floor(Date.now() / 1000),
    nbf: Math.floor(Date.now() / 1000),
  };
  return jwt.sign(payload, APP_SECRET, {
    algorithm: 'HS256',
    expiresIn: '24h',
    jwtid: crypto.randomUUID(),
  });
}

function authToken(roomId, userId, hmsRole) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    access_key: APP_ACCESS_KEY,
    room_id: roomId,
    user_id: userId,
    role: hmsRole,
    type: 'app',
    version: 2,
    iat: now,
    nbf: now,
  };
  return jwt.sign(payload, APP_SECRET, {
    algorithm: 'HS256',
    expiresIn: '24h',
    jwtid: crypto.randomUUID(),
  });
}

function mockToken(userId, role, roomId) {
  console.warn('[TOKEN_SERVER] No valid 100ms credentials — returning mock token');
  return `mock.${Buffer.from(
    JSON.stringify({ userId, role, roomId, iat: Date.now() }),
  ).toString('base64')}.mock`;
}

async function createOrGetRoom(roomName, description) {
  if (roomCache.has(roomName)) {
    return roomCache.get(roomName);
  }

  if (!hasRealCreds()) {
    const mock = { id: `mock_${roomName}`, name: roomName };
    roomCache.set(roomName, mock);
    console.warn('[TOKEN_SERVER] mock room created:', mock.id);
    return mock;
  }

  const body = {
    name: roomName,
    description: description || `WTF call room ${roomName}`,
  };
  if (TEMPLATE_ID && !TEMPLATE_ID.includes('your_')) {
    body.template_id = TEMPLATE_ID;
  }

  const res = await fetch('https://api.100ms.live/v2/rooms', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${managementToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  const data = await res.json();
  if (!res.ok) {
    const err = new Error(data.message || data.error || `Room create failed (${res.status})`);
    err.status = res.status;
    err.details = data;
    throw err;
  }

  const room = { id: data.id, name: data.name || roomName };
  roomCache.set(roomName, room);
  console.log(`[TOKEN_SERVER] room ready id=${room.id} name=${room.name}`);
  return room;
}

function json(res, status, payload) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  res.end(JSON.stringify(payload));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      try {
        const raw = Buffer.concat(chunks).toString('utf8');
        resolve(raw ? JSON.parse(raw) : {});
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    json(res, 204, {});
    return;
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);

  try {
    // Health
    if (req.method === 'GET' && url.pathname === '/health') {
      json(res, 200, {
        ok: true,
        has100msCreds: hasRealCreds(),
        firebaseReady,
        roles: ROLE_MAP,
      });
      return;
    }

    // Create / get room by deterministic name (call request id)
    if (req.method === 'POST' && url.pathname === '/rooms') {
      const body = await readBody(req);
      const callRequestId = body.callRequestId || body.name;
      if (!callRequestId) {
        json(res, 400, { error: 'callRequestId is required' });
        return;
      }
      const roomName = String(callRequestId).startsWith('wtf_')
        ? String(callRequestId)
        : `wtf_${callRequestId}`.replace(/[^a-zA-Z0-9._:-]/g, '_');
      const room = await createOrGetRoom(roomName, body.description);
      json(res, 200, {
        roomId: room.id,
        roomName: room.name,
        roles: ROLE_MAP,
        mock: !hasRealCreds(),
      });
      return;
    }

    // Auth token for client SDK join
    if (req.method === 'GET' && url.pathname === '/token') {
      const userId = url.searchParams.get('userId');
      const role = url.searchParams.get('role'); // trainer | member
      let roomId = url.searchParams.get('roomId');
      const roomName = url.searchParams.get('roomName') || url.searchParams.get('callRequestId');

      if (!userId || !role) {
        json(res, 400, { error: 'userId and role are required' });
        return;
      }
      if (!ROLE_MAP[role]) {
        json(res, 400, { error: `Unknown role: ${role}. Use trainer or member` });
        return;
      }

      if (!roomId) {
        if (!roomName) {
          json(res, 400, { error: 'roomId or roomName/callRequestId is required' });
          return;
        }
        const name = String(roomName).startsWith('wtf_')
          ? String(roomName)
          : `wtf_${roomName}`.replace(/[^a-zA-Z0-9._:-]/g, '_');
        const room = await createOrGetRoom(name);
        roomId = room.id;
      }

      const hmsRole = ROLE_MAP[role];
      const token = hasRealCreds()
        ? authToken(roomId, userId, hmsRole)
        : mockToken(userId, role, roomId);

      console.log(
        `[TOKEN_SERVER] token userId=${userId} appRole=${role} hmsRole=${hmsRole} roomId=${roomId}`,
      );
      json(res, 200, {
        token,
        roomId,
        role: hmsRole,
        mock: !hasRealCreds(),
      });
      return;
    }

    // --- Chat sync (member ↔ trainer) ---
    if (req.method === 'POST' && url.pathname === '/chat/messages') {
      const body = await readBody(req);
      if (!body.id || !body.chatId || !body.senderId || !body.receiverId || !body.text) {
        json(res, 400, { error: 'id, chatId, senderId, receiverId, text are required' });
        return;
      }

      const existing = chatMessages.findIndex((m) => m.id === body.id);
      const message = {
        id: body.id,
        chatId: body.chatId,
        senderId: body.senderId,
        receiverId: body.receiverId,
        text: body.text,
        createdAt: body.createdAt || new Date().toISOString(),
        status: body.status || 'sent',
      };

      if (existing >= 0) {
        chatMessages[existing] = { ...chatMessages[existing], ...message };
      } else {
        chatMessages.push(message);
        await pushToUser(message.receiverId, 'New message', message.text, {
          chatId: message.chatId,
          type: 'chat',
        });
      }
      saveChatMessages(chatMessages);
      console.log(`[TOKEN_SERVER] chat ${message.senderId} → ${message.receiverId}: ${message.text}`);
      json(res, 200, { ok: true, message });
      return;
    }

    if (req.method === 'GET' && url.pathname === '/chat/messages') {
      const chatId = url.searchParams.get('chatId');
      const userId = url.searchParams.get('userId');
      let list = chatMessages;
      if (chatId) {
        list = list.filter((m) => m.chatId === chatId);
      } else if (userId) {
        list = list.filter((m) => m.senderId === userId || m.receiverId === userId);
      }
      list = [...list].sort(
        (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
      );
      json(res, 200, { messages: list });
      return;
    }

    if (req.method === 'POST' && url.pathname === '/chat/read') {
      const body = await readBody(req);
      if (!body.chatId || !body.userId) {
        json(res, 400, { error: 'chatId and userId are required' });
        return;
      }
      let changed = 0;
      chatMessages = chatMessages.map((m) => {
        if (m.chatId === body.chatId && m.receiverId === body.userId && m.status !== 'read') {
          changed += 1;
          return { ...m, status: 'read' };
        }
        return m;
      });
      if (changed > 0) saveChatMessages(chatMessages);
      json(res, 200, { ok: true, updated: changed });
      return;
    }

    // Register FCM device token (optional push)
    if (req.method === 'POST' && url.pathname === '/fcm-token') {
      const body = await readBody(req);
      if (!body.userId || !body.token) {
        json(res, 400, { error: 'userId and token are required' });
        return;
      }
      fcmTokens.set(body.userId, body.token);
      console.log(`[TOKEN_SERVER] FCM token saved for ${body.userId}`);
      json(res, 200, { ok: true });
      return;
    }

    // Send push via Firebase Admin (FCM HTTP v1)
    if (req.method === 'POST' && url.pathname === '/notify') {
      const body = await readBody(req);
      const { userId, title, body: message, data } = body;
      if (!userId || !title) {
        json(res, 400, { error: 'userId and title are required' });
        return;
      }

      const deviceToken = fcmTokens.get(userId);
      if (!deviceToken) {
        json(res, 404, { error: 'No FCM token registered for user', queued: false });
        return;
      }

      if (!firebaseReady) {
        console.warn('[TOKEN_SERVER] Firebase Admin not ready — remote push skipped');
        json(res, 200, {
          ok: false,
          reason: 'Firebase Admin not configured',
          localFallback: true,
          deviceTokenRegistered: true,
        });
        return;
      }

      const dataPayload = {};
      if (data && typeof data === 'object') {
        for (const [k, v] of Object.entries(data)) {
          dataPayload[k] = String(v);
        }
      }

      const messageId = await getMessaging().send({
        token: deviceToken,
        notification: {
          title,
          body: message || '',
        },
        data: dataPayload,
        android: {
          priority: 'high',
          notification: {
            channelId: 'wtf_calls',
          },
        },
      });

      console.log(`[TOKEN_SERVER] FCM push to ${userId}: ${messageId}`);
      json(res, 200, { ok: true, messageId });
      return;
    }

    json(res, 404, { error: 'Not found' });
  } catch (err) {
    console.error('[TOKEN_SERVER] error:', err.message, err.details || '');
    json(res, err.status || 500, {
      error: err.message || 'Internal error',
      details: err.details || undefined,
    });
  }
});

server.listen(PORT, () => {
  console.log(`[TOKEN_SERVER] running on http://localhost:${PORT}`);
  console.log('[TOKEN_SERVER] GET  /health');
  console.log('[TOKEN_SERVER] POST /rooms { callRequestId }');
  console.log('[TOKEN_SERVER] GET  /token?userId=&role=&roomName=');
  console.log('[TOKEN_SERVER] POST /chat/messages');
  console.log('[TOKEN_SERVER] GET  /chat/messages?chatId=');
  console.log('[TOKEN_SERVER] POST /chat/read');
  console.log('[TOKEN_SERVER] POST /fcm-token { userId, token }');
  console.log('[TOKEN_SERVER] POST /notify { userId, title, body }');
  console.log(`[TOKEN_SERVER] HMS roles: trainer→${ROLE_MAP.trainer}, member→${ROLE_MAP.member}`);
  console.log(`[TOKEN_SERVER] Firebase Admin: ${firebaseReady ? 'ON' : 'OFF'}`);
  if (!hasRealCreds()) {
    console.warn(
      '[TOKEN_SERVER] WARNING: Set real APP_ACCESS_KEY + APP_SECRET in .env for live 100ms calls',
    );
  }
});
