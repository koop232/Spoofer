/**
 * Duel Spoofer Relay
 * ------------------
 * Zero-dependency HTTP relay that bridges the ADMIN client and the TESTER client.
 *
 * Why this exists:
 *   Roblox exploit/executor scripts run on the CLIENT. Any Instance an executor
 *   creates (folders, attributes, RemoteEvents) exists ONLY in that client's own
 *   simulation -- it is never replicated to the server or to other players.
 *   So two different players can NOT see each other's local state.
 *   This relay is the out-of-band channel that carries the spoof between them.
 *
 * Endpoints:
 *   GET  /health                              -> liveness probe
 *   POST /push    {room,key,slot,brainrot,..} -> admin publishes a spoof
 *   POST /revert  {room,key}                  -> admin clears both slots
 *   GET  /state?room=&since=&wait=            -> tester reads state (supports long-poll)
 *   GET  /api/rooms                           -> dashboard: list active rooms
 *   GET  /                                    -> live web dashboard
 *
 * Run:  node relay/server.js          (PORT=3000 RELAY_KEY=secret optional)
 */

'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';
const RELAY_KEY = process.env.RELAY_KEY || ''; // empty string = auth disabled
const MAX_EVENTS = 60;
const MAX_WAIT_MS = 25000;
const ROOM_TTL_MS = 1000 * 60 * 60 * 6; // prune idle rooms after 6h
const VALID_SLOTS = new Set(['Main', 'Other']);
const PUBLIC_DIR = path.join(__dirname, 'public');
const STARTED_AT = Date.now();

/** @type {Map<string, Room>} */
const rooms = new Map();

function now() {
  return Date.now();
}

function makeRoom(name) {
  return {
    name,
    seq: 0,
    slots: { Main: null, Other: null },
    events: [],
    waiters: [],
    createdAt: now(),
    lastActivity: now(),
    pushes: 0,
    lastAdmin: null,
    lastTesterSeenAt: null,
  };
}

function getRoom(rawName) {
  const name = String(rawName || 'default').trim().slice(0, 64) || 'default';
  if (!rooms.has(name)) rooms.set(name, makeRoom(name));
  return rooms.get(name);
}

function snapshot(room) {
  return {
    ok: true,
    room: room.name,
    seq: room.seq,
    slots: room.slots,
    events: room.events.slice(0, 25),
    serverTime: now(),
  };
}

/** Release every long-poll waiter parked on this room. */
function wake(room) {
  const waiters = room.waiters;
  room.waiters = [];
  for (const w of waiters) {
    clearTimeout(w.timer);
    try {
      w.resolve();
    } catch (_) {
      /* client vanished */
    }
  }
}

function logEvent(room, event) {
  room.events.unshift(event);
  if (room.events.length > MAX_EVENTS) room.events.length = MAX_EVENTS;
}

// ── HTTP plumbing ─────────────────────────────────────────────────────────────

function send(res, status, payload, extraHeaders) {
  const body = Buffer.from(JSON.stringify(payload), 'utf8');
  res.writeHead(status, Object.assign(
    {
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Length': body.length,
      'Cache-Control': 'no-store',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    },
    extraHeaders || {}
  ));
  res.end(body);
}

