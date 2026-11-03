// Real Network.framework HTTP listener in the isolated simulator harness. No HTTP mocks.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import net from 'node:net';

import {gunzipSync} from 'node:zlib';
import {execFileSync} from 'node:child_process';
const container=execFileSync('xcrun',['simctl','get_app_container','booted','com.xuegao.theosmobilecompiler','data'],{encoding:'utf8'}).trim();
const docs=path.join(container,'Documents');let count=0;
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const state=()=>JSON.parse(fs.readFileSync(path.join(docs,'RemoteTestState.json'),'utf8'));
async function wait(test,ms=12000){const end=Date.now()+ms;while(Date.now()<end){try{if(await test())return;}catch{}await delay(100);}throw new Error('Timed out waiting for simulator state');}
const check=(test,name)=>{if(!test)throw new Error(name);console.log('PASS '+name);count++;};
async function command(action,args={}){const p=path.join(docs,'RemoteTestCommand.json');fs.writeFileSync(p+'.tmp',JSON.stringify({action,...args}));fs.renameSync(p+'.tmp',p);await wait(()=>!fs.existsSync(p));await delay(150);}
await wait(()=>{const s=state();return s.state==='running'&&typeof s.codeLabel==='string'&&s.url===`http://127.0.0.1:${s.port}`&&s.audio;});
await wait(()=>new Promise(resolve=>{const s=net.connect(state().port,'127.0.0.1',()=>{s.destroy();resolve(true);});s.on('error',()=>resolve(false));}));
await delay(400);await wait(()=>{const s=state();return s.state==='running'&&s.url===`http://127.0.0.1:${s.port}`;});const startState=state();const port=startState.port,origin=`http://127.0.0.1:${port}`;
async function request(url,{body,cookie,headers={},method,version,webPort=port}={}){return new Promise((resolve,reject)=>{const options={host:'127.0.0.1',port:webPort,path:url,method:method||(body===undefined?'GET':'POST'),agent:false,timeout:7000,headers:{...body!==undefined?{'Origin':`http://127.0.0.1:${webPort}`,'Content-Type':'application/json'}:{},...cookie?{'Cookie':cookie}:{},...headers},...version?{minVersion:version,maxVersion:version}:{}};const q=http.request(options,r=>{let chunks=[];r.on('data',c=>chunks.push(c));r.on('end',()=>{const data=Buffer.concat(chunks);let json;try{json=JSON.parse(data.toString());}catch{}resolve({status:r.statusCode,headers:r.headers,json,data,protocol:r.socket?.getProtocol?.()});});});q.on('timeout',()=>q.destroy(new Error('request timeout')));q.on('error',reject);if(body!==undefined)q.end(typeof body==='string'?body:JSON.stringify(body));else q.end();});}
check(origin===startState.url&&!startState.tls,'native exposes HTTP without a certificate');
check((await request('/health')).status===200,'standard HTTP health check');
for(const url of ['/','/remote.js','/remote.css','/app-icon.png','/monaco/vs/loader.js']){const r=await request(url);check(r.status===200&&r.data.length>300,'offline asset '+url);check(!!r.headers['content-security-policy'],'CSP '+url);}
const rawEditor=await request('/monaco/vs/editor/editor.main.js');const zippedEditor=await request('/monaco/vs/editor/editor.main.js',{headers:{'Accept-Encoding':'gzip'}});
check(zippedEditor.headers['content-encoding']==='gzip'&&gunzipSync(zippedEditor.data).equals(rawEditor.data),'compressed offline editor decodes byte-for-byte');
check(zippedEditor.data.length<rawEditor.data.length*.4,'editor transfer compressed below 40 percent');
check(!(await request('/monaco/vs/editor/editor.main.js',{headers:{'Accept-Encoding':'gzip;q=0'}})).headers['content-encoding'],'client disabling gzip receives original resource');
check((await request('/highlight.js')).data.includes(Buffer.from('hljs')),'offline secondary syntax engine served');
check(await new Promise((resolve,reject)=>{const q=http.get({host:'127.0.0.1',port,path:'/monaco/vs/editor/editor.main.js',agent:false},r=>{const chunks=[];r.pause();setTimeout(()=>r.resume(),11000);r.on('data',c=>chunks.push(c));r.on('end',()=>resolve(Buffer.concat(chunks).equals(rawEditor.data)));r.on('error',reject);});q.setTimeout(20000,()=>q.destroy(new Error('slow resource timed out')));q.on('error',reject);}), 'editor response survives client reading beyond ten seconds');

