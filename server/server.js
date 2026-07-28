import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import Database from 'better-sqlite3';
import { customAlphabet } from 'nanoid';
import crypto from 'crypto';
const app=express(), db=new Database(process.env.DB||'licenses.sqlite');
const nano=customAlphabet('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',32);
app.use(helmet()); app.use(cors()); app.use(express.json({limit:'1mb'}));
db.exec(`CREATE TABLE IF NOT EXISTS licenses(id TEXT PRIMARY KEY, customer TEXT, createdAt TEXT, activatedAt TEXT, lastCheck TEXT, deviceId TEXT, appVersion TEXT, status TEXT NOT NULL DEFAULT 'inactive');
CREATE TABLE IF NOT EXISTS logs(id TEXT PRIMARY KEY, type TEXT, date TEXT, payload TEXT);`);
function log(type,payload){db.prepare('INSERT INTO logs VALUES(?,?,?,?)').run(crypto.randomUUID(),type,new Date().toISOString(),JSON.stringify(payload||{}));}
function lic(id){return db.prepare('SELECT * FROM licenses WHERE id=?').get(id)}
app.post('/api/admin/licenses',(req,res)=>{const id='ZAK-'+nano().match(/.{1,4}/g).join('-');const now=new Date().toISOString();db.prepare('INSERT INTO licenses(id,customer,createdAt,appVersion,status) VALUES(?,?,?,?,?)').run(id,req.body.customer||'',now,req.body.appVersion||'1.0.0','inactive');log('LICENSE_CREATED',{id});res.json(lic(id));});
app.post('/api/admin/licenses/batch',(req,res)=>{const n=Math.max(1,Math.min(50,Number(req.body.count)||1));const out=[];for(let i=0;i<n;i++){const r=app._router.handle?null:null;const id='ZAK-'+nano().match(/.{1,4}/g).join('-'),now=new Date().toISOString();db.prepare('INSERT INTO licenses(id,customer,createdAt,appVersion,status) VALUES(?,?,?,?,?)').run(id,req.body.customerPrefix?req.body.customerPrefix+' '+(i+1):'',now,req.body.appVersion||'1.0.0','inactive');out.push(lic(id));}log('LICENSE_BATCH',{count:n});res.json(out);});
app.get('/api/admin/licenses',(req,res)=>res.json(db.prepare('SELECT * FROM licenses ORDER BY createdAt DESC').all()));
app.patch('/api/admin/licenses/:id',(req,res)=>{const old=lic(req.params.id);if(!old)return res.status(404).json({error:'not_found'});const next={...old,...req.body};db.prepare('UPDATE licenses SET customer=?,activatedAt=?,lastCheck=?,deviceId=?,appVersion=?,status=? WHERE id=?').run(next.customer,next.activatedAt,next.lastCheck,next.deviceId,next.appVersion,next.status,req.params.id);log('LICENSE_UPDATED',{id:req.params.id,patch:req.body});res.json(lic(req.params.id));});
app.delete('/api/admin/licenses/:id',(req,res)=>{db.prepare('DELETE FROM licenses WHERE id=?').run(req.params.id);log('LICENSE_DELETED',{id:req.params.id});res.json({ok:true});});
app.post('/api/activate',(req,res)=>{const {licenseId,deviceId,appVersion}=req.body;const l=lic(licenseId); if(!l)return res.status(404).json({ok:false,error:'invalid_license'}); if(['revoked','expired'].includes(l.status))return res.status(403).json({ok:false,error:l.status}); if(l.deviceId&&l.deviceId!==deviceId)return res.status(409).json({ok:false,error:'device_already_bound'});const now=new Date().toISOString();db.prepare('UPDATE licenses SET activatedAt=COALESCE(activatedAt,?),lastCheck=?,deviceId=?,appVersion=?,status=? WHERE id=?').run(now,now,deviceId,appVersion||l.appVersion,'active',licenseId);log('LICENSE_ACTIVATED',{licenseId,deviceId});res.json({ok:true,license:lic(licenseId)});});
app.post('/api/check',(req,res)=>{const {licenseId,deviceId}=req.body;const l=lic(licenseId); if(!l)return res.status(404).json({ok:false,error:'invalid_license'}); if(l.deviceId!==deviceId)return res.status(409).json({ok:false,error:'device_mismatch'}); if(l.status!=='active')return res.status(403).json({ok:false,error:l.status});db.prepare('UPDATE licenses SET lastCheck=? WHERE id=?').run(new Date().toISOString(),licenseId);res.json({ok:true,status:'active'});});
app.post('/api/admin/revoke',(req,res)=>{db.prepare('UPDATE licenses SET status=? WHERE id=?').run('revoked',req.body.licenseId);log('LICENSE_REVOKED',req.body);res.json({ok:true});});
app.post('/api/admin/reset-device',(req,res)=>{db.prepare('UPDATE licenses SET deviceId=NULL,activatedAt=NULL,status=? WHERE id=?').run('inactive',req.body.licenseId);log('DEVICE_RESET',req.body);res.json({ok:true});});
app.get('/api/admin/logs',(req,res)=>res.json(db.prepare('SELECT * FROM logs ORDER BY date DESC LIMIT 500').all()));
app.listen(process.env.PORT||3000,()=>console.log('license server ready'));
