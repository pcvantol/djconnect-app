import {generateKeyPairSync,createHash} from 'node:crypto';
import {readFileSync,writeFileSync,unlinkSync,mkdirSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
const root=process.env.DJC_SCANNER_JOSE_ROOT ?? '/private/tmp/djc-scanner-profile03-interop';
const {CompactEncrypt,compactDecrypt,importJWK,calculateJwkThumbprint}=await import(pathToFileURL(root+'/node/package/dist/webapi/index.js').href);
const work=root+'/work/followup';mkdirSync(work,{recursive:true,mode:0o700});
const bin=root+'/swift-build/debug/Interop',pair=generateKeyPairSync('rsa',{modulusLength:2048,publicExponent:65537});
const jwk=pair.publicKey.export({format:'jwk'}),kid=await calculateJwkThumbprint(jwk,'sha256');
const pub=await importJWK(jwk,'RSA-OAEP-256'),priv=await importJWK(pair.privateKey.export({format:'jwk'}),'RSA-OAEP-256');
const files={pub:work+'/public.der',priv:work+'/private.der',plain:work+'/plain.bin',token:work+'/token.jwe'};
writeFileSync(files.pub,pair.publicKey.export({type:'pkcs1',format:'der'}),{mode:0o600});writeFileSync(files.priv,pair.privateKey.export({type:'pkcs1',format:'der'}),{mode:0o600});
const header={alg:'RSA-OAEP-256',enc:'A256GCM',typ:'djc-rendezvous-destination+jwe',kid},checks=[],characterizations=[];
function nativeEncrypt(bytes){writeFileSync(files.plain,bytes);const r=spawnSync(bin,['encrypt',files.pub,files.plain,kid],{encoding:'utf8'});assert.equal(r.status,0,r.stderr);return r.stdout.trim();}
function nativeDecrypt(token){writeFileSync(files.token,token);return spawnSync(bin,['decrypt',files.priv,files.token]);}
try {
 for(const [name,payload] of [['UTF8 Unicode',Buffer.from('Muziek 🎧 · Straße · été · canción · \u0000')],['8192 bytes',Buffer.alloc(8192,65)],['16384 bytes',Buffer.alloc(16384,66)]]) {
  const token=nativeEncrypt(payload),d=await compactDecrypt(token,priv,{keyManagementAlgorithms:['RSA-OAEP-256'],contentEncryptionAlgorithms:['A256GCM']});assert.deepEqual(Buffer.from(d.plaintext),payload);checks.push(name+': native -> Node exact bytes');
  const t=await new CompactEncrypt(payload).setProtectedHeader(header).encrypt(pub),n=nativeDecrypt(t);assert.equal(n.status,0);assert.deepEqual(n.stdout,payload);checks.push(name+': Node -> native exact bytes');
 }
 const repeats=Array.from({length:12},()=>nativeEncrypt(Buffer.from('identical synthetic payload')));assert.equal(new Set(repeats).size,12);assert.equal(new Set(repeats.map(t=>t.split('.')[2])).size,12);checks.push('12 repeated native encryptions yield distinct JWE/IV; finite observation, not RNG proof');
 const token=await new CompactEncrypt(Buffer.from('synthetic malformed-length case')).setProtectedHeader(header).encrypt(pub);
 for(const [segment,length] of [[2,11],[2,13],[4,15],[4,17],[1,0],[3,0],[4,0]]){
  const s=token.split('.');s[segment]=Buffer.alloc(length,1).toString('base64url');const bad=s.join('.');assert.notEqual(nativeDecrypt(bad).status,0);await assert.rejects(compactDecrypt(bad,priv));checks.push(`Native and Node reject segment${segment} length${length}`);
 }
 const withExtra=await new CompactEncrypt(Buffer.from('characterize strict profile separately')).setProtectedHeader({...header,extension_example:'not admitted'}).encrypt(pub);
 assert.equal(nativeDecrypt(withExtra).status,0);characterizations.push('Valid crypto with extra protected field still decrypts: generic library is not closed-profile admission');
 const dupHeader='{"alg":"RSA-OAEP-256","enc":"A256GCM","typ":"djc-rendezvous-destination+jwe","kid":"'+kid+'","kid":"'+kid+'"}';
 // Changing authenticated bytes without re-encryption must reject; this does not prove duplicate-key parser rejection.
 const segments=token.split('.');segments[0]=Buffer.from(dupHeader).toString('base64url');assert.notEqual(nativeDecrypt(segments.join('.')).status,0);checks.push('Native rejects altered authenticated header bytes; no duplicate-key parser claim');
 const report={api_commit:'48a025d6b6343dd3220aa06d9f7a63c4f76a37bd',profile:'0.3.0-draft',scope:'isolated synthetic native Mac JOSESwift/Node; sizes test crypto byte fidelity, not wire limit admission',checks,characterizations,checks_passed:checks.length,AppAttest:'NOT_RUN',native_ios:'NOT_RUN',strict_profile_adapter:'NOT_IMPLEMENTED',keys:'Ephemeral synthetic RSA only; not App Attest; all work files deleted'};
 writeFileSync(process.env.DJC_SCANNER_RESULT_PATH ?? '/private/tmp/djc-scanner-profile03-followup-20261017/jose-followup-result.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({checks_passed:checks.length,characterizations:characterizations.length,AppAttest:'NOT_RUN'}));
} finally {for(const file of Object.values(files))try{unlinkSync(file)}catch{}}
