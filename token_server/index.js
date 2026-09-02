require('dotenv').config();
const http = require('http');
const fs = require('fs');
const path = require('path');
const { Server } = require('socket.io');
const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

const PORT = parseInt(process.env.PORT || '3000', 10);

// ─── JSON file paths ───────────────────────────────────────────────────────────
const chatStorePath    = path.join(__dirname, 'chat_store.json');
const callStorePath    = path.join(__dirname, 'call_requests_store.json');
const fcmStorePath     = path.join(__dirname, 'fcm_tokens.json');

// ─── Helpers ───────────────────────────────────────────────────────────────────
function loadJsonArray(filePath) {
  try {
    if (fs.existsSync(filePath)) return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (_) {}
  return [];
}

function loadJsonObject(filePath) {
  try {
    if (fs.existsSync(filePath)) return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (_) {}
  return {};
}

function saveJson(filePath, data) {
  try {
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
  } catch (e) {
    console.warn('[SERVER] save failed', filePath, e.message);
  }
}

// ─── In-memory stores ──────────────────────────────────────────────────────────
let chatMessages  = loadJsonArray(chatStorePath);
let callRequests  = loadJsonArray(callStorePath);
const fcmTokens   = new Map(Object.entries(loadJsonObject(fcmStorePath)));

function saveFcmTokens()    { saveJson(fcmStorePath, Object.fromEntries(fcmTokens)); }
function saveChatMessages() { saveJson(chatStorePath, chatMessages); }
function saveCallRequests() { saveJson(callStorePath, callRequests); }

// ─── Firebase Admin (optional FCM) ────────────────────────────────────────────
let firebaseReady = false;
const serviceAccountPath =
  process.env.FIREBASE_SERVICE_ACCOUNT ||
  path.join(__dirname, 'firebase-adminsdk.json');

if (fs.existsSync(serviceAccountPath)) {
  try {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    if (getApps().length === 0) {
      initializeApp({ credential: cert(serviceAccount) });
    }
    firebaseReady = true;
    console.log(`[SERVER] Firebase Admin ready (project: ${serviceAccount.project_id})`);
  } catch (e) {
    console.warn('[SERVER] Firebase Admin init failed:', e.message);
  }
} else {
  console.warn('[SERVER] No firebase-adminsdk.json — remote FCM push disabled');
}

async function pushToUser(userId, title, body, data) {
  const deviceToken = fcmTokens.get(userId);
  if (!deviceToken || !firebaseReady) return null;
  try {
    const dataPayload = {};
    if (data && typeof data === 'object') {
      for (const [k, v] of Object.entries(data)) dataPayload[k] = String(v);
    }
    return await getMessaging().send({
      token: deviceToken,
      notification: { title, body: body || '' },
      data: dataPayload,
      android: { priority: 'high', notification: { channelId: 'wtf_calls' } },
    });
  } catch (e) {
    console.warn('[SERVER] push failed:', e.message);
    return null;
  }
}

// ─── Call reminder loop ────────────────────────────────────────────────────────
function startCallReminderLoop() {
  setInterval(async () => {
    const now = Date.now();
    let changed = false;
    for (const r of callRequests) {
      if (r.status !== 'approved') continue;
      const t = new Date(r.scheduledFor).getTime();
      if (Number.isNaN(t)) continue;
      const mins = (t - now) / 60000;

      // T-10 reminder: only between 10 min and 1 min before the call
      // (min > 1 guard prevents firing when call is already starting/past)
      if (!r.reminderNotified && mins <= 10 && mins > 1) {
        const msg = 'Ready to join? Check mic and camera.';
        await pushToUser(r.memberId, 'Call starting soon', msg, { type: 'call_reminder', callRequestId: r.id });
        await pushToUser(r.trainerId, 'Call starting soon', msg, { type: 'call_reminder', callRequestId: r.id });
        r.reminderNotified = true;
        changed = true;
        console.log(`[SERVER] T-10 push for call ${r.id}`);
      }

      // Call-time push: within 90 seconds of the scheduled time (±)
      if (!r.callNotified && Math.abs(t - now) <= 90000) {
        const msg = 'Join Call now — your session is starting.';
        await pushToUser(r.memberId, 'Join Call', msg, { type: 'call_now', callRequestId: r.id });
        await pushToUser(r.trainerId, 'Join Call', msg, { type: 'call_now', callRequestId: r.id });
        r.callNotified = true;
        changed = true;
        console.log(`[SERVER] call-time push for ${r.id}`);
      }
    }
    if (changed) saveCallRequests();
  }, 20000);
}

// ─── Socket.IO (real-time chat) ────────────────────────────────────────────────
/** @type {import('socket.io').Server | null} */
let io = null;
/** userId → Set<socketId> */
const onlineUsers = new Map();

function setupSocketIo(httpServer) {
  io = new Server(httpServer, { cors: { origin: '*' } });

  io.on('connection', (socket) => {
    const userId = socket.handshake.query.userId;
    if (userId) {
      if (!onlineUsers.has(userId)) onlineUsers.set(userId, new Set());
      onlineUsers.get(userId).add(socket.id);
      io.emit('presence:update', { userId, online: true });
      console.log(`[SOCKET] connected userId=${userId} socket=${socket.id}`);
    }

    socket.on('chat:join', (data) => {
      const chatId = (data && typeof data === 'object') ? data.chatId : data;
      if (chatId) socket.join(`chat:${chatId}`);
    });

    socket.on('chat:leave', (data) => {
      const chatId = (data && typeof data === 'object') ? data.chatId : data;
      if (chatId) socket.leave(`chat:${chatId}`);
    });

    socket.on('message:send', async (data, ack) => {
      try {
        const { message } = await upsertChatMessage(data);
        broadcastMessage(message);
        if (typeof ack === 'function') ack({ ok: true, message });
      } catch (e) {
        if (typeof ack === 'function') ack({ ok: false, error: e.message });
        else socket.emit('error', { message: e.message });
      }
    });

    socket.on('message:read', (data, ack) => {
      if (!data.chatId || !data.userId) {
        if (typeof ack === 'function') ack({ ok: false });
        return;
      }
      const updated = markChatRead(data.chatId, data.userId);
      broadcastRead({ chatId: data.chatId, userId: data.userId, updated });
      if (typeof ack === 'function') ack({ ok: true, updated });
    });

    socket.on('typing:start', (data) => { if (data.chatId) socket.to(`chat:${data.chatId}`).emit('typing:start', data); });
    socket.on('typing:stop',  (data) => { if (data.chatId) socket.to(`chat:${data.chatId}`).emit('typing:stop',  data); });

    socket.on('presence:query', (data, ack) => {
      const userIds = (data && Array.isArray(data.userIds)) ? data.userIds : [];
      const result = {};
      for (const uid of userIds) result[uid] = onlineUsers.has(uid);
      if (typeof ack === 'function') ack({ online: result });
    });

    socket.on('disconnect', () => {
      if (userId) {
        const set = onlineUsers.get(userId);
        if (set) {
          set.delete(socket.id);
          if (set.size === 0) {
            onlineUsers.delete(userId);
            io.emit('presence:update', { userId, online: false });
          }
        }
        console.log(`[SOCKET] disconnected userId=${userId} socket=${socket.id}`);
      }
    });
  });
}

// ─── Chat helpers ──────────────────────────────────────────────────────────────
async function upsertChatMessage(body, { push = true } = {}) {
  if (!body.id || !body.chatId || !body.senderId || !body.receiverId || !body.text) {
    const err = new Error('id, chatId, senderId, receiverId, text are required');
    err.status = 400;
    throw err;
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
    if (push) {
      await pushToUser(body.receiverId, 'New message', body.text, {
        type: 'chat_message',
        chatId: body.chatId,
        senderId: body.senderId,
      });
    }
  }
  saveChatMessages();
  return { message };
}

function markChatRead(chatId, userId) {
  let updated = 0;
  chatMessages = chatMessages.map((m) => {
    if (m.chatId === chatId && m.receiverId === userId && m.status !== 'read') {
      updated++;
      return { ...m, status: 'read' };
    }
    return m;
  });
  saveChatMessages();
  return updated;
}

function broadcastMessage(message) {
  if (io) io.to(`chat:${message.chatId}`).emit('message:new', message);
}

function broadcastRead(payload) {
  if (io) io.to(`chat:${payload.chatId}`).emit('message:read', payload);
}

// ─── HTTP helpers ──────────────────────────────────────────────────────────────
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
      } catch (e) { reject(e); }
    });
    req.on('error', reject);
  });
}