check((await request('/api/v1/status')).status===401,'private APIs require authentication');
check((await request('/health',{headers:{Host:'attacker.invalid'}})).status===403,'Host rebinding rejected over HTTP');
check((await request('/health',{headers:{Origin:'https://attacker.invalid'}})).status===403,'cross-origin request rejected');
await command('rotate');await wait(()=>state().code.length===8);
const label=state().codeLabel;await delay(2100);check(label!==state().codeLabel&&state().codeLabel.includes('剩余'),'native countdown changes while snapshot codeExpiry stays constant');
const code=state().code;
const paired=await request('/api/v1/pair',{body:{name:'HTTP Integration',code,workspace:true}});check(paired.status===200&&paired.json.data.state==='approved','correct code grants access immediately');
const cookie=paired.headers['set-cookie'][0].split(';')[0];check(cookie.startsWith('DylixRemoteSession='),'HTTP compatible session cookie');
check(!/Secure/.test(paired.headers['set-cookie'][0])&&/HttpOnly/.test(paired.headers['set-cookie'][0])&&/SameSite=Strict/.test(paired.headers['set-cookie'][0]),'HTTP cookie remains HttpOnly and SameSite Strict');
check(!JSON.stringify(paired.json).includes('token'),'bearer token excluded from JSON response');
await wait(()=>state().pending.length===0&&state().code==='');check(state().pending.length===0,'no phone approval request remains');
check((await request('/api/v1/pair',{body:{name:'Replay',code}})).status===403,'random code replay rejected');
let status=await request('/api/v1/status',{cookie});check(status.status===200&&status.json.session.permission==='workspace','workspace scope matches requested pairing');const csrf=status.json.session.csrf;
check((await request('/api/v1/workspace',{body:{action:'projects'},cookie})).status===403,'mutation without CSRF rejected');
check((await request('/../Documents',{cookie})).status===404,'document traversal not served');
await command('background');await wait(()=>state().lifecycle.startsWith('background'));check(state().state==='running'&&(await request('/health')).status===200,'background notification preserves listener during grace');
await command('expire');await wait(()=>state().lifecycle==='background_audio');check(state().state==='running'&&(await request('/health')).status===200,'Remote owns audio and retains listener after grace expiry');
await command('audio',{enabled:false});await command('expire');await wait(()=>state().state==='suspended');check(state().httpEnabled&&state().devices.length>0,'disabled audio permits suspension without losing authorization');
await command('foreground');await wait(()=>state().state==='running');await command('audio',{enabled:true});check(!state().audio.owners.includes('remote'),'foreground releases Remote audio lease');check((await request('/api/v1/status',{cookie})).status===200,'foreground resumes HTTP cookie without pairing');
const fixed='67495328';await command('fixed',{code:fixed});await wait(()=>state().codeMode==='fixed'&&state().code===fixed);check(state().codeExpiry===0,'fixed code has no countdown expiry');
await command('stop');await wait(()=>state().state==='stopped');await command('start');await wait(()=>state().state==='running');check(state().code===fixed&&state().codeMode==='fixed','fixed code restored from Keychain on restart');
const a=await request('/api/v1/pair',{body:{code:fixed,name:'Fixed A'}}),b=await request('/api/v1/pair',{body:{code:fixed,name:'Fixed B'}});check(a.status===200&&b.status===200,'fixed code accepts multiple trusted devices');const ac=a.headers['set-cookie'][0].split(';')[0],bc=b.headers['set-cookie'][0].split(';')[0];check(ac!==bc,'each browser gets independent credential');
await command('revoke',{id:a.json.data.deviceID});check((await request('/api/v1/status',{cookie:ac})).status===401&&(await request('/api/v1/status',{cookie:bc})).status===200,'revoking one fixed-code device preserves other device');
await command('rotate');await wait(()=>state().codeMode==='random');check((await request('/api/v1/pair',{body:{code:fixed,name:'Old fixed'}})).status===403,'switch to random invalidates old fixed code');
await command('stop');await wait(()=>state().state==='stopped');await command('start');await wait(()=>state().state==='running');check(state().codeMode==='random'&&state().code!==fixed,'random mode survives restart without old fixed secret');
// Workspace and WebDAV use the same native services, authenticated over HTTP.
const full=await request('/api/v1/pair',{body:{code:state().code,name:'DAV Integration',workspace:true}});
check(full.status===200,'workspace test device paired');
const wc=full.headers['set-cookie'][0].split(';')[0],ws=await request('/api/v1/status',{cookie:wc}),xs=ws.json.session.csrf;
async function workspace(action,args={},projectID=''){
 let r=await request('/api/v1/workspace',{body:{action,arguments:args,projectID},cookie:wc,headers:{'X-Dylix-CSRF':xs}}),job=r.json?.data;
 for(let n=0;n<120;n++){
  if(job?.state==='completed')return job.result;
  if(job?.state==='failed'||job?.error)throw new Error(JSON.stringify(job));
  if(job?.state==='awaiting_confirmation')r=await request('/api/v1/jobs/confirm',{body:{id:job.id,nonce:job.nonce,accepted:true},cookie:wc,headers:{'X-Dylix-CSRF':xs}});
  else {await delay(100);r=await request('/api/v1/jobs/get',{body:{id:job.id},cookie:wc,headers:{'X-Dylix-CSRF':xs}});}
  job=r.json?.data;
 }throw new Error('workspace job timeout '+action);
}
const project=await workspace('create_project',{name:'RemoteTLS-'+Date.now(),template:'objectivec'});
check(!!project.projectID,'native project template creates real workspace');
const projectID=project.projectID;
// Auto-save is an explicit device/project grant, not a client-only bypass.
const source=await workspace('read',{path:'Test.m'},projectID);
let deniedAuto=false;try{await workspace('save',{path:'Test.m',sha256:source.sha256,text:source.text,automatic:true},projectID);}catch(e){deniedAuto=e.message.includes('自动保存授权');}
check(deniedAuto,'automatic save denied before explicit grant');
check(!(await workspace('editor_autosave_status',{},projectID)).enabled,'automatic save disabled by default');
await workspace('editor_autosave',{enabled:true},projectID);
check((await workspace('editor_autosave_status',{},projectID)).enabled,'confirmed auto-save grants current project');
await workspace('save',{path:'Test.m',sha256:source.sha256,text:source.text+'\n// grant regression\n',automatic:true},projectID);
const savedAuto=await workspace('read',{path:'Test.m'},projectID);
check(savedAuto.text.endsWith('// grant regression\n'),'granted auto-save writes actual source');
await workspace('save',{path:'Test.m',sha256:savedAuto.sha256,text:source.text,automatic:true},projectID);
check((await workspace('backups',{path:'Test.m'},projectID)).backups.length>=2,'automatic saves retain native backups');
await workspace('editor_autosave',{enabled:false},projectID);
let disabledAuto=false;try{await workspace('save',{path:'Test.m',sha256:source.sha256,text:source.text,automatic:true},projectID);}catch{disabledAuto=true;}
check(disabledAuto,'turning off auto-save revokes native grant');

