const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
const root='/web';
http.createServer((req,res)=>{
 const name=new URL(req.url,'http://fixture.invalid').pathname;
 if(name==='/native-image.jpg'){res.writeHead(200,{'content-type':'image/jpeg','content-disposition':'attachment; filename="wed-snap-image.jpg"'});fs.createReadStream('/input.jpg').pipe(res);return;}
 const p=path.resolve(root,'.'+(name==='/'?'/index.html':name));
 if(!p.startsWith(root+'/')){res.writeHead(403).end();return;}
 fs.readFile(p,(e,b)=>{if(e){res.writeHead(404).end();return;}res.writeHead(200,{'content-type':p.endsWith('.js')?'application/javascript':p.endsWith('.css')?'text/css':'text/html','cache-control':'no-store'});res.end(b);});
}).listen(5196,'0.0.0.0');
