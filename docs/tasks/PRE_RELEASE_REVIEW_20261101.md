# Rà soát trước phát hành — 01/11/2026

Chủ duyệt bố cục mới và yêu cầu rà lỗi/tối ưu, đồng thời giao phía API tìm lỗ hổng. Root kiểm UI/infra; code tay to review API/bảo mật riêng. Đây là review mã/bản local, không là pentest hoặc xác nhận bản production đã cập nhật.

## UI QR: nhận delta, chưa thấy lỗi chặn mới

Đọc Support.tsx/AdminSupport.tsx/support.css/API helper/SupportQr và handoff [UI bố cục mới](../evidence/support-qr-layout-20261101/ui/HANDOFF.md). Delta chỉ ba file trình bày; route, bảy trường PUT, CSRF, native QR download, copy fallback, pending→Lưu giữ cách hoạt động đã nghiệm thu. Text API được render bằng React text; QR URL chỉ relative đúng prefix + SHA64, không HTML/URL tùy ý. Không dependency mới hoặc yêu cầu thêm API.

Root xem ảnh desktop và 320px; tái dùng build/typecheck exit0 và responsive 320/390, download/copy44px trong handoff. Thực chạy git diff --check ba file UI exit0. Root CUA mở 5202/ung-ho thấy asset index-BfLrO2ud.js đúng bản mới, QR load thật trong fixture, page1265≤viewport1280; không upload/Lưu/tải/nguồn lại. Link trợ năng nằm ngoài viewport khi không focus (top−87.2/bottom−37.6); Tab hiện ởtop12 rồi Tab tiếp sangbrand thì ẩn lại. Không xác nhận lỗi che nội dung từ riêng ảnh fullpage cũ. Đã đóng tab root; giữ preview của chủ.

Giữ giới hạn: dữ liệu minh họa có nhãn, không QR nhận tiền; bank-only/clipboard-fallback/reduced-motion runtime chưa kiểm thêm. Tái dùng journey API/PG/Redis đã đạt vì backend không đổi, không mở lại suite.

## Hai điểm cần đối chiếu ở API/infra

1. **O1, tối ưu đọc dữ liệu công khai:** SupportService.read() dòng11–13 lấy toàn Settings row và Zod-parse; public() dòng26 và image() dòng47 gọi cùng đường đọc. Khi saved+pending cùng tối đa, có khoảng5.34MiB base64 nội bộ cho mỗi lần đọc, ngay cả metadata chỉ trả vài trường hoặc public đang tắt. Có thể giảm projection dữ liệu/kiểm enabled và ID ngay trong truy vấn, hoặc cơ chế giới hạn nhỏ đã có; phải giữ off/private/draft atomic, không thêm cache stale. Chưa đo tải hoặc chứng minh DoS; không có bằng chứng draft/base64 bị trả public.
2. **C1, rủi ro thời hạn hậu-body:** Caddyfile dòng57 đặt response_header_timeout10s. Nó giới hạn chờ header từ upstream ([tài liệu Caddy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy#the-http-transport)); không được suy upload20s tự động xung đột vì thời điểm bắt đầu khác. Decoder tối đa8s và transaction maxWait2s/timeout5s có thể tạo đường hậu-body dài hơn10s. Chưa chạy native Caddy hoặc tái hiện lỗiHTTP; giữ là điểm cấu hình cần xác minh, không gọi lỗi502 đã xảy ra. Nếu cần sửa, giới hạn đúng route upload, giữ cap/auth và timeout của API khác, không tăng global vô cớ.

Đã chuyển cả hai điểm cho reviewer API đối chiếu trong cùng lượt audit. Chưa sửa runtime theo giả thuyết.

## API/bảo mật đang được review riêng

Giao code tay to đọc auth/session/admin/CSRF/Origin/cookies/client-IP/rate, public/private/uploadQR, job/preview/ticket ownership, đườngURL/path/SSRF và advisory đúng dependency phiên bản. Yêu cầu finding có file:line, trigger/hậu quả/bằng chứng/mức độ và fix plan; phân biệt lỗi đã chứng minh với tối ưu/target-config. Chỉ tái hiện nhỏ khi cần, không quét/bruteforce/load production, không nguồn TikTok, không dependency/framework mới hoặc thay đổi code trước kết luận. Báo cáo backend được chốt riêng, không coi task đang chạy là kết quả an toàn.

Candidate vẫn draft đến sau kết luận và delta cần sửa; chưa commit/push/CI/buildimage/publish/deploy trong review này. Caddy native adapt/validate tiếp tục là gate release bắt buộc.

## Sau handoff API

[Báo cáo API và quyết định fix](API_SECURITY_REVIEW_20261101.md) đã chốt ba điểm, chưa chứng minh high/critical. O1 tương ứng API-02, C1 tương ứng API-01; có thêm API-03 về headerPairs32 không có hiệu lực ở Busboy1.6.0. Root đã đối chiếu primary advisory/source; giao sửa hẹp theo kế hoạch ở báo cáo đó trước freeze, không lặp journey/test đã đạt hoặc redesign UI. Đây vẫn là review mã + kiểm nhỏ có mục tiêu, không quét hay kiểm tải production.
