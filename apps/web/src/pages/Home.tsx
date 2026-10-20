import React, { useEffect, useRef, useState } from 'react';
import Advertising from '../components/Advertising';
import Icon from '../components/Icon';
import StudioReveal from '../components/StudioReveal';
import { useJobLifecycle } from '../hooks/useJobLifecycle';
import { useDownloadLink } from '../hooks/useDownloadLink';
import { api, isMissingJob, messages } from '../lib/api';
import { names } from '../lib/platforms';
import type { Ad, Job, Session } from '../types';
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
    if (j.state === 'selectable') setFormat((f) => f || j.items[0]?.formats[0]?.id || '');
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
  async function prepare() {
    if (!job || job.state !== 'selectable' || !item || !selected || photoBlocked || pending.current) return;
    pending.current = 'prepare';
    const version = operation.current;
    setBusy(true);
    setError('');
    try {
      const r = await api(`jobs/${job.id}/prepare`, session.csrf, 'POST', {
        itemId: item.id,
        formatId: format,
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
  return (
    <>
      <main className="studio-home" data-state={state}>
        <section className="hero">
          <div className="intro">
            <p className="eyebrow">Từ đường dẫn đến thiết bị</p>
            <h1>Giữ lại<br />điều bạn <em>thích.</em></h1>
            <p className="hero-copy">Video hay. Bức ảnh đẹp.<br />Lưu nội dung bạn có quyền sử dụng.</p>
            <p className="intro-foot">Không cần tài khoản.<br />Không ép xem quảng cáo.</p>
          </div>
          <div className="download-card">
            <div className="tool-title"><span>Dán link</span><span>Công cụ tải nội dung</span></div>
            {!jobId && <h2>Link của bạn,<br />phần còn lại để {session.productName}.</h2>}
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
          </div>
        </section>
        <section className="result-area" ref={resultRegion} tabIndex={-1} aria-label="Kết quả nội dung">
          {!jobId && !error && <div className="empty-state"><h2>Bắt đầu bằng một đường dẫn.</h2><p>Thông tin nội dung và lựa chọn từ nguồn sẽ xuất hiện tại đây.</p></div>}
            {(jobId || error) && (
              <div className="job-panel" aria-live="polite" aria-atomic="false" aria-busy={busy}>
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
                  <div className="selection">
                    {!photo && job.previewUrl && (
                      <img
                        className="preview"
                        src={job.previewUrl}
                        alt="Ảnh xem trước video"
                        onError={(e) => {
                          e.currentTarget.style.display = 'none';
                        }}
                      />
                    )}
                    <div className="selection-info">
                      <span className="micro">
                        {photo ? `BÀI ẢNH · ${item?.formats.length || 0} ảnh` : <>VIDEO ·{' '}{job.duration
                          ? `${Math.floor(job.duration / 60)}:${String(Math.floor(job.duration % 60)).padStart(2, '0')}`
                          : 'Thời lượng chưa xác định'}</>}
                      </span>
                      <h2>{job.title}</h2>
                      <label htmlFor="format">{photo ? 'Chọn một ảnh' : 'Chất lượng từ nguồn'}</label>
                      <select
                        id="format"
                        value={format}
                        onChange={(e) => {
                          setFormat(e.target.value);
                          prepareKey.current = crypto.randomUUID();
                        }}
                        disabled={busy || state !== 'selectable'}
                        aria-describedby={photo ? 'photo-selection-note' : undefined}
                      >
                        {item?.formats.map((f) => (
                          <option key={f.id} value={f.id}>
                            {f.label}{photo
                              ? (f.width && f.height ? ` · ${f.width} × ${f.height} px` : '')
                              : <> · {f.size
                              ? `${(f.size / 1048576).toFixed(1)} MiB`
                              : 'Kích thước chưa xác định'}</>}
                          </option>
                        ))}
                      </select>
                      {photo && <p className="photo-selection-note" id="photo-selection-note">
                        Một tệp JPG cho ảnh đã chọn. Muốn tải ảnh khác sau khi chuẩn bị, hãy phân tích lại link để tạo tác vụ mới.
                      </p>}
                      {!item?.formats.length && <p className="muted" role="status">Chưa có lựa chọn phù hợp. Hãy phân tích lại link.</p>}
                      {state === 'selectable' ? (
                        <button className="primary" disabled={busy || !selected} onClick={() => { resultRegion.current?.focus({ preventScroll: true }); void prepare(); }}>
                          {photo ? 'Chuẩn bị ảnh đã chọn' : 'Chuẩn bị tải'} <Icon name="arrow" />
                        </button>
                      ) : state !== 'ready' ? null : downloadLink.url ? (
                        <a
                          className="primary"
                          href={downloadLink.url}
                          download={photo ? 'wed-snap-image.jpg' : 'wed-snap-video.mp4'}
                          onClick={() => setStarted(true)}
                        >
                          Tải xuống <Icon name="arrow" />
                        </a>
                      ) : downloadLink.error ? (
                        <>
                          <p className="error" role="alert">
                            {downloadLink.error}
                          </p>
                          <button className="secondary" onClick={downloadLink.retry}>
                            Tạo lại liên kết tải
                          </button>
                        </>
                      ) : (
                        <button className="primary" disabled>
                          Đang tạo liên kết tải…
                        </button>
                      )}
                      {started && (
                        <div>
                          <p className="started">
                            <Icon name="check" /> Đã bắt đầu yêu cầu tải. Kiểm tra danh sách tải của
                            trình duyệt.
                          </p>
                          <p className="muted">
                            Việc lưu tệp do trình duyệt thực hiện. Nếu cần, kiểm tra quyền tải xuống của trình duyệt.
                          </p>
                        </div>
                      )}
                    </div>
                  </div>
                )}
                {['expired', 'cancelled', 'failed'].includes(state) && (
                  <p className="muted terminal-state">
                    {stateLabels[state]}. Bạn có thể phân tích lại link để tiếp tục.
                  </p>
                )}
              </div>
            )}
        </section>
        {ad && <Advertising ad={ad} csrf={session.csrf} />}
        <section className="how" id="how">
          <div className="section-intro">
            <h2>Một link.<br />Ba thao tác.</h2>
          </div>
          <StudioReveal className="steps">
            {[
              {
                icon: 'link',
                title: 'Dán đường dẫn',
                text: 'Sao chép link bài đăng công khai và dán vào ô phía trên.',
              },
              {
                icon: 'play',
                title: 'Chọn nội dung',
                text: 'Xem thông tin và chọn một chất lượng mà nguồn cung cấp.',
              },
              {
                icon: 'arrow',
                title: 'Lưu khoảnh khắc',
                text: 'Nhấn chuẩn bị, rồi tải xuống khi tệp thực sự sẵn sàng.',
              },
            ].map((s, i) => (
              <article key={s.title}>
                <span className="step-icon">
                  <Icon name={s.icon} />
                </span>
                <span className="step-no">0{i + 1}</span>
                <h3>{s.title}</h3>
                <p>{s.text}</p>
              </article>
            ))}
          </StudioReveal>
        </section>
        <section className="faq">
          <div>
            <h2>Bạn nên biết.</h2>
            <p>Một số bài có thể không tải được do thay đổi từ nền tảng.</p>
          </div>
          <StudioReveal className="faq-list">
            {[
              [
                'Tôi có thể tải loại nội dung nào?',
                photoEnabled
                  ? 'MP4 công khai có hình và tiếng, cùng từng ảnh JPG trong bài ảnh TikTok được hỗ trợ. Mỗi lần chỉ chuẩn bị một ảnh. Livestream, playlist và nội dung cần đăng nhập chưa được bật.'
                  : 'Hiện chỉ bật nền tảng đã qua kiểm chứng. MP4 công khai có cả hình và tiếng được hỗ trợ; ảnh, livestream, playlist và nội dung cần đăng nhập chưa được bật.',
              ],
              [
                'Tệp của tôi được giữ bao lâu?',
                'Tệp chưa tải tồn tại tối đa 10 phút. Rời trang sẽ bắt đầu thời gian chờ hủy; lượt truyền đã bắt đầu được máy chủ duy trì độc lập với trang.',
              ],
              [
                'Có bắt buộc xem hoặc nhấn quảng cáo không?',
                'Không. Nội dung tài trợ là tùy chọn và không trì hoãn việc chuẩn bị hoặc tải tệp.',
              ],
            ].map(([q, a]) => (
              <details key={q}>
                <summary>
                  {q}
                  <span>+</span>
                </summary>
                <p>{a}</p>
              </details>
            ))}
          </StudioReveal>
        </section>
      </main>
      {sponsor && (
        <div className="sponsor-box studio-sponsor">
          <Advertising ad={sponsor} csrf={session.csrf} onClose={() => setSponsor(null)} />
        </div>
      )}
    </>
  );
}
