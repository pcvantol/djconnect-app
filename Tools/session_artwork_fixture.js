#!/usr/bin/env node
'use strict';
// Explicit local composed transport fixture. Uses pinned Core synthetic pixels
// and frozen native contracts, with fresh test-only identities/deadlines.
// Not a new Core producer receipt, installed HA or licensed provider evidence.
const http = require('http');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const native = JSON.parse(fs.readFileSync(path.join(root,'Tests/Fixtures/native-moment-receipt.json'))).spotify;
const projection = JSON.parse(fs.readFileSync(path.join(root,'Tests/Fixtures/session-artwork-core-5c7ecb79.json'))).examples.album_story.projection;
const pixels = fs.readFileSync(path.join(root,'Tests/Fixtures/session-artwork-cover-core-5c7ecb79.png'));
let runtime, snapshot, imageReads = 0, rejected = 0;
function reset() {
  runtime = structuredClone(native.runtime);
  snapshot = structuredClone(native.snapshot);
  const original = Date.parse(snapshot.session_flow.created_at);
  const offset = Date.now() - original;
  function shift(value) {
    if (Array.isArray(value)) return value.map(shift);
    if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,shift(v)]));
    if (typeof value === 'string' && /^\d{4}-\d\d-\d\dT/.test(value) && Number.isFinite(Date.parse(value))) return new Date(Date.parse(value)+offset).toISOString();
    return value;
  }
  snapshot = shift(snapshot); runtime = shift(runtime);
  const media = structuredClone(projection);
  media.session_id = snapshot.session.session_id;
  media.moment_id = snapshot.native_delivery.current_moment_id;
  media.artwork.current_display_allowed = true;
  media.artwork.captured_at = new Date().toISOString();
  media.artwork.expires_at = new Date(Date.now()+20000).toISOString();
  media.artwork.url = `/api/djconnect/v1/session/media/image/${media.session_id}/fixture-cover`;
  snapshot.session_media = [media];
  imageReads=0; rejected=0;
}
reset();
http.createServer((req,res)=>{
  const url = new URL(req.url,'http://127.0.0.1');
  const send=(code,body)=>{res.writeHead(code,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(body));};
  if (url.pathname === '/fixture/reset') { reset(); return send(200,{fixture:'composed_synthetic',success:true}); }
  if (url.pathname === '/fixture/metrics') return send(200,{imageReads,rejected});
  if (url.pathname.includes('/session/media/image/')) {
    if (req.headers.authorization !== 'Bearer local-moment-contract-fixture' || req.headers['x-djconnect-client-type'] !== 'ios') {rejected++;return send(401,{success:false});}
    imageReads++;
    res.writeHead(200,{'Content-Type':'image/png','Cache-Control':'no-store','Content-Length':pixels.length});return res.end(pixels);
  }
  if (url.pathname === '/api/djconnect/v1/session/active') return send(200,{success:true,active_session:{...runtime,broadcast:snapshot}});
  if (url.pathname.endsWith('/capabilities')) return send(200,{success:true,capabilities:{}});
  if (url.pathname.includes('/command') || url.pathname.endsWith('/status')) return send(200,{success:true,ha_version:'4.0.0',ha_major_minor:'4.0',backend_available:true,playback:{has_playback:true,is_playing:true,track_name:'Fixture track',artist_name:'Fixture artist'}});
  send(404,{success:false,error:'fixture_route_missing'});
}).listen(18788,'127.0.0.1',()=>console.log('SYNTHETIC_ARTWORK_FIXTURE http://127.0.0.1:18788'));