// ─── HTTP server ───────────────────────────────────────────────────────────────
const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') { json(res, 204, {}); return; }

  const url = new URL(req.url, `http://localhost:${PORT}`);

  try {
    // ── Health ─────────────────────────────────────────────────────────────────
    if (req.method === 'GET' && url.pathname === '/health') {
      json(res, 200, {
        ok: true,
        firebaseReady,
        onlineUsers: onlineUsers.size,
        chatMessages: chatMessages.length,
        callRequests: callRequests.length,
      });
      return;
    }

    // ── Call Requests: create / update ─────────────────────────────────────────
    if (req.method === 'POST' && url.pathname === '/call-requests') {
      const body = await readBody(req);
      if (!body.id || !body.memberId || !body.trainerId || !body.scheduledFor) {
        json(res, 400, { error: 'id, memberId, trainerId, scheduledFor are required' });
        return;
      }
      const idx = callRequests.findIndex((r) => r.id === body.id);
      const request = {
        id: body.id,
        memberId: body.memberId,
        trainerId: body.trainerId,
        requestedAt: body.requestedAt || new Date().toISOString(),
        scheduledFor: body.scheduledFor,
        note: body.note || '',
        status: body.status || 'pending',
        declineReason: body.declineReason || null,
        // Always false for brand new requests
        reminderNotified: false,
        callNotified: false,
      };
      if (idx >= 0) {
        // Preserve reminder flags on update — never reset them once set
        callRequests[idx] = {
          ...callRequests[idx],
          ...request,
          reminderNotified: callRequests[idx].reminderNotified ?? false,
          callNotified: callRequests[idx].callNotified ?? false,
        };
      } else {
        callRequests.push(request);
        await pushToUser(request.trainerId, 'New call request', request.note || 'Member requested a call', {
          type: 'call_request',
          callRequestId: request.id,
        });
      }
      saveCallRequests();
      console.log(`[SERVER] call-request saved ${request.id} status=${request.status}`);
      json(res, 200, { ok: true, request });
      return;
    }

    // ── Call Requests: list ────────────────────────────────────────────────────
    if (req.method === 'GET' && url.pathname === '/call-requests') {
      const userId = url.searchParams.get('userId');
      let list = callRequests;
      if (userId) list = list.filter((r) => r.memberId === userId || r.trainerId === userId);
      list = [...list].sort((a, b) => new Date(b.requestedAt) - new Date(a.requestedAt));
      json(res, 200, { requests: list });
      return;
    }

    // ── Call Requests: approve / decline ──────────────────────────────────────
    if (req.method === 'POST' && url.pathname === '/call-requests/status') {
      const body = await readBody(req);
      if (!body.id || !body.status) {
        json(res, 400, { error: 'id and status are required' });
        return;
      }
      const idx = callRequests.findIndex((r) => r.id === body.id);
      if (idx < 0) { json(res, 404, { error: 'Call request not found' }); return; }

      callRequests[idx] = {
        ...callRequests[idx],
        status: body.status,
        declineReason: body.declineReason || callRequests[idx].declineReason || null,
      };
      saveCallRequests();

      const r = callRequests[idx];
      if (body.status === 'approved') {
        await pushToUser(r.memberId, 'Call approved', `Your call for ${r.scheduledFor} is approved!`, {
          type: 'call_approved', callRequestId: r.id,
        });
      } else if (body.status === 'declined') {
        await pushToUser(r.memberId, 'Call declined', `Reason: ${r.declineReason || 'N/A'}`, {
          type: 'call_declined', callRequestId: r.id,
        });
      }
      console.log(`[SERVER] call-request ${r.id} → ${r.status}`);
      json(res, 200, { ok: true, request: r });
      return;
    }

    // ── Chat: send message (REST fallback) ─────────────────────────────────────
    if (req.method === 'POST' && url.pathname === '/chat/messages') {
      const body = await readBody(req);
      try {
        const { message } = await upsertChatMessage(body);
        broadcastMessage(message);
        console.log(`[SERVER] chat ${message.senderId} → ${message.receiverId}: ${message.text}`);
        json(res, 200, { ok: true, message });
      } catch (e) {
        json(res, e.status || 400, { error: e.message });
      }
      return;
    }

    // ── Chat: fetch history ────────────────────────────────────────────────────
    if (req.method === 'GET' && url.pathname === '/chat/messages') {
      const chatId = url.searchParams.get('chatId');
      const userId = url.searchParams.get('userId');
      let list = chatMessages;
      if (chatId) list = list.filter((m) => m.chatId === chatId);
      else if (userId) list = list.filter((m) => m.senderId === userId || m.receiverId === userId);
      list = [...list].sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
      json(res, 200, { messages: list });
      return;
    }

    // ── Chat: mark read ────────────────────────────────────────────────────────
    if (req.method === 'POST' && url.pathname === '/chat/read') {
      const body = await readBody(req);
      if (!body.chatId || !body.userId) {
        json(res, 400, { error: 'chatId and userId are required' });
        return;
      }
      const updated = markChatRead(body.chatId, body.userId);
      broadcastRead({ chatId: body.chatId, userId: body.userId, updated });
      json(res, 200, { ok: true, updated });
      return;
    }

    // ── FCM: register device token ─────────────────────────────────────────────
    if (req.method === 'POST' && url.pathname === '/fcm-token') {
      const body = await readBody(req);
      if (!body.userId || !body.token) {
        json(res, 400, { error: 'userId and token are required' });
        return;
      }
      fcmTokens.set(body.userId, body.token);
      saveFcmTokens();
      console.log(`[SERVER] FCM token saved for ${body.userId}`);
      json(res, 200, { ok: true });
      return;
    }

    // ── FCM: send push ─────────────────────────────────────────────────────────
    if (req.method === 'POST' && url.pathname === '/notify') {
      const body = await readBody(req);
      const { userId, title, body: message, data } = body;
      if (!userId || !title) {
        json(res, 400, { error: 'userId and title are required' });
        return;
      }
      const deviceToken = fcmTokens.get(userId);
      if (!deviceToken) {
        json(res, 404, { error: 'No FCM token registered for user' });
        return;
      }
      if (!firebaseReady) {
        json(res, 200, { ok: false, reason: 'Firebase Admin not configured' });
        return;
      }
      const dataPayload = {};
      if (data && typeof data === 'object') {
        for (const [k, v] of Object.entries(data)) dataPayload[k] = String(v);
      }
      const messageId = await getMessaging().send({
        token: deviceToken,
        notification: { title, body: message || '' },
        data: dataPayload,
        android: { priority: 'high', notification: { channelId: 'wtf_calls' } },
      });
      console.log(`[SERVER] FCM push to ${userId}: ${messageId}`);
      json(res, 200, { ok: true, messageId });
      return;
    }

    json(res, 404, { error: 'Not found' });
  } catch (err) {
    console.error('[SERVER] error:', err.message);
    json(res, err.status || 500, { error: err.message || 'Internal error' });
  }
});

setupSocketIo(server);
startCallReminderLoop();

server.listen(PORT, '0.0.0.0', () => {
  console.log(`\n[SERVER] ✅ Running on http://0.0.0.0:${PORT}`);
  console.log(`[SERVER] 📱 LAN access: http://192.168.0.199:${PORT}`);
  console.log(`[SERVER] 🔥 Firebase: ${firebaseReady ? 'ON' : 'OFF (FCM push disabled)'}`);
  console.log('[SERVER] Routes:');
  console.log('  GET  /health');
  console.log('  POST /call-requests          — create / update');
  console.log('  GET  /call-requests?userId=  — list');
  console.log('  POST /call-requests/status   — approve / decline');
  console.log('  POST /chat/messages          — send (REST fallback)');
  console.log('  GET  /chat/messages?chatId=  — history');
  console.log('  POST /chat/read              — mark read');
  console.log('  POST /fcm-token              — register device token');
  console.log('  POST /notify                 — send push');
  console.log('[SERVER] Socket.IO: message:send / message:read / typing:on|off / presence\n');
});
