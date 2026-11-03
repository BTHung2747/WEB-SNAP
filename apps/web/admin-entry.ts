import {readFile} from 'node:fs/promises';
import path from 'node:path';
import type {Plugin} from 'vite';
export function requireAdminPath(value: string | undefined) {
  if (!value || value !== value.trim() || !/^\/[a-z][a-z0-9-]{19,63}$/.test(value) || /^\/(admin|api|assets|brand|privacy|terms|report|ung-ho|gop-y)(-|$)/.test(value)) throw new Error('ADMIN_PATH_INVALID');
  return value;
}
export function privateAdminEntry(): Plugin {
  return {name:'wed-private-admin-entry', configurePreviewServer(server) {
    const entry=requireAdminPath(process.env.ADMIN_PATH);
    const file=path.resolve(server.config.root,server.config.build.outDir,'admin.html');
    server.middlewares.use(async (req,res,next)=>{
      let decoded: string;
      try {decoded=decodeURIComponent(new URL(req.url||'/', 'http://local.invalid').pathname);} catch {res.statusCode=404;res.end();return;}
      if (/^\/admin(?:\/|\.html(?:\/|$)|$)/i.test(decoded)) {res.statusCode=404;res.end();return;}
      if(decoded.startsWith(entry+'/')) {res.statusCode=404;res.end();return;}
      if(decoded!==entry) {next();return;}
      res.setHeader('Cache-Control','no-store');res.setHeader('X-Robots-Tag','noindex, nofollow');
      if(!['GET','HEAD'].includes(req.method||'')){res.statusCode=405;res.end();return;}
      try {const html=await readFile(file);res.setHeader('Content-Type','text/html; charset=utf-8');res.end(req.method==='HEAD'?undefined:html);} catch {res.statusCode=404;res.end();}
    });
  }};
}
