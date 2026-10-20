// Existing protected API root + real native Swift client; local software proof only.
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {createHash,randomBytes,webcrypto} from 'node:crypto';
import {readFile,writeFile,mkdtemp,chmod,realpath,open} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {execFileSync,spawn} from 'node:child_process';

const [repoArgument,scratchArgument,joseArgument]=process.argv.slice(2);
assert.equal(process.argv.length,5,'API checkout, prepared Swift scratch and pinned JOSE package are required');
const apiRepo=await realpath(repoArgument),scratch=await realpath(scratchArgument);
const pin='828fbaf300ca369dcc753b676295e84094d5e8c6';
assert.equal(execFileSync('git',['-C',apiRepo,'rev-parse','HEAD'],{encoding:'utf8'}).trim(),pin);
assert.equal(execFileSync('git',['-C',apiRepo,'status','--porcelain'],{encoding:'utf8'}).trim(),'');
const runtimePath=join(apiRepo,'qualification/rendezvous/root-integration-runtime.mjs');
const hash=b=>createHash('sha256').update(b).digest('hex');
assert.equal(hash(await readFile(runtimePath)),'27e9f5ae2a7b7350f3ae51352cf4efb023ec17f79bc8f42968cc3bdfbfe34854');
const {startRootIntegrationRuntime}=await import(pathToFileURL(runtimePath).href);
const {loadPinnedJose}=await import(pathToFileURL(join(apiRepo,'qualification/rendezvous/generate_destination_vector.mjs')).href);
const {compactDecrypt}=await loadPinnedJose(joseArgument);
const directory=await mkdtemp('/private/tmp/djc-rendezvous-http-');await chmod(directory,0o700);
const server=createServer((req,res)=>{res.writeHead(404);res.end();});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin='http://127.0.0.1:'+server.address().port;
let api;
try{
 api=await startRootIntegrationRuntime(origin);await api.verify();
 const v='djc-rendezvous/1',encode=b=>Buffer.from(b).toString('base64url');
 const pair=await webcrypto.subtle.generateKey({name:'RSA-OAEP',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},false,['encrypt','decrypt']);
 const full=await webcrypto.subtle.exportKey('jwk',pair.publicKey),claim=randomBytes(32);
 const post=async(route,body,browser=true)=>fetch(api.base+route,{method:'POST',redirect:'error',signal:AbortSignal.timeout(8000),headers:{'Content-Type':'application/json',...(browser?{Origin:origin}:{})},body:JSON.stringify(body)});
 const created=await post('create',{v,generation:1,browser_public_key:{kty:'RSA',n:full.n,e:full.e},claim_commitment:encode(createHash('sha256').update(claim).digest())});
 assert.equal(created.status,201);const transaction=await created.json();
 assert.equal(transaction.expires_at-transaction.created_at,120000);
 const planPath=join(directory,'plan.json');
 await writeFile(planPath,JSON.stringify({api_locator:api.base,qr:JSON.stringify(transaction.qr_payload)}),{mode:0o600,flag:'wx'});
 const log=await open(join(directory,'native-test.log'),'wx',0o600);
 try{
  const child=spawn('swift',['test','--scratch-path',scratch,'--skip-build','--filter','rendezvousHTTPNativeClientInterop'],{
   cwd:process.cwd(),env:{...process.env,DJCONNECT_RENDEZVOUS_HTTP_PLAN:planPath},stdio:['ignore',log.fd,log.fd]});
  const timer=setTimeout(()=>child.kill('SIGTERM'),60000);
  try{assert.equal(await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',resolve);}),0,'native opt-in test failed; private log retained');}
  finally{clearTimeout(timer);}
 }finally{await log.close();}
 await api.verify();
 const native=JSON.parse(await readFile(join(directory,'native-envelope.json')));
 const decrypted=await compactDecrypt(native.jwe,pair.privateKey,{keyManagementAlgorithms:['RSA-OAEP-256'],contentEncryptionAlgorithms:['A256GCM']});
 assert.deepEqual(decrypted.protectedHeader,{alg:'RSA-OAEP-256',enc:'A256GCM',typ:'djc-rendezvous-destination+jwe',kid:transaction.qr_payload.browser_key_thumbprint});
 const expected={v,transaction_id:transaction.transaction_id,generation:transaction.generation,browser_key_thumbprint:transaction.qr_payload.browser_key_thumbprint,expires_at:transaction.expires_at,
  bootstrap_origin:'https://vibecast.tv',display_entry_url:'https://ha.example.com/djconnect/vibecast/display',issuer_epoch:'A'.repeat(43)};
 assert.deepEqual(JSON.parse(new TextDecoder().decode(decrypted.plaintext)),expected);
 assert.equal(native.digest,encode(createHash('sha256').update(native.jwe).digest()));
 const cancelled=await post('cancel',{v,transaction_id:transaction.transaction_id,generation:transaction.generation,claim_secret:encode(claim)});
 assert.equal(cancelled.status,200);assert.equal((await cancelled.json()).state,'cancelled');
 const observations=await api.observations();
 assert.deepEqual(observations.filter(x=>x.method==='POST').map(x=>[x.route,x.status]),[['/create',201],['/inspect',200],['/cancel',200]]);
 await api.verify();
 const receipt={scope:'PROTECTED_API_LOOPBACK_HTTP_NATIVE_MAC_INSPECT_AND_SOFTWARE_JWE_NOT_GENUINE_NATIVE_HANDOFF',api_source:pin,runtime_sha256:hash(await readFile(runtimePath)),
  source:api.receipt(),native_tests:1,post_observations:observations.filter(x=>x.method==='POST'),jwe_standard:'RSA-OAEP-256/A256GCM',
  recipient_private_key_exported:false,ha_context:'SYNTHETIC_EXAMPLE_DOMAIN',native_app_attest:false,physical:false,public_activation:false};
 await writeFile(join(directory,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{mode:0o600,flag:'wx'});
 console.log(JSON.stringify({result:'PASS',scope:receipt.scope,receipt:join(directory,'receipt.json')}));
}finally{await api?.close();await new Promise(resolve=>server.close(resolve));}
