import Icon from './Icon';
import StudioReveal from './StudioReveal';

export function HomeIntro() { return (<div className="intro">
            <p className="eyebrow">Từ đường dẫn đến thiết bị</p>
            <h1>Giữ lại điều<br />{' '}bạn <em>thích.</em></h1>
            <p className="hero-copy">Tải video TikTok, Facebook, X và YouTube tới 1080p theo nguồn. Video TikTok không logo. Tải riêng ảnh TikTok và MP3 khi nguồn hỗ trợ.</p>
            <p className="intro-foot"><Icon name="check" /> Không cần tài khoản. Không ép xem quảng cáo.</p>
            <div className="link-illustration" aria-hidden="true">
              <span><Icon name="link" /><small>LINK</small></span><i /><span className="illustration-media"><Icon name="play" /><small>MEDIA</small></span><i /><span><Icon name="arrow" /><small>TỆP CỦA BẠN</small></span>
            </div>
          </div>); }

export function HomeGuide({ photoEnabled }: { photoEnabled?: boolean }) {
  const formatSupport = [
    'Tải MP4 từ video công khai trên TikTok, YouTube, Facebook (gồm Reels) và bài X có một video.',
    'Video TikTok không dính logo nền tảng và giữ chữ, logo có sẵn của tác giả.',
    photoEnabled === false ? 'Tải ảnh TikTok hiện chưa được bật.' : 'Tải từng ảnh JPG trong bài ảnh TikTok.',
    'Có MP3 từ TikTok, Facebook và YouTube khi nguồn hỗ trợ âm thanh. Video tối đa 1080p theo nguồn.',
    'Mỗi tác vụ chuẩn bị một tệp. Chưa hỗ trợ livestream, playlist và nội dung cần đăng nhập.',
  ].join(' ');
  return (<><section className="how" id="how">
          <div className="section-intro">
            <h2>Một link. Ba thao tác.</h2>
          </div>
          <StudioReveal className="steps">
            {[
              {
                icon: 'link',
                title: 'Dán đường dẫn',
                text: 'Sao chép link công khai từ TikTok, Facebook, X hoặc YouTube rồi dán vào ô phía trên.',
              },
              {
                icon: 'play',
                title: 'Chọn nội dung',
                text: photoEnabled === false
                  ? 'Xem trước rồi chọn video hoặc MP3 tùy nội dung nguồn cung cấp.'
                  : 'Xem trước rồi chọn video, ảnh hoặc MP3 tùy nội dung nguồn cung cấp.',
              },
              {
                icon: 'arrow',
                title: 'Lưu khoảnh khắc',
                text: 'Nhấn chuẩn bị, rồi tải xuống khi tệp thực sự sẵn sàng.',
              },
            ].map((s) => (
              <article key={s.title}>
                <span className="step-icon">
                  <Icon name={s.icon} />
                </span>
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
                formatSupport,
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
        </section></>); }
