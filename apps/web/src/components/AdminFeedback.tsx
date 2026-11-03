import {useEffect, useRef, useState} from 'react';
import {api, ApiError} from '../lib/api';
import {feedbackKinds, feedbackStatuses, type FeedbackDetail, type FeedbackList, type FeedbackRow, type FeedbackStatus} from '../lib/feedback';
const date = (value: string) => new Date(value).toLocaleString('vi-VN');
export default function AdminFeedback({csrf, onAuthExpired}: {csrf: string; onAuthExpired: () => void}) {
  const [data, setData] = useState<FeedbackList | null>(null), [detail, setDetail] = useState<FeedbackDetail | null>(null);
  const [page, setPage] = useState(1), [status, setStatus] = useState(''), [revision, setRevision] = useState(0);
  const [busy, setBusy] = useState('load'), [error, setError] = useState(''), [notice, setNotice] = useState(''), [confirm, setConfirm] = useState(false);
  const alive = useRef(false), version = useRef(0), pending = useRef(false);
  const heading = useRef<HTMLHeadingElement>(null), detailHeading = useRef<HTMLHeadingElement>(null);
  const filter = useRef<HTMLSelectElement>(null), restoreFilter = useRef(false);
  const current = (v: number) => alive.current && version.current === v;
  function failure(e: unknown, v: number) {
    if (!current(v)) return;
    if (e instanceof ApiError && e.status === 403 && e.code === 'ADMIN_REQUIRED') onAuthExpired();
    else setError(e instanceof ApiError ? e.message : 'Không kết nối được máy chủ. Hãy thử lại.');
  }
  useEffect(() => {
    alive.current = true; const v = ++version.current;
    setBusy('load'); setError(''); setDetail(null); setConfirm(false);
    void api(`admin/feedback?page=${page}${status ? '&status='+status : ''}`, csrf).then((result: FeedbackList) => {if (current(v)) setData(result);})
      .catch(e => failure(e, v)).finally(() => {if (current(v)) setBusy('');});
    return () => {alive.current = false; ++version.current;};
  }, [csrf, page, status, revision]);
  useEffect(() => {if (detail) detailHeading.current?.focus();}, [detail?.id]);
  useEffect(() => {if (!busy && restoreFilter.current) {restoreFilter.current=false; filter.current?.focus();}}, [busy]);
  async function open(row: FeedbackRow) {
    if (pending.current) return; pending.current = true; const v = ++version.current;
    setBusy('open'); setError(''); setNotice(''); setConfirm(false);
    try {
      const next: FeedbackDetail = await api('admin/feedback/'+row.id, csrf);
      if (next.status === 'unread') {await api('admin/feedback/'+row.id, csrf, 'PUT', {status:'read'}); next.status = 'read';}
      if (current(v)) {setDetail(next); setData(old => old ? {...old, items:old.items.map(item => item.id===row.id ? {...item, status:next.status} : item)} : old);}
    } catch (e) {failure(e, v);} finally {pending.current = false; if (current(v)) setBusy('');}
  }
  async function change(action: 'delete' | FeedbackStatus) {
    if (!detail || pending.current) return; pending.current = true; const v = ++version.current;
    setBusy(action); setError('');
    try {
      await api('admin/feedback/'+detail.id, csrf, action==='delete' ? 'DELETE' : 'PUT', action==='delete' ? undefined : {status:action});
      if (current(v)) {setDetail(null); setConfirm(false); setNotice(action==='delete' ? 'Đã xóa phản hồi.' : 'Đã cập nhật trạng thái.'); setRevision(n => n+1); heading.current?.focus();}
    } catch (e) {failure(e, v);} finally {pending.current = false; if (current(v)) setBusy('');}
  }
  return <section className="admin-feedback" aria-label="Hộp thư phản hồi" aria-busy={!!busy}>
    <div className="feedback-inbox-top"><div><h2 tabIndex={-1} ref={heading}>Hộp thư của bạn</h2><p className="muted">{data ? `${data.total} phản hồi${status ? ' trong bộ lọc' : ''}` : 'Góp ý riêng từ người dùng WED SNAP'}</p></div><button className="secondary" disabled={!!busy} onClick={() => setRevision(n=>n+1)}>Làm mới</button></div>
    <p className="muted">Thư được giữ trong hộp thư 90 ngày, tối đa 1.000 thư. Thư quá hạn được dọn khi nhận thư mới hoặc mở danh sách. Xóa thư không gửi email.</p>
    <label className="feedback-filter" htmlFor="feedback-filter-status">Trạng thái<select id="feedback-filter-status" ref={filter} disabled={!!busy} value={status} onChange={e=>{restoreFilter.current=true;setStatus(e.target.value);setPage(1);setData(null);}}><option value="">Tất cả</option>{Object.entries(feedbackStatuses).map(([key,label])=><option key={key} value={key}>{label}</option>)}</select></label>
    {error && <p className="error" role="alert">{error}</p>}{notice && <p className="success" role="status">{notice}</p>}
    {busy && <p role="status">{busy==='load' ? 'Đang tải hộp thư…' : 'Đang xử lý phản hồi…'}</p>}
    {data && <><div className="table-wrap" tabIndex={0} role="region" aria-label="Danh sách phản hồi, cuộn ngang nếu cần"><table><thead><tr><th scope="col">Lời nhắn</th><th scope="col">Trạng thái</th><th scope="col">Thời gian gửi</th></tr></thead><tbody>{data.items.map(row=><tr key={row.id}><td><span className="feedback-kind">{feedbackKinds[row.kind]}</span><button className="feedback-subject text-btn" disabled={!!busy} onClick={()=>void open(row)}>{row.subject}</button><small>{row.name || 'Khách ẩn danh'}</small></td><td><span className={'feedback-status status-'+row.status}>{feedbackStatuses[row.status]}</span></td><td><time dateTime={row.createdAt}>{date(row.createdAt)}</time></td></tr>)}</tbody></table>{!data.items.length && <p className="feedback-empty">{status ? 'Chưa có phản hồi trong trạng thái này.' : 'Hộp thư đang trống. Góp ý mới sẽ xuất hiện tại đây.'}</p>}</div>
    <nav className="feedback-pagination" aria-label="Phân trang phản hồi"><button className="secondary" disabled={!!busy || data.page<=1} onClick={()=>setPage(data.page-1)}>Trang trước</button><span>Trang {data.page}/{data.pages}</span><button className="secondary" disabled={!!busy || data.page>=data.pages} onClick={()=>setPage(data.page+1)}>Trang sau</button></nav></>}
    {!data && error && <button className="secondary" onClick={()=>setRevision(n=>n+1)}>Tải lại hộp thư</button>}
    {detail && <section className="feedback-detail" aria-labelledby="feedback-detail-title"><div className="feedback-detail-heading"><span>{feedbackKinds[detail.kind]} · {feedbackStatuses[detail.status]}</span><button className="text-btn" disabled={!!busy} onClick={()=>{setDetail(null);setConfirm(false);heading.current?.focus();}}>Đóng nội dung</button></div>
      <h2 id="feedback-detail-title" tabIndex={-1} ref={detailHeading}>{detail.subject}</h2>
      <dl><div><dt>Người gửi</dt><dd>{detail.name || 'Khách ẩn danh'}</dd></div><div><dt>Email liên hệ</dt><dd>{detail.email || 'Không cung cấp'}</dd></div><div><dt>Gửi lúc</dt><dd>{date(detail.createdAt)}</dd></div></dl>
      <p className="feedback-letter">{detail.message}</p>
      <div className="feedback-detail-actions">{detail.status!=='resolved' && <button className="primary" disabled={!!busy} onClick={()=>void change('resolved')}>Đánh dấu đã xử lý</button>}{detail.status!=='unread' && <button className="secondary" disabled={!!busy} onClick={()=>void change('unread')}>Đánh dấu chưa đọc</button>}{detail.status==='resolved' && <button className="secondary" disabled={!!busy} onClick={()=>void change('read')}>Mở lại</button>}<button className="text-btn danger" disabled={!!busy} onClick={()=>setConfirm(true)}>Xóa phản hồi</button></div>
      {confirm && <div className="feedback-delete-confirm" role="alert"><p>Xóa phản hồi này khỏi hộp thư? Bạn không thể hoàn tác thao tác này.</p><button className="secondary danger" disabled={!!busy} onClick={()=>void change('delete')}>Xác nhận xóa</button><button className="text-btn" disabled={!!busy} onClick={()=>setConfirm(false)}>Giữ lại</button></div>}
    </section>}
  </section>;
}
