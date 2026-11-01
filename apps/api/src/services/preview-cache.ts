// Cache-only reads. No client-selected path or network request is accepted here.
import { constants } from 'node:fs';
import { open, lstat, realpath } from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { z } from 'zod';
import { filePath, mediaRoot } from '../../../../packages/shared/src/core';
const key = z.string().regex(/^(video|ttp1_[0-9]{2}_[a-f0-9]{64})$/);
const entry = z.object({ key, mime: z.literal('image/jpeg'), width: z.number().int().min(1).max(640),
  height: z.number().int().min(1).max(640), bytes: z.number().int().min(4).max(131072), sha256: z.string().regex(/^[a-f0-9]{64}$/),
  normalizedSha256: z.string().regex(/^[a-f0-9]{64}$/).optional() }).strict().refine(e=>e.key==='video'||!!e.normalizedSha256);
const manifest = z.object({ version: z.literal(1), entries: z.array(entry).max(50) }).strict();
async function folder(id: string) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(id)) throw new Error('PREVIEW_PATH');
  const directory=filePath(id),root=await lstat(mediaRoot),st=await lstat(directory);
  if (root.isSymbolicLink() || !root.isDirectory() || st.isSymbolicLink() || !st.isDirectory() ||
      await realpath(directory)!==path.resolve(mediaRoot,id) || await realpath(mediaRoot)!==path.resolve(mediaRoot)) throw new Error('PREVIEW_PATH');
  return directory;
}
async function bounded(file: string,cap: number) {
  const handle=await open(file,constants.O_RDONLY|constants.O_NOFOLLOW);
  try {
    const st=await handle.stat();if (!st.isFile() || st.size<=0 || st.size>cap) throw new Error('PREVIEW_SIZE');
    const buffer=Buffer.alloc(st.size+1);let used=0;
    while (used<buffer.length) { const r=await handle.read(buffer,used,buffer.length-used,used);if (!r.bytesRead) break;used+=r.bytesRead; }
    if (used!==st.size) throw new Error('PREVIEW_SIZE');return buffer.subarray(0,used);
  } finally { await handle.close(); }
}
async function index(id: string) {
  const directory=await folder(id);
  const data=manifest.parse(JSON.parse((await bounded(path.join(directory,'previews.json'),24576)).toString('utf8')));
  if (new Set(data.entries.map(e=>e.key)).size!==data.entries.length) throw new Error('PREVIEW_KEYS');
  return {directory,entries:data.entries};
}
export async function previewKeys(id: string): Promise<Set<string>> {
  try { return new Set((await index(id)).entries.map(e=>e.key)); } catch { return new Set(); }
}
export async function cachedPreview(id: string,requested: string) {
  key.parse(requested);
  const cache=await index(id),item=cache.entries.find(e=>e.key===requested);
  if (!item) throw new Error('PREVIEW_MISSING');
  const data=await bounded(path.join(cache.directory,`preview-${requested}.jpg`),131072);
  if (data.length!==item.bytes || data[0]!==255 || data[1]!==216 || data[2]!==255 ||
      data.at(-2)!==255 || data.at(-1)!==217 || createHash('sha256').update(data).digest('hex')!==item.sha256) throw new Error('PREVIEW_CONTENT');
  return {data,mime:'image/jpeg'};
}
export async function legacyVideoPreview(id: string) {
  const directory=await folder(id),data=await bounded(path.join(directory,'preview'),2097152);
  const jpeg=data[0]===255 && data[1]===216 && data[2]===255 && data.at(-2)===255 && data.at(-1)===217;
  const png=data.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
  if (!jpeg && !png) throw new Error('PREVIEW_CONTENT');return {data,mime:jpeg?'image/jpeg':'image/png'};
}
