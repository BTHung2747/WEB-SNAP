# Image Docker có thể dọn — 12/10/2026

Kiểm tra trực tiếp Docker và đối chiếu Compose/Dockerfile/runner hiện hành; chỉ đọc, **chưa xóa image, container, cache hoặc volume**. Đây là đánh giá dung lượng, không phải nghiệm thu chức năng mới. Tiến độ kiểm schema DNS và các finding OPEN không thay đổi.

Docker hiện có14 image,25 container (đều đã dừng). Tổng image sau tính layer chung3.888GB; Docker báo reclaimable582.4MB. Build cache6.813GB, reclaimable3.722GB. Kích thước hiển thị từng image không thể cộng để tính dung lượng giải phóng; build cache còn có thể giữ layer sau khi bỏ image.

| Image/tag | Quyết định | Căn cứ |
|---|---|---|
| wed-snap-media-renderer-lab:37-20261007 | Ưu tiên gỡ nếu dọn theo hướng hiện tại | Browser lab cũ đã nhường ưu tiên cho Cobalt/core;0 container tham chiếu, không được runner ảnh/DNS hiện tại dùng. Khoảng572.3MB layer riêng theo Docker, không cam kết đây là số byte giải phóng thực. Gỡ thì không chạy lại trực tiếp lab renderer ghim imageID cũ. |
| wed-snap-tiktok-app-core-fixes:20261009 | Giữ | Image31742091…dfa417e đang được runner nguồn ảnh, nghiên cứu DNS và successor dns-answer-diagnostics ghim.0 container tồn tại không có nghĩa image này không cần. |
| wed-snap-app:local | Giữ | API/web/worker của Compose chính;3 container chính tham chiếu. |
| wed-snap-egress:local | Giữ | Proxy chính và nguồn lab;3 container tham chiếu. |
| postgres:16.10-bookworm | Giữ | CSDL chính và lab;5 container tham chiếu. |
| redis:7.4.6-bookworm | Giữ | Queue/phiên/runtime chính và lab;4 container tham chiếu. |
| node:22.22.3-bookworm-slim | Giữ cache build nền | FROM của Dockerfile ứng dụng và apps/media;0 container trực tiếp nhưng là base build. Chỉ khoảng2.679MB riêng theo Docker. |
| wed-snap-media:2026.08.19 | Giữ cache bộ media/lab | Bộ yt-dlp/FFmpeg và base của các lab media cũ; không ưu tiên dọn, khoảng11.82kB riêng. |
| wed-snap-tiktok-app-integration:20261009 | Không ưu tiên gỡ | Parent FROM của app-core-fixes, dùng khi rebuild lab đó;0 container, khoảng19.14kB riêng. Bỏ cache không làm mất layer mà core-fixes vẫn cần, nhưng mất parent tag cho rebuild. |
| wed-snap-tiktok-cobalt-lab:20261008 | Giữ trong lúc còn kiểm TikTok | Image Cobalt cũ và build-stage của app-integration, các runner/review mẫu cũ ghim image này; khoảng7.324MB riêng. Không coi1.23GB hiển thị là số sẽ thu hồi. |
| wed-snap-media-curlcffi-lab:373-20261007 | Không ưu tiên gỡ | Parent build của Cobalt và renderer; khoảng14.17kB riêng. Có thể bỏ cache khi chấp nhận phải khôi phục/rebuild chuỗi lab cũ; ít lợi ích dung lượng khi giữ các child image. |
| wed-snap-p3-test:local | Ứng viên đợt dọn lab lịch sử riêng |3 container test đã dừng vẫn tham chiếu; cần xem/dọn đúng container lab trước khi gỡ image. Khoảng89.01MB riêng. |
| wed-snap-rate-test:local | Ứng viên đợt dọn lab lịch sử riêng |3 container rate-test đã dừng vẫn tham chiếu; khoảng88.89MB riêng. |
| wed-snap-p3-egress:local | Ứng viên cùng đợt dọn P3 |1 container P3 egress đã dừng tham chiếu; khoảng9.997kB riêng. Không phải wed-snap-egress:local của ứng dụng chính. |

Nhóm container hiện có: wed-snap6,wed-snap-p3-test6,wed-snap-rate-test6,wed-snap-test6,wed-snap-restore1. Không dùng việc tất cả đang dừng để kết luận được xóa stack chính hoặc dữ liệu DB. Việc đánh giá volume/test DB cần nhiệm vụ riêng; chưa kiểm nội dung hoặc khả năng khôi phục trong phiên này.

Ưu tiên dung lượng: renderer cũ trước; sau đó xem xét build cache đang không sử dụng. Cache có thể dựng lại nhưng các lần build sau sẽ tốn thời gian/tải lại hơn; các nhiệm vụ hiện tại vẫn dùng cached image core-fixes và không cần build. Chưa chạy lệnh prune hoặc lệnh xóa hàng loạt.

Lệnh thực đã chạy chỉ đọc: docker image ls, docker ps -a, docker system df, docker system df -v, docker image inspect; tìm tham chiếu bằng rg trong Compose/Dockerfile/runner/handoff. Không khởi động dịch vụ, build/pull/install, gọi TikTok/CDN, thay settings, sửa code hoặc dữ liệu. Docker API cần sandbox escalation đọc-only; lệnh mặc định ban đầu bị permission denied, lệnh được phê duyệt sau đó đọc thành công.
