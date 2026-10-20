# Trạng thái hiện hành WED SNAP

Cập nhật: 20/10/2026. Đây là điểm vào ngắn cho agent; lịch sử chi tiết vẫn được giữ nguyên trong AUDIT, PROGRESS và evidence nhưng không đọc mặc định.

## Trạng thái sản phẩm đã xác nhận

- Giao diện A sáng đã tích hợp vào `apps/web` và được nghiệm thu độc lập offline trên desktop/mobile. Hai nhánh ảnh capability false/thiếu và capability true với ticket retry/native JPG đã đạt bằng React thật + API fixture.
- **UI A→backend fixture đã nghiệm thu độc lập16/10**: browsernativeGET1, analyze/prepare hai child0, negatives403/404, HEADlease/GET/Range, outputJPEG64×64/248B được reviewer decode/hash,87logsealed hợp lệ/cleanup0resources. [Kết luận chuẩn](evidence/ui-final-fixture-review-20261016/ASSESSMENT.md). File-device saveUNKNOWN; không phải nguồn thật/main.
- Một ảnh TikTok canonical đã đi qua API/worker/egress trong lượt nguồn được giao và được reviewer đối chiếu tệp thật. Đây không phải chứng nhận mọi link, toàn album hoặc production.
- DNS child theo layout ứng dụng `/app` đã nghiệm thu độc lập offline ngày 16/10. Recipe ứng dụng không cần vá; `/repo` chỉ là mount lab. Không mở thêm vòng DNS nếu không có delta hoặc finding mới.
- Main flags cho TikTok photo/gallery chưa bật. Chưa có nghiệm thu UI + backend thật + nguồn thật trong cùng một luồng, chưa public deployment/P5–P6.
- Không có nhiệm vụ UI hoặc DNS đang mở chỉ vì lịch sử còn prompt cũ. Khi chưa có delta/handoff mới, reviewer dừng thay vì tự tạo thêm vòng test.
- **F-BROWSER-RECEIPT-RACE đóng**:23ca filesystem trước và final fixture runtime đã được đối chiếu; completionPASS chỉ sau finalgate+cleanup, nooverwrite/hashes đúng. [Review lịch sử](evidence/ui-gateway-handshake-review-20261016/ASSESSMENT.md). Provider universaltimeout chưa bảo đảm, tabUNKNOWN cũ giữ.
- Nhiệm vụ combined fixture **đã khép**: reviewer chạy6ca gateunit+validator riêng đạt,75artifact/6successor/199pin khớp. Không còn nhiệm vụ tựlaunch tiếp; nguồn thật/main/gallery/deploy cần chỉ thị riêng. Giữ toàn bộFAIL/evidence cũ.
- Phân công UI+nguồn thật: **Win32 host boundary giữ đạt offline19/10** ([98ca +5check](evidence/ui-source-direct-win32-integration-review-20261019/ASSESSMENT.md)); mount/admission giữ đạt offline. [Python reporting correction đã đóng](evidence/ui-source-access-triage-readonly-review-20261019/ASSESSMENT.md), query Python cũ vẫn FAIL/version=null, token/ACL cause lịch sử chưa chứng minh.
- Docker local version29.8.1/API1.56 đã quan sát qua exec được phê duyệt; **7query metadata/cache readonly đã nghiệm thu độc lập19/10** ([kết luận chuẩn](evidence/ui-source-cache-metadata-readonly-review-20261019/ASSESSMENT.md)):4immutable IDs/5roles Linux/amd64, scoped list0/0,7native+operationPASS;40artifact/5source và frozen31source/61artifact khớp,20fixture reviewer đạt, không query daemon lại. Engine advertised capabilities chưa là role enforcement; read_thread không lộ raw approval fields, chi tiết permission là record backend.
- Runtime offline lượt đầu19/10 **FAIL trước app start** ([review](evidence/ui-source-runtime-offline-probe-review-20261019/ASSESSMENT.md));48artifact/12source/250pins giữ, cleanup-only ownCID đãCLOSED09:46:30UTC, original cleanupfalse/outerexit1 giữ. Hai finding đã **đóng scope sửa offline** ([review fix](evidence/ui-source-runtime-probe-fix-review-20261019/ASSESSMENT.md)):6source/17artifact/311baseline pins khớp,58case backend+17check reviewer tách riêng,0daemon; Go-template thực/runtime vẫnNOT_RUN.
- Attempt probe sửa **FAIL preflight trướcCREATE** ([review](evidence/ui-source-runtime-probe-fixed-attempt-review-20261019/ASSESSMENT.md)):4root0 khác3nativePASS/1FAIL; collision forced/jobAfterRoot1/final0/EOF, chưa biết PID/cause.6source/7overview+8epoch/311baseline pins nguyên; ledger/results rỗng,5rolesNOT_RUN, scopedabsenceCLOSED10:13:26UTC, khôngretry/mutation. Không bỏ force gate hoặc quy lỗi TikTok/daemon từ root0.
- [Diagnostic1ps không tái hiện](evidence/ui-source-job-residual-diagnostic-review-20261019/ASSESSMENT.md), cause/PID lịch sửUNKNOWN; không đổi forcegate/giảm nghĩa perturbation. **F-DIAG-PERSISTED-BYTE-CAP đã đóng successor offline** ([review logger+wiring](evidence/ui-source-diagnostic-runtime-review-20261019/ASSESSMENT.md)):7source/1326artifact/398pins khớp,630finalreceiptspans dướicap (coverage khôngcase);21byte+18wiring backend/15check reviewer tách riêng,0native. Old18799Bfixture/FAIL giữ, successor9543B/caps16K64K exactbyte.
- **Runtime offline có diagnostic đã nghiệm thu19/10** ([kết luận chuẩn](evidence/ui-source-diagnostic-runtime-attempt-review-20261019/ASSESSMENT.md)):5role exited0/54nativePASS/165envelopes dướicap, Node22Linux/import/schema synthetic/149mappingrows/kernel-role đạt;5ownCIDcleanup/scopedabsenceCLOSED14:56:14.8911709UTC.7source/7overview+167child/1326oldartifact/398pins nguyên; reviewer9nhóm kiểm+scopecheck,0daemon. Product outer0/47106ms, coordinator45035ms;1diagnosticPIDidentityUNKNOWN giữ, không certify originalowner/source.
- Task offline **đã khép**, backendDỪNG/frontendREADY/chờ vì khôngdelta; không tự mở vòng test. UI–backend–TikTok thật chungluồng vẫn chưa nghiệmthu; egress/TLS/browserNOT_RUN, clock/portUNKNOWN/ownerchưalaunch-ready. Lượtnguồn/bước tíchhợp cần phạmvi/quyền riêng; [target cũ](tasks/UI_SOURCE_TARGET_20261016.json) không cấp quyền: keys/grant/claim0/main/gallery/deploy/nguồn đóng.
- Chủ yêu cầu **“khi nào tiktok hoàn thiện thì hô tôi”**: đã tạo heartbeat theo dõi trong chat nghiệm thu mỗi giờ, chỉ báo hoàn tất có review độc lập hoặc sự cố/quyết định mới cần chủ; im lặng khi không đổi, không nhắc lại blocker quyền nguồn đã báo. Đây không cấp quyền triển khai/lượt nguồn mới; automation `b-o-khi-tiktok-c-nghi-m-thu-ho-n-ch-nh` ACTIVE.
- **Lệnh mới của chủ “làm đi”19/10** chấp thuận đúng1lượt UI→backend→TikTok thật bài cũ/ảnh02, lab riêng+cleanup, không main/gallery/deploy. [Task hiện hành](tasks/UI_TIKTOK_SINGLE_PHOTO_NEW_LAUNCH_20261019.md) thay HOLD vì thiếu human go-ahead: backend chuẩn bị readiness/successor/one-use authority và frontend chuẩn bị browser, reviewer GO sau handoff kỹ thuật rồi mới1source admission. Chưa mint grant/claim/launch/source request từ việc ghi nhận lệnh; old target/grant vẫn không authority và không tái dùng.
- **Review A: chưa launch-ready/chưa GO B** ([kết luận](evidence/ui-source-live-attempt-a-review-20261019/ASSESSMENT.md)):9source/72artifact/1914deps/2165batchpins khớp; readiness batch outer1/2661ms FAIL trướcCREATE, nativeResult/PID/causeUNKNOWN, absence chưachứngminh. Backend42unit+8fake tách reviewer3purechecks/0native; PoC issuer luôn deny, live adapter thiếu và finding cleanup-mount coupling còn mở. Frontend protocolstaticREADY; [giao hoàn thiện adapter+cleanup+trace](tasks/UI_SOURCE_LIVE_ADAPTER_FIX_20261019.md), choAPIextension lab hẹp/diff riêng, khôngnative/runtime/source tiếp trước review. Human1lượt còn nguyên/chưaconsume, không cần xin lại.
- **Review adapter20/10: nhận một phần offline, chưa GO readiness/B** ([chuẩn](evidence/ui-source-live-adapter-fix-review-20261020/ASSESSMENT.md)):22source/4787artifact/5immutable và A preservation khớp,6794hashpaths; backend36managed+6fake tách reviewer2nhóm phảnvídụ/0native. PositiveAPI đã nối, cleanup-mount coupling đóng offline; bộlọc chặn PostgreSQL payload `-c` và windowreader bỏprivateproof/contractbudget là2finding mới. [Sửa hẹp](tasks/UI_SOURCE_ADAPTER_FINAL_GAPS_20261020.md) trước readiness; frontendREADY/chờ, human workflow chưaconsume, main/gallery/deploy đóng.

