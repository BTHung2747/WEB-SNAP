// AGPL-3.0 WED SNAP RAM bridge, derived from the tested photo-runtime/picker.mjs.
// Cobalt (imput and contributors) owns parsing and ordered JPEG selection.
import fs from 'node:fs';
import resolver from './vendor/tiktok.js';

try {
    const id = process.argv[2], cap = 8 * 1024 * 1024;
    if (!/^[0-9]{15,22}$/.test(id)) throw new Error();
    const chunks = []; let size = 0;
    for (;;) {
        const buffer = Buffer.alloc(Math.min(16384, cap - size + 1));
        const count = fs.readSync(0, buffer, 0, buffer.length, null);
        if (!count) break;
        size += count;
        if (size > cap) throw new Error();
        chunks.push(buffer.subarray(0, count));
    }
    const body = Buffer.concat(chunks).toString('utf8');
    let calls = 0;
    globalThis.fetch = async url => {
        if (++calls !== 1 || url !== 'https://www.tiktok.com/@i/video/' + id) throw new Error();
        return {headers: new Headers(), text: async () => body};
    };
    const result = await resolver({postId: id, h265: false, isAudioOnly: false, alwaysProxy: false});
    const m = result.lab;
    if (result.error || !m || m.id !== id || m.resolvedPostId !== id || !m.imagePost || m.privateItem ||
        !Array.isArray(result.picker) || result.picker.length < 1 || result.picker.length > 50 ||
        !Array.isArray(m.dimensions) || m.dimensions.length !== result.picker.length) throw new Error();
    const images = result.picker.map((photo, i) => {
        if (photo.type !== 'photo' || typeof photo.url !== 'string') throw new Error();
        const u = new URL(photo.url), [width, height] = m.dimensions[i];
        if (u.protocol !== 'https:' || !u.hostname || u.username || u.password || u.hash || (u.port && u.port !== '443') ||
            !Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1 ||
            width > 8192 || height > 8192 || width * height > 16000000) throw new Error();
        return {index: i + 1, url: photo.url, width, height};
    });
    // Private pipe only: the core consumes this bounded packet in RAM, never a public log.
    const caption = typeof m.caption === 'string' ? m.caption.replace(/https?:\/\/\S+/g, '[url-redacted]').replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, 300) : '';
    let audio = null;
    if (typeof result.urls === 'string' && /^[0-9]{5,24}$/.test(String(m.music?.id || '')) && Number.isFinite(m.music?.duration) && m.music.duration > 0 && m.music.duration <= 600) {
        const url = new URL(result.urls);
        if (url.protocol === 'https:' && url.hostname && !url.username && !url.password && !url.hash && (!url.port || url.port === '443'))
            audio = {id: String(m.music.id), duration: m.music.duration, url: result.urls, ext: result.bestAudio === 'mp3' ? 'mp3' : 'm4a'};
    }
    const packet = JSON.stringify({id, type: 'photo', images, caption, audio});
    if (Buffer.byteLength(packet) > 128 * 1024) throw new Error();
    process.stdout.write(packet);
} catch {
    process.stdout.write(JSON.stringify({error: 'PHOTO_METADATA_UNAVAILABLE'}));
    process.exitCode = 20;
}
