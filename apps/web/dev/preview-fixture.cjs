// Adapted from ui-a-photo-branches-20261016/preview.cjs. Disposable local API only.
// No source requests, credentials, real downloads or persistent admin mutations.
const http = require('node:http'), fs = require('node:fs'), path = require('node:path');
const build = path.resolve(process.env.UI_PREVIEW_ROOT || 'docs/evidence/ui-preview-admin-redesign-20261030/frontend/web');
const out = path.dirname(build), port = Number(process.env.UI_PREVIEW_PORT || 5195);
const suppliedImage = process.env.UI_PREVIEW_IMAGE ? path.resolve(process.env.UI_PREVIEW_IMAGE) : null;
const sample = suppliedImage || (process.env.UI_PREVIEW_CARDS ? path.join(out,'fixture-01.jpg') : path.resolve('design/ui-redesign-v1/assets/sample.jpg'));
const settings = {maxDuration:600,maxBytes:209715200,maxInputBytes:262144000,analyzeTimeout:30,prepareTimeout:180,sessionTtl:120,releaseGrace:30,readyTtl:600,sweepSeconds:30,leaseTtl:90,retryGrace:120,transferMax:1800,monthlyBytes:10737418240,diskStopPercent:80,queueLimit:20,acceptJobs:true,enabledPlatforms:['youtube','tiktok']};
const campaign = {id:'fixture-campaign',title:'Chiến dịch minh họa giao diện',imageUrl:null,targetUrl:'https://example.com/',linkType:'sponsored',placement:'banner',enabled:false,startsAt:'2026-10-30T00:00:00.000Z',endsAt:'2026-11-06T00:00:00.000Z',weight:1};
const jobs = new Map(); let serial = 0;
http.createServer(async (req,res) => {
  const u = new URL(req.url, `http://127.0.0.1:${port}`);
  const ref = new URL(req.headers.referer || `http://127.0.0.1:${port}`);
  let raw = ''; for await (const chunk of req) raw += chunk;
  let body; try { body = raw ? JSON.parse(raw) : null; } catch { res.writeHead(400).end(); return; }
  const json = (data,status=200) => {
    fs.appendFileSync(path.join(out,'requests.jsonl'),JSON.stringify({time:new Date().toISOString(),method:req.method,path:u.pathname,body,status})+'\n');
    res.writeHead(status,{'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-wed-preview':'fixture-only'});
    res.end(JSON.stringify(status>=400?{error:data}:data));
  };
  if (u.pathname.startsWith('/api/')) {
    const p = u.pathname.replace('/api/v1/','');
    if (p === 'session') return json({productName:'WED SNAP',csrf:'fixture-only',supported:['youtube','tiktok'],contact:null,heartbeatSeconds:15,capabilities:{tiktokPhoto:ref.searchParams.get('cap')!=='false'}});
    if (p.startsWith('ads')) return json(null);
    if (p.startsWith('admin/')) {
      if (ref.searchParams.get('preview') === 'login') return json({code:'ADMIN_REQUIRED'},403);
      if (req.method !== 'GET') return json({code:'FIXTURE_READONLY'},405);
      if (p === 'admin/dashboard') return json({groups:[{state:'ready',_count:3},{state:'selectable',_count:2},{state:'failed',_count:1}],queue:{waiting:0,active:0},budget:[{month:new Date().toISOString().slice(0,7),charged:41943040}],failed:[{id:'fixture-error',platform:'tiktok',errorCode:'SOURCE_TIMEOUT',updatedAt:'2026-10-30T02:15:00.000Z'}],verified:['youtube','tiktok']});
      if (p === 'admin/settings') return json(settings);
      if (p === 'admin/campaigns') return json([campaign]);
      if (p.startsWith('admin/ad-statistics')) return json({window:{from:'2026-10-23T00:00:00.000Z',to:'2026-10-30T00:00:00.000Z',timezone:'UTC'},rows:[{campaignId:campaign.id,title:campaign.title,impressions:0,clicks:0,ctrPercent:null}]});
    }
    if (p === 'jobs/analyze' && req.method === 'POST') {
      let input; try { input=new URL(body?.url); } catch { return json({code:'FIXTURE_URL_NOT_SIMULATED',message:'Bản minh họa chỉ mô phỏng link TikTok canonical /photo/ hoặc /video/. Không gọi nguồn thật.'},422); }
      const match=/^\/@[^/]+\/(photo|video)\/\d+\/?$/.exec(input.pathname);
      if(input.protocol!=='https:' || !['www.tiktok.com','tiktok.com'].includes(input.hostname) || !match)
        return json({code:'FIXTURE_URL_NOT_SIMULATED',message:'Link này chưa được fixture mô phỏng. Dùng link TikTok canonical /photo/ hoặc /video/; bản local không gọi nguồn thật.'},422);
      const id='fixture-job-'+(++serial), photo=match[1]==='photo';
      const previewUrl = ref.searchParams.has('no-preview') ? null : `/api/v1/jobs/${id}/preview`;
      const dims=[[720,960],[960,720],[800,800],[720,960],[800,800]];
      const formats = photo ? Array.from({length:5},(_,i)=>({id:'ttp1_'+String(i+1).padStart(2,'0')+'_'+'a'.repeat(64),label:`Ảnh ${i+1}/5`,size:null,kind:'photo',imageCount:5,index:i+1,width:process.env.UI_PREVIEW_CARDS?dims[i][0]:2132,height:process.env.UI_PREVIEW_CARDS?dims[i][1]:2132,previewUrl:previewUrl ? previewUrl+'/'+(i===4?'missing':'ttp1_'+String(i+1).padStart(2,'0')+'_'+'a'.repeat(64)):null})) : [{id:'source',label:'MP4 H.264 có tiếng · 1080p',size:null,sourceDefault:true,highest:true},{id:'720',label:'MP4 H.264 có tiếng · 720p',size:null}];
      jobs.set(id,{id,state:ref.searchParams.get('phase')||'selectable',errorCode:ref.searchParams.get('phase')==='failed'?'SOURCE_TIMEOUT':null,title:suppliedImage?'Lights':photo?'Bộ ảnh minh họa giao diện':'Video minh họa giao diện',duration:photo||suppliedImage?null:27,previewUrl:photo?null:previewUrl,items:[{id:'fixture-item',kind:photo?'photo':'video',formats}]});
      return json({jobId:id},202);
    }
    const m = /^jobs\/([^/]+)(?:\/(.*))?$/.exec(p);
    if (m) {
      const job=jobs.get(m[1]); if(!job)return json({code:'JOB_NOT_FOUND'},404);
      if (m[2]?.startsWith('preview')) {
        if(m[2].endsWith('/missing') || ['failed','cancelled','expired'].includes(job.state)) return json({code:'PREVIEW_NOT_FOUND'},404);
        const number=/ttp1_(\d{2})_/.exec(m[2])?.[1] || '01';
        const image=process.env.UI_PREVIEW_CARDS?path.join(out,'fixture-'+number+'.jpg'):sample;
        res.writeHead(200,{'content-type':'image/jpeg','cache-control':'private, no-store','x-content-type-options':'nosniff'});return fs.createReadStream(image).pipe(res);
      }
      if(m[2]==='prepare'){
        if(job.state!=='selectable' || !job.items[0].formats.some(f=>f.id===body?.formatId)) return json({code:'FIXTURE_INVALID_SELECTION'},409);
        job.state='ready';job.preparedFormatId=body.formatId;return json({state:'ready'},202);
      }
      if(m[2]==='download-ticket')return json({url:'/api/v1/downloads/fixture-only-'+job.id});
      if(m[2]==='cancel'){job.state='cancelled';return json({state:'cancelled'});}
      if(m[2])return json({ok:true});return json(job);
    }
    if(p.startsWith('downloads/'))return json({code:'FIXTURE_NO_DOWNLOAD'},410);
    return json({code:'NOT_FOUND'},404);
  }
  let file=path.resolve(build,'.'+u.pathname);
  if(!file.startsWith(build+path.sep) && file!==build){res.writeHead(403).end();return;}
  if(!fs.existsSync(file)||fs.statSync(file).isDirectory())file=path.join(build,'index.html');
  fs.readFile(file,(error,bytes)=>{
    if(error){res.writeHead(404).end();return;}
    const html=file.endsWith('.html');
    if(html)bytes=Buffer.from(bytes.toString().replace('<body>',`<body><aside style="padding:8px 16px;background:#29241f;color:#fffefa;font:12px/1.5 Segoe UI,sans-serif;text-align:center">BẢN KIỂM TRA CỤC BỘ · ${suppliedImage?'Ảnh Lights đã tải trước đó được lặp để minh họa các lựa chọn, ảnh cuối kiểm fallback':'API/ảnh calibration minh họa'} · Không tải tệp thật, không gọi nguồn mới · Chỉ mô phỏng link TikTok /photo/ và /video/</aside>`));
    res.writeHead(200,{'content-type':html?'text/html; charset=utf-8':file.endsWith('.js')?'application/javascript':'text/css','cache-control':'no-store'});res.end(bytes);
  });
}).listen(port,'127.0.0.1',()=>console.log(`UI_FIXTURE_ONLY http://127.0.0.1:${port}`));
