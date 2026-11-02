// Build-time only: reuse React's official renderer, no live server or API calls.
import React from 'react';
import { renderToString, renderToStaticMarkup } from 'react-dom/server';
import { readFile, writeFile } from 'node:fs/promises';
import App from '../src/App';
import { site, publicPages } from '../src/lib/site';

const template = await readFile(new URL('../dist/index.html', import.meta.url), 'utf8');
if (!template.includes('<div id="root"></div>')) throw new Error('PUBLIC_HTML_ROOT');
// Effects never execute during renderToString. Any accidental render-time fetch fails.
globalThis.fetch = () => { throw new Error('BUILD_NETWORK_FORBIDDEN'); };
const pages = [...publicPages, { path: '/admin', title: 'Quản trị | WED SNAP', description: 'Khu vực quản trị WED SNAP.' }];
for (const page of pages) {
  const privatePage = page.path === '/admin';
  const head = renderToStaticMarkup(<>
    <title>{page.title}</title><meta name="description" content={page.description} />
    <meta name="robots" content={privatePage ? 'noindex, nofollow' : 'index, follow'} />
    <link rel="canonical" href={site.origin + page.path} />
    <meta property="og:type" content="website" /><meta property="og:site_name" content={site.name} />
    <meta property="og:title" content={page.title} /><meta property="og:description" content={page.description} />
    <meta property="og:url" content={site.origin + page.path} /><meta property="og:locale" content="vi_VN" />
    <meta property="og:image" content={site.origin + site.image} /><meta property="og:image:width" content="1200" /><meta property="og:image:height" content="630" />
    <meta property="og:image:alt" content="WED SNAP – Lưu nội dung bạn có quyền sử dụng" />
    <meta name="twitter:card" content="summary_large_image" /><meta name="twitter:title" content={page.title} />
    <meta name="twitter:description" content={page.description} /><meta name="twitter:image" content={site.origin + site.image} />
  </>);
  const html = template.replace(/<title>[\s\S]*?<\/title>/, '').replace('</head>', head + '</head>')
    .replace('<div id="root"></div>', `<div id="root">${renderToString(<App pathname={page.path} />)}</div>`);
  const name = page.path === '/' ? 'index' : page.path.slice(1);
  await writeFile(new URL(`../dist/${name}.html`, import.meta.url), html);
}
await writeFile(new URL('../dist/sitemap.xml', import.meta.url), '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + publicPages.map(p => `  <url><loc>${site.origin + p.path}</loc></url>`).join('\n') + '\n</urlset>\n');
console.log('PUBLIC_HTML_READY pages=5 private=1 buildNetwork=0');
