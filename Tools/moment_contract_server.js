#!/usr/bin/env node
'use strict';
// Local synthetic fixture only. Its semantic payloads come from the pinned
// Core Runtime receipt; this server models the owner HTTP/WS envelopes.
const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const {decodeFrame, encodeFrame} = require('./ha_contract_fixture');
let receipt = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (!Array.isArray(receipt.end_events)) throw new Error('Generate a fresh pinned receipt with Runtime end events before starting the fixture');
let nativeCapture = null;
let nativeFlavor = null;
let snapshot = receipt.snapshot;
let ended = false;
let rejectOwner = false;
let cacheable = false;
let malformed = false;
let delayActive = false;
let activeFailure = false;
let lateFailureOnce = false;
let subscriptions = 0;
let playbackMutations = 0;
let commandKinds = [];
const sockets = new Set();
function send(socket, data) { socket.write(encodeFrame(JSON.stringify(data))); }
function event(socket, data) { send(socket, {id:1,type:'event',event:{event_type:'djconnect/session/broadcast',data}}); }
const server = http.createServer(async (request,response) => {
  const chunks = []; for await (const chunk of request) chunks.push(chunk);
  const rawBody = Buffer.concat(chunks).toString('utf8');
  const body = rawBody ? JSON.parse(rawBody) : {};
  const path = request.url.split('?')[0];
  let data = {success:true};
  let responseStatus=200;
  let requestDelay=0;
  if (path === "/api/djconnect/v1/session/active" && lateFailureOnce) { lateFailureOnce=false; requestDelay=1000; responseStatus=401; }
  if (path === "/api/djconnect/v1/session/active" && activeFailure) responseStatus=401;
  if (path === '/fixture/spotify_reset') {
    require('child_process').execFileSync('python3', ['Tools/generate_native_moment_receipt.py','--core',process.argv[3],'--output',process.argv[2]+'.native'], {timeout:45000});
    nativeFlavor='spotify'; activeFailure=false; lateFailureOnce=false; nativeCapture=JSON.parse(fs.readFileSync(process.argv[2]+'.native','utf8')).spotify;
    snapshot=nativeCapture.snapshot; receipt.runtime=nativeCapture.runtime;
    ended=false; rejectOwner=false; cacheable=false; malformed=false; delayActive=false; subscriptions=0; playbackMutations=0; commandKinds=[];
    for (const socket of sockets) socket.destroy();
  } else if (path === '/fixture/native_reset') {
    nativeFlavor='cc0'; activeFailure=false; lateFailureOnce=false;
    require('child_process').execFileSync('python3', ['Tools/generate_native_moment_receipt.py','--core',process.argv[3],'--output',process.argv[2]+'.native'], {timeout:45000});
    nativeCapture = JSON.parse(fs.readFileSync(process.argv[2]+'.native','utf8')).after;
    snapshot = nativeCapture.http_initial.snapshot;
    receipt.runtime = {...receipt.runtime,session_id:snapshot.session.session_id,broadcast:snapshot};
    ended=false; rejectOwner=false; cacheable=false; malformed=false; delayActive=false; subscriptions=0; playbackMutations=0; commandKinds=[];
    for (const socket of sockets) socket.destroy();
  } else if (path === '/fixture/reset') {
    nativeCapture = null; nativeFlavor = null;
    require('child_process').execFileSync('python3', ['Tools/generate_moment_contract_receipt.py','--core',process.argv[3] || process.env.DJCONNECT_CORE_ROOT || require('path').resolve(__dirname, '../../djconnect'),'--output',process.argv[2]], {timeout:45000});
    receipt = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')); snapshot = receipt.snapshot; ended = false; rejectOwner = false; cacheable = false; malformed = false; delayActive=false; subscriptions = 0; playbackMutations = 0; commandKinds = [];
    for (const socket of sockets) socket.destroy();
  } else if (path === '/api/djconnect/v1/session/active') data.active_session = ended ? null : {...receipt.runtime,broadcast:snapshot};
  else if (path === '/api/djconnect/v1/websocket/session') data = {success:true,access_token:'local-fixture-ha-auth',expires_in:3600,commands:[]};
  else if (path === '/api/djconnect/v1/session/end') {
    ended = true;
    for (const socket of sockets) for (const item of (nativeFlavor==='spotify' ? nativeCapture.end_events : nativeCapture ? nativeCapture.events.slice(-2) : receipt.end_events)) event(socket,item);
  } else if (path === '/fixture/advance') {
    snapshot = nativeCapture ? nativeCapture.http_shared_producer.snapshot : receipt.updated_snapshot;
    for (const socket of sockets) for (const item of (nativeCapture ? nativeCapture.events.slice(0,5) : receipt.events)) event(socket,item);
  } else if (path === '/fixture/expire') {
    snapshot = nativeCapture.expired;
    for (const socket of sockets) for (const item of (nativeFlavor==='spotify' ? nativeCapture.expiry_events : nativeCapture.events.slice(5,7))) event(socket,item);
  } else if (path === '/fixture/terminal_denial') {
    const terminal = {...nativeCapture.events.at(-1)}; delete terminal.delivery_sequence;
    ended=true; for (const socket of sockets) event(socket,terminal);
  } else if (path === '/fixture/track_change') {
    snapshot = receipt.track_change_snapshot;
    for (const socket of sockets) for (const item of receipt.track_change_events) event(socket,item);
  } else if (path === '/fixture/active_failure') {
    activeFailure=true;
  } else if (path === '/fixture/clear_active_failure') {
    activeFailure=false;
  } else if (path === '/fixture/late_failure') {
    lateFailureOnce=true;
  } else if (path === '/fixture/delay_active') {
    delayActive = true;
  } else if (path === '/fixture/malformed') {
    malformed = true;
  } else if (path === '/fixture/cacheable') {
    cacheable = true;
  } else if (path === '/fixture/reject_owner') {
    rejectOwner = true; for (const socket of sockets) socket.destroy();
  } else if (path === '/fixture/reconnect') {
    for (const socket of sockets) socket.destroy();
  } else if (path === '/fixture/metrics') data = {subscriptions,active_connections:sockets.size,playbackMutations,commandKinds,ended};
  else if (path.includes('/command')) {
    const kind = body.command || body.type || 'unknown'; commandKinds.push(kind);
    if (!['get_outputs','get_queue','get_playlists','get_playback','get_now_playing','outputs','devices','queue','playlists','now_playing','status'].includes(kind)) playbackMutations++;
  }
  if (malformed && data.active_session) delete data.active_session.room;
  if (path.includes('/command') || path.endsWith('/status')) {
    const p = snapshot.playback || {};
    data = {success:true,ha_version:'4.0.0-rc.1',ha_major_minor:'4.0',backend_available:true,
      music_backend:'spotify_direct',music_backend_name:'Spotify Direct',music_backend_available:true,
      playback:{has_playback:p.state==='playing'||p.state==='paused',is_playing:p.state==='playing',
        track_name:p.title,artist_name:p.artist,progress_ms:p.position_ms,duration_ms:p.duration_ms,
        volume_percent:54,shuffle:false,repeat_state:'off'}};
  }
  if (responseStatus !== 200) data={success:false,error:"auth_stale"};
  if (requestDelay) await new Promise(resolve => setTimeout(resolve,requestDelay));
  if (delayActive && path === '/api/djconnect/v1/session/active') await new Promise(resolve => setTimeout(resolve, 1000));
  response.writeHead(responseStatus,{'Content-Type':'application/json','Cache-Control':cacheable ? 'public,max-age=600' : 'no-store'});
  response.end(JSON.stringify(data));
});
server.on('upgrade',(request,socket) => {
  const key = request.headers['sec-websocket-key'];
  if (request.url !== '/api/websocket' || !key) { socket.destroy(); return; }
  const accept = crypto.createHash('sha1').update(key+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
  socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: '+accept+'\r\n\r\n');
  send(socket,{type:'auth_required',ha_version:'2026.10.0'});
  let pending = Buffer.alloc(0);
  socket.on('data',chunk => {
    pending = Buffer.concat([pending,chunk]);
    while (pending.length) {
      const frame = decodeFrame(pending);
      if (!frame) return;
      pending = pending.subarray(frame.consumed);
      if (frame.opcode === 8) { socket.end(); return; }
      if (frame.opcode !== 1 && frame.opcode !== 2) continue;
      const message = JSON.parse(frame.text);
      if (message.type === 'auth') send(socket,{type:'auth_ok',ha_version:'2026.10.0'});
      else if (message.type === 'djconnect/session/broadcast/subscribe') {
        if (rejectOwner) {
          send(socket,{id:message.id,type:'result',success:false,error:{code:'profile_access_denied'}}); continue;
        }
        if (message.session_id !== receipt.runtime.session_id || ended) {
          send(socket,{id:message.id,type:'result',success:false,error:{code:'active_session_not_found'}}); continue;
        }
        subscriptions++; sockets.add(socket);
        send(socket,{id:message.id,type:'result',success:true,result:{success:true,session_id:receipt.runtime.session_id,subscription_id:'fixture-subscription-'+subscriptions,snapshot}});
      }
    }
  });
  socket.on('error',()=>{});
  socket.on('close',()=>sockets.delete(socket));
});
server.listen(18787,'127.0.0.1',()=>console.log('LOCAL_SYNTHETIC_OWNER_FIXTURE http://127.0.0.1:18787'));
