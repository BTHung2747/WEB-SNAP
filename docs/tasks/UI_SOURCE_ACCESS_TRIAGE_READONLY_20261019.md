# Backend: đính chính kết quả và triage ACCESS_DENIED chỉ đọc

19/10/2026. Giao theo ủy quyền chủ: sau nghiệm thu, reviewer tự phân công bước phù hợp cho backend/frontend. Đây là successor của kiểm môi trường readonly, **không phải quyền sửa hệ thống hoặc thử lại Docker để lấy PASS**. Backend thực hiện; reviewer chờ bàn giao, frontend READY/chờ.

## Đầu vào và phạm vi file

- Đọc AGENTS/CURRENT, [review môi trường](../evidence/ui-source-environment-readonly-review-20261019/ASSESSMENT.md), receipt cụ thể được dẫn và đúng component cần.
- Evidence mới: `docs/evidence/ui-source-access-triage-readonly-20261019/backend/`; script nếu cần chỉ `labs/tiktok/ui-source-access-triage-readonly/`.
- Giữ nguyên owner24source, diagnostic4script/36artifact và mọi manifest lịch sử. Không sửa app/UI/helper gate/policy/lock/config để giải quyết một outcome chưa rõ.

## A. Đính chính F-ENV-PYTHON-OUTCOME-REPORTING

1. Tạo CORRECTION/HANDOFF successor, tham chiếu nguyên Python receipt/version.json. Nêu8query có6rootExit0 nhưng5nativePASS/3FAIL; Python root0/nativeFAIL/forcedTermination=true, version=null. FileVersion metadata không là query runtime PASS.
2. Code inventory đã giữ `$r.OK=false`; không vá nó hoặc native gate để chấp nhận root0. Không gọi lại Python--version để thay lịch sử; không suy nguyên nhân forced termination khi chưa có count/identity/event đủ chứng minh.
3. Giữ Docker và w32tm FAIL, port/skew/cache/runtime UNKNOWN như review. Correction không tự chứng nhận môi trường hoặc đóng finding thay reviewer.

## B. Triage có giới hạn, không lặp daemon request

Đặt bảng giả thuyết trước kiểm: principal của execution khác user khởi Docker Desktop; restricted/AppContainer/integrity token; process/service trạng thái chưa biết; pipe ACL; transport/daemon state. Chỉ facts đã quan sát mới loại/chọn giả thuyết; `ACCESS_DENIED` riêng lẻ không định nguyên nhân.

Được phép **một inventory metadata cục bộ, bounded và chỉ đọc**:

- Current execution identity/token attributes tối thiểu bằng API Windows/.NET chính thức đã xác minh. Chỉ các trường cần để so sánh equality, restriction/elevation/integrity nếu API cho phép; không dump token/group/privilege list hoặc `whoami /all`, không lưu SID/user name/domain thô. Có thể lưu bool same-owner/enum hoặc hash label trong evidence để tránh thông tin định danh.
- Chỉ process metadata của `Docker Desktop`/`com.docker.backend` và service `com.docker.service` nếu đã có: existence/PID/startUTC/session/version và owner equality khi quan sát an toàn. Không command line/env/handles dump; không inventory toàn máy. Kiểm identity PID/start time nếu dùng PID để so owner. Process/service có/không không tự chứng minh daemon API đang hoạt động; service không chạy có thể phù hợp WSL2, không tự khuyến nghị start.
- Named-pipe **metadata/presence theo exact endpoint đã xác minh** chỉ khi API metadata-only đã được đối chiếu chính thức. **Không open/connect/read/write pipe, không bypass Docker CLI hoặc đổi sang transport khác** để kiểm quyền. Nếu ACL cần mở/connect hoặc quyền mới, ghi NOT_RUN/UNKNOWN và nêu ranh giới cần chủ duyệt; không thực hiện.
- Đọc tài liệu/source chính thức để phân biệt product permission model với suy luận về sandbox/current token. Không khám phá app internals, secret files hoặc sửa sandbox policy. Nếu cần API declaration mới, ưu tiên API sẵn có; tối thiểu readonly glue bằng runtime hiện có, phải xác minh signatures/layout trước, không dependency/SDK/compiler mới.

Mỗi native query≤15s/cap≤64KiB, tuần tự, no retries/fallback enumeration sau access denied, dùng owned-tree/EOF proof thích hợp. Raw output chỉ bounded RAM; lưu projection allowlist/return codes/limitations. Không lấy script exit0 làm mọi observation PASS. Metadata nội bộ lỗi thì ghi UNKNOWN; không xin nâng quyền hoặc đổi process token trong task.

## Cấm trong task này

Không Docker CLI daemon query lần nữa (version/info/image/ps/network), không query `w32tm`/port lỗi lần nữa, không Python--version rerun, không daemon HTTP/IPC probe. Không Docker Desktop diagnose/support tool nếu có side effects/upload, không logs/config/auth/cert/credential store dump. Không service/start/restart/WSL/settings/context/env/ACL/group/token changes, impersonation/elevation, launch dưới user khác, container/network run/create/exec/pull/build/cleanup, app HTTP/TikTok/CDN/source DNS, signer/approval/grant/claim, main/gallery/deploy.

## Bàn giao và dừng

CORRECTION + HANDOFF/manifest mới, source before/after pins không đổi, bảng hypotheses/evidence/not observed, exact commands/exit/deadline/caps/ownership. Chỉ đề xuất bước can thiệp khi có evidence hỗ trợ; không mặc định “Run as Administrator” hoặc thêm docker-users là fix.

Nếu hết metadata đọc an toàn mà nguyên nhân vẫn chưa xác định, kết luận INCONCLUSIVE và nêu một yêu cầu nhỏ, rõ cho chủ; không mở thêm vòng query tương tự. Báo reviewer chat `01a14259-19b0-73f0-bd0c-0f5be84f6a88` theo chỉ thị báo cáo rồi dừng. CURRENT do reviewer cập nhật; không nhắn/giao frontend.