## Thứ tự nguồn sự thật

1. Mã nguồn hiện hành trong `apps/`, `packages/`, `prisma/`, `infra/` và component lab được giao.
2. File này.
3. TASK/HANDOFF/ASSESSMENT mới nhất được nhiệm vụ dẫn trực tiếp.
4. `docs/STRUCTURE.md` cho bản đồ đường dẫn.
5. AUDIT, PROGRESS, TEST_REPORT và raw evidence chỉ để truy nguyên lịch sử cụ thể.

Nếu có xung đột, không đọc tràn lan. Xác định đúng component, mở một handoff/assessment gần nhất và raw tối thiểu cần thiết, rồi ghi lại trạng thái đúng vào file này.

## Định tuyến theo nhiệm vụ

| Nhiệm vụ | Đọc thêm |
|---|---|
| UI/UX | `apps/web/`, phần web trong `docs/STRUCTURE.md`; đọc Taste Skill theo AGENTS |
| API/session/job/download | `apps/api/`, `packages/shared/`, `docs/API.md`, `docs/LIFECYCLE.md` khi liên quan |
| Worker/lifecycle/cleanup | `apps/worker/`, `docs/LIFECYCLE.md`, test đúng phase |
| Media/yt-dlp/FFmpeg | `apps/media/`, `docs/ADAPTERS.md`, dependency lock hiện hành |
| Egress/DNS/SSRF/TLS | `apps/egress/`, handoff/assessment egress mới nhất được nhiệm vụ dẫn |
| TikTok lab | Chỉ thư mục con được giao trong `labs/tiktok/` và evidence cùng tên |
| Phạm vi/kiến trúc/roadmap | `PLAN_WORKFLOW_VIDEO_DOWNLOADER_V1.md` |
| Lịch sử nghiệm thu | Heading/ngày/keyword cụ thể trong AUDIT/PROGRESS; không đọc toàn file |

