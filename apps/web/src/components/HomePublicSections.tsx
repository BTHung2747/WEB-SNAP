import Icon from './Icon';
import StudioReveal from './StudioReveal';

export function HomeIntro() { return (<div className="intro">
            <p className="eyebrow">Từ đường dẫn đến thiết bị</p>
            <h1>Giữ lại điều<br />{' '}bạn <em>thích.</em></h1>
            <p className="hero-copy">Tải video TikTok không logo, ảnh TikTok, video YouTube và nhạc MP3.<br />Lưu về điện thoại hay máy tính, với video tới 1080p từ nguồn.</p>
            <p className="intro-foot"><Icon name="check" /> Không cần tài khoản. Không ép xem quảng cáo.</p>
            <div className="link-illustration" aria-hidden="true">
              <span><Icon name="link" /><small>LINK</small></span><i /><span className="illustration-media"><Icon name="play" /><small>MEDIA</small></span><i /><span><Icon name="arrow" /><small>TỆP CỦA BẠN</small></span>
            </div>
          </div>); }

export function HomeGuide({ photoEnabled }: { photoEnabled?: boolean }) { return (<><section className="how" id="how">
          <div className="section-intro">
            <h2>Một link. Ba thao tác.</h2>
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
                photoEnabled === undefined
                  ? 'Tải video YouTube, video và từng ảnh TikTok không dính logo nền tảng, hoặc âm thanh MP3 khi có nguồn phù hợp. Giữ nguyên chữ và logo của tác giả. Video tối đa Full HD 1080p từ nguồn; không bảo đảm mọi liên kết đều tải được.'
                  : photoEnabled
                  ? 'MP4 công khai có hình và tiếng, từng ảnh JPG trong bài ảnh TikTok và âm thanh MP3 khi có nguồn phù hợp. Mỗi tác vụ chuẩn bị một tệp. Livestream, playlist và nội dung cần đăng nhập chưa được bật.'
                  : 'Hiện chỉ bật nền tảng đã qua kiểm chứng. MP4 công khai có hình và tiếng, cùng âm thanh MP3 khi có nguồn phù hợp; ảnh, livestream, playlist và nội dung cần đăng nhập chưa được bật.',
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