const sandbox=await workspace('sandbox_list');check(sandbox.entries.some(e=>e.folder),'Documents browser lists folders without project selection');
check(!sandbox.entries.some(e=>e.name.startsWith('RemoteTest')),'simulator private harness files excluded from listing');
for(const path of ['../Library','/etc/passwd','.studio-remote-backups']){let blocked=false;try{await workspace('sandbox_list',{path});}catch{blocked=true;}check(blocked,'sandbox path denied '+path);}

// Native file manager upload: immutable conflict token, staged ownership and cleanup.
const uploadPath='upload156-integration.dylib';
const staged=await workspace('input_chunk',{offset:0,name:'upload156-integration.dylib',data:Buffer.from('binary fixture').toString('base64')});
const probe=await workspace('sandbox_upload_probe',{path:uploadPath});
await workspace('sandbox_upload',{path:uploadPath,inputID:staged.inputID,sha256:probe.sha256});
check(fs.readFileSync(path.join(docs,uploadPath)).equals(Buffer.from('binary fixture')),'file manager stores dylib bytes without execution');
check((await workspace('sandbox_list')).entries.some(e=>e.name===uploadPath),'uploaded binary appears in file manager');
const conflictProbe=await workspace('sandbox_upload_probe',{path:uploadPath});
const conflictInput=await workspace('input_chunk',{offset:0,name:uploadPath,data:Buffer.from('new bytes').toString('base64')});
fs.writeFileSync(path.join(docs,uploadPath),'phone edit');let conflict=false;try{await workspace('sandbox_upload',{path:uploadPath,inputID:conflictInput.inputID,sha256:conflictProbe.sha256});}catch(e){conflict=e.message.includes('409');}
check(conflict&&fs.readFileSync(path.join(docs,uploadPath),'utf8')==='phone edit','upload rejects concurrent phone modification');
for(const path of ['../upload.txt','Library/upload.txt','.env','missing-folder/upload.txt']){let denied=false;try{await workspace('sandbox_upload_probe',{path});}catch{denied=true;}check(denied,'upload target policy rejects '+path);}
const link=path.join(docs,'upload156-link.dylib');try{fs.unlinkSync(link);}catch{}fs.symlinkSync(path.join(docs,uploadPath),link);let symlinkDenied=false;try{await workspace('sandbox_upload_probe',{path:'upload156-link.dylib'});}catch{symlinkDenied=true;}check(symlinkDenied,'binary upload rejects actual symlink');fs.unlinkSync(link);
const discarded=await workspace('input_chunk',{offset:0,name:'discard.txt',data:''});await workspace('input_discard',{inputID:discarded.inputID});let discardDenied=false;try{await workspace('sandbox_upload',{path:'discard.txt',inputID:discarded.inputID,sha256:'missing'});}catch{discardDenied=true;}check(discardDenied,'discarded temporary upload cannot be committed');
fs.unlinkSync(path.join(docs,uploadPath));

