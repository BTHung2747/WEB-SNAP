# WED SNAP: hai hướng giao diện, concept v1

Ngày 15/10/2026, cập nhật 16/10/2026. Chủ đã chọn **A, Studio sáng**; source Home/shared shell trong `apps/web` đã tích hợp và đang chờ review offline, chưa backend combined/main/deploy. [Bàn giao tích hợp](../../docs/evidence/ui-a-app-integration-20261016/HANDOFF.md). Các mốc prototype bên dưới giữ làm lịch sử; motion đã PASS độc lập với giới hạn reduced runtime ngày16/10.

## Hướng đã chốt

Lấy A làm cơ sở cho bước tích hợp tiếp theo: nền sáng, chữ than, điểm nhấn cam cháy, desktop hai cột lệch và mobile ưu tiên form. B được giữ làm phương án tham chiếu. Việc chọn hướng không thay kết quả kiểm prototype hoặc kết luận backend; tích hợp ứng dụng là bước tiếp theo theo phạm vi được giao.

## Đề xuất

### Cập nhật motion A ngày 15/10/2026 — chờ review độc lập

Theo nhiệm vụ `docs/evidence/ui-a-studio-audit-20261015/TASK_ANIMATION.md`, chỉ A nạp thêm `a/motion.css` và `a/motion.js`; không đổi CSS/JS chung hay B. Giữ palette/layout và dials 6/3/5. Taste Skill được áp dụng ở mức chuyển động nhỏ, có mục đích, không thêm engine/dependency.

Nhịp: tương tác 180ms; khối kết quả 220ms/dịch 4px; entry intro/form/tiêu đề admin 400ms/dịch 6px/opacity .96→1; reveal nhóm hướng dẫn/admin 360ms, một lần mỗi trang, stagger tối đa 70ms. Form chỉ lệch entry 40ms, vẫn thao tác ngay; focus trong form dừng entry. Focus ring tức thì, hover chỉ cho con trỏ chính xác, nhấn dịch 1px. Không animate kích thước, không lặp, không progress hoặc thời gian tải giả.

CSS mặc định giữ nội dung hiện; `IntersectionObserver` chỉ gắn reveal một lần và ngừng theo dõi nhóm đã thấy. Thiếu JS/observer vẫn hiện nội dung. `prefers-reduced-motion: reduce` tắt animation/transition/cuộn mượt; listener dừng observer khi đổi tùy chọn. Không chạm logic trạng thái/focus/aria-live trong demo. Tài liệu API và kết quả kiểm nằm ở [bàn giao motion](../../docs/evidence/ui-a-motion-v1-20261015/HANDOFF.md).

Đã kiểm browser thực tại viewport 1440×900, 375×812, 390×844; luồng mẫu/video/ảnh/chuẩn bị/hủy, ready/failed/expired/queued/analyzing, đổi nhanh 16 trạng thái, focus nút và reveal. Quan sát được transform đang chạy rồi về none. Reduced-motion **chỉ kiểm guard nguồn và mock listener, chưa emulation runtime**. Ảnh tĩnh không chứng minh độ mượt/FPS. Các mục kiểm A/B bên dưới là baseline lịch sử trước motion; không dùng lại chúng làm kết quả mới. Chưa tích hợp app/backend hay deploy.

Chọn **A, Studio sáng** làm cơ sở cho trang tải công khai. Form tách khỏi phần giới thiệu, nhãn và viền rõ hơn bản cũ, màu cam tạo nhận diện riêng. A cũng phù hợp với người dùng mở nhanh công cụ trên điện thoại. **B, Studio tối** hợp người dùng thích một không gian thao tác ổn định: thanh nhập nằm trên, vùng kết quả nằm dưới, điều hướng bên trên desktop. B thay bố cục và thứ bậc, không phải bản đổi màu của A.

Mở [index A/B](index.html), [A](a/index.html), [B](b/index.html), [mobile A](preview.html?theme=a), [mobile B](preview.html?theme=b). Máy chủ xem mẫu hiện tại: `http://127.0.0.1:4318/`. Có thể mở trực tiếp HTML trên máy khi máy chủ dừng; link preview hiện tại chỉ phục vụ loopback.

## Chẩn đoán bản trước

Đã xem đủ 12 ảnh trong `docs/evidence/ui-current-capture-20261015/` và đọc Home, Legal, Admin, Header, Footer cùng các styles tương ứng.

- Khoảng trống phía trên và hero đặt giữa khiến form xuất hiện muộn; thông điệp lớn nhưng ít nhận diện công cụ.
- Chữ phụ, trạng thái nền tảng và viền input quá nhẹ; nhiều thành phần có trọng lượng thị giác gần nhau.
- Dãy ba khối hướng dẫn và nhịp thẻ đồng đều làm trang giống một mẫu landing chung.
- Luồng chọn, chuẩn bị, tải; trạng thái chờ/lỗi; đường về và pháp lý có giá trị, cần giữ khi tích hợp.

Phần tốt về lifecycle và bảo mật đã nghiệm thu không thuộc phạm vi concept này.

## Hướng A: Studio sáng

