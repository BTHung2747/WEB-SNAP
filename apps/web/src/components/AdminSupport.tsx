import { useEffect, useRef, useState, type FormEvent } from 'react';
import { ApiError } from '../lib/api';
import { getAdminSupport, qrByteLimit, removeSupportQr, saveSupport, supportFields, supportQrUrl, uploadSupportQr, type SupportFields } from '../lib/support';
import SupportQr from './SupportQr';

export default function AdminSupport({ csrf, onAuthExpired }: { csrf: string; onAuthExpired: () => void }) {
  const [draft, setDraft] = useState<SupportFields | null>(null);
  const [saved, setSaved] = useState<SupportFields | null>(null);
  const [qr, setQr] = useState<{ qrUrl: string | null; qrPending: boolean }>({ qrUrl: null, qrPending: false });
  const [file, setFile] = useState<File | null>(null);
  const [localUrl, setLocalUrl] = useState<string | null>(null);
  const [busy, setBusy] = useState('load');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [attempt, setAttempt] = useState(0);
  const fileInput = useRef<HTMLInputElement>(null);
  const alive = useRef(false);
  const version = useRef(0);
  const operation = useRef(false);
  const uploadController = useRef<AbortController | null>(null);
  const restoreFocus = useRef<HTMLElement | null>(null);
  const current = (v: number) => alive.current && version.current === v;
  function failure(e: unknown, v: number) {
    if (!current(v)) return;
    if (e instanceof ApiError && e.status === 403 && e.code === 'ADMIN_REQUIRED') onAuthExpired();
    else setError(e instanceof ApiError ? e.message : 'Không kết nối được máy chủ. Hãy thử lại.');
  }
  useEffect(() => {
    alive.current = true;
    const v = ++version.current;
    setBusy('load'); setError('');
    void getAdminSupport(csrf).then(data => {
      if (!current(v)) return;
      setDraft(supportFields(data)); setSaved(supportFields(data));
      setQr({ qrUrl: data.qrUrl, qrPending: data.qrPending });
    }).catch(e => failure(e, v)).finally(() => { if (current(v)) setBusy(''); });
    return () => { alive.current = false; ++version.current; uploadController.current?.abort(); };
  }, [csrf, attempt]);
  useEffect(() => {
    if (!file) { setLocalUrl(null); return; }
    const url = URL.createObjectURL(file);
    setLocalUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);
  useEffect(() => {
    if (!busy) {
      const target = restoreFocus.current;
      restoreFocus.current = null;
      if (target?.isConnected && !target.matches(':disabled')) target.focus();
      else if (target) fileInput.current?.focus();
    }
  }, [busy]);
  function selectFile(next: File | null) {
    setError(''); setNotice('');
    if (next && (!['image/png', 'image/jpeg'].includes(next.type) || next.size === 0)) {
      setError('Chọn ảnh PNG hoặc JPEG hợp lệ. Máy chủ sẽ kiểm tra ảnh sau khi tải lên.'); setFile(null);
    } else if (next && next.size > qrByteLimit) {
      setError('Ảnh QR tối đa 2 MiB. Hãy chọn ảnh nhỏ hơn.'); setFile(null);
    } else setFile(next);
    if (fileInput.current) fileInput.current.value = '';
  }
  async function run(action: 'upload' | 'remove' | 'save') {
    if (!draft || operation.current) return;
    operation.current = true;
    const v = ++version.current;
    if (document.activeElement instanceof HTMLElement) restoreFocus.current = document.activeElement;
    setBusy(action); setError(''); setNotice('');
    try {
      if (action === 'save') {
        if (file) throw new ApiError('SUPPORT_LOCAL_FILE');
        const fields = supportFields(draft);
        for (const key of ['title', 'message', 'bankName', 'accountName', 'accountNumber', 'transferNote'] as const) fields[key] = fields[key].trim();
        if (!fields.title || !fields.message || Object.values(fields).some(value => typeof value === 'string' && /[<>\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(value))) throw new ApiError('SUPPORT_TEXT_INVALID');
        if (fields.enabled && !qr.qrUrl && !(fields.bankName && fields.accountName && fields.accountNumber)) throw new ApiError('SUPPORT_PAYMENT_REQUIRED');
        const result = await saveSupport(fields, csrf);
        if (!current(v)) return;
        setDraft(supportFields(result)); setSaved(supportFields(result)); setQr({ qrUrl: result.qrUrl, qrPending: result.qrPending });
        setNotice(result.enabled ? 'Đã lưu và công khai thông tin ủng hộ cùng QR hiện tại.' : 'Đã lưu. Trang ủng hộ đang tắt; thông tin nhận tiền không công khai.');
      } else {
        if (action === 'upload' && !file) return;
        const controller = new AbortController();
        uploadController.current = controller;
        const result = action === 'upload' ? await uploadSupportQr(file!, csrf, controller.signal) : await removeSupportQr(csrf);
        if (!current(v)) return;
        // The response contains SAVED text. Keep the text draft being edited.
        setQr({ qrUrl: result.qrUrl, qrPending: result.qrPending }); setFile(null);
        setNotice(action === 'upload' ? 'Đã tải QR lên bản chờ. Bấm Lưu để áp dụng cùng nội dung.' : 'Đã gỡ QR khỏi bản chờ. Bấm Lưu để gỡ khỏi trang công khai.');
      }
    } catch (e) { failure(e, v); }
    finally {
      if (current(v)) { setBusy(''); operation.current = false; uploadController.current = null; }
    }
  }
  function submit(e: FormEvent) { e.preventDefault(); void run('save'); }
  const dirty = draft && saved && JSON.stringify(draft) !== JSON.stringify(saved);
  const qrUrl = supportQrUrl(qr.qrUrl, true);
  if (!draft) return <section className="admin-support" aria-label="Thiết lập ủng hộ">
    {error ? <><p className="error" role="alert">{error}</p><button className="secondary" onClick={() => setAttempt(n => n + 1)}>Thử lại</button></> : <p role="status">Đang tải thiết lập ủng hộ…</p>}
  </section>;
  return <form className="admin-support" onSubmit={submit} aria-label="Thiết lập ủng hộ" aria-busy={!!busy}>
    <div className="support-admin-status"><span>{saved?.enabled ? 'Trang đang bật' : 'Trang đang tắt'}</span><a href="/ung-ho" target="_blank" rel="noopener">Xem trang công khai ↗</a></div>
    <p className="muted">Thông tin và QR chỉ áp dụng cho trang công khai sau khi bấm Lưu.</p>
    {error && <p className="error" role="alert">{error}</p>}
    {notice && <p className="success" role="status">{notice}</p>}
    {busy && <p role="status">{busy === 'upload' ? 'Đang tải và kiểm tra ảnh QR…' : busy === 'remove' ? 'Đang gỡ QR khỏi bản chờ…' : 'Đang lưu thông tin…'}</p>}
    <fieldset disabled={!!busy} className="support-content-fields">
      <legend>Nội dung trang</legend>
      <label className="checkbox"><input type="checkbox" checked={draft.enabled} onChange={e => setDraft({ ...draft, enabled: e.target.checked })} />Bật nhận ủng hộ trên trang công khai</label>
      <label>Tiêu đề<input required maxLength={100} value={draft.title} onChange={e => setDraft({ ...draft, title: e.target.value })} /></label>
      <label>Lời kêu gọi<textarea required maxLength={2000} rows={5} value={draft.message} onChange={e => setDraft({ ...draft, message: e.target.value })} aria-describedby="support-message-help" /></label>
      <p id="support-message-help" className="muted">Tối đa 2.000 ký tự văn bản thuần. Nội dung ủng hộ luôn tự nguyện.</p>
    </fieldset>
    <fieldset disabled={!!busy} className="support-qr-fields">
      <legend>Ảnh QR</legend>
      <div className="support-qr-editor">
        <div className="support-qr-preview"><SupportQr url={localUrl || qrUrl} alt={localUrl ? 'Ảnh vừa chọn, chưa tải lên máy chủ' : 'QR trong thiết lập quản trị'} />
          <p className="support-qr-state">{file ? 'Ảnh local • Chưa tải lên' : qr.qrPending ? (qrUrl ? 'QR bản chờ • Chưa áp dụng' : 'Bản chờ gỡ QR • Chưa áp dụng') : (qrUrl ? 'QR đã lưu' : 'Chưa có QR')}</p></div>
        <div className="support-qr-tools">
          <label htmlFor="support-qr-file">Chọn ảnh QR của bạn</label>
          <input id="support-qr-file" ref={fileInput} type="file" accept="image/png,image/jpeg" onChange={e => { const selected = e.currentTarget.files?.[0]; if (selected) selectFile(selected); }} aria-describedby="support-qr-help" />
          <p id="support-qr-help" className="muted">PNG hoặc JPEG, tối đa 2 MiB. Chọn ảnh rõ nét, có khoảng trắng quanh mã. Máy chủ kiểm tra ảnh khi tải lên.</p>
          {file && <p className="support-file-name">{file.name}</p>}
          <div className="support-qr-actions">
            {file && <><button className="secondary" type="button" onClick={() => void run('upload')}>Tải ảnh lên bản chờ</button><button className="text-btn" type="button" onClick={() => selectFile(null)}>Bỏ ảnh vừa chọn</button></>}
            {!file && qrUrl && <button className="secondary" type="button" onClick={() => void run('remove')}>Gỡ QR ở bản chờ</button>}
          </div>
          <p className="muted">Tải lên hoặc gỡ QR sẽ lưu bản chờ qua lần tải lại trang. Nội dung đang nhập vẫn cần bấm Lưu.</p>
        </div>
      </div>
    </fieldset>
    <fieldset disabled={!!busy} className="support-bank-fields">
      <legend>Thông tin chuyển khoản</legend>
      <p className="muted">Có thể để trống khi đã có QR. Nếu không dùng QR, cần đủ ngân hàng, chủ tài khoản và số tài khoản để bật trang.</p>
      <div className="settings-grid">{([
        ['bankName', 'Ngân hàng', 100], ['accountName', 'Chủ tài khoản', 120],
        ['accountNumber', 'Số tài khoản', 64], ['transferNote', 'Nội dung chuyển khoản', 240],
      ] as const).map(([key, label, limit]) => <label key={key}>{label}<input maxLength={limit} value={draft[key]} onChange={e => setDraft({ ...draft, [key]: e.target.value })} autoComplete="off" spellCheck={false} /></label>)}</div>
    </fieldset>
    <div className="support-save"><p role="status">{file ? 'Ảnh mới chưa tải lên. Tải ảnh lên hoặc bỏ ảnh trước khi Lưu.' : dirty || qr.qrPending ? 'Có thay đổi chưa áp dụng. Bấm Lưu để cập nhật trang công khai.' : 'Tất cả thay đổi đã được lưu.'}</p><button className="primary" disabled={!!busy || !!file}>Lưu</button></div>
  </form>;
}
