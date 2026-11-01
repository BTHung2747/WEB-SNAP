import React, { useEffect, useRef, useState } from 'react';
import { api, ApiError } from '../lib/api';
import { names } from '../lib/platforms';
import type { Session } from '../types';
import AdminSupport from '../components/AdminSupport';
type AdStatistics = { window: { from: string; to: string; timezone: 'UTC' }; rows: { campaignId: string; title: string; impressions: number; clicks: number; ctrPercent: number | null }[] };
export default function Admin({ session }: { session: Session }) {
  const [logged, setLogged] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [tab, setTab] = useState('dashboard');
  const [dashboard, setDashboard] = useState<any>(null);
  const [settings, setSettings] = useState<any>(null);
  const [campaigns, setCampaigns] = useState<any[]>([]);
  const [draft, setDraft] = useState<any>(null);
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState('');
  const [statistics, setStatistics] = useState<AdStatistics | null>(null);
  const [statsLoading, setStatsLoading] = useState(false);
  const [statsError, setStatsError] = useState('');
  const [fromInput, setFromInput] = useState('');
  const [toInput, setToInput] = useState('');
  const statsVersion = useRef(0);
  const mounted = useRef(false);
  const version = useRef(0);
  const emailInput = useRef<HTMLInputElement>(null);
  const titleInput = useRef<HTMLInputElement>(null);
  const draftOpener = useRef<HTMLButtonElement | null>(null);
  const createButton = useRef<HTMLButtonElement>(null);
  const hadDraft = useRef(false);
  const focusAfterBusy = useRef<HTMLElement | null>(null);
  const activeTab = useRef<HTMLButtonElement>(null);
  const current = (v: number) => mounted.current && version.current === v;
  function invalidateStatistics() {
    ++statsVersion.current;
    setStatistics(null);
    setStatsLoading(false);
    setStatsError('');
  }
  function clearPrivate() {
    invalidateStatistics();
    setFromInput('');
    setToInput('');
    setLogged(false);
    setDashboard(null);
    setSettings(null);
    setCampaigns([]);
    setDraft(null);
    setPassword('');
    setNotice('');
    setTab('dashboard');
  }
  function failure(e: unknown, v: number, initial = false) {
    if (!current(v)) return;
    if (e instanceof ApiError && e.status === 403 && e.code === 'ADMIN_REQUIRED') {
      clearPrivate();
      setError(initial ? '' : 'Phiên quản trị đã hết hạn. Vui lòng đăng nhập lại.');
    } else setError((e as Error).message);
  }
  async function refresh(initial = false) {
    const v = ++version.current;
    invalidateStatistics();
    setBusy('refresh');
    setError('');
    try {
      const [d, s, c] = await Promise.all([
        api('admin/dashboard', session.csrf),
        api('admin/settings', session.csrf),
        api('admin/campaigns', session.csrf),
      ]);
      if (!current(v)) return;
      setDashboard(d);
      setSettings(s);
      setCampaigns(c);
      setLogged(true);
      if (tab === 'campaigns') void loadStatistics(fromInput, toInput);
    } catch (e) { failure(e, v, initial); }
    finally { if (current(v)) setBusy(''); }
  }
  // Every user operation supersedes earlier refreshes. Unmount invalidates all continuations.
  async function mutate(path: string, method: string, body: unknown, action: string, done: () => void, reload = true) {
    if (busy === action) return;
    if (document.activeElement instanceof HTMLElement && document.activeElement.closest('.admin')) focusAfterBusy.current = document.activeElement;
    const v = ++version.current;
    invalidateStatistics();
    setBusy(action);
    setError('');
    setNotice('');
    try {
      await api(path, session.csrf, method, body);
      if (!current(v)) return;
      done();
      if (reload) await refresh();
    } catch (e) { failure(e, v); }
    finally { if (current(v)) setBusy(''); }
  }
  useEffect(() => {
    mounted.current = true;
    void refresh(true);
    return () => { mounted.current = false; ++version.current; ++statsVersion.current; };
  }, []);
  useEffect(() => {
    if (logged && tab === 'campaigns') void loadStatistics(fromInput, toInput);
    return () => { ++statsVersion.current; };
  }, [logged, tab]);
  async function loadStatistics(from: string, to: string) {
    const v = version.current, sv = ++statsVersion.current;
    const valid = () => current(v) && statsVersion.current === sv;
    setStatistics(null);
    setStatsError('');
    if ((!!from !== !!to) || (from && (!Number.isFinite(Date.parse(from)) || !Number.isFinite(Date.parse(to)) || Date.parse(from) >= Date.parse(to) || Date.parse(to) - Date.parse(from) > 90 * 86400000))) {
      setStatsError('Nhập cả Từ và Đến bằng ISO có múi giờ, Từ < Đến, tối đa 90 ngày.');
      setStatsLoading(false);
      return;
    }
    setStatsLoading(true);
    try {
      const query = from ? '?' + new URLSearchParams({ from, to }).toString() : '';
      const data: AdStatistics = await api('admin/ad-statistics' + query, session.csrf);
      if (valid()) setStatistics(data);
    } catch (e) {
      if (!valid()) return;
      if (e instanceof ApiError && e.status === 403 && e.code === 'ADMIN_REQUIRED') failure(e, v);
      else setStatsError(e instanceof ApiError && e.code === 'INVALID_REQUEST' ? 'Khoảng thời gian không hợp lệ. Dùng ISO có múi giờ, ngày tồn tại và tối đa 90 ngày.' : (e as Error).message);
    } finally { if (valid()) setStatsLoading(false); }
  }
  useEffect(() => { if (!logged) emailInput.current?.focus(); else activeTab.current?.focus(); }, [logged]);
  useEffect(() => {
    if (!busy) {
      const target = focusAfterBusy.current;
      focusAfterBusy.current = null;
      if (target?.isConnected && !target.matches(':disabled')) target.focus();
    }
  }, [busy]);
  useEffect(() => {
    if (draft) titleInput.current?.focus();
    else if (hadDraft.current) (draftOpener.current?.isConnected ? draftOpener.current : createButton.current)?.focus();
    hadDraft.current = !!draft;
  }, [!!draft, draft?.id]);
  async function login(e: React.FormEvent) {
    e.preventDefault();
    await mutate('admin/login', 'POST', { email, password }, 'login', () => setPassword(''));
  }
  async function saveSettings(e: React.FormEvent) {
    e.preventDefault();
    await mutate('admin/settings', 'PUT', settings, 'save', () => setNotice('Đã lưu cấu hình.'));
  }
  const fresh = () => ({
    title: '',
    imageUrl: '',
    targetUrl: '',
    linkType: 'sponsored',
    placement: 'banner',
    enabled: false,
    startsAt: new Date().toISOString(),
    endsAt: new Date(Date.now() + 7 * 86400000).toISOString(),
    weight: 1,
  });
  async function saveCampaign(e: React.FormEvent) {
    e.preventDefault();
    const { id, ...rest } = draft;
    await mutate(`admin/campaigns${id ? '/' + id : ''}`, id ? 'PUT' : 'POST', {
      ...rest, imageUrl: rest.imageUrl || null,
    }, 'save', () => {
      focusAfterBusy.current = draftOpener.current || createButton.current;
      setDraft(null);
      setNotice('Đã lưu chiến dịch.');
    });
  }
  const numericLabels: Record<string, string> = {
    maxDuration: 'Thời lượng tối đa (giây)',
    maxBytes: 'Dung lượng đầu ra tối đa (byte)',
    maxInputBytes: 'Tổng dung lượng đầu vào tối đa (byte)',
    analyzeTimeout: 'Thời gian phân tích tối đa (giây)',
    prepareTimeout: 'Thời gian chuẩn bị tối đa (giây)',
    sessionTtl: 'Thời gian chờ duy trì phiên (giây)',
    releaseGrace: 'Thời gian chờ sau khi rời trang (giây)',
    readyTtl: 'Thời gian giữ tệp chưa tải (giây)',
    sweepSeconds: 'Chu kỳ dọn tệp (giây)',
    leaseTtl: 'Thời hạn lượt truyền (giây)',
    retryGrace: 'Thời gian cho phép tải tiếp (giây)',
    transferMax: 'Thời gian truyền tối đa (giây)',
    monthlyBytes: 'Ngân sách dữ liệu ra tháng (byte)',
    diskStopPercent: 'Ngừng nhận khi ổ đĩa đã dùng (%)',
    queueLimit: 'Số tác vụ tối đa',
  };
  const numericGroups = [
    { title: 'Nội dung và dung lượng', note: 'Giới hạn áp dụng cho từng tác vụ.', keys: ['maxDuration', 'maxBytes', 'maxInputBytes'] },
    { title: 'Thời gian xử lý', note: 'Giới hạn riêng cho hai giai đoạn lấy thông tin và chuẩn bị.', keys: ['analyzeTimeout', 'prepareTimeout'] },
    { title: 'Phiên, tệp và truyền tải', note: 'Phiên trang và lượt truyền tệp có vòng đời độc lập.', keys: ['sessionTtl', 'releaseGrace', 'readyTtl', 'sweepSeconds', 'leaseTtl', 'retryGrace', 'transferMax'] },
    { title: 'Ngân sách và hàng đợi', note: 'Ngưỡng bảo vệ tài nguyên vận hành.', keys: ['monthlyBytes', 'diskStopPercent', 'queueLimit'] },
  ];
  const numericHelp = (key: string, value: number): string => {
    const number = (n: number) => n.toLocaleString('vi-VN', { maximumFractionDigits: 2 });
    if (['maxBytes', 'maxInputBytes', 'monthlyBytes'].includes(key))
      return value >= 1073741824 ? `≈ ${number(value / 1073741824)} GiB` : `≈ ${number(value / 1048576)} MiB`;
    if (key === 'diskStopPercent') return 'Phần trăm ổ đĩa đã dùng';
    if (key === 'queueLimit') return 'Tác vụ trong hệ thống';
    return value >= 60 ? `≈ ${number(value / 60)} phút` : `${number(value)} giây`;
  };
  return (
    <main className={`admin${logged ? ' is-authenticated' : ' is-login'}`}>
      {logged && (
          <nav className="admin-tabs" aria-label="Điều hướng quản trị">
            {[
              ['dashboard', 'Tổng quan'],
              ['campaigns', 'Quảng cáo'],
              ['support', 'Ủng hộ'],
              ['settings', 'Cấu hình'],
            ].map(([key, label]) => (
              <button
                key={key}
                className={key === tab ? 'active' : ''}
                aria-pressed={key === tab}
                ref={key === tab ? activeTab : undefined}
                onClick={() => {
                  if (key !== tab) invalidateStatistics();
                  setTab(key);
                  setError('');
                  setNotice('');
                }}
              >
                {label}
              </button>
            ))}
            <button disabled={!!busy} onClick={() => void refresh()}>Làm mới ↻</button>
          </nav>
      )}
      <div className="admin-content">
      <div className="admin-heading">
        <div>
          <span className="admin-section-label">Không gian quản trị</span>
          <h1>{logged ? ({ dashboard: 'Tổng quan hoạt động', campaigns: 'Chiến dịch tài trợ', support: 'Thiết lập ủng hộ', settings: 'Cấu hình hệ thống' }[tab] || 'Quản lý WED SNAP') : 'Quản lý WED SNAP'}</h1>
          <p className="admin-subtitle">{logged ? 'Theo dõi tác vụ, quản lý tài trợ và cấu hình vận hành.' : 'Đăng nhập để quản lý hoạt động của hệ thống.'}</p>
        </div>
        {logged && (
          <button
            className="secondary"
            disabled={busy === 'logout'}
            onClick={() => void mutate('admin/logout', 'POST', undefined, 'logout', clearPrivate, false)}
          >
            Đăng xuất
          </button>
        )}
      </div>
      {busy && <p role="status">{busy === 'refresh' ? 'Đang tải dữ liệu…' : busy === 'login' ? 'Đang đăng nhập…' : busy === 'logout' ? 'Đang đăng xuất…' : 'Đang lưu thay đổi…'}</p>}
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}
      {notice && (
        <p className="success" role="status">
          {notice}
        </p>
      )}
      {!logged ? (
        <div className="admin-login-layout">
        <aside className="admin-login-intro">
          <span className="brand-icon" aria-hidden="true">w.</span>
          <h2>Quản lý hoạt động.<br />Giữ mọi thứ trong tầm nhìn.</h2>
          <p>Tổng quan tác vụ, chiến dịch tài trợ và các giới hạn hệ thống.</p>
          <p className="muted">Chỉ tài khoản quản trị được cấp quyền mới có thể truy cập. Không chia sẻ thông tin đăng nhập.</p>
        </aside>
        <form className="admin-login" onSubmit={login}>
          <h2>Đăng nhập quản trị</h2>
          <p className="muted">Sử dụng tài khoản quản trị của bạn.</p>
          <label>
            Email
            <input
              type="email"
              ref={emailInput}
              required
              autoComplete="username"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </label>
          <label>
            Mật khẩu
            <input
              type="password"
              minLength={12}
              required
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </label>
          <button className="primary" disabled={busy === 'login'}>Đăng nhập →</button>
        </form>
        </div>
      ) : (
        <>
          {tab === 'support' && !busy && <AdminSupport csrf={session.csrf} onAuthExpired={() => {
            ++version.current; clearPrivate(); setBusy('');
            setError('Phiên quản trị đã hết hạn. Vui lòng đăng nhập lại.');
          }} />}
          {tab === 'dashboard' && dashboard && (
            <>
              <div className="metrics">
                <article>
                  <span>Tác vụ</span>
                  <strong>{dashboard.groups.reduce((n: number, g: any) => n + g._count, 0)}</strong>
                </article>
                <article>
                  <span>Đang chờ / xử lý</span>
                  <strong>
                    {dashboard.queue.waiting} / {dashboard.queue.active}
                  </strong>
                </article>
                <article>
                  <span>Dữ liệu đã tính trong tháng</span>
                  <strong>
                    {(
                      (Number(
                        dashboard.budget.find(
                          (b: any) => b.month === new Date().toISOString().slice(0, 7),
                        )?.charged,
                      ) || 0) / 1048576
                    ).toFixed(1)}
                    <small> MiB</small>
                  </strong>
                </article>
              </div>
              <div className="admin-dashboard-grid"><section>
              <h2>Trạng thái tác vụ</h2>
              <div className="table-wrap" role="region" aria-label="Trạng thái tác vụ" tabIndex={0}>
                <table>
                  <thead>
                    <tr>
                      <th>Trạng thái</th>
                      <th>Số lượng</th>
                    </tr>
                  </thead>
                  <tbody>
                    {!dashboard.groups.length && <tr><td colSpan={2}>Chưa có tác vụ.</td></tr>}
                    {dashboard.groups.map((g: any) => (
                      <tr key={g.state}>
                        <td><span className={`job-state state-${g.state}`}>{({ready:'Sẵn sàng',selectable:'Chờ lựa chọn',failed:'Thất bại',analyzing:'Đang phân tích',queued:'Đang chờ',preparing:'Đang chuẩn bị',cancelled:'Đã hủy',expired:'Hết hạn'} as Record<string,string>)[g.state] || g.state}</span></td>
                        <td>{g._count}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              </section><section>
              <h2>Lỗi gần đây</h2>
              <div className="table-wrap" role="region" aria-label="Lỗi gần đây" tabIndex={0}>
                <table>
                  <thead>
                    <tr>
                      <th>Nền tảng</th>
                      <th>Mã lỗi</th>
                      <th>Thời điểm</th>
                    </tr>
                  </thead>
                  <tbody>
                    {!dashboard.failed.length && <tr><td colSpan={3}>Chưa có lỗi gần đây.</td></tr>}
                    {dashboard.failed.map((j: any) => (
                      <tr key={j.id}>
                        <td>{names[j.platform]}</td>
                        <td>{j.errorCode}</td>
                        <td>{new Date(j.updatedAt).toLocaleString('vi-VN')}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              </section></div>
              <p className="muted">
                Hệ thống tạm tính dung lượng trước mỗi lượt truyền. Nếu tiến trình dừng bất thường,
                khoản dự phòng vẫn được giữ để tránh đánh giá thấp ngân sách. Đây không phải số liệu tính phí của nhà cung cấp.
              </p>
            </>
          )}
          {tab === 'settings' && settings && (
            <form onSubmit={saveSettings}>
              <div className="settings-top">
                <label className="checkbox">
                  <input
                    type="checkbox"
                    checked={settings.acceptJobs}
                    onChange={(e) => setSettings({ ...settings, acceptJobs: e.target.checked })}
                  />
                  Nhận tác vụ mới
                </label>
                <p>Mỗi tiến trình tải xử lý 1 tác vụ tại một thời điểm.</p>
              </div>
              <h2>Nền tảng</h2>
              <div className="platform-toggles">
                {Object.entries(names).map(([id, name]) => (
                  <label key={id} className="checkbox">
                    <input
                      type="checkbox"
                      disabled={!dashboard.verified.includes(id)}
                      checked={settings.enabledPlatforms.includes(id)}
                      onChange={(e) =>
                        setSettings({
                          ...settings,
                          enabledPlatforms: e.target.checked
                            ? [...settings.enabledPlatforms, id]
                            : settings.enabledPlatforms.filter((p: string) => p !== id),
                        })
                      }
                    />
                    {name} {!dashboard.verified.includes(id) && <small>Chưa kiểm chứng</small>}
                  </label>
                ))}
              </div>
              <h2>Giới hạn vận hành</h2>
              {numericGroups.map((group) => <fieldset className="settings-group" key={group.title}>
                <legend>{group.title}</legend><p className="muted">{group.note}</p>
                <div className="settings-grid">
                {group.keys.map((key) => (
                  <label key={key} className="settings-field">
                    <span>{numericLabels[key]}</span>
                    <input
                      type="number"
                      min={0}
                      required
                      value={settings[key]}
                      onChange={(e) => setSettings({ ...settings, [key]: Number(e.target.value) })}
                    />
                    <small>{numericHelp(key, settings[key])}</small>
                  </label>
                ))}
                </div>
              </fieldset>)}
              <div className="settings-save"><p className="muted">Các thay đổi chỉ được áp dụng khi bạn lưu.</p><button className="primary" disabled={!!busy}>Lưu cấu hình</button></div>
            </form>
          )}
          {tab === 'campaigns' && (
            <>
              <div className="row-heading">
                <h2>Chiến dịch tài trợ</h2>
                <button className="primary" ref={createButton} disabled={!!busy} onClick={(e) => { draftOpener.current = e.currentTarget; setNotice(''); setError(''); setDraft(fresh()); }}>
                  + Tạo chiến dịch
                </button>
              </div>
              <p className="muted">
                Impression, click và CTR là thống kê nội bộ; không phải doanh thu hoặc lượt xem
                YouTube.
              </p>
              <form className="ad-window" onSubmit={(e) => { e.preventDefault(); void loadStatistics(fromInput.trim(), toInput.trim()); }}>
                <label>Từ (ISO có múi giờ)<input type="text" maxLength={64} placeholder="2026-01-01T00:00:00Z" value={fromInput} onChange={(e) => setFromInput(e.target.value)} /></label>
                <label>Đến (ISO có múi giờ)<input type="text" maxLength={64} placeholder="2026-01-02T00:00:00Z" value={toInput} onChange={(e) => setToInput(e.target.value)} /></label>
                <button className="secondary" disabled={!!busy}>Xem thống kê</button>
                <button type="button" className="text-btn" disabled={!!busy} onClick={() => { setFromInput(''); setToInput(''); void loadStatistics('', ''); }}>7 ngày gần nhất</button>
              </form>
              <p className="muted">Khoảng [Từ, Đến), tối đa 90 ngày. Bỏ cả hai để xem 7 × 24 giờ gần nhất; lịch chạy chiến dịch độc lập với thời điểm sự kiện.</p>
              {statsLoading && <p role="status">Đang tải thống kê…</p>}
              {statsError && <p className="error" role="alert">{statsError}</p>}
              {statistics && <p className="ad-window-label">UTC: {statistics.window.from} → {statistics.window.to} (không gồm Đến)</p>}
              {statistics && statistics.rows.every((r) => r.impressions === 0 && r.clicks === 0) && <p role="status">Không có sự kiện trong khoảng này.</p>}
              <div className="table-wrap" role="region" aria-label="Chiến dịch tài trợ" tabIndex={0}>
                <table>
                  <thead>
                    <tr>
                      <th>Chiến dịch</th>
                      <th>Vị trí</th>
                      <th>Impression</th>
                      <th>Click / CTR</th>
                      <th>Trạng thái</th>
                      <th>Thao tác</th>
                    </tr>
                  </thead>
                  <tbody>
                    {!campaigns.length && <tr><td colSpan={6}>Chưa có chiến dịch.</td></tr>}
                    {campaigns.map((c) => {
                      const row = statistics?.rows.find((r) => r.campaignId === c.id);
                      return (
                        <tr key={c.id}>
                          <td>{c.title}</td>
                          <td>{c.placement}</td>
                          <td>{row ? row.impressions : '-'}</td>
                          <td>
                            {row ? row.clicks : '-'} / {row?.ctrPercent == null ? '-' : row.ctrPercent.toFixed(1) + '%'}
                          </td>
                          <td><span className={`campaign-status${c.enabled ? ' enabled' : ''}`}>{c.enabled ? 'Bật' : 'Tắt'}</span></td>
                          <td>
                            <button
                              className="text-btn"
                              disabled={!!busy}
                              onClick={(e) => {
                                draftOpener.current = e.currentTarget;
                                setNotice(''); setError('');
                                setDraft({
                                  id: c.id,
                                  title: c.title,
                                  imageUrl: c.imageUrl || '',
                                  targetUrl: c.targetUrl,
                                  linkType: c.linkType,
                                  placement: c.placement,
                                  enabled: c.enabled,
                                  startsAt: c.startsAt,
                                  endsAt: c.endsAt,
                                  weight: c.weight,
                                });
                              }}
                            >
                              Sửa
                            </button>
                            <button
                              className="text-btn danger"
                              disabled={!!busy}
                              onClick={() => void mutate('admin/campaigns/' + c.id, 'DELETE', undefined, 'save', () => {})}
                            >
                              Xóa
                            </button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
              {draft && (
                <form className="campaign-form" onSubmit={saveCampaign}>
                  <h2>{draft.id ? 'Sửa chiến dịch' : 'Chiến dịch mới'}</h2>
                  <div className="settings-grid">
                    {[
                      ['title', 'Tiêu đề', 'text'],
                      ['targetUrl', 'URL đích HTTPS', 'url'],
                      ['imageUrl', 'URL banner HTTPS (tùy chọn)', 'url'],
                      ['weight', 'Trọng số', 'number'],
                    ].map(([key, label, type]) => (
                      <label key={key}>
                        {label}
                        <input
                          type={type}
                          ref={key === 'title' ? titleInput : undefined}
                          required={key !== 'imageUrl'}
                          value={draft[key]}
                          onChange={(e) =>
                            setDraft({
                              ...draft,
                              [key]: type === 'number' ? Number(e.target.value) : e.target.value,
                            })
                          }
                        />
                      </label>
                    ))}
                    <label>
                      Vị trí
                      <select
                        value={draft.placement}
                        onChange={(e) => setDraft({ ...draft, placement: e.target.value })}
                      >
                        <option value="banner">Banner</option>
                        <option value="sponsor">Hộp tài trợ</option>
                      </select>
                    </label>
                    <label>
                      Loại liên kết
                      <select
                        value={draft.linkType}
                        onChange={(e) => setDraft({ ...draft, linkType: e.target.value })}
                      >
                        <option value="sponsored">Tài trợ</option>
                        <option value="affiliate">Affiliate</option>
                      </select>
                    </label>
                    {[
                      ['startsAt', 'Bắt đầu'],
                      ['endsAt', 'Kết thúc'],
                    ].map(([key, label]) => (
                      <label key={key}>
                        {label}
                        <input
                          type="datetime-local"
                          required
                          value={new Date(
                            new Date(draft[key]).getTime() -
                              new Date(draft[key]).getTimezoneOffset() * 60000,
                          )
                            .toISOString()
                            .slice(0, 16)}
                          onChange={(e) => {
                            if (e.target.value)
                              setDraft({ ...draft, [key]: new Date(e.target.value).toISOString() });
                          }}
                        />
                      </label>
                    ))}
                  </div>
                  <label className="checkbox">
                    <input
                      type="checkbox"
                      checked={draft.enabled}
                      onChange={(e) => setDraft({ ...draft, enabled: e.target.checked })}
                    />
                    Bật chiến dịch trong lịch chạy
                  </label>
                  <div className="form-actions">
                    <button className="primary" disabled={!!busy}>Lưu chiến dịch</button>
                    <button type="button" className="secondary" onClick={() => setDraft(null)}>
                      Đóng
                    </button>
                  </div>
                </form>
              )}
            </>
          )}
        </>
      )}
      </div>
    </main>
  );
}

