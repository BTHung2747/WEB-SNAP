# Kiểm môi trường lab — chỉ đọc, chưa chạy nguồn

19/10/2026, Asia/Saigon. Sau nghiệm thu tích hợp Win32, reviewer đề xuất kiểm môi trường lab với Docker chỉ đọc, chưa gọi TikTok. Chủ trả lời: **“sau khi kieem chứng xong bạn có thể ra lệnh phù hợp với code tay to hoặc giao diện web snap”**. Theo ủy quyền này, giao `code tay to` kiểm môi trường backend; frontend tiếp tục READY/chờ. Reviewer chỉ chạy kiểm chứng sau bàn giao, không chạy test song song.

## Đầu vào và sản phẩm bàn giao

- Đọc AGENTS/CURRENT và [review tích hợp hiện hành](../evidence/ui-source-direct-win32-integration-review-20261019/ASSESSMENT.md). Chỉ đọc đúng component/manifest/plan liên quan tới các kiểm tra bên dưới; không mở toàn bộ lịch sử.
- Evidence mới: `docs/evidence/ui-source-environment-readonly-20261019/backend/`. Nếu cần script chẩn đoán, chỉ tạo trong `labs/tiktok/ui-source-environment-readonly/`; không sửa owner24file, PoC, app/UI, lockfile, historical evidence/golden, trust/approval/admission hoặc settings.
- HANDOFF có bảng từng điều kiện: OBSERVED_READONLY / FAIL / NOT_RUN / UNKNOWN, command thực/child exit/duration/caps/provenance, artifact manifest và danh sách quyền/tác vụ còn cần. Không biến metadata thành chứng nhận runtime. Không tự tạo `PASS_OBSERVED` cho source environment proof hoặc ký/cấp authority.

## Bước1 — host/toolchain và đúng Docker endpoint

1. Đối chiếu current owner24source theo manifest đã review (`95d0baad0de5ed95d29fb0bd5c49a6659fed18de5a584c03297f25190dd6dd07` của backend integration) và helper source pin trong loader. Ghi hash executable tuyệt đối/version của pwsh/.NET/Node/Python/Docker hiện có; không cài/nâng/copy binary. Không rerun98/95/34 hoặc sửa code chức năng khi không có delta.
2. Chỉ đọc metadata Docker context/endpoint cần thiết, kiểm cả override theo environment mà không dump toàn environment hoặc credentials. **Trước mọi daemon request, xác minh đích là Docker Desktop/local Windows named pipe**; không liên hệ remote TCP/SSH context, không chuyển context hay sửa DOCKER_HOST/DOCKER_CONTEXT toàn cục. Đích không rõ/không local thì dừng phần daemon và báo UNKNOWN, không đoán.
3. Docker Desktop không chạy hoặc access denied: ghi đúng lỗi và dừng phần phụ thuộc. **Không start/restart app/service/WSL/daemon hoặc xin nâng quyền để tự vượt.**

## Bước2 — các quan sát chỉ đọc được phép

- Được gọi Docker CLI **chỉ các truy vấn** đã xác minh bằng tài liệu chính thức: context show/list/inspect metadata; version/info; image inspect cho đúng image IDs/roles trong plan hiện hành; ps/network list và inspect cho đúng lab labels/IDs/names được plan/hồ sơ dẫn. Không kiểm kê images/container/settings không liên quan.
- Lấy image expectations/memory/PID/network/mount layout từ `labs/tiktok/ui-source-prelaunch/wiring.ps1`/plan liên quan, chỉ đọc. Chọn trường metadata tối thiểu: ID/platform/cache presence/runtime version/engine OS/cgroup information nếu API cung cấp. Không dump full inspect, Config.Env, auth/docker config, cert/private key, proxy URL/credentials, logs, container filesystem hoặc Docker credential store.
- Quan sát filesystem đúng planned mount sources: tồn tại, canonical path, reparse policy, quyền truy cập chỉ đọc trong scope. Có thể đọc ACL đúng các path được giao, không thay ACL hoặc tạo junction/mount/test file vào nguồn. Host path đúng không chứng minh Docker Desktop bind mapping thực; không lấy mapping từ giả định prefix hoặc synthetic inspect làm proof.
- Đọc UTC/timezone/trạng thái đồng bộ sẵn có trên host; không chỉnh đồng hồ, đồng bộ lại, gọi external NTP/HTTP để tạo skew proof. Nếu chưa có đối chiếu nguồn thời gian tin cậy thì skew vẫn UNKNOWN.
- Có thể đọc trạng thái listening của đúng cổng lab cần dùng (ví dụ5206 theo contract) mà không kết nối/health GET. Chỉ báo trống/bận/không quan sát được; không kill process hay giải phóng cổng.
- Nếu có lab resources cũ: chỉ ghi nhận scoped IDs/labels/trạng thái từ truy vấn, không tự xóa/stop/clean/prune hoặc thao tác main stack. Job host0 không chứng minh container/network đã đóng.

