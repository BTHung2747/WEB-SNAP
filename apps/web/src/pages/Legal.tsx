import type { Session } from '../types';
export default function Legal({ page, session }: { page: string; session: Session }) {
  const text: Record<
    string,
    {
      title: string;
      sections: [string, string][];
    }
  > = {
    privacy: {
      title: 'Quyền riêng tư',
      sections: [
        [
          'Phiên tải của bạn',
          'Cookie HttpOnly giữ quyền sở hữu tác vụ. Chúng tôi lưu metadata tác vụ, trạng thái và số byte cần thiết để xử lý và dọn tệp. Không yêu cầu cookie tài khoản mạng xã hội.',
        ],
        [
          'Lưu trữ có thời hạn',
          'Tệp chưa tải tự hết hạn sau tối đa 10 phút. Tác vụ và metadata hết hạn được dọn sau 24 giờ; sự kiện quảng cáo thô được giữ tối đa 30 ngày. Nhật ký quản trị được giữ để kiểm tra thay đổi.',
        ],
        [
          'Nội dung tài trợ',
          'Ảnh quảng cáo từ nguồn HTTPS của nhà tài trợ có thể gửi IP trình duyệt đến nguồn đó. Liên kết chỉ mở khi bạn chủ động nhấn. Thống kê nội bộ không xác nhận doanh thu bên ngoài.',
        ],
      ],
    },
    terms: {
      title: 'Điều khoản sử dụng',
      sections: [
        [
          'Quyền sử dụng nội dung',
          'Chỉ dùng đường dẫn công khai đến nội dung bạn sở hữu hoặc có quyền tải. Bạn chịu trách nhiệm tôn trọng quyền tác giả và điều khoản của nguồn.',
        ],
        [
          'Phạm vi hỗ trợ',
          'Không hỗ trợ nội dung riêng tư, yêu cầu đăng nhập, paywall, DRM, playlist hoặc livestream. Không cam kết mọi link đều tải được. Chất lượng phụ thuộc nguồn, không nâng chất lượng nhân tạo.',
        ],
        [
          'Tệp tạm và giới hạn',
          'Giới hạn local ban đầu: tối đa 10 phút, đầu ra 200 MiB. Hệ thống có thể tạm dừng nhận tải mới khi đạt giới hạn tài nguyên hoặc dữ liệu. Truyền xong từ máy chủ không chứng minh trình duyệt đã lưu tệp.',
        ],
      ],
    },
    report: {
      title: 'Báo cáo nội dung',
      sections: [
        [
          'Gửi thông tin rõ ràng',
          'Gửi URL bài đăng, mô tả vấn đề và bằng chứng quyền sở hữu hoặc quyền đại diện. Không gửi mật khẩu, cookie hay tài liệu chứa secret.',
        ],
        [
          'Kênh liên hệ',
          session.contact
            ? `Email chủ website: ${session.contact}`
            : 'Chủ website chưa cấu hình email liên hệ. Phải bổ sung kênh tiếp nhận trước khi mở công khai.',
        ],
      ],
    },
  };
  const d = text[page] || text.terms;
  return (
    <main className="legal">
      <a href="/" className="text-btn">
        ← Trở về trang tải
      </a>
      <span className="eyebrow">WED SNAP</span>
      <h1>{d.title}</h1>
      {d.sections.map(([h, p]) => (
        <section key={h}>
          <h2>{h}</h2>
          <p>{p}</p>
        </section>
      ))}
    </main>
  );
}