Design Read: công cụ nội dung công khai cho người dùng phổ thông, ngôn ngữ trực tiếp, studio sáng có độ tương phản cao. Dials: DESIGN_VARIANCE 6, MOTION_INTENSITY 3, VISUAL_DENSITY 5.

Desktop dùng lưới hai cột lệch 0.82/1.18: ngữ cảnh bên trái, khối nhập nổi bên phải. Khi có kết quả, tiêu đề thừa trong form được thu gọn; kết quả trải thành hàng riêng với minh họa và lựa chọn. Hướng dẫn chuyển sang danh sách dọc bên phải, không dùng ba thẻ bằng nhau.

Mobile chuyển về một cột. Tiêu đề giảm còn 40px, form và nút phân tích hiện trong màn đầu 390 × 844. Bỏ phần nhắc quyền lợi trùng lặp ở cột trái. Các trạng thái dùng cùng vị trí kết quả để giữ định hướng.

## Hướng B: Studio tối

Design Read: bàn thao tác media gọn cho người dùng phổ thông, nền than và điểm nhấn bạc hà. Dials: DESIGN_VARIANCE 7, MOTION_INTENSITY 3, VISUAL_DENSITY 5.

Desktop có rail 192px, thanh nhập ngang và nút phân tích ở bên phải. Khối kết quả là một workspace liên tục, luôn có nhãn; ví dụ video/ảnh là các điều khiển thật của prototype. Thông tin nền tảng được chuyển xuống dưới kết quả. Mobile gỡ rail và giữ tên/đường quản trị trên hàng đầu, thanh nhập và nút xếp dọc.

## Tokens

| Vai trò | A | B |
| --- | --- | --- |
| Nền | `#f7f4ee` | `#141b18` |
| Bề mặt | `#fffefa` | `#1c2520` |
| Chữ chính | `#29241f` | `#eff4ef` |
| Chữ phụ | `#6c6258` | `#a7b9ad` |
| Điểm nhấn | `#b63d18` | `#91e5b7` |
| Chữ trên nút chính | `#fffefa` | `#11251a` |
| Viền điều khiển | `#8f8478` | `#73887a` |

Mỗi hướng giữ một theme xuyên suốt. Không thêm nút tự đổi sáng/tối trong concept so sánh. Palette ấm của A đến trực tiếp từ brief, không phải lựa chọn mặc định của skill.

Font: `Segoe UI Variable`, `Segoe UI`, Arial, sans-serif có sẵn trên máy; không tải font/CDN. Không cài font mới hoặc giả định font web bản quyền đã được cung cấp. Heading A 42-65px desktop/40px mobile; B 48px/35px. Nội dung dùng phân cấp 12-17px, tiêu đề 650-750; số liệu bật tabular figures. Tích hợp thực tế vẫn cần xác nhận font trên Android/iOS.

Spacing theo nhịp 4/8: 12, 16, 24, 32, 48, 64. Khung tối đa 1280px. Mobile gutter 18px. Radius có quy tắc: khung ngoài 16-24px, điều khiển 8-10px, badge 4-5px. Baseline A/B chỉ có hover/active và cuộn anchor; A nay có lớp motion riêng như cập nhật ở trên, B giữ nguyên.

## Dữ liệu mẫu và tương tác

Bộ chọn đầu trang có: idle, analyzing, chọn video, chọn ảnh, queued, preparing, ready, failed, cancelled, expired. `video` và `photo` là hai cách trình bày của trạng thái nghiệp vụ `selectable`; không đề xuất thay enum ứng dụng. Các trạng thái không tự chuyển để người xem chủ động so sánh.

Form kiểm URL cơ bản tại trình duyệt. “Dùng mẫu” điền URL mẫu, “Phân tích” chuyển UI cục bộ; không gọi URL đã nhập. Đổi ảnh cập nhật CTA, chuẩn bị khóa input, hủy hiện thông báo; nút tải mẫu chỉ báo đã thử. Đây không phải mô phỏng backend đã hoàn thành, không có stream, ticket hoặc lease thật.

Ảnh trong component mẫu được sao chép nguyên byte từ bằng chứng lịch sử `docs/evidence/tiktok-photo-source-trial-v4-live-20261013/source-task/task-cf3808fc328743369a848f3bb5a5495e/b8f3a0d86c51490383c87fc925c876da/worker/image.jpg`, SHA256 `7fc4899a9e249f93789724dd036852110f360eb570b4b85539fb38ebdde1f0d2`. Không gọi nguồn mới. Chú thích ngay dưới ảnh nói rõ đây là minh họa concept, không phải thumbnail được API cung cấp. Khi tích hợp, chỉ hiện preview được contract cho phép; nhánh ảnh hiện tại không có thumbnail, nên có thể bỏ vùng minh họa mà không thêm CDN GET/gallery. Ảnh lịch sử này không phải tài sản marketing/brand được đề xuất đưa lên production.