## Quy tắc tìm kiếm và evidence

- Dùng `rg --ignore-file .ignore` và giới hạn đường dẫn, ví dụ `rg -n "pattern" apps/api packages/shared`.
- Không dùng `rg -uu`, `Get-ChildItem -Recurse` ở root hoặc `Get-Content -Raw` trên hồ sơ lớn trừ khi người dùng giao kiểm kê toàn kho.
- Trong evidence, đọc theo thứ tự: `ASSESSMENT.md` hoặc `HANDOFF.md` → manifest/proof → raw file cụ thể. Không suy test PASS chỉ từ tên file hoặc script tồn tại.
- Binaries, certificate bundles, snapshot source và raw logs không được đưa vào context nếu hash/summary đã đủ cho câu hỏi.
- Tool output phải được lọc: ưu tiên danh sách tên file, số lượng, hash hoặc đoạn dòng hẹp; lưu raw vào file khi cần và chỉ báo tóm tắt trong chat.

## Cập nhật sau công việc

- Cập nhật mục trạng thái tương ứng trong file này bằng tối đa vài dòng và liên kết tới một nguồn chuẩn.
- Không chép toàn prompt, log, hash list hoặc cùng một kết luận vào cả CURRENT, AUDIT và PROGRESS.
- Chỉ tạo evidence mới đủ để chứng minh delta hiện tại; tham chiếu snapshot/hash đã có thay vì sao chép toàn cây nguồn/dependency.
- Không xóa hay sửa evidence/golden/manifests lịch sử để tối ưu token.

## Hồ sơ hiện hành cần biết

- UI app review: `docs/evidence/ui-a-app-integration-review-20261016/ASSESSMENT.md`.
- UI photo branches review: `docs/evidence/ui-photo-branches-review-20261016/ASSESSMENT.md`.
- Backend photo source review: `docs/evidence/tiktok-photo-source-fixed-live-review-20261015/ASSESSMENT.md`.
- DNS app-layout review: `docs/evidence/tiktok-dns-app-port-review-20261016/ASSESSMENT.md`.
- Handoff reviewer: `docs/HANDOFF_KIEM_THU_CHAT_MOI_20261016.md`.

## Thay đổi quản trị ngữ cảnh 16/10/2026

- Thêm `.ignore` để loại evidence/raw/binary và hai ledger lịch sử khỏi tìm kiếm mặc định.
- `AGENTS.md` chuyển từ đọc bắt buộc nhiều tài liệu lớn sang progressive disclosure qua CURRENT.
- Khởi tạo Git local ngày16/10 trên nhánh `main` và gắn `origin` tới `https://github.com/BTHung2747/WEB-SNAP.git`; tại lần khởi tạo, remote trống và chưa commit/push.
- Phạm vi đồng bộ GitHub theo lệnh chủ20/10: mã nguồn, lab, tests, scripts, cấu hình mẫu và tài liệu thuộc Git trên `main`. Giữ quy tắc `.gitignore` hiện có: `.env`, dependencies/build, log/video, backups, `lab-runs/` và raw evidence không nằm trong bản Git; dữ liệu local và bằng chứng nghiệm thu không bị xóa.
- AUDIT/PROGRESS/evidence cũ được giữ nguyên; tối ưu này không phải kết quả chức năng mới và không cấp quyền chạy nguồn, bật main hoặc deploy.
