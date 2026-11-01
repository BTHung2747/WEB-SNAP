import { useEffect, useRef, useState } from 'react';
import SupportQr from '../components/SupportQr';
import { getPublicSupport, supportQrUrl, type PublicSupport } from '../lib/support';

export default function Support() {
  const [data, setData] = useState<PublicSupport | null>(null);
  const [error, setError] = useState('');
  const [attempt, setAttempt] = useState(0);
  const [notice, setNotice] = useState('');
  const [fallback, setFallback] = useState<{ label: string; value: string } | null>(null);
  const copyInput = useRef<HTMLTextAreaElement>(null);
  const copyVersion = useRef(0);
  useEffect(() => {
    let active = true;
    setData(null); setError(''); setNotice(''); setFallback(null);
    void getPublicSupport().then(value => { if (active) setData(value); })
      .catch(() => { if (active) setError('Chưa tải được thông tin ủng hộ. Vui lòng thử lại.'); });
    return () => { active = false; ++copyVersion.current; };
  }, [attempt]);
  useEffect(() => { if (fallback) { copyInput.current?.focus(); copyInput.current?.select(); } }, [fallback]);
  async function copy(label: string, value: string) {
    const v = ++copyVersion.current;
    setNotice(''); setFallback(null);
    try {
      if (!navigator.clipboard) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(value);
      if (copyVersion.current === v) setNotice(`Đã sao chép ${label.toLocaleLowerCase('vi-VN')}.`);
    } catch {
      if (copyVersion.current === v) setFallback({ label, value });
    }
  }
  const ready = data?.enabled ? data : null;
  const qr = ready ? supportQrUrl(ready.qrUrl) : null;
  const rows = ready ? [
    ['Ngân hàng', ready.bankName], ['Chủ tài khoản', ready.accountName],
    ['Số tài khoản', ready.accountNumber], ['Nội dung chuyển khoản', ready.transferNote],
  ].filter(([, value]) => !!value) : [];
  return <main className="support-page">
    <a className="support-back" href="/">← Về trang tải</a>
    {!data ? <section className="support-state">
      <span className="support-eyebrow">Cùng duy trì WED SNAP</span>
      <h1>Ủng hộ WED SNAP</h1>
      {error ? <><p className="error" role="alert">{error}</p><button className="secondary" onClick={() => setAttempt(n => n + 1)}>Thử lại</button></> : <p role="status">Đang tải thông tin ủng hộ…</p>}
    </section> : !ready ? <section className="support-state">
      <span className="support-eyebrow">Cùng duy trì WED SNAP</span>
      <h1>Chưa mở nhận ủng hộ</h1>
      <p>Thông tin ủng hộ đang được cập nhật. Cảm ơn bạn đã quan tâm đến WED SNAP.</p>
      <a className="primary" href="/">Tiếp tục sử dụng công cụ</a>
    </section> : <div className="support-layout">
      <section className="support-intro">
        <span className="support-eyebrow">Cùng duy trì WED SNAP</span>
        <h1>{ready.title}</h1>
        <p className="support-message">{ready.message}</p>
        <p className="support-voluntary">Hoàn toàn tự nguyện. Bạn luôn có thể sử dụng công cụ mà không cần ủng hộ.</p>
      </section>
      <section className={`support-payment ${qr && rows.length ? 'has-qr-and-bank' : qr ? 'is-qr-only' : 'is-bank-only'}`} aria-labelledby="support-payment-title">
        <h2 id="support-payment-title">Thông tin ủng hộ</h2>
        <div className="support-payment-body">
        {qr && <div className="support-scan"><SupportQr url={qr} alt="Mã QR ủng hộ do quản trị WED SNAP cung cấp" /><a className="secondary support-download" href={qr} download="wed-snap-ung-ho.png">Tải ảnh QR</a></div>}
        {rows.length > 0 && <dl className="support-bank">{rows.map(([label, value]) => <div key={label}>
          <div><dt>{label}</dt><dd className={label === 'Số tài khoản' ? 'support-account-number' : undefined}>{value}</dd></div>
          <button type="button" className="text-btn" aria-label={`Sao chép ${label.toLocaleLowerCase('vi-VN')}`} onClick={() => void copy(label, value)}>Sao chép</button>
        </div>)}</dl>}
        {!qr && !rows.length && <p>Thông tin nhận ủng hộ đang được cập nhật.</p>}
        </div>
        {notice && <p className="support-copy-status" role="status">{notice}</p>}
        {fallback && <div className="support-copy-fallback"><label htmlFor="support-copy">Không sao chép tự động được. Chọn và sao chép {fallback.label.toLocaleLowerCase('vi-VN')}:</label><textarea id="support-copy" ref={copyInput} readOnly value={fallback.value} rows={2} onFocus={e => e.currentTarget.select()} /></div>}
        <p className="support-payment-note">Kiểm tra thông tin người nhận trong ứng dụng ngân hàng trước khi chuyển khoản.</p>
      </section>
    </div>}
  </main>;
}
