# Proxy truy cập nguồn

`src/egress.py` là code proxy được ứng dụng và các lab sử dụng để kiểm soát host, DNS/public-IP và kết nối CONNECT. Dockerfile giữ entrypoint `/app/egress.py` bên trong container.

Phần này không phải extractor YouTube/TikTok. Các thay đổi tổ chức thư mục không cho phép nới allowlist, mở kết nối trực tiếp hoặc đổi bảo vệ SSRF.

## TikTok policy — default off, offline review only

`TIKTOK_EGRESS_POLICY_ENABLED` chỉ bật với `1`; mặc định không bật. Phạm vi vẫn nằm trong EGRESS_DOMAINS và chỉ các suffix tiktok.com/tiktokcdn.com/tiktokv.com/byteoversea.com/ibytedtos.com. CONNECT không thấy URL path: cờ có thể ảnh hưởng cả video TikTok. Không bật cờ hoặc photo main từ việc recipe/code đã thay đổi. Chưa build image mới hoặc kiểm nguồn.

Cờ tắt giữ resolver/connect cũ. Cờ bật dùng public aiohappyeyeballs2.7.1 nguyênbyte, DNS helper subprocess/std getaddrinfo, strict raw256→ordered unique64/public policy. Setup absolute10s gồm vendor verification, chờ admission, DNS và tất cả nhóm; giữ reserve1s, policyC groups≤4/pair≤2/socket≤2/delay.25/group≤2/reap.1. Không fallback sau lỗi. TLS end-to-end/parser/443/host allowlist/tunnel idle30/max240 giữ.

Trace là RAM/request≤256rows/128KiB encoded, không global Trace.current hoặc quota cả đời server; giữ tối đa16 completion receipts. Khi opt-in, server có tối đa8 active handlers (cả non-TikTok để chặn nhân thread), chỉ1 setup DNS/connect cùng lúc; slot chờ tiêu thụ setup deadline. Đây là thay đổi admission khi cờ bật; nhánh transport/non-TikTok vẫn resolver cũ. Không giới hạn8 trong cờ tắt. DNS helper có RLIMIT_AS64MiB, IPC16/32KiB, direct Popen ownership/kill/wait/group0; tổng proxy/helper phải nằm trong cgroup96MiB. Không đọc trace-file PID để cấp quyền cleanup.

Mỗi request có socket/trace/loop/tasks/registry riêng. Cleanup vật lý không phụ thuộc trace; thiếu/mâu thuẫn receipt/trace không là proxy success. CONNECT200 cần DNS closure/trace/tasks đúng, registry close và request shutdown/return mới cho completion accepted. Lỗi observer **sau khi đã chuyển bytes** không thể thu hồi bytes cũ: proxy xuất completion FAIL, chưa có transaction cross-process với media. Không quảng cáo nguồn/app E2E an toàn từ transport fixture. Bước sau cần review giới hạn này trước nguồn/activation; không tự sửa media để tạo side channel.

Dockerfile chỉ COPY module/vendor để review lần build sau; không pip install. Python mục tiêu3.12.12 đã kiểm qua image cache8bc0…7f10, media3.11.2 cache3174…417e riêng; xem docs/TIKTOK_PHOTO_EGRESS_STEP3_HANDOFF.md và evidence mới. Main Compose/env/settings/egress allowlist vẫn không đổi.

## Phase completion gate3b — bắt buộc cho photo opt-in

Worker parent tạo scope mới mỗi analyze/prepare; open trước child, Basic capability chỉ trong CONNECT, seal sau native0+ProcessGroup0, poll bounded và take đúng phase/job một lần trước trả data cho processor. Không dựa global proxy health hoặc nonce đơn lẻ. Unknown/missing/partial/false/mismatch/overflow/replay/expired/channel failure đều không selectable/ready; staging được lifecycle hiện có dọn sau ownership/group closure. Không rollback bytes đã gửi và không thêm source GET/HEAD/retry.

Control POST `/_wed/phase` dùng stdlib HTTP parser trên listener8888 cũ, bearer secret64hex chỉ parent/proxy; cần `TIKTOK_EGRESS_CONTROL_SECRET` cùng giá trị ở hai bên và `TIKTOK_EGRESS_CONTROL_NETWORKS` là CIDR internal cụ thể trên proxy. Cả địa chỉ local interface và peer phải trong cùng CIDR cấu hình, không chỉ private-IP chung. Không cấu hình thì control deny; photo parent fail trước child, không fallback. Không đổi main env/Compose trong nhiệm vụ này. Non-photo/YouTube không bị buộc token mới.

Broker RAM≤64scope/2CONNECT analyze hoặc3prepare; TTL từ deadline tuyệt đối30/180 hoặc app chặt hơn, không refresh. Sealed scope từ chối CONNECT mới; take một lần, pressure từ chối open mới thay vì evict proof đang chờ. Expiry thu hồi capability/cancel đúng context, chỉ bỏ ownership khi socket/loop/thread đã đóng; state không rõ luôn deny. Control body≤1024B/header≤16KiB, response≤2048B; parent HTTP header cap4KiB, mỗi call≤1s và phase remaining, ≤24poll trong≤5s và end gốc. Không endpoint GET/redirect hoặc điều khiển source target.

Correlation/capability/epoch chỉ RAM và environment của child, control secret bị loại khỏi child env. Origin không nhận proxy authorization; public packet/schema/DB không có field nội bộ mới. Video/YouTube giữ nhánh cũ. Chi tiết/evidence sửa finding ở docs/TIKTOK_PHOTO_EGRESS_STEP3B_HANDOFF.md; vẫn chưa build/bật main/nguồn/UI/deploy.
