// Controlled HA WebSocket wire fixture. Loopback only; no real pairing/provider.
const http = require('node:http');
const crypto = require('node:crypto');
const fs = require('node:fs');
const report = process.argv[2];
if (!report) throw Error('Report path required');
const sockets = new Set();
const state = { connections: 0, auth: 0, capabilities: 0, commands: [], httpCommands: [], premature: 0 };
Object.defineProperty(state, 'openSockets', { enumerable: true, get: () => sockets.size });
let releaseAuth = false, immediate = false, queued = [];
function frame(value, opcode = 1) {
  const body = Buffer.isBuffer(value) ? value : Buffer.from(JSON.stringify(value));
  let h;
  if (body.length < 126) h = Buffer.from([0x80 | opcode, body.length]);
  else if (body.length <= 65535) { h = Buffer.alloc(4); h[0] = 0x80 | opcode; h[1] = 126; h.writeUInt16BE(body.length, 2); }
  else { h = Buffer.alloc(10); h[0] = 0x80 | opcode; h[1] = 127; h.writeBigUInt64BE(BigInt(body.length), 2); }
  return Buffer.concat([h, body]);
}
function send(socket, value) { if (!socket.destroyed) socket.write(frame(value)); }
function result(socket, id, command) { send(socket, { id, type: 'result', success: true, result: { success: true, message: command } }); }
function json(res, value) { res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(value)); }
const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://localhost');
  if (u.pathname === '/_test/state') return json(res, state);
  if (u.pathname === '/_test/auth') {
    releaseAuth = true;
    for (const s of sockets) if (s.authPending) { s.authPending = false; s.authed = true; send(s, { type: 'auth_ok' }); }
    return json(res, state);
  }
  if (u.pathname === '/_test/results') {
    const values = queued; queued = [];
    for (const x of values.reverse()) result(x.socket, x.id, x.command);
    return json(res, state);
  }
  if (u.pathname === '/_test/oversize') { for (const s of sockets) s.write(frame(Buffer.alloc(2097153, 120))); return json(res, state); }
  if (u.pathname === '/_test/immediate') { immediate = true; return json(res, state); }
  if (u.pathname === '/_test/close') { for (const s of sockets) s.destroy(); return json(res, state); }
  if (u.pathname === '/_test/reply') {
    const x = u.searchParams.get('keep') === '1' ? queued[0] : queued.shift();
    if (x) {
      const value = { id: Number(u.searchParams.get('id') ?? x.id), type: u.searchParams.get('type') ?? 'result', success: true, result: { success: true, message: x.command } };
      const kind = u.searchParams.get('kind');
      if (kind === 'bool') value.id = true;
      if (kind === 'string') value.id = String(x.id);
      if (kind === 'missing') delete value.id;
      send(x.socket, value);
    }
    return json(res, state);
  }
  if (u.pathname === '/api/djconnect/v1/command') {
    let bytes = '';
    req.on('data', b => { bytes += b; if (bytes.length > 2097152) req.destroy(); });
    req.on('end', () => { const body = JSON.parse(bytes); state.httpCommands.push(body.command); json(res, { success: true, message: body.command }); });
    return;
  }
  res.writeHead(404); res.end();
});
server.on('upgrade', (req, socket) => {
  if (req.url !== '/api/websocket') { socket.destroy(); return; }
  state.connections++; sockets.add(socket); socket.on('close', () => sockets.delete(socket)); socket.on('error', () => {});
  const accept = crypto.createHash('sha1').update(req.headers['sec-websocket-key'] + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
  socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ' + accept + '\r\n\r\n');
  socket.setTimeout(30000, () => socket.destroy());
  send(socket, { type: 'auth_required', ha_version: 'fixture-only' });
  let input = Buffer.alloc(0);
  socket.on('data', chunk => {
    input = Buffer.concat([input, chunk]);
    if (input.length > 4194304) { socket.destroy(); return; }
    while (input.length >= 2) {
      let n = input[1] & 127, offset = 2;
      if (n === 126) { if (input.length < 4) return; n = input.readUInt16BE(2); offset = 4; }
      else if (n === 127) { if (input.length < 10) return; const big = input.readBigUInt64BE(2); if (big > 4194304n) { socket.destroy(); return; } n = Number(big); offset = 10; }
      const masked = (input[1] & 128) !== 0, opcode = input[0] & 15;
      if (input.length < offset + (masked ? 4 : 0) + n) return;
      const mask = masked ? input.subarray(offset, offset + 4) : null; if (masked) offset += 4;
      const body = Buffer.from(input.subarray(offset, offset + n)); input = input.subarray(offset + n);
      if (mask) for (let i = 0; i < body.length; i++) body[i] ^= mask[i % 4];
      if (opcode === 8) { socket.end(frame(Buffer.alloc(0), 8)); return; }
      if (opcode === 9) { socket.write(frame(body, 10)); continue; }
      if (opcode !== 1) continue;
      let msg; try { msg = JSON.parse(body.toString()); } catch { socket.destroy(); return; }
      if (msg.type === 'auth') {
        state.auth++;
        if (msg.access_token !== 'fixture-only-ha') { send(socket, { type: 'auth_invalid' }); continue; }
        if (releaseAuth) { socket.authed = true; send(socket, { type: 'auth_ok' }); } else socket.authPending = true;
        continue;
      }
      if (!socket.authed) { state.premature++; send(socket, { id: msg.id, type: 'result', success: false, error: { code: 'unauthorized', message: 'Not authenticated' } }); continue; }
      if (msg.type === 'djconnect/capabilities') {
        // Core cc8039 websocket_api.py243: capabilities needs type/id, no DJC identity.
        state.capabilities++;
        send(socket, { id: msg.id, type: 'result', success: true, result: { success: true, websocket_supported: true, transports: { websocket: true }, commands: ['djconnect/command', 'djconnect/ask_dj/history'] } });
      } else if (msg.type === 'djconnect/ask_dj/history') {
        send(socket, { id: msg.id, type: 'result', success: false, error: { code: 'profile_access_denied', message: 'HIDDEN_PROFILE_FIXTURE_DETAIL' } });
      } else if (msg.type === 'djconnect/command') {
        const command = msg.command ?? msg.payload?.command;
        if (msg.identity?.device_id !== 'djconnect-macos-fixture' || msg.identity?.client_type !== 'macos' || msg.identity?.device_token !== 'fixture-only-djc') {
          send(socket, { id: msg.id, type: 'result', success: false, error: { code: 'unauthorized', message: 'Invalid fixture identity' } }); continue;
        }
        state.commands.push({ id: msg.id, command });
        if (immediate) result(socket, msg.id, command); else queued.push({ socket, id: msg.id, command });
      } else send(socket, { id: msg.id, type: 'result', success: false, error: { code: 'unknown_command', message: 'Fixture route unavailable' } });
    }
  });
});
server.listen(0, '127.0.0.1', () => {
  // Publish only complete bytes. Opening the final name before writeFileSync
  // finishes lets the concurrently polling native test observe empty JSON.
  // linkSync keeps the original exclusive-create behavior for the final name.
  const pending = report + '.pending';
  fs.writeFileSync(pending, JSON.stringify({ port: server.address().port }), { flag: 'wx' });
  fs.linkSync(pending, report);
  fs.unlinkSync(pending);
});
process.on('SIGTERM', () => { for (const s of sockets) s.destroy(); server.closeAllConnections(); server.close(() => process.exit(0)); });
