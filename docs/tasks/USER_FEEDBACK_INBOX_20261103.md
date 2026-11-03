# Trang góp ý và hộp thư quản trị — 03/11/2026

## Phạm vi người dùng giao

Thêm trang cho khách góp ý/báo lỗi/đề xuất, nhận ở email hoặc quản trị. Chọn **hộp thư quản trị lưu PostgreSQL** làm nơi nhận chính vì package/lock và API hiện chưa có SMTP/mail provider. Không cần thêm dịch vụ trả phí hay giả thông báo đã gửi email. Có thể dùng liên kết email liên hệ hiện có như cách gửi trực tiếp, không coi đó là backend gửi mail.

## Sản phẩm cần thực hiện

- Trang `/gop-y` có liên kết công khai phù hợp trong header/footer. Theo giao diện đã duyệt và Taste Skill; không redesign trang tải hoặc modal video/ảnh.
- Lời mời thân thiện: “WED SNAP tốt hơn nhờ góp ý của bạn. Nếu gặp trục trặc hoặc có một ý tưởng hay, hãy để lại lời nhắn cho mình.” Loại góp ý/báo lỗi/đề xuất; chủ đề và nội dung rõ ràng. Tên/email trả lời tùy chọn; nội dung bắt buộc, giới hạn và thông báo dễ hiểu. Có loading, gửi thành công sau backend nhận, lỗi/rate limit; giữ nội dung khi gửi lỗi.
- Tab **Phản hồi** trong admin cạnh các tab hiện có: danh sách phân trang, phân biệt chưa đọc/đã đọc/đã xử lý, mở nội dung, đánh dấu và xóa. Chỉ admin đăng nhập đọc/quản lý; không thêm đường dẫn admin ở public.
- Lưu thư thành bản ghi riêng, migration bổ sung, không nhét nội dung vào Settings/AuditLog hoặc phụ thuộc vòng đời download job/session. Không tự trả lời email hoặc mở form upload.
- Tái sử dụng NestJS/Prisma/Zod/Redis và helpers xác thực, CSRF, trusted client identity, rate limit hiện có. Giới hạn chặt fields/body/message và tần suất theo session/IP; không lưu raw IP hay log nội dung/email. Có hạn mức lưu trữ hợp lý và cách xóa, tránh endpoint spam ghi không giới hạn. Giải thích chính xác hạn mức chọn trong handoff, không tạo framework chống spam mới.
- Nội dung plain text, không HTML/markdown thực thi; React escaping, query Prisma có kiểu, UUID/pagination/status validation. Không tự fetch liên kết người dùng gửi. Lỗi không lộ nội dung, địa chỉ hoặc stack. Hộp thư/email không công khai cho khách khác.
- Mô tả riêng tư ngắn: chỉ quản trị đọc nội dung và email để xử lý/liên hệ, không gửi mật khẩu/cookie/thông tin nhạy cảm; cập nhật trang privacy/API khi cần. Chốt chính sách giữ/xóa phù hợp, không hứa cơ chế chưa có.

## Triển khai và kiểm chứng

Code giao chat “code tay to” hiện hữu. Đọc AGENTS/CURRENT rồi đúng component; kiểm dependency/lock/API chính thức trước dùng, không thêm mail provider/framework/dependency khi stack đã đáp ứng. Giữ React/Vite/Tailwind và các luồng tải/auth/CSRF/lease đang hoạt động. Root sở hữu task/PLAN/CURRENT.

Chỉ kiểm cần thiết: validation/CSRF/admin authorization/rate limiting và lưu–list–đọc–đánh dấu–xóa qua API thật với DB/schema cô lập đã migrate; không dùng fixture làm chứng cứ DB thật. Dùng recipe sẵn có nếu cần, không thêm harness/lab framework. Một lượt type/build phù hợp sau thay đổi, không full suite media hoặc nguồn YouTube/TikTok. Kiểm UI desktop/màn hẹp/bàn phím/focus và trạng thái lỗi/thành công, ghi rõ fixture hay backend thật. Không kiểm lại MP3 hoặc nguồn đã đạt.

Không commit/CI/push/build image/deploy hay thao tác settings/dữ liệu production trong task này. Cung cấp diff/file list, migration/rollout note, lệnh thực chạy/kết quả, ảnh giao diện và giới hạn còn thiếu. Nếu gặp lỗi, tìm nguyên nhân cụ thể, không thêm vòng test hoặc xin quyền nguồn không liên quan. Xong bàn giao và dừng để root nghiệm thu.

## Trạng thái

03/11: **đã thực hiện và nghiệm thu chức năng local**. [Root review](../../lab-runs/feedback-inbox-20261103/ROOT_REVIEW.md) đối chiếu 24 source pins/27 artifacts, đọc diff và kết quả API thật với DB/Redis cô lập, ảnh desktop/mobile. Public form và admin inbox lưu–đọc–xử lý–xóa đạt; final type/build và focused JSON-only check đạt. Không chạy lại test/nguồn đã khép. Handoff coder và migration/rollout note nằm cùng thư mục review.

Chưa commit/CI/deploy hoặc migrate production. Trước rollout cần backup, migrate additive trước API mới và native Caddy validate trên image ứng viên; cache hiện không có binary/image Caddy phù hợp nên root chưa chạy bước này. Smoke HTTPS `/gop-y` sau cập nhật còn thiếu. Không SMTP; thư nhận trong admin. Lỗi YouTube production riêng vẫn chờ dữ liệu VPS.