function readBody(req, limitBytes = 64 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > limitBytes) {
        reject(new Error('payload too large'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

/**
 * Accepts JSON, and also form-encoded / bare strings, because some Roblox
 * executors mangle Content-Type or send the body as a plain string.
 */
function parseBody(raw) {
  if (!raw) return {};
  const text = raw.trim();
  if (!text) return {};
  try {
    const parsed = JSON.parse(text);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (_) {
    const out = {};
    for (const pair of text.split('&')) {
      const idx = pair.indexOf('=');
      if (idx === -1) continue;
      try {
        out[decodeURIComponent(pair.slice(0, idx))] = decodeURIComponent(pair.slice(idx + 1));
      } catch (_) {
        /* ignore malformed pair */
      }
    }
    return out;
  }
}

function authorized(payload, query) {
  if (!RELAY_KEY) return true;
  const supplied = (payload && payload.key) || (query && query.get('key')) || '';
  return String(supplied) === RELAY_KEY;
}

function clampString(value, max, fallback = '') {
  if (value === undefined || value === null) return fallback;
  const s = String(value).trim();
  if (!s) return fallback;
  return s.slice(0, max);
}

// ── Route handlers ────────────────────────────────────────────────────────────

async function handlePush(req, res, query) {
  const payload = parseBody(await readBody(req));
  if (!authorized(payload, query)) return send(res, 401, { ok: false, error: 'bad key' });

  const slot = clampString(payload.slot, 16, 'Main');
  if (!VALID_SLOTS.has(slot)) {
    return send(res, 400, { ok: false, error: 'slot must be "Main" or "Other"' });
  }

  const brainrot = clampString(payload.brainrot, 120);
  if (!brainrot) return send(res, 400, { ok: false, error: 'brainrot is required' });

  const room = getRoom(payload.room || query.get('room'));
  room.seq += 1;
  room.pushes += 1;
  room.lastActivity = now();

  const genNumber = Number(payload.gen);
  const entry = {
    slot,
    brainrot,
    gen: Number.isFinite(genNumber) ? genNumber : 0,
    genText: clampString(payload.genText, 32, ''),
    admin: clampString(payload.admin, 64, 'admin'),
    at: now(),
    seq: room.seq,
  };

  room.slots[slot] = entry;
  room.lastAdmin = entry.admin;
  logEvent(room, Object.assign({ type: 'push' }, entry));
  wake(room);

  send(res, 200, { ok: true, seq: room.seq, slot, applied: entry });
}

async function handleRevert(req, res, query) {
  const payload = parseBody(await readBody(req));
  if (!authorized(payload, query)) return send(res, 401, { ok: false, error: 'bad key' });

  const room = getRoom(payload.room || query.get('room'));
  room.seq += 1;
  room.lastActivity = now();
  room.slots = { Main: null, Other: null };
  logEvent(room, {
    type: 'revert',
    admin: clampString(payload.admin, 64, 'admin'),
    at: now(),
    seq: room.seq,
  });
  wake(room);

  send(res, 200, { ok: true, seq: room.seq });
}

/**
 * Long-polling read. If the caller is already up to date (`since` >= seq) we
 * park the response until something changes or `wait` elapses. That gives the
 * tester near-instant updates without hammering the relay.
 */
function handleState(req, res, query) {
  const room = getRoom(query.get('room'));
  room.lastActivity = now();
  room.lastTesterSeenAt = now();

  const since = Number(query.get('since') || 0) || 0;
  const waitMs = Math.min(Math.max(Number(query.get('wait') || 0) || 0, 0) * 1000, MAX_WAIT_MS);

  if (room.seq > since || waitMs === 0) {
    return send(res, 200, Object.assign(snapshot(room), { changed: room.seq > since }));
  }

  const waiter = { resolve: null, timer: null };
  waiter.resolve = () => {
    if (waiter.done) return;
    waiter.done = true;
    clearTimeout(waiter.timer);
    send(res, 200, Object.assign(snapshot(room), { changed: room.seq > since }));
  };
  waiter.timer = setTimeout(waiter.resolve, waitMs);

  res.on('close', () => {
    waiter.done = true;
    clearTimeout(waiter.timer);
    const i = room.waiters.indexOf(waiter);
    if (i !== -1) room.waiters.splice(i, 1);
  });

  room.waiters.push(waiter);
}

function handleRooms(res) {
  const list = [];
  for (const room of rooms.values()) {
    list.push({
      name: room.name,
      seq: room.seq,
      pushes: room.pushes,
      lastAdmin: room.lastAdmin,
      lastActivity: room.lastActivity,
      listeners: room.waiters.length,
      slots: room.slots,
    });
  }
  list.sort((a, b) => b.lastActivity - a.lastActivity);
  send(res, 200, { ok: true, rooms: list, serverTime: now() });
}

function serveStatic(res, urlPath) {
  const rel = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
  const full = path.join(PUBLIC_DIR, rel);
  if (!full.startsWith(PUBLIC_DIR)) {
    return send(res, 403, { ok: false, error: 'forbidden' });
  }
  fs.readFile(full, (err, data) => {
    if (err) return send(res, 404, { ok: false, error: 'not found' });
    const ext = path.extname(full).toLowerCase();
    const types = {
      '.html': 'text/html; charset=utf-8',
      '.css': 'text/css; charset=utf-8',
      '.js': 'text/javascript; charset=utf-8',
      '.json': 'application/json; charset=utf-8',
      '.svg': 'image/svg+xml',
    };
    res.writeHead(200, {
      'Content-Type': types[ext] || 'application/octet-stream',
      'Content-Length': data.length,
      'Cache-Control': 'no-store',
    });
    res.end(data);
  });
}

// ── Server ────────────────────────────────────────────────────────────────────

const server = http.createServer((req, res) => {
  const parsed = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const route = parsed.pathname.replace(/\/+$/, '') || '/';
  const query = parsed.searchParams;

  if (req.method === 'OPTIONS') return send(res, 204, {});

  const fail = (err) => {
    console.error('[relay] error:', err && err.message);
    if (!res.headersSent) send(res, 500, { ok: false, error: 'internal error' });
  };

  try {
    if (route === '/health') {
      return send(res, 200, {
        ok: true,
        uptimeSec: Math.round((now() - STARTED_AT) / 1000),
        rooms: rooms.size,
        authRequired: Boolean(RELAY_KEY),
      });
    }
    if (route === '/push' && req.method === 'POST') return handlePush(req, res, query).catch(fail);
    if (route === '/revert' && req.method === 'POST') return handleRevert(req, res, query).catch(fail);
    if (route === '/state' && req.method === 'GET') return handleState(req, res, query);
    if (route === '/api/rooms' && req.method === 'GET') return handleRooms(res);

    // Some executors expose no POST-capable request(); they fall back to
    // game:HttpGet, which is GET-only. Mirror both mutations over GET.
    if (route === '/push' && req.method === 'GET') {
      return handlePushSync(res, Object.fromEntries(query.entries()), query);
    }
    if (route === '/revert' && req.method === 'GET') {
      return handleRevertSync(res, Object.fromEntries(query.entries()), query);
    }

    if (req.method === 'GET') return serveStatic(res, parsed.pathname);
    return send(res, 404, { ok: false, error: 'not found' });
  } catch (err) {
    fail(err);
  }
});

/** GET-based push fallback for restricted executors. */
function handlePushSync(res, payload, query) {
  if (!authorized(payload, query)) return send(res, 401, { ok: false, error: 'bad key' });
  const slot = clampString(payload.slot, 16, 'Main');
  if (!VALID_SLOTS.has(slot)) return send(res, 400, { ok: false, error: 'bad slot' });
  const brainrot = clampString(payload.brainrot, 120);
  if (!brainrot) return send(res, 400, { ok: false, error: 'brainrot is required' });

  const room = getRoom(payload.room);
  room.seq += 1;
  room.pushes += 1;
  room.lastActivity = now();
  const genNumber = Number(payload.gen);
  const entry = {
    slot,
    brainrot,
    gen: Number.isFinite(genNumber) ? genNumber : 0,
    genText: clampString(payload.genText, 32, ''),
    admin: clampString(payload.admin, 64, 'admin'),
    at: now(),
    seq: room.seq,
  };
  room.slots[slot] = entry;
  room.lastAdmin = entry.admin;
  logEvent(room, Object.assign({ type: 'push' }, entry));
  wake(room);
  send(res, 200, { ok: true, seq: room.seq, slot, applied: entry });
}

/** GET-based revert fallback for restricted executors. */
function handleRevertSync(res, payload, query) {
  if (!authorized(payload, query)) return send(res, 401, { ok: false, error: 'bad key' });
  const room = getRoom(payload.room);
  room.seq += 1;
  room.lastActivity = now();
  room.slots = { Main: null, Other: null };
  logEvent(room, {
    type: 'revert',
    admin: clampString(payload.admin, 64, 'admin'),
    at: now(),
    seq: room.seq,
  });
  wake(room);
  send(res, 200, { ok: true, seq: room.seq });
}

setInterval(() => {
  const cutoff = now() - ROOM_TTL_MS;
  for (const [name, room] of rooms) {
    if (room.lastActivity < cutoff && room.waiters.length === 0) rooms.delete(name);
  }
}, 60000).unref();

server.listen(PORT, HOST, () => {
  console.log(`[relay] Duel Spoofer relay listening on http://${HOST}:${PORT}`);
  console.log(`[relay] auth: ${RELAY_KEY ? 'ENABLED (RELAY_KEY set)' : 'disabled (no RELAY_KEY)'}`);
  console.log('[relay] dashboard: /   |   api: /push /revert /state /health');
});
