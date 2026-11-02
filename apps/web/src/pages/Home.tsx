import React, { useEffect, useRef, useState } from 'react';
import Advertising from '../components/Advertising';
import Icon from '../components/Icon';
import { HomeIntro, HomeGuide } from '../components/HomePublicSections';
import { useJobLifecycle } from '../hooks/useJobLifecycle';
import { useDownloadLink } from '../hooks/useDownloadLink';
import { api, isMissingJob, messages } from '../lib/api';
import { names } from '../lib/platforms';
import type { Ad, Job, Session } from '../types';
import { initialSourceFormat } from '../lib/source-quality';
import MediaPreview from '../components/MediaPreview';
export default function Home({ session }: { session: Session }) {
  const [url, setUrl] = useState('');
  const [job, setJob] = useState<Job | null>(null);
  const [jobId, setJobId] = useState<string | null>(null);
  const [format, setFormat] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [started, setStarted] = useState(false);
  const [ad, setAd] = useState<Ad | null>(null);
  const [sponsor, setSponsor] = useState<Ad | null>(null);
  const photoEnabled = session.capabilities?.tiktokPhoto === true;
  const photo = job?.items[0]?.kind === 'photo';
  const photoBlocked = photo && !photoEnabled;
  const item = job?.items[0];
  const selected = item?.formats.find((f) => f.id === format);
  const downloadLink = useDownloadLink(photoBlocked ? null : job, session.csrf);
  const prepareKey = useRef(crypto.randomUUID());
  const operation = useRef(0);
  const pending = useRef<'analyze' | 'prepare' | null>(null);
  const mounted = useRef(true);
  const sponsorRequest = useRef(0);
  const resultRegion = useRef<HTMLElement>(null);
  const resultDialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    if (jobId && !resultDialog.current?.open) resultDialog.current?.showModal();
    if (!jobId && resultDialog.current?.open) resultDialog.current.close();
  }, [jobId]);
  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; operation.current++; sponsorRequest.current++; };
  }, []);
  function stopPreparing() {
    if (pending.current === 'prepare') {
      operation.current++;
      pending.current = null;
      setBusy(false);
    }
  }
  const tracking = !!jobId && ['analyzing', 'selectable', 'queued', 'preparing', 'ready'].includes(job?.state || 'analyzing');
  const lifecycle = useJobLifecycle(jobId, tracking, session.csrf, (j) => {
    if (['failed', 'cancelled', 'expired'].includes(j.state)) {
      stopPreparing();
      sponsorRequest.current++;
      setSponsor(null);
    }
    setJob(j);
    setError(j.errorCode ? messages[j.errorCode] || j.errorCode : '');
    if (j.state === 'selectable') setFormat((f) => f || initialSourceFormat(j.items[0]?.formats || []));
  }, (e, missing) => {
    if (missing) {
      stopPreparing();
      sponsorRequest.current++;
      setSponsor(null);
    }
    setError(e.message);
    if (missing && jobId) setJob((j) => ({
      ...(j || { id: jobId, title: null, duration: null, previewUrl: null, items: [] }),
      state: 'expired', errorCode: isMissingJob(e) ? e.code : 'JOB_EXPIRED',
    }));
  });
  useEffect(() => {
    let live = true;
    api('ads?placement=banner', session.csrf)
      .then((a) => { if (live) setAd(a); })
      .catch(() => {});
    return () => { live = false; };
  }, [session.csrf]);
  async function analyze(e: React.FormEvent) {
    e.preventDefault();
    if (pending.current) return;
    pending.current = 'analyze';
    const version = ++operation.current;
    sponsorRequest.current++;
    setSponsor(null);
    setBusy(true);
    setError('');
    setStarted(false);
    try {
      if (jobId) {
        try { await api(`jobs/${jobId}/cancel`, session.csrf, 'POST'); }
        catch (e) { if (!isMissingJob(e)) throw e; }
      }
      if (!mounted.current || operation.current !== version) return;
      lifecycle.stop();
      setJob(null);
      setJobId(null);
      setFormat('');
      prepareKey.current = crypto.randomUUID();
      const data = await api('jobs/analyze', session.csrf, 'POST', { url: url.trim() });
      if (!mounted.current || operation.current !== version) return;
      setJobId(data.jobId);
      // Old-job callbacks may invalidate grants while replacement cancel is pending.
      // Bind this generation to the accepted new job's sponsor request.
      const sponsorVersion = ++sponsorRequest.current;
      // The cookie-session grant is atomic on the server across tabs.
      api('ads?placement=sponsor', session.csrf)
        .then((a) => {
          if (a && mounted.current && sponsorRequest.current === sponsorVersion)
            setSponsor(a);
        })
        .catch(() => {});
    } catch (e) {
      if (mounted.current && operation.current === version) setError((e as Error).message);
    } finally {
      if (mounted.current && operation.current === version) {
        pending.current = null;
        setBusy(false);
      }
    }
  }
  async function prepare(formatId = format) {
    if (!job || job.state !== 'selectable' || !item || !item.formats.some((f) => f.id === formatId) || photoBlocked || pending.current) return;
    pending.current = 'prepare';
    if (formatId !== format) prepareKey.current = crypto.randomUUID();
    setFormat(formatId);
    const version = operation.current;
    setBusy(true);
    setError('');
    try {
      const r = await api(`jobs/${job.id}/prepare`, session.csrf, 'POST', {
        itemId: item.id,
        formatId,
        idempotencyKey: prepareKey.current,
      });
      if (mounted.current && operation.current === version && lifecycle.current.current === job.id)
        setJob((j) => j?.id === job.id ? { ...j, state: r.state } : j);
    } catch (e) {
      if (mounted.current && operation.current === version) setError((e as Error).message);
    } finally {
      if (mounted.current && operation.current === version) { pending.current = null; setBusy(false); }
    }
  }
  async function cancel() {
    if (!jobId) return;
    const version = operation.current;
    try {
      await api(`jobs/${jobId}/cancel`, session.csrf, 'POST');
      if (!mounted.current || operation.current !== version) return;
      lifecycle.stop();
      stopPreparing();
      sponsorRequest.current++;
      setSponsor(null);
      setJob((j) => ({ ...(j || { id: jobId, title: null, duration: null, previewUrl: null, items: [], errorCode: null }), state: 'cancelled' }));
    } catch (e) {
      if (!mounted.current || operation.current !== version) return;
      if (isMissingJob(e)) {
        lifecycle.stop();
        stopPreparing();
        sponsorRequest.current++;
        setSponsor(null);
        setJob((j) => ({ ...(j || { id: jobId, title: null, duration: null, previewUrl: null, items: [] }), state: 'expired', errorCode: e.code }));
      }
      setError((e as Error).message);
    }
  }
  const state = job?.state || (jobId ? 'analyzing' : 'idle');
  const processing = ['analyzing', 'queued', 'preparing'].includes(state);
  const stateLabels: Record<string, string> = {
    analyzing: 'Đang lấy thông tin từ nguồn…',
    queued: 'Đang chờ đến lượt xử lý…',
    preparing: 'Đang chuẩn bị tệp của bạn…',
    expired: 'Tệp đã hết hạn',
    cancelled: 'Tác vụ đã được hủy',
    failed: 'Không lấy được nội dung',
  };
  function closeResults() {
    resultDialog.current?.close();
    document.getElementById('video-url')?.focus();
  }
  function downloadAction(formatId: string, imageIndex?: number) {
    const currentFormat = formatId === format;
    const actionClass = 'balanced-action';
    if (state === 'selectable') return <button className={actionClass} disabled={busy}
      onClick={(e) => {
        if (imageIndex) e.currentTarget.closest('article')?.focus({ preventScroll: true });
        else resultRegion.current?.focus({ preventScroll: true });
        void prepare(formatId);
      }}><Icon name="arrow" />{imageIndex ? `Chuẩn bị ảnh ${imageIndex}` : 'Chuẩn bị MP4'}</button>;
    if (state === 'ready' && currentFormat && downloadLink.url) return <a className={actionClass} href={downloadLink.url}
      download={photo ? 'wed-snap-image.jpg' : 'wed-snap-video.mp4'} onClick={() => setStarted(true)}>
      <Icon name="arrow" />{imageIndex ? `Tải ảnh ${imageIndex}` : 'Tải MP4'}</a>;
    if (state === 'ready' && currentFormat && downloadLink.error) return <><p className="error" role="alert">{downloadLink.error}</p><button className={actionClass} onClick={downloadLink.retry}>Tạo lại liên kết tải</button></>;
    return <button className={actionClass} disabled>{currentFormat ? state === 'ready' ? 'Đang tạo liên kết…' : 'Đang chuẩn bị…' : 'Đã khóa lựa chọn'}</button>;
  }
  return (
    <>
      <main className="studio-home" data-state={state}>
        <section className="hero">
          <HomeIntro />
          <div className={`download-card${jobId ? ' has-result' : ''}`}>
            <div className="tool-title"><span>Công cụ tải nội dung</span><span>MP4{photoEnabled ? ' / JPG' : ''}</span></div>
            <h2>Link của bạn. Tệp bạn cần.</h2>
            <form onSubmit={(event) => { void analyze(event); resultRegion.current?.focus({ preventScroll: true }); }}>
              <label htmlFor="video-url">{photoEnabled ? 'Đường dẫn video hoặc bài ảnh công khai' : 'Đường dẫn video công khai'}</label>
              <div className="url-row">
                <Icon name="link" />
                <input
                  id="video-url"
                  type="url"
                  value={url}
                  onChange={(e) => setUrl(e.target.value)}
                  placeholder={photoEnabled ? 'Dán đường dẫn tại đây…' : 'Dán đường dẫn video tại đây…'}
                  required
                  maxLength={2048}
                  autoComplete="off"
                  disabled={busy || processing}
                  aria-describedby="source-note"
                />
                <button
                  type="button"
                  className="paste"
                  disabled={busy || processing}
                  onClick={() =>
                    navigator.clipboard
                      .readText()
                      .then(setUrl)
                      .catch(() => setError('Hãy dùng Ctrl+V hoặc nhấn giữ ô nhập để dán link.'))
                  }
                >
                  Dán
                </button>
              </div>
              <button className="primary analyze" disabled={busy || processing} type="submit">
                {busy ? 'Đang gửi…' : 'Phân tích link'}
                <span aria-hidden="true">↗</span>
              </button>
            </form>
            <div className="card-note" id="source-note">
              <Icon name="shield" /> Chỉ tải nội dung bạn sở hữu hoặc được phép sử dụng.
            </div>
            <div className="platforms" id="support">
              {Object.entries(names).map(([id, name]) => (
                <span key={id} className={session.supported.includes(id) ? 'platform enabled' : 'platform'}>
                  {name}<small>{session.supported.includes(id) ? 'Đã bật' : 'Chưa bật'}</small>
                </span>
              ))}
            </div>
            {photoEnabled && <p className="photo-support">TikTok ảnh: chọn và tải một ảnh mỗi lần.</p>}
            {session.supported.length === 0 && <p className="support-note">Chưa có nền tảng được bật trên môi trường này.</p>}
            {jobId && <button className="text-btn reopen-result" onClick={() => resultDialog.current?.showModal()}>Xem lại kết quả</button>}
            {!jobId && error && <p className="error" role="alert">{error}</p>}
          </div>
        </section>
        <dialog ref={resultDialog} className="result-dialog balanced-dialog" aria-labelledby="result-dialog-title"
          onClose={() => document.getElementById('video-url')?.focus()}>
        <h2 id="result-dialog-title" className="sr-only">{photo ? 'Ảnh trong bài đăng' : 'Video của bạn'}</h2>
        <button className="balanced-close" aria-label="Đóng kết quả" onClick={closeResults}><Icon name="close" /></button>
        <section className="result-area" ref={resultRegion} tabIndex={-1} aria-label="Kết quả nội dung">
            {(jobId || error) && (
              <div className="job-panel" data-state={state} aria-live="polite" aria-atomic="false" aria-busy={busy}>
                {error && (
                  <p className="error" role="alert">
                    {error}
                  </p>
                )}
                {processing && (
                  <div className="processing">
                    <span className="status-mark" aria-hidden="true" />
                    <div className="status-copy" key={state}>
                      <strong>{stateLabels[state]}</strong>
                      <p>Bạn có thể hủy yêu cầu bất cứ lúc nào.</p>
                    </div>
                    <button className="text-btn" onClick={() => { resultRegion.current?.focus({ preventScroll: true }); void cancel(); }}>
                      Hủy
                    </button>
                  </div>
                )}
                {photoBlocked && <p className="muted" role="status">Tải ảnh TikTok chưa được bật. Bạn có thể thử một đường dẫn video được hỗ trợ.</p>}
                {job && !photoBlocked && ['selectable', 'queued', 'preparing', 'ready'].includes(state) && (
                  photo ? <div className="balanced-album">
                    <div className="balanced-album-list" role="group" aria-label="Ảnh trong bài đăng">
                      {item?.formats.map((f, i) => {
                        const index = f.index || i + 1;
                        return <article tabIndex={-1} data-format-id={f.id} aria-label={`Ảnh ${index}`}
                          className={`balanced-item${format === f.id && (busy || state !== 'selectable') ? ' is-selected' : ''}`} key={f.id}>
                          <div className="balanced-visual">
                          <MediaPreview url={f.previewUrl} jobId={job.id} alt={`Xem trước ảnh ${index}`} compact />
                          </div>
                          <div className="balanced-copy">
                            <p className="balanced-kind">Ảnh trong bài đăng</p>
                            <h3>{job.title || 'Bài ảnh của bạn'}</h3>
                            <p className="balanced-meta">Ảnh {index} / {item?.formats.length || 0}</p>
                            <div className="balanced-photo-info"><span>Thông tin ảnh</span><strong>{f.label}</strong>
                              {f.width && f.height ? <span>{f.width} × {f.height}</span> : null}</div>
                            <div className="balanced-controls">{downloadAction(f.id, index)}
                              <button className="balanced-other" onClick={closeResults}>Thử liên kết khác</button></div>
                          </div>
                        </article>;
                      })}
                    </div>
                    {state !== 'selectable' && <p className="album-lock-note">Ảnh đã chọn được khóa cho tác vụ này. Muốn tải ảnh khác, hãy phân tích lại link.</p>}
                  </div> : <div className="balanced-item">
                    <div className="balanced-visual"><MediaPreview url={job.previewUrl} jobId={job.id} alt={job.title ? `Xem trước: ${job.title}` : 'Ảnh xem trước video'} /></div>
                    <div className="balanced-copy">
                      <p className="balanced-kind">Video của bạn</p>
                      <h3>{job.title || 'Video của bạn'}</h3>
                      {job.duration != null && <p className="balanced-meta">{Math.floor(job.duration / 60)}:{String(Math.floor(job.duration % 60)).padStart(2, '0')}</p>}
                      <div className="balanced-quality">
                        {(item?.formats.length || 0) > 1 && <label htmlFor="format">Chất lượng</label>}
                        {(item?.formats.length || 0) > 1 && <select id="format" name="format" value={format} disabled={busy || state !== 'selectable'} title={selected?.label} aria-describedby="video-format-note"
                            onChange={(e) => { setFormat(e.target.value); prepareKey.current = crypto.randomUUID(); }}>
                            {item?.formats.map((f) => <option value={f.id} key={f.id}>{f.label}</option>)}
                          </select>}
                        {selected && <p id="video-format-note">{selected.label}</p>}
                      </div>
                      <div className="balanced-controls">
                        {selected ? downloadAction(selected.id) : <button className="balanced-action" disabled>Chưa có lựa chọn phù hợp</button>}
                        <button className="balanced-other" onClick={closeResults}>Thử liên kết khác</button>
                      </div>
                    </div>
                  </div>
                )}
                {started && <p className="started"><Icon name="check" /> Đã bắt đầu yêu cầu tải. Kiểm tra danh sách tải của trình duyệt.</p>}
                {['expired', 'cancelled', 'failed'].includes(state) && (
                  <p className="muted terminal-state">
                    {stateLabels[state]}. Bạn có thể phân tích lại link để tiếp tục.
                  </p>
                )}
              </div>
            )}
        </section>
        </dialog>
        {ad && <Advertising ad={ad} csrf={session.csrf} />}
        <HomeGuide photoEnabled={photoEnabled} />
      </main>
      {sponsor && (
        <div className="sponsor-box studio-sponsor">
          <Advertising ad={sponsor} csrf={session.csrf} onClose={() => setSponsor(null)} />
        </div>
      )}
    </>
  );
}
