// Isolated Mac/native/API software exchange, not a service or signed-iOS claim.
import {spawn, spawnSync} from 'node:child_process';
import {createInterface} from 'node:readline';
import {readFileSync, writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import assert from 'node:assert/strict';

const [binary, generator, packageDirectory, output] = process.argv.slice(2);
assert.ok(binary && generator && packageDirectory && output);
assert.equal(createHash('sha256').update(readFileSync(generator)).digest('hex'), '15533bbd9e74c6557508ac11bbda26c4d851c3a62172c0790733b4b0c4891001');
const {loadPinnedJose} = await import(pathToFileURL(generator));
const jose = await loadPinnedJose(packageDirectory); // exact80-file dependency guard owned by API
const child = spawn(binary, [], {stdio: ['pipe', 'pipe', 'pipe']});
const lines = createInterface({input: child.stdout})[Symbol.asyncIterator]();
let stderr = '';
child.stderr.on('data', b => { stderr += b.length; });
const checks = [];
async function receive() {
 let timer;
 try {
  const next = await Promise.race([lines.next(), new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('native_timeout')), 5000); })]);
  assert.equal(next.done, false); assert.ok(next.value.length <= 16384); return JSON.parse(next.value);
 } finally { clearTimeout(timer); }
}
async function call(input) { child.stdin.write(JSON.stringify(input) + '\n'); return receive(); }
function pass(label) { checks.push(label); }
function api(input) {
 const r = spawnSync(process.execPath, [generator, packageDirectory], {input: JSON.stringify(input), encoding: 'utf8', timeout: 5000, maxBuffer: 32768});
 assert.equal(r.status, 0); assert.equal(r.stderr, ''); return r.stdout.trimEnd();
}
try {
 const native = await receive();
 assert.deepEqual(Object.keys(native.jwk).sort(), ['e', 'kty', 'n']);
 assert.equal(native.jwk.e, 'AQAB'); assert.equal(await jose.calculateJwkThumbprint(native.jwk), native.thumbprint);
 pass('fresh native public JWK and independent RFC7638 agreement');
 const now = 1_800_000_000_000;
 const plaintext = {v: 'djc-rendezvous/1', transaction_id: '12345678-1234-4123-8123-123456789abc', generation: 7,
  browser_key_thumbprint: native.thumbprint, expires_at: now + 120000, bootstrap_origin: 'https://vibecast.tv',
  display_entry_url: 'https://ha.example.org/djconnect/vibecast/display', issuer_epoch: Buffer.alloc(32, 2).toString('base64url')};
 const payload = Buffer.from(JSON.stringify(plaintext)), expected = payload.toString('base64');
 const input = {jwk: native.jwk, thumbprint: native.thumbprint, plaintext};
 const envelope = api(input);
 const opened = await call({mode: 'decrypt', envelope, expected, now});
 assert.deepEqual(Buffer.from(opened.plaintext, 'base64'), payload); pass('exact API generator -> native decrypt preserves plaintext bytes');
 assert.notEqual(api(input), envelope); pass('API fresh randomness');
 const pair = await jose.generateKeyPair('RSA-OAEP-256', {modulusLength: 2048, extractable: false});
 assert.equal(pair.privateKey.extractable, false);
 const jwk = await jose.exportJWK(pair.publicKey), thumb = await jose.calculateJwkThumbprint(jwk);
 const outgoingPayload = Buffer.from(JSON.stringify({...plaintext, browser_key_thumbprint: thumb}));
 const encrypted = await call({mode: 'encrypt', jwk, plaintext: outgoingPayload.toString('base64')});
 const decoded = await jose.compactDecrypt(encrypted.envelope, pair.privateKey, {keyManagementAlgorithms: ['RSA-OAEP-256'], contentEncryptionAlgorithms: ['A256GCM']});
 assert.deepEqual(Buffer.from(decoded.plaintext), outgoingPayload);
 assert.deepEqual(decoded.protectedHeader, {alg: 'RSA-OAEP-256', enc: 'A256GCM', typ: 'djc-rendezvous-destination+jwe', kid: thumb});
 pass('native encrypt -> Node jose nonextractable private key exact plaintext/header');
 assert.notEqual((await call({mode: 'encrypt', jwk, plaintext: outgoingPayload.toString('base64')})).envelope, encrypted.envelope);
 pass('native fresh randomness');
 for (let index = 0; index < 5; index++) {
  const parts = envelope.split('.'), bytes = Buffer.from(parts[index], 'base64url'); bytes[0] ^= 1; parts[index] = bytes.toString('base64url');
  assert.deepEqual(await call({mode: 'decrypt', envelope: parts.join('.'), expected, now}), {rejected: true}); pass('native denies tampered segment ' + index);
  const reverse = encrypted.envelope.split('.'), changed = Buffer.from(reverse[index], 'base64url'); changed[0] ^= 1; reverse[index] = changed.toString('base64url');
  await assert.rejects(jose.compactDecrypt(reverse.join('.'), pair.privateKey)); pass('Node denies native segment mutation ' + index);
 }
 const recipient = await jose.importJWK(native.jwk, 'RSA-OAEP-256');
 const header = {alg: 'RSA-OAEP-256', enc: 'A256GCM', typ: 'djc-rendezvous-destination+jwe', kid: native.thumbprint};
 for (const [label, variant] of [['typ', {...header, typ: 'other'}], ['kid', {...header, kid: thumb}], ['extra header', {...header, unexpected: 'extra'}], ['enc', {...header, enc: 'A128GCM'}]]) {
  const bad = await new jose.CompactEncrypt(payload).setProtectedHeader(variant).encrypt(recipient);
  assert.deepEqual(await call({mode: 'decrypt', envelope: bad, expected, now}), {rejected: true}); pass('native denies valid crypto with wrong ' + label);
 }
 for (const key of Object.keys(plaintext)) {
  const changed = {...plaintext, [key]: typeof plaintext[key] === 'number' ? plaintext[key] + 1 : plaintext[key] + 'x'};
  const bad = await new jose.CompactEncrypt(Buffer.from(JSON.stringify(changed))).setProtectedHeader(header).encrypt(recipient);
  assert.deepEqual(await call({mode: 'decrypt', envelope: bad, expected, now}), {rejected: true}); pass('native denies plaintext context mismatch ' + key);
 }
 assert.deepEqual(await call({mode: 'decrypt', envelope, expected, now: plaintext.expires_at}), {rejected: true}); pass('native denies original expiry equality');
 for (const bad of [envelope + '.AA', envelope.split('.').slice(0, 4).join('.'), envelope + '\n']) {
  assert.deepEqual(await call({mode: 'decrypt', envelope: bad, expected, now}), {rejected: true}); pass('native denies serialization alias');
 }
 const wrong = await jose.generateKeyPair('RSA-OAEP-256', {modulusLength: 2048, extractable: false});
 await assert.rejects(jose.compactDecrypt(encrypted.envelope, wrong.privateKey)); pass('Node denies wrong recipient');
 const wrongEnvelope = await new jose.CompactEncrypt(payload).setProtectedHeader(header).encrypt(wrong.publicKey);
 assert.deepEqual(await call({mode: 'decrypt', envelope: wrongEnvelope, expected, now}), {rejected: true}); pass('native denies wrong recipient');
 assert.equal(stderr, '');
 writeFileSync(output, JSON.stringify({scope: 'actual isolated Mac software CLI/API generator interop; no browser, signed-iOS, AppAttest or HA authority',
  api_commit: 'fbe118b3b62b53793ec4d1bbc0aa8adcdff69ba4', native_library: 'JOSESwift3.0.0/c2664a902e75c0426a1d43132bd4babc6fd173d3',
  node_library: 'jose6.2.12/API exact80-file manifest', checks_passed: checks.length, checks,
  private_keys: 'fresh process memory only; never exported or persisted', contract: '0.4.0-draft NOT_FROZEN / NO_RUNTIME_GO'}, null, 2) + '\n', {mode: 0o600});
 console.log(JSON.stringify({checks_passed: checks.length}));
} finally { child.stdin.end(); child.kill(); }