Trạng thái nền tảng và tất cả số liệu admin đều có nhãn mẫu. TikTok vẫn ghi chưa bật. Quản trị chỉ dựng Tổng quan; Quảng cáo/Cấu hình là nhãn không tương tác, chưa dựng lại biểu mẫu. Trang pháp lý chỉ có trích đoạn nguyên văn và đường về, không thay bản pháp lý ứng dụng. Không thể hiện quảng cáo trong concept; khi tích hợp vẫn giữ nhãn/đóng và không cản tải.

## Kiểm tra baseline A/B đã chạy trước motion (lịch sử)

Browser thực qua Codex in-app browser, tuần tự, loopback static server. Ảnh JPEG toàn trang trực tiếp từ browser; viewport 1440 × 900 và 390 × 844, kiểm thêm 375 × 812. Browser có scrollbar 15px, vì vậy clientWidth có thể nhỏ hơn viewport; cả hai được lưu trong evidence.

- 66 trường hợp bố cục riêng biệt: 10 trạng thái trang tải cùng admin cho A/B tại 1440, 390, 375. Không tràn ngang hoặc ảnh hỏng; nút/input/select hiển thị có chiều cao ít nhất 44px.
- Đã thao tác chọn ảnh, cập nhật CTA, chuẩn bị, hủy, nhấn tải mẫu, gửi form bằng Enter và lỗi protocol. Chọn bằng bàn phím, focus ring, skip-link được kiểm bằng DOM trạng thái và ảnh focus.
- Đo 12 cặp token: CTA A 5.67:1, B 10.81:1; chữ phụ trên nền A 5.43:1, B 8.49:1; viền input A 3.33:1, B 4.61:1.
- Không có animation tự chạy. Browser đọc được guard reduced motion; chưa ép thay đổi tùy chọn chuyển động của hệ điều hành.
- Syntax JS dùng `node --check`, không bundle/build ứng dụng. Không Docker, install, API/media/source E2E, deploy, Lighthouse, screen reader hoặc thiết bị cảm ứng thật.

Đây là kiểm tra cơ bản cho concept, chưa tuyên bố full WCAG hay hiệu năng production. Xem `docs/evidence/ui-redesign-v1-20261015/browser-checks.json` và gallery ảnh.

## Tệp và bản đồ tích hợp sau khi chọn

| Prototype | Vai trò | Chuyển về ứng dụng sau khi chủ chọn |
| --- | --- | --- |
| `a/index.html`, `b/index.html` | Bố cục Home, nhập link, hướng dẫn | `apps/web/src/pages/Home.tsx` |
| `prototype.js` | Bộ trạng thái và thao tác mẫu | Không chép vào app; giữ hooks/API thật |
| `a/admin.html`, `b/admin.html`, `admin.js` | Màn Tổng quan | Phần dashboard trong `apps/web/src/pages/Admin.tsx` |
| `legal.html`, `legal.js` | Trích đoạn tham chiếu | Giữ nội dung đầy đủ trong `apps/web/src/pages/Legal.tsx` |
| `studio.css` | Tokens và component styles A/B | `style.css`, `styles/home.css`, `admin.css`, `layout.css`, `legal.css`, `responsive.css` |
| Header/footer/rail trong HTML | Nhận diện và điều hướng | `components/Header.tsx`, `Footer.tsx`; giữ route hiện hành |
| `assets/mark.svg` | Favicon concept, wordmark hình học đơn giản | Chủ duyệt nhận diện trước khi thay logo |
| `assets/sample.jpg` | Minh họa nội dung concept | Không tích hợp tự động |
| `index.html`, `preview.html`, `preview.js` | So sánh A/B và khung mobile | Chỉ dùng để review, không đưa vào ứng dụng |
| `preview-server.cjs` | Máy chủ static loopback | Chỉ phục vụ concept |
| `DESIGN.md` | Bàn giao thiết kế | Tài liệu tham chiếu |

Không thay React 19.1.1/Vite 7.3.6/Tailwind 3.4.17 hay lockfile. Đã đối chiếu package/lock hiện có; native controls, CSS Grid và các API DOM đủ cho concept, không cần thư viện UI mới. Mã demo không phải implementation lại nghiệp vụ tải.

Khi tích hợp, giữ `useJobLifecycle`, `useDownloadLink`, `useSession`, idempotency, CSRF, liên kết tải native và quan hệ độc lập phiên/job/transfer lease. Contract cần thay phải được điều phối trước. Không lấy việc chọn hướng làm quyền bật nền tảng hay chạy nguồn.

## Skill và nguồn tham khảo

Taste Skill dự án `.agents/skills/design-taste-frontend/SKILL.md` được dùng để audit trước, loại hero giữa/ba thẻ đều, khóa palette và shape, kiểm focus/contrast/mobile. Các quy tắc marketing không phù hợp admin, ảnh quảng bá hay hiệu ứng nặng không áp vào công cụ này.

Đã đọc [redesign-existing-projects chính chủ](https://github.com/Leonxlnx/taste-skill/blob/main/skills/redesign-skill/SKILL.md) ngày 15/10/2026, tham khảo audit typography/layout/states và giữ stack. Không cài hoặc ghi đè skill. Hướng dẫn dự án và brief được ưu tiên khi khác nội dung tham khảo.