fs.writeFileSync(path.join(docs,'RemoteBrowserFixture.json'),JSON.stringify({projectID}));
const zip=execFileSync('python3',['-c',"import io,zipfile,sys; b=io.BytesIO(); z=zipfile.ZipFile(b,'w'); z.writestr('Fixture/Makefile','TARGET = iphone:clang:latest:15.0\\nARCHS = arm64\\n'); z.writestr('Fixture/Test.m','int remote_fixture = 1;\\n'); z.close(); sys.stdout.buffer.write(b.getvalue())"]);
const uploaded=await workspace('input_chunk',{offset:0,data:zip.toString('base64'),name:'fixture.zip'});
check(!!uploaded.inputID,'HTTP workspace accepts staged ZIP input');
const imported=await workspace('import_project',{inputID:uploaded.inputID,name:'Remote ZIP fixture'});
check(!!imported.id,'ZIP import succeeds using a new destination');
check((await workspace('tree',{},imported.id)).entries.some(e=>e.path==='Test.m'),'ZIP import preserves source tree');
const invalid=await request('/api/v1/workspace',{body:{action:'input_chunk',arguments:{offset:{bad:1},data:''}},cookie:wc,headers:{'X-Dylix-CSRF':xs}});
check(invalid.status===400&&!!invalid.json.data.error,'malformed upload offset rejected before job execution');
for(let n=0;n<3;n++){const tasks=await workspace('tasks');check(tasks.tasks.every(t=>!t.result&&t.action!=='tasks'),'task summaries exclude recursive prior task results '+n);}
await command('dav_start',{projectID,readOnly:true});await wait(()=>state().davState==='running');
const dp=state().davPort;let cred=state().davCredential;
let auth='Basic '+Buffer.from('dylix:'+cred.password).toString('base64');
check((await request('/',{webPort:dp,method:'OPTIONS'})).status===401,'WebDAV requires credentials');
check((await request('/',{webPort:dp,method:'OPTIONS',headers:{Authorization:auth}})).status===200,'WebDAV HTTP authentication');
check((await request('/',{webPort:dp,method:'PROPFIND',headers:{Authorization:auth,Depth:'1'}})).status===207,'WebDAV PROPFIND real project');
check((await request('/remote-secure.txt',{webPort:dp,method:'PUT',body:'first',headers:{Authorization:auth}})).status===403,'read-only WebDAV rejects write');
const oldAuth=auth;await command('dav_start',{projectID,readOnly:false});await wait(()=>state().davState==='running'&&state().davCredential.password!==cred.password);
cred=state().davCredential;auth='Basic '+Buffer.from('dylix:'+cred.password).toString('base64');
check((await request('/',{webPort:dp,method:'OPTIONS',headers:{Authorization:oldAuth}})).status===401,'changing DAV grant revokes previous credential');
const dh={Authorization:auth};
check((await request('/remote-secure.txt',{webPort:dp,method:'PUT',body:'first',headers:dh})).status===201,'DAV PUT creates real file');
let file=await request('/remote-secure.txt',{webPort:dp,headers:dh});check(file.status===200&&file.data.toString()==='first'&&!!file.headers.etag,'DAV GET and ETag');
check((await request('/remote-secure.txt',{webPort:dp,method:'PUT',body:'stale',headers:{...dh,'If-Match':'"stale"'}})).status===412,'stale ETag rejects overwrite');
const locked=await request('/remote-secure.txt',{webPort:dp,method:'LOCK',body:'<lockinfo xmlns="DAV:"><lockscope><exclusive/></lockscope><locktype><write/></locktype></lockinfo>',headers:{...dh,Depth:'0','Content-Type':'application/xml'}});
check(locked.status===200&&!!locked.headers['lock-token'],'DAV LOCK issues lock token');
check((await request('/remote-secure.txt',{webPort:dp,method:'PUT',body:'blocked',headers:dh})).status===423,'lock blocks conflicting write');
const lt=locked.headers['lock-token'];
check((await request('/remote-secure.txt',{webPort:dp,method:'PUT',body:'updated',headers:{...dh,If:`(${lt})`,'If-Match':file.headers.etag}})).status===204,'lock owner writes with matching ETag');
check((await request('/remote-secure.txt',{webPort:dp,method:'UNLOCK',headers:{...dh,'Lock-Token':lt}})).status===204,'DAV UNLOCK releases lock');
check((await request('/remote-secure.txt',{webPort:dp,method:'COPY',headers:{...dh,Destination:`http://127.0.0.1:${dp}/remote-copy.txt`}})).status===201,'DAV COPY honors HTTP destination');
await command('lock');
check((await request('/api/v1/events',{cookie:wc})).status===423,'will-lock notification blocks private data immediately');
check((await request('/api/v1/status',{cookie:wc})).status===200,'locked state remains observable to authorized client');
check((await request('/remote-secure.txt',{webPort:dp,headers:dh})).status===423,'will-lock notification blocks DAV data');
await command('unlock');check((await request('/remote-secure.txt',{webPort:dp,headers:dh})).data.toString()==='updated','unlock restores file access');
for(const name of ['remote-secure.txt','remote-copy.txt'])check((await request('/'+name,{webPort:dp,method:'DELETE',headers:dh})).status===204,'DAV DELETE test file '+name);
await command('background');await command('expire');await wait(()=>state().lifecycle==='background_audio');check(state().davState==='running','DAV shares Remote audio lease after expiry');
await command('foreground');await wait(()=>state().davState==='running');check((await request('/',{webPort:dp,method:'OPTIONS',headers:dh})).status===200,'DAV resumes with same credential');
await command('dav_stop');await wait(()=>state().davState==='stopped');
// Actual iOS app-switch lifecycle (in addition to deterministic expiry callback above).
execFileSync('xcrun',['simctl','launch','booted','com.apple.Preferences']);await delay(1200);check((await request('/health')).status===200,'actual app switch keeps service during background grace');
execFileSync('xcrun',['simctl','launch','booted','com.xuegao.theosmobilecompiler']);await wait(()=>state().lifecycle==='foreground');check((await request('/health')).status===200,'actual foreground returns service online');
console.log(`TOTAL ${count} HTTP simulator checks passed`);
