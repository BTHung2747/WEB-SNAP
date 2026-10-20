import { execFile } from 'node:child_process';
import { readFileSync, readdirSync, readlinkSync } from 'node:fs';
import { promisify } from 'node:util';

type Member = { pid: number; ticks: string; pgid: number; sid: number; state: string };
export class ProcessGroupUnconfirmed extends Error {
  constructor(message: string, readonly code = 'WORKER_INTERRUPTED') { super(message); }
}
function member(pid: number): Member | undefined {
  try {
    const parts = readFileSync(`/proc/${pid}/stat`, 'utf8').split(') ').at(-1)!.split(' ');
    return { pid, state: parts[0], pgid: Number(parts[2]), sid: Number(parts[3]), ticks: parts[19] };
  } catch (error: any) {
    if (['ENOENT', 'ESRCH'].includes(error.code)) return undefined;
    throw error;
  }
}
const running = (m: Member) => !['Z', 'X'].includes(m.state);

/** Detached adapter groups only. Preserve identity continuity after the leader exits. */
export class ProcessGroup {
  private known = new Map<number, string>();
  private namespace = readlinkSync('/proc/self/ns/pid');
  constructor(private readonly pgid: number) {
    const leader = member(pgid);
    if (leader && leader.pgid === pgid && leader.sid === pgid) this.known.set(pgid, leader.ticks);
  }
  members(): Member[] {
    if (readlinkSync('/proc/self/ns/pid') !== this.namespace) throw new ProcessGroupUnconfirmed('PID namespace changed');
    const members = readdirSync('/proc')
      .filter(name => /^\d+$/.test(name))
      .map(name => member(Number(name)))
      .filter((m): m is Member => !!m && m.pgid === this.pgid && m.sid === this.pgid && running(m));
    if (!members.length) return [];
    // A numeric PGID alone is not authorization. At least one original member
    // must still anchor this group generation before admitting descendants.
    if (!members.some(m => this.known.get(m.pid) === m.ticks))
      throw new ProcessGroupUnconfirmed('Group generation could not be verified');
    for (const m of members) this.known.set(m.pid, m.ticks);
    return members;
  }
  async signal(signal: 'SIGTERM' | 'SIGKILL') {
    const members = this.members();
    if (!members.length) return;
    // pidfd pins each verified process, eliminating PID/PGID-reuse signal races.
    await promisify(execFile)('python3', ['/app/apps/worker/src/signal-process.py', JSON.stringify({ namespace: this.namespace, pgid: this.pgid, members }), signal], { timeout: 1000 });
  }
}
