# Phát hành diagnostic nguồn — 03/11/2026

Mục tiêu: biết nguyên nhân AUTH_REQUIRED của YouTube và preview TikTok thiếu trên VPS, trước khi chọn bản sửa chức năng. Đây không phải bản đã sửa xong tải nguồn.

Review chuẩn: `lab-runs/production-source-reliability-20261103/ROOT_REVIEW.md`; handoff và pins trong cùng thư mục. Root đã đọc diff, đối chiếu 5 source pins + 7 evidence successor. Coder chạy các kiểm offline nhỏ network-none, không source request. Root không chạy lặp suite. Giữ nguyên mapper/packet/exit, caps/TTL, selection, lifecycle, CSRF và luồng tải.

## Phần thay đổi

- Media adapter ghi diagnostic YouTube tối đa 1 KiB trong thư mục job: gate, exception class và reason enum; không lưu raw exception/URL/cookie/metadata. Thông báo không chắc giữ UNKNOWN.
- Worker đọc hai receipt cố định trước error parse/cleanup, kiểm schema/regular/nofollow/size và phát hai structured events `youtube_source_diagnostic`, `preview_generation_diagnostic`. Logging best-effort không làm đổi kết quả job.
- Hai test files offline kiểm public packet, privacy, ownership và mirror. Không đổi API, web, egress, dependencies, migrations hoặc settings.

## Kế hoạch phát hành

1. Commit chỉ 5 source/test đã review và file task này trên baseline 5c4c095; không đưa các file dirty khác vào commit.
2. Dùng workflow release.yml hiện có build/compile, kiểm artifact, Caddy và routes bắt buộc. Chỉ dùng image digest từ run thành công, cùng commit.
3. Chủ dùng terminal Lightsail như đã chọn. Pull app mới trước; không đổi web/egress/DB hoặc chạy migrate vì component không đổi. Lưu env/image refs rollback và kiểm không có job/transfer đang chạy trước thay API/worker. Giữ mọi giá trị env và setting; chỉ thay APP_IMAGE bằng digest đã xác minh.
4. Sau startup API/worker đạt, kiểm frontend thật đúng mẫu YouTube và TikTok cần chẩn đoán; không lặp toàn bộ MP3/all5/human-review đã đạt. Lấy log đã lọc với 2 diagnostic events mới để chọn functional fix. Mobile FORMAT_UNAVAILABLE vẫn chưa rõ phase, không coi desktop PASS là đã khép lỗi đó.

Hiện chưa commit/publish/deploy; source identity và app digest sẽ ghi sau CI. Chưa nhận nguyên nhân nguồn VPS từ diagnostic mới.
