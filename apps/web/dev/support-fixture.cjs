// Disposable frontend fixture, not backend/persistence/image-validation proof.
// Only loopback; never calls a source, bank or external API. All state is in memory.
const http = require('node:http'), fs = require('node:fs'), path = require('node:path');
const { createHash } = require('node:crypto');
const build = path.resolve(process.env.UI_PREVIEW_ROOT);
const out = path.dirname(build), port = Number(process.env.UI_PREVIEW_PORT || 5201);
const image = process.env.UI_SUPPORT_TEST_IMAGE ? fs.readFileSync(process.env.UI_SUPPORT_TEST_IMAGE) : null;
const imageId = image ? createHash('sha256').update(image).digest('hex') : null;
const defaults = { enabled:false, title:'Ủng hộ WED SNAP', message:'WED SNAP hiện chưa có quảng cáo. Nếu thấy công cụ hữu ích, bạn có thể ủng hộ một khoản nhỏ để giúp mình duy trì máy chủ và tiếp tục phát triển. Mọi sự ủng hộ đều tự nguyện. Cảm ơn bạn!', bankName:'', accountName:'', accountNumber:'', transferNote:'' };
let config = { ...defaults }, savedQr = null, pending = null, logged = true;
const adminData = () => ({ ...config, qrUrl:(pending ? pending.qr : savedQr) ? `/api/v1/admin/support/qr/${pending ? pending.qr : savedQr}` : null, qrPending:pending !== null });
http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${port}`);
  const ref = new URL(req.headers.referer || `http://127.0.0.1:${port}`);
  const scenario = ref.searchParams.get('fixture');
  const p = url.pathname.replace('/api/v1/', '');
  const reply = (data, status = 200, meta = {}) => {
    // Metadata only; no account/text/filename/binary logging.
    fs.appendFileSync(path.join(out, 'fixture-requests.jsonl'), JSON.stringify({ method:req.method, path:url.pathname, status, ...meta }) + '\n');
    res.writeHead(status, {'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-wed-preview':'support-fixture-only'});
    res.end(JSON.stringify(status >= 400 ? {error:data} : data));
  };
  if (url.pathname.startsWith('/api/')) {
    if (p === 'session') return reply({ productName:'WED SNAP', csrf:'fixture-only', supported:[], contact:null, heartbeatSeconds:15, capabilities:{tiktokPhoto:false} });
    if (p === 'admin/login' && req.method === 'POST') { logged = true; return reply({ok:true}); }
    if (p.startsWith('admin/') && !logged) return reply({code:'ADMIN_REQUIRED'},403);
    if (p === 'admin/support' && req.method === 'GET' && scenario === 'auth') return reply({code:'ADMIN_REQUIRED'},403);
    if (p === 'admin/logout') { logged = false; return reply({ok:true}); }
    if (p === 'admin/dashboard') return reply({groups:[],queue:{waiting:0,active:0},budget:[],failed:[],verified:[]});
    if (p === 'admin/settings') return reply({enabledPlatforms:[]});
    if (p === 'admin/campaigns') return reply([]);
    if (p === 'admin/ad-statistics') return reply({window:{from:'2026-10-24T00:00:00Z',to:'2026-10-31T00:00:00Z',timezone:'UTC'},rows:[]});
    if (p === 'support') {
      if (scenario === 'error') return reply({code:'INTERNAL_ERROR'},503);
      if (scenario === 'empty') return reply({...defaults,enabled:true});
      if (scenario === 'slow') await new Promise(resolve => setTimeout(resolve,1500));
      return reply(config.enabled ? {...config,qrUrl:savedQr ? `/api/v1/support/qr/${savedQr}` : null} : {enabled:false});
    }
    if (/^(admin\/)?support\/qr\/[a-f0-9]{64}$/.test(p)) {
      const id = p.split('/').pop(), active = p.startsWith('admin/') ? (pending ? pending.qr : savedQr) : (config.enabled ? savedQr : null);
      if (!image || id !== active || scenario === 'broken-image') { res.writeHead(404).end(); return; }
      res.writeHead(200,{'content-type':'image/png','cache-control':'no-store','x-content-type-options':'nosniff'}); return res.end(image);
    }
    if (p.startsWith('admin/support')) {
      if (scenario === 'csrf') return reply({code:'CSRF_INVALID'},403);
      if (req.method === 'GET' && p === 'admin/support') return reply(adminData());
      if (req.headers['x-csrf-token'] !== 'fixture-only') return reply({code:'CSRF_INVALID'},403);
      if (p === 'admin/support/qr' && req.method === 'POST') {
        let bytes = 0, chunks = [];
        for await (const chunk of req) { bytes += chunk.length; if (bytes > 2162688) return reply({code:'SUPPORT_QR_LIMIT'},413); chunks.push(chunk); }
        // Observe multipart shape, not a general parser or image decoder. Uploaded
        // bytes are discarded; fixture serves only the labelled calibration PNG.
        const raw = Buffer.concat(chunks).toString('latin1');
        const fileParts = (raw.match(/name="file"; filename=/g) || []).length;
        const fields = (raw.match(/Content-Disposition: form-data;/g) || []).length;
        const contentType = req.headers['content-type'] || '';
        const multipart = /^multipart\/form-data; boundary=/.test(contentType);
        const meta = {multipart,fileParts,fields,bytes,csrf:true,origin:req.headers.origin === `http://127.0.0.1:${port}`};
        if (scenario === 'upload-error') return reply({code:'SUPPORT_QR_INVALID'},400,meta);
        if (!multipart || fileParts !== 1 || fields !== 1 || !imageId) return reply({code:'INVALID_REQUEST'},400,meta);
        if (scenario === 'slow-upload') await new Promise(resolve => setTimeout(resolve,1500));
        pending = {qr:imageId}; return reply(adminData(),201,meta);
      }
      if (p === 'admin/support/qr' && req.method === 'DELETE') { pending = {qr:null}; return reply(adminData()); }
      if (p === 'admin/support' && req.method === 'PUT') {
        let raw = ''; for await (const chunk of req) raw += chunk;
        let body; try { body = JSON.parse(raw); } catch { return reply({code:'INVALID_REQUEST'},400); }
        const keys = Object.keys(body).sort();
        if (JSON.stringify(keys) !== JSON.stringify(Object.keys(defaults).sort())) return reply({code:'INVALID_REQUEST'},400,{keys});
        const qr = pending ? pending.qr : savedQr;
        if (body.enabled && !qr && !(body.bankName && body.accountName && body.accountNumber)) return reply({code:'SUPPORT_PAYMENT_REQUIRED'},400);
        config = body; savedQr = qr; pending = null; return reply(adminData(),200,{keys,qrPublished:!!qr,enabled:body.enabled});
      }
    }
    return reply({code:'NOT_FOUND'},404);
  }
  let file = path.resolve(build, '.' + url.pathname);
  if (!file.startsWith(build + path.sep) && file !== build) { res.writeHead(403).end(); return; }
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(build, 'index.html');
  fs.readFile(file, (error, bytes) => {
    if (error) { res.writeHead(404).end(); return; }
    const html = file.endsWith('.html');
    if (html) bytes = Buffer.from(bytes.toString().replace('<body>', '<body><aside style="padding:8px 16px;background:#252a2e;color:#fff;font:12px/1.6 Segoe UI,sans-serif;text-align:center">BẢN KIỂM TRA UI · Dữ liệu giả lập trong RAM · Ảnh kiểm tra không phải QR nhận tiền · Không gọi ngân hàng/nguồn thật</aside>'));
    res.writeHead(200, {'content-type':html ? 'text/html; charset=utf-8' : file.endsWith('.js') ? 'application/javascript' : 'text/css','cache-control':'no-store'}); res.end(bytes);
  });
}).listen(port, '127.0.0.1', () => console.log(`SUPPORT_UI_FIXTURE_ONLY http://127.0.0.1:${port}`));
