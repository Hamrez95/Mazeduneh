const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(process.argv[2]);
const port = Number(process.argv[3] || 8080);
const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript','.json':'application/json','.css':'text/css','.wasm':'application/wasm','.svg':'image/svg+xml','.png':'image/png','.woff2':'font/woff2','.ttf':'font/ttf','.ico':'image/x-icon'};
http.createServer((req, res) => {
  if (!['GET','HEAD'].includes(req.method)) {res.writeHead(405);res.end();return;}
  let name;
  try { name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); }
  catch {res.writeHead(400);res.end();return;}
  let file = path.resolve(root, '.' + name);
  if (file !== root && !file.startsWith(root + path.sep)) {res.writeHead(403);res.end();return;}
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    if (path.extname(name)) {res.writeHead(404);res.end();return;}
    file = path.join(root, 'index.html');
  }
  res.writeHead(200, {'Content-Type':types[path.extname(file)] || 'application/octet-stream','Cache-Control':'no-store'});
  if(req.method === 'HEAD') res.end(); else fs.createReadStream(file).pipe(res);
}).listen(port, '127.0.0.1', () => console.log(`Admin ready at http://127.0.0.1:${port}`));
