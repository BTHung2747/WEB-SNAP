# Ghép bộ chạy và bàn giao browser nguồn — offline, chưa launch

Theo phân công của chủ: **code tay to sở hữu backend/runtime; Giao diện WED SNAP sở hữu frontend/browser; reviewer điều phối/nghiệm thu.** Đọc AGENTS + CURRENT và [nghiệm thu hai guard](../evidence/ui-source-glue-fix-review-20261016/ASSESSMENT.md). Không tự chạy nguồn sau khi hoàn thành nhiệm vụ này.

## Mục tiêu và giới hạn

Đóng khoảng trống từ source glue đã kiểm offline sang **một owner runner rõ ràng và giao thức browser có thể dùng được**. Tái dùng runner nguồn/observation, supervisor, resource/phase closure, atomic handshake đã có; không tạo framework/harness tổng quát, parser/downloader/transport mới. Không chạy lại các vòng DNS/fixture/UI đã khép.

Chủ chọn lại bài công khai cũ/ảnh02 ở `docs/tasks/UI_SOURCE_TARGET_20261016.json`; record này không phải grant. **Không tạo APPROVED_NEW/grant/claim/live runID hoặc invoke launcher/runtime trong giai đoạn này.** Dry-run vectors phải OFFLINE_TEST_ONLY, không thể qua source gate. Không Docker/server/browser/DB/Redis/HTTP/DNS/TikTok/CDN; không build/pull/install/main/gallery/deploy. Máy8GB: test cần thiết chạy tuần tự, có watchdog, chỉ delta được giao.

## code tay to — ghép owner runner/preflight, chưa thực thi

1. Đọc wiring source glue mới cùng readiness plan; chuẩn bị successor riêng trong `labs/tiktok/ui-source-prelaunch/`, không sửa runner lịch sử/readiness entry. Ghép inventory113+delta13−3targets=123leaf theo đúng roles/sibling imports. Kiểm collision, leafRO, dependencies/cache không bị dir bind che, build A3byte pins; input/control/output phải theo ownership (đừng mount toàn control RO nếu runtime cần ghi receipts). Không chỉ đổi nhãn fixture thành source.
2. Tái dùng owner runtime skeleton đã nghiệm thu để nối argv app/gateway/proxy, isolated owned resources/networks/processes/log capture, time/size/resource budgets và outer final gate/cleanup. Một owner duy nhất; không analyze/prepare/ticket/native thay browser. Cổng live thiếu human launch instruction mới/authority/claim-once/budget/pins/target/cutoff phải từ chối trước egress. Không dùng target record, state APPROVED_NEW tự khai hoặc file attestation đơn lẻ thay quyền người dùng. Chưa tạo/consume authority thật; test không gọi live execution path.
3. Bổ sung preflight tối thiểu cho full wiring, imports/runtime/cache/image pins và clock-domain mapping. Những mục cần container/Node22/Linux/DB thật trong nhiệm vụ này phải ghi NOT_RUN và **chưa thể chứng nhận launch-ready**, không dùng host24/spies thế chỗ. Không tự chạy probe container để lấp UNKNOWN. Giữ runtime928MiB theo policy đang pin; overall≤480s, reserve cleanup20+seal1, controller cleanup≤15; watchdog thấp hơn hiện có không được tự tăng. Không đổi budget-policy.json hoặc cap gateway2MiB ngầm.
4. Nối owner contract/source-decision/source-budget RO ở đúng consumer, claim một lần/nooverwrite theo cách đã có; gate trước mọi side effect phù hợp. Chốt cách lấy expiresAt và remaining monotonic cục bộ, không trừ ticks host/container/CUA. Thiếu budget để startup/browser/cleanup thì fail thay vì kéo dài hạn. Không hardcode N/count/dimensions/SHA ảnh thật; max2metadata mỗi phase và conditional1JPEG, retry0/redirect0.
5. Nối **publisher entry thực dùng** cho frontend tới `ui-source-glue/handshake.py:publish_observation` (role producer), cùng host clock domain và exact binding. Tái dùng atomic helper, không gọi CLI fixture hoặc tự viết decision/completion. Owner chỉ ACCEPTED sau tabCLOSED/screenshot hash và cutoff; completionPASS chỉ sau final runtime/cleanup proof. Tách native browser response/local API export/saved-deviceUNKNOWN.
6. Test chỉ delta, không framework mới: default/missing/old/consumed/target-only/offline flags fail trước launch callback; dry render inventory/argv/pins/caps/ownership; owner/producer wiring không overwrite. Dùng fake execution callbacks có nhãn rõ, không actual Docker/source. Giữ95unit đã đóng làm reference; chỉ rerun phần bị sửa/tích hợp cùng gate cần thiết, không tự mở matrix lịch sử. Preserve nguyên evidence và ghi actual exits/limits/NOT_RUN.

Output `docs/evidence/ui-source-prelaunch-20261016/backend/HANDOFF.md` + manifest/pins/delta receipts; nêu chính xác phần code có và phần chưa runtime. Chỉ sửa namespace mới trừ finding cần báo reviewer trước. Bàn giao reviewer theo chỉ thị chủ rồi dừng, không nhắn chat Thông báo hoặc tự launch bước sau.

## Giao diện WED SNAP — delta source protocol, không thay UI

1. Giữ FRONTEND_READY/build A, không sửa app/design/lifecycle/lock và không browser/CUA/server/test nguồn. Không chép lại toàn checklist13operations đã có; dẫn chiếu handoff readiness frontend.
2. Đọc contract/binding/handshake source glue đã nghiệm thu, lập **mapping delta** từ contract fixture cũ sang source mode: exact schema/binding/runID/target/index/decisionSHA/budgetSHA/cutoff, readiness backend.ready/host-ready, tab ownership, screenshot browser.jpg/hash và role producer. Không tạo file authority hoặc biến fixture scope thành quyền nguồn.
3. Chốt điều kiện nhận runtime/publisher command của backend: đường dẫn owner-controlled, clock domain/deadline, pin proof và source go-ahead. Publisher entry cụ thể backend đang ghép: chưa được bàn giao thì ghi WAITING_BACKEND_ENTRY, không bịa tên/argv. Đọc các file bàn giao khi có, chỉ ghi pending field cần backend, không tự nhắn chat khác nếu chủ chưa cho phép.
4. Giữ13operation/AX mới, một native click, ticket redaction, không downloadwait/path/fetch/blob; tab UNKNOWN/timeout không retry. Observation không đồng nghĩa completion. Không dùng browser response/API export làm saved-devicePASS; không tải lại hoặc tự đọc Downloads.

Output ngắn `docs/evidence/ui-source-prelaunch-20261016/frontend/HANDOFF.md` + mapping/kiểm static tối thiểu, không testharness mới hoặc rerun28web/3build full nếu không có delta. Bàn giao rồi giữREADY/chờ; reviewer đọc, frontend chưa thao tác nguồn và không cần nhắn chat khác.

## Reviewer

Kiểm hai handoff sau khi hoàn tất; không chạy runtime song song backend. Chỉ sau khi runner/protocol/preflight rõ và có **lệnh nguồn mới của người dùng**, mới giao một lượt ghép cụ thể với backend owner/frontend browser. UNKNOWN về môi trường phải được kiểm trong lượt có phạm vi phù hợp, không nâng offlinePASS thành sourcePASS. Reviewer cập nhật CURRENT ngắn gọn; không dàn log vào AUDIT/PROGRESS.
