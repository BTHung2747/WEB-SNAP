import {test, after} from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {validateUrl, queue, redis, db} from '../packages/shared/src/core';
import {checkedFacebookResolved, facebookPostId} from '../packages/shared/src/facebook';
import {checkedAudioFormats} from '../packages/shared/src/audio';

test('Facebook preserves video identity on web and app links while removing tracking', () => {
  const id='1116506344587308', canonical=`https://www.facebook.com/watch?v=${id}`;
  for (const link of [`https://facebook.com/watch/?v=${id}&mibextid=abc`,
      `https://m.facebook.com/video.php?v=${id}`, `https://www.facebook.com/page/videos/${id}/`,
      `https://www.facebook.com/reel/${id}/?s=share`]) {
    assert.deepEqual(validateUrl(link), {platform:'facebook',url:canonical});
    assert.equal(facebookPostId(link),id);
  }
  for (const link of ['https://www.facebook.com/share/v/1CC991vc2J/?mibextid=abc',
      'https://www.facebook.com/share/r/1FXFLYpvcv/', 'https://fb.watch/Abc-123_/']) {
    assert.equal(validateUrl(link).url,link.split('?')[0]);
  }
});
test('Facebook rejects ambiguous IDs, profile/feed, credentials, ports and redirect URLs as input', () => {
  for (const link of ['https://facebook.com/watch?v=111111&v=222222',
      'https://facebook.com/watch?v=111111&video_id=111111',
      'https://facebook.com/reel/111111?v=222222', 'https://facebook.com/watch?v=not-a-video',
      'https://facebook.com/profile.php?id=111111', 'https://facebook.com/',
      'https://facebook.com/watch/live?v=111111', 'https://facebook.com.evil.invalid/reel/111111',
      'https://user@facebook.com/reel/111111', 'https://facebook.com:444/reel/111111',
      'https://facebook.com/l.php?u=https://127.0.0.1', 'https://facebook.com/reel/111111#x',
      'https://facebook.com\\@evil.invalid/reel/111111']) assert.throws(()=>validateUrl(link),link);
});
test('Facebook share resolution must bind the final numeric ID and canonical URL', () => {
  const resolved={id:'1116506344587308',kind:'video',url:'https://www.facebook.com/watch?v=1116506344587308'};
  assert.deepEqual(checkedFacebookResolved(resolved,'https://facebook.com/share/v/1CC991vc2J/'),resolved);
  for (const bad of [{...resolved,url:'https://evil.invalid/'},{...resolved,kind:'photo'},
      {...resolved,id:'abc123'},{...resolved,extra:'x'}])
    assert.throws(()=>checkedFacebookResolved(bad,'https://facebook.com/share/v/1CC991vc2J/'));
  assert.throws(()=>checkedFacebookResolved(resolved,'https://facebook.com/watch?v=222222'));
});
test('Facebook MP3 accepts only its own numeric content ID and hash-bound video descriptor', () => {
  const s={contentId:'1441001750812471',duration:8.966,platform:'facebook',
    source:{acodec:'mp4a.40.5',ext:'m4a',height:0,id:'2305162356971507a',origin:'format',vcodec:'none',width:0},
    sourceType:'video',version:'wed-audio-v1'};
  const canonical=(v:any):string=>v&&typeof v==='object'?'{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}':JSON.stringify(v);
  const f={id:'mp3_'+createHash('sha256').update(canonical(s)).digest('hex'),kind:'audio',label:'MP3 · âm thanh',size:null,selection:s};
  assert.equal(checkedAudioFormats([f],'facebook','video',s.contentId).length,1);
  assert.throws(()=>checkedAudioFormats([f],'youtube','video'));
  assert.throws(()=>checkedAudioFormats([f],'facebook','photo'));
  assert.throws(()=>checkedAudioFormats([f],'facebook','video','222222'));
  assert.throws(()=>checkedAudioFormats([{...f,selection:{...s,contentId:'abcdef'}}],'facebook','video'));
});
after(async()=>{await queue.close();redis.disconnect();await db.$disconnect();});
