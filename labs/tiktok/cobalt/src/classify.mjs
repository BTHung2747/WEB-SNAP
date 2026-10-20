// AGPL-3.0 lab glue; HTML stays in a bounded private pipe to installed yt-dlp helpers.
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
export function classifyHTML(text) {
  try {
    return JSON.parse(execFileSync('python3',[fileURLToPath(new URL('./classify.py',import.meta.url))],
      { input:text,encoding:'utf8',stdio:'pipe',shell:false,timeout:2000,killSignal:'SIGKILL',maxBuffer:4096 }));
  } catch { throw new Error('CLASSIFIER_FAILED'); }
}
