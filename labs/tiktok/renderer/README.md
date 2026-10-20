# Lab renderer TikTok

Đây là implementation thử nghiệm browser, chưa tích hợp vào adapter sản phẩm. Điểm vào build/launch là `build_renderer.ps1` và `run_renderer_capability.ps1`. Cả hai cần đọc phạm vi hiện hành trong `docs/AUDIT_TIEN_DO.md` trước khi thực thi; thư mục không tự cấp quyền build hoặc thay guard.

`renderer_capability.js` dùng Playwright đã ghim trong image lab. `renderer_diagnostics.js` thu bằng chứng launch. Container bind mount thư mục này vào `/lab` chỉ đọc; bảo vệ, resource limits và ownership giữ như trước.

Hiện vẫn bị chặn ở sandbox/chroot; proposal đổi seccomp chưa áp dụng. Xem `../../../docs/STRUCTURE.md` và handoff launch ở gốc `docs/`. Các lệnh cũ dưới `tests/p37/` được chuyển tiếp tới implementation ở đây.
