# Chuẩn bị P5–P6 — chưa deploy

Không thuê VPS, mua domain, mở public hoặc tích hợp tài khoản quảng cáo trong phiên triển khai local.

## P5: VPS thử nghiệm ngắn hạn

1. Chủ dự án chọn ngân sách/VPS Linux/IP và quyền thử; chỉ sau đó mới triển khai. Không giả định gói frontend miễn phí cho phép media backend.
2. Dùng static Vite build qua reverse proxy; API/worker từ image đã lock. **Không dùng Vite dev/tsx watch để public.** Chuyển API sang `node dist/apps/api/src/main.js`, worker tương tự; không bind source trong production.
3. Dùng TLS thật, domain `APP_ORIGIN`, `COOKIE_SECURE=true`; firewall chỉ 80/443 và SSH cần thiết. PostgreSQL/Redis/egress chỉ nội bộ. Giữ worker internal network và proxy kiểm tra DNS/IP; không publish CONNECT proxy.
4. Khởi tạo secret khác local, migration deploy, admin không mặc định. Giới hạn upload/body tại reverse proxy, timeout truyền lớn hơn deadline app có chủ đích; no buffering toàn video. Health route không tiết lộ secrets.
5. Chạy lại P0 **từ IP VPS**: tối thiểu 3 mẫu được phép mỗi loại dự kiến bật, ca sai/đã xóa/auth, ffprobe + phát có tiếng. Ghi ngày/version/IP môi trường (IP có thể che trong bản công khai), mode/input/output/deadline. Nếu IP bị chặn, tắt nền tảng; không bypass truy cập.
6. Test workflow thật desktop và điện thoại ít nhất một trình duyệt mỗi loại; thử Range/retry, rời trang chưa tải, đóng tab khi đang tải, mất mạng, restart API/worker, disk80%, ngân sách, SSRF redirect/DNS.
7. Đo RAM/CPU/disk/input/output/workerSeconds trên tải có kiểm soát; chọn giới hạn vận hành từ số liệu. Local concurrency1; không tự tăng server concurrency trước khi đo.
8. Bổ sung structured metrics, cảnh báo disk/queue/error/egress, log retention/rotation, bản backup được mã hóa/cất riêng và thử restore. Chưa có gửi cảnh báo/email/Slack tự động trong MVP local.

## P6: Mở có kiểm soát

- Chỉ bật adapter/loại nội dung đạt P5, ghi phạm vi công khai trung thực. Bổ sung CONTACT_EMAIL thật, điều khoản/quyền riêng tư và quy trình báo cáo.
- Có người chịu trách nhiệm xử lý sự cố; xác nhận restore admin/campaign/settings thành công trên target riêng.
- Chuẩn bị tắt `acceptJobs` và adapter; thử rollout/rollback không mất quyền phiên đang truyền.
- Đặt ngân sách tháng và bộ chặn; đối soát phí nhà cung cấp; chống abuse và đo lượng tải. Không tuyên bố doanh thu hoặc lượt xem từ click nội bộ.
- Nếu dùng mạng quảng cáo/affiliate, chủ web cung cấp chương trình/tài khoản/điều kiện đã duyệt; kiểm tra link và nội dung theo chương trình. Không nhập script HTML tùy ý vào admin.
- Mở giới hạn ít người trước; kiểm tra sweep/crash/restore trong nhiều chu kỳ; tăng tải dựa trên số liệu, không cam kết mọi URL/nền tảng.

Điều kiện còn chặn public được theo dõi trong docs/PROGRESS.md và TEST_REPORT.md. Việc có cấu hình deploy/runbook không có nghĩa P5–P6 đã thực hiện.
