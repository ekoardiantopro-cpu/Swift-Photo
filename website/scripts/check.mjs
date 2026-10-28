import {readdir, readFile, stat} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../dist');
const errors = [];
const files = (await readdir(root)).filter(name=>name.endsWith('.html'));
for (const name of files) {
  const html = await readFile(path.join(root,name),'utf8');
  if (!html.includes('<html lang="id">') || !html.includes('<main') || !html.includes('name="viewport"')) errors.push(`${name}: missing document structure`);
  if ((html.match(/<h1[ >]/g)||[]).length !== 1) errors.push(`${name}: exactly one h1 required`);
  const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);
  if (ids.length !== new Set(ids).size) errors.push(`${name}: duplicate ID`);
  if (/YOUR_|REPLACE_ME|TODO|lorem ipsum|example\.com/i.test(html)) errors.push(`${name}: placeholder content`);
  if (!html.includes('href="/privacy"') || !html.includes('href="/terms"')) errors.push(`${name}: missing legal navigation`);
  for (const [,value] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (!value.startsWith('/') && !value.startsWith('#')) continue;
    const [href, hash] = value.split('#');
    let destination = href ? href === '/' ? 'index.html' : href.slice(1) : name;
    if (!path.extname(destination)) destination += '.html';
    try {
      await stat(path.join(root,destination));
      if (hash && path.extname(destination) === '.html') {
        const target = await readFile(path.join(root,destination),'utf8');
        if (!target.includes(`id="${hash}"`)) errors.push(`${name}: missing anchor ${value}`);
      }
    } catch {errors.push(`${name}: broken link ${value}`);}
  }
}
const assets = await readdir(path.join(root,'assets'));
if (assets.some(name=>!['logo.png','site.js','styles.css'].includes(name))) errors.push('Unexpected public assets');
const privacy = await readFile(path.join(root,'privacy.html'),'utf8');
for (const term of ['drive.file','Limited Use','Google API Services User Data Policy','ekoardianto.pro@gmail.com','089633427198','menghapus']) {
  if (!privacy.includes(term)) errors.push(`Privacy disclosure missing: ${term}`);
}
if (errors.length) {console.error(errors.join('\n')); process.exit(1);}
console.log(`Checked ${files.length} pages: local links, anchors, legal navigation, contact and Google data disclosures passed.`);
