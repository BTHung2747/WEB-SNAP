// Preview only: read-only static files bound to loopback, no app/backend access.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = __dirname;
const evidence = path.resolve(root, '../../docs/evidence/ui-redesign-v1-20261015');
const types = { '.html':'text/html; charset=utf-8', '.css':'text/css; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.jpg':'image/jpeg', '.svg':'image/svg+xml', '.md':'text/plain; charset=utf-8' };
const server = http.createServer((request, response) => {
  if (!['GET','HEAD'].includes(request.method)) { response.writeHead(405); response.end(); return; }
  let name;
  try { name = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname); } catch { response.writeHead(400); response.end(); return; }
  const directory = name.startsWith('/evidence/') ? evidence : root;
  if (directory === evidence) name = name.slice('/evidence'.length);
  let target = path.resolve(directory, '.' + name);
  if (!(target === directory || target.startsWith(directory + path.sep))) { response.writeHead(403); response.end(); return; }
  if (name.endsWith('/')) target = path.join(target, 'index.html');
  fs.stat(target, (error, stat) => {
    if (error || !stat.isFile() || !types[path.extname(target)]) { response.writeHead(404); response.end(); return; }
    response.writeHead(200, { 'Content-Type':types[path.extname(target)], 'Content-Length':stat.size, 'Cache-Control':'no-store', 'X-Content-Type-Options':'nosniff' });
    if (request.method === 'HEAD') { response.end(); return; }
    fs.createReadStream(target).pipe(response);
  });
});
server.listen(4318, '127.0.0.1', () => console.log('WED SNAP concept preview: http://127.0.0.1:4318/'));
process.on('SIGINT', () => server.close(() => process.exit(0)));
