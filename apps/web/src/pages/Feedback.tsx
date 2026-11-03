import {useEffect, useRef, useState, type FormEvent} from 'react';
import {api, ApiError} from '../lib/api';
import {feedbackKinds, type FeedbackKind} from '../lib/feedback';
import type {Session} from '../types';
const empty = () => ({kind: 'feedback' as FeedbackKind, subject: '', message: '', name: '', email: ''});
export default function Feedback({session, connectionError}: {session: Session | null; connectionError: string}) {
  const [draft, setDraft] = useState(empty);
  const [busy, setBusy] = useState(false), [error, setError] = useState(''), [sent, setSent] = useState(false);
  const pending = useRef(false), alive = useRef(false), success = useRef<HTMLDivElement>(null);
  const errorBox = useRef<HTMLParagraphElement>(null), subject = useRef<HTMLInputElement>(null), sentBefore = useRef(false);
  useEffect(() => {alive.current = true; return () => {alive.current = false;};}, []);
  useEffect(() => {if (sent) {success.current?.focus(); sentBefore.current=true;} else if (sentBefore.current) subject.current?.focus();}, [sent]);
  useEffect(() => {if (error) errorBox.current?.focus();}, [error]);
  async function submit(event: FormEvent) {
    event.preventDefault(); if (pending.current || !session) return;
    pending.current = true; setBusy(true); setError('');
    try {
      const result = await api('feedback', session.csrf, 'POST', draft);
      if (!result.received) throw new Error();
      if (alive.current) {setSent(true); setDraft(empty());}
    } catch (e) {
      if (alive.current) setError(e instanceof ApiError ? e.code==='RATE_LIMITED' ? 'Bạn đã gửi nhiều góp ý trong thời gian ngắn. Vui lòng thử lại sau; nội dung của bạn vẫn được giữ.' : e.message : 'Chưa xác nhận được máy chủ đã nhận thư. Nội dung vẫn được giữ để bạn kiểm tra và thử lại.');
    } finally {pending.current = false; if (alive.current) setBusy(false);}
  }
  return <main className="feedback-page">
    <a className="support-back" href="/">← Về trang tải</a>
    <header className="feedback-intro">
      <h1>Mình lắng nghe bạn.</h1>
      <p>WED SNAP tốt hơn nhờ góp ý của bạn. Nếu gặp trục trặc hoặc có một ý tưởng hay, hãy để lại lời nhắn cho mình.</p>
    </header>
    {sent ? <div className="feedback-sent" role="status" tabIndex={-1} ref={success}>
      <span className="feedback-received">Đã nhận góp ý</span>
      <h2>Cảm ơn bạn đã dành thời gian.</h2>
      <p>Thư đã được lưu vào hộp thư quản trị WED SNAP. Mình sẽ đọc và cân nhắc góp ý của bạn.</p>
      <p className="muted">Nếu bạn để lại email, quản trị có thể chủ động liên hệ. Đây không phải thông báo đã gửi email.</p>
      <div className="feedback-actions"><a className="primary" href="/">Về trang tải</a><button className="secondary" onClick={() => setSent(false)}>Gửi góp ý khác</button></div>
    </div> : <form className="feedback-form" onSubmit={submit} aria-busy={busy}>
      <fieldset disabled={busy}>
        <legend className="sr-only">Nội dung góp ý</legend>
        <div className="feedback-field"><label htmlFor="feedback-kind">Bạn muốn gửi điều gì?</label><select id="feedback-kind" value={draft.kind} onChange={e => setDraft({...draft, kind: e.target.value as FeedbackKind})}>{Object.entries(feedbackKinds).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></div>
        <div className="feedback-field"><label htmlFor="feedback-subject">Chủ đề <span>(bắt buộc)</span></label><input id="feedback-subject" ref={subject} required maxLength={120} value={draft.subject} onChange={e => setDraft({...draft, subject: e.target.value})} placeholder="Ví dụ: Gợi ý cách chọn định dạng tải" /></div>
        <div className="feedback-field"><label htmlFor="feedback-message">Lời nhắn của bạn <span>(bắt buộc)</span></label><textarea id="feedback-message" required maxLength={4000} rows={7} value={draft.message} onChange={e => setDraft({...draft, message: e.target.value})} aria-describedby="feedback-message-help feedback-count" placeholder="Bạn gặp vấn đề ở bước nào, hoặc muốn WED SNAP cải thiện điều gì?" /><div className="feedback-message-help"><small id="feedback-message-help">Văn bản thuần, không HTML. Đừng gửi mật khẩu, cookie hay thông tin nhạy cảm.</small><small id="feedback-count">{draft.message.length.toLocaleString('vi-VN')}/4.000</small></div></div>
        <div className="feedback-contact">
          <div className="feedback-field"><label htmlFor="feedback-name">Tên của bạn <span>(tùy chọn)</span></label><input id="feedback-name" autoComplete="name" maxLength={80} value={draft.name} onChange={e => setDraft({...draft, name: e.target.value})} /></div>
          <div className="feedback-field"><label htmlFor="feedback-email">Email để liên hệ lại <span>(tùy chọn)</span></label><input id="feedback-email" type="email" autoComplete="email" maxLength={254} value={draft.email} onChange={e => setDraft({...draft, email: e.target.value})} placeholder="ban@example.com" /></div>
        </div>
      </fieldset>
      <div className="feedback-privacy"><strong>Chỉ quản trị đọc lời nhắn của bạn.</strong><p>Nội dung và email được dùng để xử lý góp ý, liên hệ khi cần. Không công khai cho khách khác. <a href="/privacy">Xem quyền riêng tư</a>.</p></div>
      {!session && <p role="status">{connectionError || 'Đang kết nối phiên để gửi góp ý…'}</p>}
      {error && <p className="error" role="alert" tabIndex={-1} ref={errorBox}>{error}</p>}
      <div className="feedback-submit"><p>Mình rất trân trọng từng góp ý, dù lớn hay nhỏ.</p><button className="primary" disabled={busy || !session}>{busy ? 'Đang gửi…' : 'Gửi góp ý'}</button></div>
    </form>}
  </main>;
}
