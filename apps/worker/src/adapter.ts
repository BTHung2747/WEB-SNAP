import { spawn } from 'node:child_process';
import { mkdir, readdir, stat, lstat, unlink, link } from 'node:fs/promises';
import { after, AppError, db, filePath, ownerExpired } from '../../../packages/shared/src/core';
import { diskAvailable } from './lifecycle';
import { liveProcesses } from './process-registry';
import { ProcessGroup, ProcessGroupUnconfirmed } from './process-group';
import { photoPostId, photoLimits, requirePhotoEnabled } from '../../../packages/shared/src/tiktok-photo';
import { performance } from 'node:perf_hooks';
import { ProxyPhase, ProxyProofError, SourceTransfer, previewTransfer } from './proxy-phase';
import { shortTikTok, requireShortEnabled, shortTransfer } from '../../../packages/shared/src/tiktok-short';
import { videoPostId, videoLimits, requireVideoEnabled, videoTransfer } from '../../../packages/shared/src/tiktok-video';
export async function runAdapter(
  id: string,
  phase: string,
  url: string,
  format: string | null,
  l: any,
  token: string,
): Promise<any> {
  const photo = !!photoPostId(url);
  const video = !!videoPostId(url);
  const short = shortTikTok(url);
  if (short) { requireShortEnabled(l.enabledPlatforms); l = videoLimits(l); if (phase !== 'analyze') throw new AppError('FORMAT_UNAVAILABLE'); }
  if (photo) { requirePhotoEnabled(l.enabledPlatforms); l = photoLimits(l); }
  if (video) { requireVideoEnabled(l.enabledPlatforms); l = videoLimits(l); }
  const absoluteEnd = performance.now() + (phase === 'analyze' ? l.analyzeTimeout : l.prepareTimeout) * 1000;
  let transfer: SourceTransfer | undefined;
  if (short) transfer = shortTransfer(short);
  if (video && phase === 'prepare') {
    let timer: NodeJS.Timeout | undefined;
    try {
      const current = await Promise.race([
        db.downloadJob.findUnique({ where: { id }, include: { items: true } }),
        new Promise<never>((_,reject) => { timer = setTimeout(() => reject(new AppError('SOURCE_TIMEOUT')), Math.max(1,Math.min(1000,absoluteEnd-performance.now()))); }),
      ]);
      if (!current || current.workerToken !== token || current.cancelRequested || ownerExpired(current) ||
          current.state !== 'preparing' || current.sourceUrl !== url || current.formatId !== format) throw new AppError('JOB_EXPIRED');
      transfer = videoTransfer(current.items,format || '',videoPostId(url)!);
    } finally { if (timer) clearTimeout(timer); }
  }
  let proxyPhase: ProxyPhase | undefined;
  try { proxyPhase = photo || video || short ? await ProxyPhase.open(phase, id, token, absoluteEnd, transfer) : undefined; }
  catch (error) {
    console.log(JSON.stringify({ event: 'proxy_phase_gate', id, phase, accepted: false, code: error instanceof ProxyProofError ? error.reason : 'CHANNEL' }));
    throw error instanceof AppError ? error : new AppError('CONTENT_UNAVAILABLE');
  }
  if (proxyPhase) {
    let timer: NodeJS.Timeout | undefined;
    try {
      const current = await Promise.race([
        db.downloadJob.findUnique({ where: { id } }),
        new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new AppError('SOURCE_TIMEOUT')), Math.max(1, Math.min(1000, absoluteEnd - performance.now()))); }),
      ]);
      if (!current || current.cancelRequested || ownerExpired(current) || current.workerToken !== token) throw new AppError('JOB_EXPIRED');
      if (short && (current.sourceUrl !== url || current.state !== 'analyzing')) throw new AppError('JOB_EXPIRED');
      if (performance.now() >= absoluteEnd) throw new AppError('SOURCE_TIMEOUT');
    } catch (error) { await proxyPhase.abort(); throw error; }
    finally { if (timer) clearTimeout(timer); }
  }
  const childEnv = { ...process.env };
  delete childEnv.TIKTOK_EGRESS_CONTROL_SECRET;
  delete childEnv.WED_EGRESS_PHASE; delete childEnv.WED_EGRESS_CAP;
  delete childEnv.WED_MEDIA_PROFILE; delete childEnv.WED_MEDIA_SELECTION;
  delete childEnv.WED_PREVIEW_REQUEST;
  if (proxyPhase) Object.assign(childEnv, proxyPhase.childEnv());
  const folder = filePath(id);
  await mkdir(folder, { recursive: true });
  const cacheName=(name: string)=> /^(previews(?:\.pending)?\.json|preview-input\.part|preview-(?:video|ttp1_[0-9]{2}_[a-f0-9]{64})\.jpg)$/.test(name);
  // A new analyze alone may create this optional cache. Never remove an earlier
  // invocation's files. Prepare only reads the immutable accepted index.
  const previews = phase==='analyze' && !!proxyPhase && process.env.TIKTOK_PREVIEW_ENABLED==='1' && !(await readdir(folder)).some(cacheName);
  if (previews) childEnv.WED_PREVIEW_REQUEST='1';
  const discardPreviews=async()=>{
    if (!previews) return;
    for(const name of (await readdir(folder)).filter(cacheName)) {
      const path=filePath(`${id}/${name}`),s=await lstat(path);
      if(s.isFile()&&!s.isSymbolicLink()) await unlink(path);
    }
  };
  if (performance.now() >= absoluteEnd) { await proxyPhase?.abort(); throw new AppError('SOURCE_TIMEOUT'); }
  return new Promise((resolve, reject) => {
    liveProcesses.add(token);
    const child = spawn(
      'python3',
      ['/app/infra/media_adapter.py', phase, url, folder, ...(format ? [format] : [])],
      {
        detached: true,
        shell: false,
        env: {
          ...childEnv,
          ADAPTER_MAX_INPUT: String(l.maxInputBytes),
          ADAPTER_MAX_OUTPUT: String(l.maxBytes),
          ADAPTER_MAX_DURATION: String(l.maxDuration),
          ADAPTER_ANALYZE_TIMEOUT: String(l.analyzeTimeout),
          ADAPTER_PREPARE_TIMEOUT: String(l.prepareTimeout),
        },
        stdio: [previews ? 'pipe' : 'ignore', 'pipe', 'ignore'],
      },
    );
    const group = child.pid ? new ProcessGroup(child.pid) : undefined;
    let output = '';
    let stopped = false;
    let reason = 'CONTENT_UNAVAILABLE';
    let polling = false;
    let stopAt = 0;
    let signalFailure = false;
    let settled = false;
    let groupStopped = false;
    let optionalPhase: ProxyPhase | undefined, optionalOpening: Promise<void> | undefined;
    let optionalRequested=false, optionalAccepted=false, lines='';
    const abortOptional=async()=>{await optionalOpening;await optionalPhase?.abort();};
    const previewRequest=(line: string)=>{
      let packet: any;try { packet=JSON.parse(line); } catch { return; }
      if(!packet || !Object.prototype.hasOwnProperty.call(packet,'_preview')) return;
      if(optionalRequested) { child.stdin?.end(); return; }
      optionalRequested=true;
      optionalOpening=(async()=>{
        try {
          const p=packet._preview;
          if(!previews || Object.keys(packet).length!==1 || !p || Object.keys(p).join()!=='count' ||
             !Number.isSafeInteger(p.count)||p.count<1||p.count>50||(video&&p.count!==1)||stopped || settled || absoluteEnd-performance.now()<9000) throw new Error('PREVIEW_REQUEST');
          // Its own expiry includes fetch/normalization + closure and precedes
          // the mandatory metadata deadline. An optional proof timeout must not
          // spend the final metadata second and turn a valid analyze into FAIL.
          const optionalEnd=Math.min(absoluteEnd-1000,performance.now()+8000);
          optionalPhase=await ProxyPhase.open('analyze',id,token,optionalEnd,previewTransfer(url,p.count));
          if(stopped||settled) { await optionalPhase.abort(); return; }
          const env=optionalPhase.childEnv();
          child.stdin?.end(JSON.stringify({phase:env.WED_EGRESS_PHASE,cap:env.WED_EGRESS_CAP,seconds:Math.min(30,(optionalEnd-performance.now())/1000)})+'\n');
        } catch { child.stdin?.end('{}\n'); }
      })();
    };
    child.stdin?.on('error',()=>{}); // A child may finish before optional grant; no retry.
    let quarantineTimer: NodeJS.Timeout | undefined;
    const quarantine = (message: string) => {
      if (settled) return;
      settled = true;
      proxyPhase?.interrupt(); void proxyPhase?.abort();
      optionalPhase?.interrupt(); void abortOptional();
      clearTimeout(deadline); clearInterval(poll);
      if (killTimer) clearTimeout(killTimer);
      if (quarantineTimer) clearTimeout(quarantineTimer);
      reject(new ProcessGroupUnconfirmed(message, stopped ? reason : 'WORKER_INTERRUPTED'));
    };
    const signalGroup = async (signal: 'SIGTERM' | 'SIGKILL') => {
      try { await group?.signal(signal); } catch { signalFailure = true; }
    };
    function stop(code: string) {
      if (stopped) return;
      stopped = true;
      reason = code;
      stopAt = Date.now();
      proxyPhase?.interrupt();
      optionalPhase?.interrupt();
      if (groupStopped) return;
      void signalGroup('SIGTERM');
      killTimer = setTimeout(() => {
        void signalGroup('SIGKILL');
      }, 2000);
      quarantineTimer = setTimeout(() => quarantine('Group exit exceeded bound'), 6000);
    }
    let killTimer: NodeJS.Timeout | undefined;
    const deadline = setTimeout(
      () => stop('SOURCE_TIMEOUT'),
      Math.max(1, absoluteEnd - performance.now()),
    );
    child.stdout!.on('data', (b: Buffer) => {
      output += b.toString();
      if (Buffer.byteLength(output) > 1024 * 1024) stop('LIMIT_EXCEEDED');
      if(previews && !optionalRequested) {
        lines+=b.toString();let split;
        while((split=lines.indexOf('\n'))>=0) {const line=lines.slice(0,split);lines=lines.slice(split+1);previewRequest(line);}
      }
    });
    const poll = setInterval(async () => {
      if (polling || stopped) return;
      polling = true;
      try {
        const j = await db.downloadJob.findUnique({ where: { id } });
        if (!j || j.cancelRequested || ownerExpired(j) || j.workerToken !== token) {
          stop('JOB_EXPIRED');
          return;
        }
        if (!(await diskAvailable(l.diskStopPercent))) {
          stop('CAPACITY_UNAVAILABLE');
          return;
        }
        const files = await readdir(folder);
        let bytes = 0;
        for (const f of files) {
          const s = await stat(filePath(`${id}/${f}`));
          bytes += s.isFile() ? s.size : 0;
        }
        if (bytes > l.maxInputBytes + l.maxBytes) {
          stop('LIMIT_EXCEEDED');
          return;
        }
        await db.downloadJob.updateMany({
          where: { id, workerToken: token },
          data: { processUntil: after(15) },
        });
      } catch {
        stop('WORKER_INTERRUPTED');
      } finally {
        polling = false;
      }
    }, 1000);
    child.on('error', () => stop('WORKER_INTERRUPTED'));
    child.on('close', async (code, signal) => {
      if (settled) return;
      try {
        const members = group?.members() || [];
        console.log(JSON.stringify({ event: 'adapter_parent_closed', id, phase, actualExit: code, actualSignal: signal, groupLive: members.length, registryProtected: liveProcesses.has(token) }));
        if (members.length && !stopped) stop('WORKER_INTERRUPTED');
        // close only confirms the parent's stdio. DEVNULL descendants can outlive it.
        while (group?.members().length) {
          if (Date.now() > stopAt + 6000) throw new ProcessGroupUnconfirmed('Group did not stop within bound');
          await new Promise(resolve => setTimeout(resolve, 20));
        }
      } catch {
        // Fail closed: processor must retain its token/lease/media protection.
        quarantine(signalFailure ? 'Group signal/identity failed' : 'Group exit unconfirmed');
        return;
      }
      if (settled) return;
      groupStopped = true;
      try {
        if (stopped) throw new AppError(reason);
        const data = JSON.parse(output.trim().split('\n').at(-1)!);
        if (code !== 0 || data.error) throw new AppError(data.error || 'CONTENT_UNAVAILABLE');
        if (proxyPhase) {
          const connections = await proxyPhase.finish(() => stopped);
          console.log(JSON.stringify({ event: 'proxy_phase_gate', id, phase, accepted: true, connections }));
        }
        if(previews) {
          try {
            await optionalOpening;
            if(optionalPhase && !stopped && performance.now()<absoluteEnd) {
              const connections=await optionalPhase.finish(()=>stopped);
              // No-overwrite publication only after native exit0/group reap and
              // the independent preview proof. Public API never reads pending.
              const pending=filePath(`${id}/previews.pending.json`),s=await lstat(pending);
              if(!s.isFile()||s.isSymbolicLink()) throw new Error('PREVIEW_INDEX');
              await link(pending,filePath(`${id}/previews.json`));await unlink(pending);
              optionalAccepted=true;
              console.log(JSON.stringify({event:'preview_phase_gate',id,accepted:true,connections}));
            }
          } catch { /* Optional rejection preserves valid metadata, never proof bypass. */ }
          finally {
            if(!optionalAccepted) {await abortOptional();await discardPreviews();console.log(JSON.stringify({event:'preview_phase_gate',id,accepted:false}));}
          }
        }
        if (stopped || performance.now() >= absoluteEnd) throw new AppError(stopped ? reason : 'SOURCE_TIMEOUT');
        resolve(data);
      } catch (error) {
        await abortOptional();await discardPreviews();
        if (proxyPhase) {
          await proxyPhase.abort();
          console.log(JSON.stringify({ event: 'proxy_phase_gate', id, phase, accepted: false, code: error instanceof ProxyProofError ? error.reason : stopped ? reason : 'NATIVE' }));
        }
        reject(new AppError(stopped ? reason : error instanceof AppError ? error.code : 'CONTENT_UNAVAILABLE'));
      } finally {
        settled = true; clearTimeout(deadline); clearInterval(poll);
        if (killTimer) clearTimeout(killTimer);
        if (quarantineTimer) clearTimeout(quarantineTimer);
        liveProcesses.delete(token);
        console.log(JSON.stringify({ event: 'adapter_group_stopped', id, phase, groupLive: 0, registryProtected: liveProcesses.has(token) }));
      }
    });
  });
}