## Cách chạy và giới hạn

Mỗi query watchdog≤15s, combined output cap≤64KiB, từng lệnh một trên máy8GB, không retry tự động khi lỗi/treo. Dùng cơ chế Win32 đã review cho owned host child nếu phù hợp; không dùng `.Kill(true)`/root exit làm tree-closure proof. Có thể compile/load **đúng helper đã review bằng toolchain hiện có** trong namespace chẩn đoán mới, pin source/assembly và ghi provenance. Không sao chép framework, không sửa private context/tool registry để giả source capability hoặc mở Invoke-SourceOwner. Nếu chưa có cách query an toàn trong scope thì nêu vướng mắc, không làm lỏng gate.

Raw stdout/stderr chỉ bounded RAM, trích trường allowlist/sanitised trước lưu; actual child ExitCode lấy từ process handle/native adapter, không LASTEXITCODE. Lưu timeout/EOF/job closure thật, thiếu thì UNKNOWN. Lệnh info/inspect trả0 chỉ chứng minh truy vấn thành công, không runtime/source PASS. Xác minh flags/template/API mới qua docs/repository chính thức trước thực thi; không đoán option.

## Những điều chưa được phép và phải giữ NOT_RUN

**Không** Docker run/create/start/restart/stop/kill/rm/prune/build/pull/load/exec/cp/commit; không network create/connect/disconnect/rm, compose up/down, service/WSL/settings/ACL mutation, cài dependency/SDK/compiler, deploy hoặc main/gallery. Không tạo container probe kể cả `--network none`, không exec vào container đang chạy, không tạo external traffic tới app/TikTok/CDN/DNS nguồn. Đọc tài liệu chính thức phục vụ kiểm tra được phép.

Vì chỉ đọc, các mục sau **không mặc định kiểm được**: Node22 Linux imports thực, public schema thực trong runtime, cgroup isolation áp dụng từng role, bind mapping/ACL trong container, egress phase closure/source app/browser/native download và cleanup runtime thật. Nếu không có evidence hiện hành được dẫn trực tiếp chứng minh cùng exact pins/environment, ghi NOT_RUN/UNKNOWN và đề xuất bounded offline probe riêng, chưa thực hiện.

Target bài cũ/ảnh02 chỉ chọn nội dung; live keys/grant/claim vẫn0. Không signer provisioning, chữ ký live hoặc live admission. Chưa có lệnh launch nguồn mới. Không giao hay gọi frontend browser trong task này.

## Bàn giao rồi dừng

Ghi HANDOFF/manifest, source before/after pins nguyên và kết luận readiness có giới hạn; giữ mọi FAIL, không viết lại lịch sử. Báo reviewer chat `01a14259-19b0-73f0-bd0c-0f5be84f6a88` theo chỉ thị báo cáo của chủ rồi dừng. Không tự sửa blocker, chạy probe hoặc triển khai bước tiếp. CURRENT do reviewer cập nhật.

Reviewer được chủ cho tự phân công bước tiếp phù hợp cho hai chat sau nghiệm thu; quyền điều phối này không tự mở rộng quyền chạy nguồn, tạo/xóa tài nguyên, cài đặt hoặc deploy. Khi bước tiếp cần authority mới, phải nêu rõ để chủ quyết định.
