import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync,readdirSync} from 'node:fs';
import {requireAdminPath} from '../apps/web/admin-entry';
import React from 'react';
import {renderToString} from 'react-dom/server';
import App from '../apps/web/src/App';
const fixture='/fixture-console-0123456789';
const invalid=[undefined,'','/','/*','/admin','/admin.html','/api','/assets','/gop-y','/admin-01234567890123456789','/fixture-console-0123456789/','/abc/defghijklmnopqrstuvwxyz','/abcdefghijklmnopqrst?x=1','/abcdefghijklmnopqrst\n','/ABCdefghijklmnopqrst'];
assert.equal(requireAdminPath(fixture),fixture);
for(const pathname of ['/admin','/private-admin','/unknown-admin-entry']) {
 const html=renderToString(React.createElement(App,{pathname}));assert.doesNotMatch(html,/app-admin|admin-login/);assert.match(html,/Không tìm thấy trang/);
}
for(const [index,value] of invalid.entries()){assert.throws(()=>requireAdminPath(value));const r=spawnSync('/bin/sh',['/app/infra/production/web-entrypoint.sh','/bin/true'],{env:{...process.env,ADMIN_PATH:value||''}});assert.equal(r.status,20,JSON.stringify({index,stderr:r.stderr.toString().slice(0,200)}));assert.equal(r.stderr.toString().trim(),'ADMIN_PATH_INVALID');}
assert.equal(spawnSync('/bin/sh',['/app/infra/production/web-entrypoint.sh','/bin/true'],{env:{...process.env,ADMIN_PATH:fixture}}).status,0);
const privateHTML=readFileSync('/ui/admin.html','utf8');
assert.match(privateHTML,/<meta name="wed-snap-page" content="admin"/);assert.doesNotMatch(privateHTML,/rel="canonical"|property="og:url"/);
for(const name of readdirSync('/ui').filter(n=>n.endsWith('.html')&&n!=='admin.html'))assert.doesNotMatch(readFileSync('/ui/'+name,'utf8'),/name="wed-snap-page"/);
for(const name of ['robots.txt','sitemap.xml'])assert.doesNotMatch(readFileSync('/ui/'+name,'utf8'),/admin\.html|fixture-console/);
console.log('ADMIN_ENTRY_OFFLINE_PASS policyJS+shell parity, privateSSR marker, publicSSR absence');
