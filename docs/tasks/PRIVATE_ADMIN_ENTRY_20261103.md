# Đổi đường dẫn vào quản trị — 03/11/2026

## Yêu cầu hiện hành

Chủ muốn đổi đường dẫn trang admin sang tên khó đoán. Root đã giải thích: đây là thay URL, không phải mã hóa hoặc thay thế đăng nhập. Không thêm link admin công khai.

Đổi **đường vào trang quản trị**, không đổi các API `/api/v1/admin/*`, cookie, quyền admin, CSRF, rate-limit hay nội dung các tab đã nghiệm thu. Không chuyển hướng từ `/admin` sang địa chỉ mới vì sẽ tiết lộ địa chỉ.

## Cách triển khai

- Dùng `ADMIN_PATH` do máy chủ cấu hình khi chạy. Giá trị ngẫu nhiên dành cho chủ đã lưu riêng ở `lab-runs/admin-entry-route-20261103/owner-route.json`; không đưa giá trị thật vào Git, bundle JS công khai, sitemap, robots.txt, public HTML/links, log hoặc env mẫu. Không coi URL là một credential đủ để vào quản trị.
- Server phục vụ file admin riêng tại đúng path cấu hình; chặn `/admin`, `/admin/*`, `/admin.html` và các biến thể slash thông thường, không redirect tiết lộ path mới. Direct API vẫn yêu cầu quyền như cũ.
- React nhận biết trang admin qua marker chỉ có trong HTML admin do server phục vụ (hoặc cách tương đương không nhúng path thật trong public bundle). Không nhận mọi unknown URL là admin. SSR/hydration thống nhất; private HTML có noindex/nofollow, không canonical/OG URL làm lộ địa chỉ tùy biến ở artifact công khai.
- Caddy/Compose/env mẫu/entrypoint và release route check hiện có cần cùng hợp đồng. Path rỗng/sai/reserved phải bị từ chối an toàn, không phát sinh matcher `/*`. Ví dụ và CI dùng giá trị fixture, không giá trị thật. Xác minh API/tùy chọn Caddy2.11.7, Vite7.3.6 chính thức đúng version trước dùng; không đoán cú pháp placeholder/default/middleware.
- Bản Vite preview local cần phục vụ cùng entry mới và chặn entry cũ, không chỉ sửa production Caddy. Tái dùng plugin/hook server của Vite hiện có; không framework/server mới. Giữ build/style/layout tải và mọi chức năng khác.

## Kiểm và bàn giao

Được code, targeted type/web-build/route checks vừa đủ; chưa commit/push/CI/build image/pull/deploy/migrate production. Không nguồn YouTube/TikTok hoặc kiểm lại feedback CRUD/MP3 đã khép. Kiểm đúng URL mới ra login/noindex, các URL cũ 404 không Location mới, API chưa đăng nhập 403, path invalid/empty fail closed và public artifacts không nhúng giá trị riêng. Dùng recipe/cached tools sẵn có; nếu thiếu native Caddy ghi rõ để dùng release gate, không mở vòng setup/pull riêng theo phỏng đoán.

Bản góp ý cho chủ đang dùng cổng5219, project/TTL trong `lab-runs/feedback-preview-current.txt` và receipt được trỏ tới. Không dừng/recreate API/DB/Redis hoặc xóa thư chủ thử để đổi UI path. Nếu còn live thì chỉ cập nhật build web và cấu hình/restart web của đúng project sau có receipt; nếu đã hết TTL, báo rõ thay vì claim còn chạy. Không overwrite manifest/handoff đã nghiệm thu; lưu delta riêng. Root giữ TASK/PLAN/CURRENT và thực hiện nghiệm thu, cập nhật link chủ sau bàn giao. Xong dừng.

## Trạng thái

03/11: **đã nghiệm thu source và preview local**. [Root review](../../lab-runs/admin-entry-route-20261103/ROOT_REVIEW.md): 14 source pins/16 artifacts khớp; focused policy/shell/SSR, type/build và Vite11HTTPcases đạt. CUA root đã mở đúng login ở entry mới. `/admin`/file/child trả404 không redirect, public artifacts không chứa giá trị riêng; API/auth giữ nguyên. API/PG/Redis preview không recreate/reset dữ liệu; TTL cũ giữ08:24:50VN.

Website chính chưa đổi, chưa commit/CI/build image/deploy. Native Caddy/Alpine/HTTP-TLS phải chạy theo release gate trên image ứng viên; không claim Vite proof thay thế. Cấu hình ADMIN_PATH thật nằm trong env máy chủ/owner-route.json ignored; phải thêm vào env trước Compose mới, không commit giá trị này.
