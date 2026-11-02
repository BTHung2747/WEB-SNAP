import { HomeIntro, HomeGuide } from '../components/HomePublicSections';
import Icon from '../components/Icon';

/** Public copy has no job hooks, fake session, CSRF, ads or download requests. */
export default function PublicHome({ error = '' }: { error?: string }) {
  return <main className="studio-home" data-state="idle">
    <section className="hero">
      <HomeIntro />
      <div className="download-card">
        <div className="tool-title"><span>Công cụ tải nội dung</span><span>MP4 / JPG</span></div>
        <h2>Link của bạn. Tệp bạn cần.</h2>
        <label htmlFor="video-url">Đường dẫn video hoặc bài ảnh công khai</label>
        <div className="url-row"><Icon name="link" /><input id="video-url" type="url" placeholder="Dán đường dẫn tại đây…" disabled /><button className="paste" disabled>Dán</button></div>
        <button className="primary analyze" disabled>Phân tích link<span aria-hidden="true">↗</span></button>
        <p role="status">{error || 'Đang kết nối công cụ tải…'}</p>
        {error && <button className="text-btn" onClick={() => location.reload()}>Thử lại</button>}
        <div className="card-note"><Icon name="shield" /> Chỉ tải nội dung bạn sở hữu hoặc được phép sử dụng.</div>
        <p className="support-note" id="support">Video YouTube, video và ảnh TikTok. Khả năng nhận tác vụ sẽ được xác nhận khi kết nối.</p>
      </div>
    </section>
    <HomeGuide />
  </main>;
}
