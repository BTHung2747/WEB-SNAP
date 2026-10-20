# Kết quả dọn Docker — 12/10/2026

Đã thực hiện theo yêu cầu “làm đi” sau [đánh giá image](DOCKER_IMAGE_CLEANUP_REVIEW_20261012.md), hoàn tất11:28 giờ Việt Nam. Không mở rộng sang dọn container test, image khác hoặc dữ liệu volume.

- Gỡ đúng `wed-snap-media-renderer-lab:37-20261007`, ID `e3e776372b59…2bf2baf9`, sau kiểm pin và không có container tham chiếu. Dùng `docker image rm --no-prune`, không force và không dọn parent image.
- Chạy `docker builder prune --force` với CLI hiện tại (alias buildx prune), không dùng `--all`, không image/container/volume/system prune. Docker báo **Total:4.295GB** thu hồi cache.
- Image14→13;13 tag/ID còn lại khớp nguyên trạng, gồm main app, egress, media, core-fixes, Cobalt/integration/curlcffi, Node/Postgres/Redis và P3/rate-test.
- Danh sách25 container và35 volume trước/sau khớp; không xóa hoặc khởi động container, không thao tác nội dung DB/media.
- Docker system df: image3.888→3.316GB; build cache103→43 entries,6.813→2.518GB, reclaimable sau0B. Hai loại dung lượng dùng chung layer nên không cộng các mức giảm thành tổng byte giải phóng. Chưa đo dung lượng trống ổ Windows hoặc compact VHDX.

Native commands đều exit0; inventory verification PASS. Before/after/result/native log và lệnh thực ở `docs/evidence/docker-image-cleanup-20261012/`. Chỉ dùng Docker CLI có sẵn; không build/pull/install hoặc gọi TikTok/CDN, không sửa source/lab/lock/dependency/golden/verifier lịch sử. AUDIT/PROGRESS chèn block mới và lưu original bytes/doc successor; [báo cáo đánh giá trước dọn](DOCKER_IMAGE_CLEANUP_REVIEW_20261012.md) được giữ như hồ sơ tại thời điểm kiểm.

Hai finding schema DNS vẫn OPEN; việc dọn cache không phải nghiệm thu chức năng. Bước tiếp vẫn [sửa schema rồi diagnostics A offline](evidence/tiktok-dns-answer-research-audit-20261012/NEXT_PROMPT.md). Lab ảnh/DNS vẫn dùng image core-fixes đã giữ. Lab browser lịch sử muốn chạy lại phải khôi phục image renderer đúng pin hoặc có nhiệm vụ rebuild/nghiệm thu riêng; không sửa hash cũ để né image đã được chủ cho gỡ.
