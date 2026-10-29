import { spawn } from 'node:child_process';
import { mkdir, readdir, stat } from 'node:fs/promises';
import { after, AppError, db, filePath, ownerExpired } from '../../../packages/shared/src/core';
import { diskAvailable } from './lifecycle';
import { liveProcesses } from './process-registry';
import { ProcessGroup, ProcessGroupUnconfirmed } from './process-group';
import { photoPostId, photoLimits, requirePhotoEnabled } from '../../../packages/shared/src/tiktok-photo';
import { performance } from 'node:perf_hooks';
import { ProxyPhase, ProxyProofError } from './proxy-phase';
import { videoPostId, videoLimits, requireVideoEnabled } from '../../../packages/shared/src/tiktok-video';
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
  if (photo) { requirePhotoEnabled(l.enabledPlatforms); l = photoLimits(l); }
  if (video) { requireVideoEnabled(l.enabledPlatforms); l = videoLimits(l); }
  const absoluteEnd = performance.now() + (phase === 'analyze' ? l.analyzeTimeout : l.prepareTimeout) * 1000;
  let proxyPhase: ProxyPhase | undefined;
  try { proxyPhase = photo || video ? await ProxyPhase.open(phase, id, token, absoluteEnd) : undefined; }
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
      if (performance.now() >= absoluteEnd) throw new AppError('SOURCE_TIMEOUT');
    } catch (error) { await proxyPhase.abort(); throw error; }
    finally { if (timer) clearTimeout(timer); }
  }
  const childEnv = { ...process.env };
  delete childEnv.TIKTOK_EGRESS_CONTROL_SECRET;
  delete childEnv.WED_EGRESS_PHASE; delete childEnv.WED_EGRESS_CAP;
  if (proxyPhase) Object.assign(childEnv, proxyPhase.childEnv());
  const folder = filePath(id);
  await mkdir(folder, { recursive: true });
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
        stdio: ['ignore', 'pipe', 'ignore'],
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
    let quarantineTimer: NodeJS.Timeout | undefined;
    const quarantine = (message: string) => {
      if (settled) return;
      settled = true;
      proxyPhase?.interrupt(); void proxyPhase?.abort();
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
    child.stdout.on('data', (b: Buffer) => {
      output += b.toString();
      if (Buffer.byteLength(output) > 1024 * 1024) stop('LIMIT_EXCEEDED');
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
        if (stopped || performance.now() >= absoluteEnd) throw new AppError(stopped ? reason : 'SOURCE_TIMEOUT');
        resolve(data);
      } catch (error) {
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
