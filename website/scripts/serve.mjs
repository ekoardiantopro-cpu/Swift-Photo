import http from 'node:http';
import path from 'node:path';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../dist');
const configuration = JSON.parse(await readFile(path.resolve(root, '../firebase.json'), 'utf8'));
const types = {'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.png':'image/png','.txt':'text/plain; charset=utf-8','.xml':'application/xml; charset=utf-8'};
const server = http.createServer(async (request, response) => {
  if (!['GET', 'HEAD'].includes(request.method)) {response.writeHead(405); response.end(); return;}
  try {
    let pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let relative = pathname === '/' ? 'index.html' : pathname.slice(1);
    if (!path.extname(relative)) relative += '.html';
    const destination = path.resolve(root, relative);
    if (!destination.startsWith(root + path.sep)) {response.writeHead(403); response.end(); return;}
    const headers = Object.fromEntries(configuration.hosting.headers[0].headers.map(({key,value})=>[key,value]));
    // Local preview is served over HTTP; HTTPS upgrade is production-only.
    headers['Content-Security-Policy'] = headers['Content-Security-Policy'].replace('; upgrade-insecure-requests', '');
    headers['Cache-Control'] = 'no-store';
    let contents;
    let status = 200;
    try { contents = await readFile(destination); }
    catch { contents = await readFile(path.join(root, '404.html')); status = 404; }
    headers['Content-Type'] = status === 404 ? types['.html'] : types[path.extname(destination)] || 'application/octet-stream';
    response.writeHead(status, headers);
    response.end(request.method === 'HEAD' ? undefined : contents);
  } catch {response.writeHead(400); response.end('Bad request');}
});
const port = Number(process.env.PORT || 4183);
server.listen(port, '127.0.0.1', ()=>console.log(`Swift Photo preview: http://127.0.0.1:${port}`));
for (const signal of ['SIGINT','SIGTERM']) process.on(signal,()=>server.close(()=>process.exit(0)));
