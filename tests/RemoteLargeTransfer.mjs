// Real >128MiB upload/download through the simulator. No mocked API responses.
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
const docs=path.join(execFileSync('xcrun',['simctl','get_app_container','booted','com.xuegao.theosmobilecompiler','data'],{encoding:'utf8'}).trim(),'Documents');
const state=()=>JSON.parse(fs.readFileSync(path.join(docs,'RemoteTestState.json'))),sleep=ms=>new Promise(r=>setTimeout(r,ms));let checks=0;
const check=(v,n)=>{if(!v)throw Error(n);console.log('PASS '+n);checks++;};
const port=state().port,origin=`http://127.0.0.1:${port}`;
async function request(url,{body,cookie,csrf,method='POST',stream=false}={}){return new Promise((resolve,reject)=>{const raw=body===undefined?undefined:JSON.stringify(body);const q=http.request({host:'127.0.0.1',port,path:url,method,agent:false,headers:{Host:`127.0.0.1:${port}`,Origin:origin,...raw?{'Content-Type':'application/json','Content-Length':Buffer.byteLength(raw)}:{},...cookie?{Cookie:cookie}:{},...csrf?{'X-Dylix-CSRF':csrf}:{}}},r=>{if(stream){resolve(r);return;}let parts=[];r.on('data',p=>parts.push(p));r.on('end',()=>{const raw=Buffer.concat(parts).toString();let json;try{json=JSON.parse(raw);}catch{}resolve({status:r.statusCode,headers:r.headers,json});});r.on('error',reject);});q.on('error',reject);q.end(raw);});}
fs.writeFileSync(path.join(docs,'RemoteTestCommand.json'),JSON.stringify({action:'rotate'}));await sleep(700);
const pair=await request('/api/v1/pair',{body:{code:state().code,name:'Large-transfer regression',workspace:true}});const cookie=pair.headers['set-cookie'][0].split(';')[0],status=await request('/api/v1/status',{cookie,method:'GET'}),csrf=status.json.session.csrf;
async function job(action,args={},accept=true){let {json}=await request('/api/v1/workspace',{body:{action,arguments:args},cookie,csrf});let j=json.data;for(let n=0;n<30000;n++){if(j.state==='completed')return j.result;if(j.state==='failed'||j.state==='cancelled'||j.error)throw Error(JSON.stringify(j));if(j.state==='awaiting_confirmation')({json}=await request('/api/v1/jobs/confirm',{body:{id:j.id,nonce:j.nonce,accepted:accept},cookie,csrf}));else{await sleep(10);({json}=await request('/api/v1/jobs/get',{body:{id:j.id},cookie,csrf}));}j=json.data;}throw Error('job timeout');}
const name='large157-transfer.zip',target=path.join(docs,name);try{fs.unlinkSync(target);}catch{}
const chunk=Buffer.alloc(512*1024);for(let n=0;n<chunk.length;n++)chunk[n]=(n*31+17)&255;
let inputID;const expected=crypto.createHash('sha256');const total=130*1024*1024+123;
for(let offset=0;offset<total;offset+=chunk.length){const data=chunk.subarray(0,Math.min(chunk.length,total-offset));expected.update(data);const r=await job('input_chunk',{inputID,offset,name,data:data.toString('base64')});inputID=r.inputID;if(offset%(32*1024*1024)===0)console.log('UPLOAD '+Math.round(offset/1024/1024)+' MiB');}
check((await job('sandbox_upload_probe',{path:name})).sha256==='missing','new large upload preflight');
await job('sandbox_upload',{path:name,inputID,sha256:'missing'});
check(fs.statSync(target).size===total,'130MiB upload commits beyond both previous ceilings');
const probe=await job('sandbox_upload_probe',{path:name});const digest=expected.digest('hex');check(probe.sha256===digest,'large preflight hashes incrementally and exactly');
const dl=await job('sandbox_download',{path:name});const head=await request(dl.url,{cookie,method:'HEAD'});check(head.status===200&&head.headers['content-length']===String(total),'HEAD reports actual large file length');
const response=await request(dl.url,{cookie,method:'GET',stream:true});const actual=crypto.createHash('sha256');let received=0;for await(const part of response){received+=part.length;actual.update(part);}check(received===total&&actual.digest('hex')===digest,'streamed download over128MiB matches complete original bytes');
const replacement=await job('input_chunk',{offset:0,name,data:Buffer.from('small replacement').toString('base64')});const replaced=await job('sandbox_upload',{path:name,inputID:replacement.inputID,sha256:probe.sha256});const backup=path.join(docs,'.studio-remote-backups',replaced.backupID);check(fs.statSync(backup).size===total&&fs.readFileSync(target,'utf8')==='small replacement','over64MiB original can be backed up and overwritten');
// Verify Content-Length stays 64-bit without downloading a 4GiB sparse fixture.
const sparseName='large157-sparse.zip',sparse=path.join(docs,sparseName),fd=fs.openSync(sparse,'w');fs.ftruncateSync(fd,2**32+37);fs.closeSync(fd);
const sparseDL=await job('sandbox_download',{path:sparseName});const sparseHead=await request(sparseDL.url,{cookie,method:'HEAD'});check(sparseHead.headers['content-length']===String(2**32+37),'HEAD preserves a file length above4GiB');
const abort=await request(sparseDL.url,{cookie,method:'GET',stream:true});abort.once('data',()=>abort.destroy());await new Promise(resolve=>abort.on('close',resolve));await sleep(100);check((await request('/health',{method:'GET'})).status===200,'aborting large download leaves service available');
for(const p of [target,sparse,backup,backup+'.json'])try{fs.unlinkSync(p);}catch{}
console.log('TOTAL '+checks+' real large-transfer checks passed');
