// Audio is one format selection in the existing item/job, never another job/file.
import { createHash } from 'node:crypto';
import { z } from 'zod';
import { AppError } from './core';
const safe=z.string().regex(/^[A-Za-z0-9_.+-]{1,80}$/);
const source=z.object({id:safe,ext:z.enum(['m4a','mp3','aac','mp4','webm']),acodec:safe,vcodec:safe,
  width:z.number().int().min(0).max(8192),height:z.number().int().min(0).max(8192),origin:z.enum(['format','music'])}).strict();
const selection=z.object({version:z.literal('wed-audio-v1'),platform:z.enum(['youtube','tiktok','facebook']),contentId:z.string().regex(/^[A-Za-z0-9_-]{6,22}$/),
  sourceType:z.enum(['video','photo']),duration:z.number().positive().max(600),source}).strict();
const schema=z.object({id:z.string().regex(/^mp3_[a-f0-9]{64}$/),kind:z.literal('audio'),label:z.literal('MP3 · âm thanh'),size:z.null(),selection}).strict();
export type AudioFormat=z.infer<typeof schema>;
const reject=():never=>{throw new AppError('FORMAT_UNAVAILABLE');};
function canonical(v:any):string {return v&&typeof v==='object'?'{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}':JSON.stringify(v);}
export const isAudioId=(id:unknown):id is string=>typeof id==='string'&&/^mp3_[a-f0-9]{64}$/.test(id);
export const primaryFormats=(value:any)=>Array.isArray(value)?value.filter(f=>f?.kind!=='audio'):value;
export function checkedAudioFormats(value:unknown,platform:string,kind:string,expected?:string):AudioFormat[]{
  if(!Array.isArray(value))return reject();
  const p=z.array(schema).max(1).safeParse(value.filter(f=>f?.kind==='audio'));
  if(!p.success)return reject();
  for(const f of p.data){const s=f.selection;
    if(s.platform!==platform||s.sourceType!==kind||(expected&&s.contentId!==expected)||
      platform==='tiktok'&&!/^[0-9]{15,22}$/.test(s.contentId)||platform==='youtube'&&!/^[A-Za-z0-9_-]{11}$/.test(s.contentId)||
      platform==='facebook'&&!/^[0-9]{6,22}$/.test(s.contentId)||
      kind==='photo'&&(platform!=='tiktok'||s.source.origin!=='music')||
      f.id!=='mp3_'+createHash('sha256').update(canonical(s)).digest('hex'))return reject();
  }
  return p.data;
}
export function selectedAudio(items:any[],id:string,platform:string,expected?:string):AudioFormat{
  if(items.length!==1||!['photo','video'].includes(items[0].kind)||!isAudioId(id))return reject();
  return checkedAudioFormats(items[0].formats,platform,items[0].kind,expected).find(f=>f.id===id)??reject();
}
export function audioLimits<T extends {maxBytes:number;maxInputBytes:number;maxDuration:number;analyzeTimeout:number;prepareTimeout:number}>(l:T):T{
  return {...l,maxBytes:Math.min(l.maxBytes,16*1024*1024),maxInputBytes:Math.min(l.maxInputBytes,36*1024*1024),maxDuration:Math.min(l.maxDuration,600),analyzeTimeout:Math.min(l.analyzeTimeout,30),prepareTimeout:Math.min(l.prepareTimeout,180)};
}
export function checkedAudioFile(value:unknown,selected:AudioFormat,l:{maxBytes:number;maxInputBytes:number}){
  const p=z.object({file:z.literal('media.mp3'),size:z.number().int().positive().safe(),inputBytes:z.number().int().positive().safe(),sha256:z.string().regex(/^[a-f0-9]{64}$/),selectedFormat:z.literal(selected.id),
    contract:z.object({mime:z.literal('audio/mpeg'),container:z.literal('mp3'),audioCodec:z.literal('mp3'),videoStreams:z.literal(0),channels:z.number().int().min(1).max(2),duration:z.number().positive(),fullDecode:z.literal('PASS')}).strict()}).strict().safeParse(value);
  if(!p.success)return reject();const v=p.data;const expected=selected.selection.duration;
  if(v.size>Math.min(l.maxBytes,16*1024*1024)||v.inputBytes>Math.min(l.maxInputBytes,36*1024*1024)||Math.abs(v.contract.duration-expected)>Math.max(1,Math.min(2,expected*.01)))return reject();
  return v;
}
