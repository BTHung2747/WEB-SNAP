# Phát hành bản MP3, góp ý và đường quản trị riêng — 03/11/2026

## Quyền và phạm vi hiện hành

Chủ đã trực tiếp yêu cầu **“được rồi đã test hết rồi đúng ko giờ thì deloy lên đi”** sau khi thử giao diện. Lệnh này cho phép chốt mã đã nghiệm thu, commit/push đúng phạm vi, chạy workflow build/publish, rồi cập nhật Lightsail savlivo.online. Nó thay giới hạn chưa commit/CI/deploy của ba task chuẩn bị, không cho phép thay guards hoặc sửa lỗi nguồn theo đoán.

Gói gồm ảnh xem trước/lưới/caption thật, MP3 TikTok ảnh/video và YouTube, SEO copy tương ứng, trang Góp ý/hộp thư quản trị và ADMIN_PATH runtime. Dùng các review đã đạt được CURRENT dẫn; không chạy lại nguồn hoặc toàn suite. Gộp candidate một lần. Code tay to chỉ hoàn thiện copy MP3/gate entrypoint cần thiết, root sở hữu Git/CI/rollout để không tác động song song.

## Kiểm tra còn cần trước cập nhật

1. Chốt file list/pins từ các manifest đã review, overlay đúng delta mới. Không `git add .`, không lấy lab, quyền nguồn, dev fixture hay dirty không liên quan. Không commit owner-route/override/env, tài khoản thử hoặc raw evidence.
2. Workflow release hiện có build cùng source app/web/egress; type/compiled/static checks, Caddy2.11.7 native adapt/validate và isolated HTTP public/private routes phải đạt trước registry publish. Chạy entrypoint mới thật trong gate, không chỉ bypass bằng `--entrypoint caddy`. Ghi CI/run/source và ba registry digests chính xác.
3. VPS: dùng terminal AWS do chủ đã chọn; root hiện chưa có SSH key. Đọc identity/source/image/disk và existing lỗi YouTube trước mutation; preload source/images, pause nhận tác vụ mới và drain đúng luồng cũ. Backup env/compose/source/images/DB/chứng chỉ bằng recipe đã có, giữ secrets trên server.
4. Thêm ADMIN_PATH vào env riêng, kiểm schema/cấu hình, migrate additive Feedback trước API mới. Không drop bảng/thư khi rollback. Giữ settings/QR/quota/flags và dữ liệu production, không đưa tài khoản preview vào production.
5. Khởi động đúng ba image đã publish, kiểm health/public/góp ý/private entry/old admin404/noindex. Khôi phục trạng thái nhận job đã lưu trước bảo trì sau smoke đạt. Không claim “đã lưu file” hay tải nguồn lại chỉ để nghiệm thu deployment.

## Known issue và giới hạn

YouTube Shorts 1fSmoMPWXs4 có báo AUTH_REQUIRED ở VPS cũ, local analyze47s đạt. Chưa có upstream reason/host log để kết luận; gói này không được quảng cáo là đã sửa lỗi đó. MP3 ba nhánh đã technical+humanPASS; giữ kết quả, không tải lại. Native release tests không thay thế hoạt động nguồn thật trên IP VPS. Nếu log hiện có không đủ thì nêu đúng, không bật proxy/cookie/client mới.

## Trạng thái

03/11: bắt đầu chốt candidate và chuẩn bị release. Chưa commit/push/workflow/deploy trong task này. Baseline production gần nhất ad3429a; phải đọc host lại trước cập nhật. Private path giữ ở ignored owner-route và env server, không ghi literal vào task.
