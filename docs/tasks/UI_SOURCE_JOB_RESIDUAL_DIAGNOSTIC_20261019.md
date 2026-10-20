# Backend — xác định residual process trong own host job, không runtime retry

19/10/2026. Chủ đã giao reviewer tự giao việc; bước này phục vụ blocker host boundary của [attempt đã review](../evidence/ui-source-runtime-probe-fixed-attempt-review-20261019/ASSESSMENT.md). Không thực hiện runtime mới hoặc tạo container. Mục tiêu là thu **identity/timeline** phân biệt residual PID thật với root/accounting/teardown timing, không đổi FAIL thànhPASS bằng phỏng đoán.

Đọc AGENTS/CURRENT, assessment ở trên, đúng `Win32Adapter.cs`/loader/native helper hiện hành và `ui-source-runtime-probe-fix/native.ps1`/core cần thiết. Evidence cũ chỉ4native receipts/summary/manifest được dẫn; không mở toàn bộ lịch sử. Tái dùng direct Win32 helper/toolchain đã có, kiểm APIs/marshalling/quyền bằng tài liệu Microsoft chính thức trước implementation; không Vanara/CsWin32/package/SDK/install mới. .NET/Win32 có sẵn cung cấp nghiệp vụ này; chỉ thêm glue quan sát còn thiếu.

Code mới chỉ `labs/tiktok/ui-source-job-residual-diagnostic/`; evidence mới `docs/evidence/ui-source-job-residual-diagnostic-20261019/backend/`. Giữ owner24source/helper gốc SHA `5ed79b96326b56535077c6a97b7b0b30fee1031379f74dc845cfc6fcebbf7f19`, fix6source/17artifact, epoch runtime-reviewed-1/8artifact và mọi baseline/manifest/app/UI/plan/locks/trust nguyên. Không sửa golden hoặc integration helper để thu đượcPASS. CURRENT do reviewer cập nhật.

## Collector chỉ quan sát

1. Ưu tiên API/properties công khai hiện có: Result có RootPID/creation/events nhưng wrapper epoch cũ không persist chúng. Cần residual PID list trước Stop thì có thể dùng **bản sao helper riêng được pin+đổi namespace** với minimal diff instrumentation; không thay helper production/integrated hoặc viết lại executor. Bàn giao base hash và diff đầy đủ, giữ nguyên create-at-job/HANDLE_LIST/KILL_ON_LAST_CLOSE/không breakaway, Stop/force/FAIL predicate, child deadline/output cap/cleanup semantics. Không thêm grace period/delay-wait/retry để đổi kết quả.
2. Query **đúng owned job handle đang sống**, JobObjectBasicProcessIdList/class3 cùng accounting/class1, RootPID/creation/exit/wait phase và monotonic event time quanh root-exit/release/before-Stop. Giữ JOB_OBJECT_QUERY, x64 DWORD/ULONG_PTR widths/offset/length và Win32 return/lastError/returnLength thực; không đọc buffer khi native call fail hoặc counts vượt bounds. Chọn cap tối đa16PID, tối đa3snapshot/operation; ERROR_MORE_DATA/count mismatch thì mark incomplete/UNKNOWN, không growth loop/retry/broad enumerate.
3. Chỉ inspect PID **vừa nhận từ own job list** bằng minimum query/synchronize rights, verify membership và creation identity để tránh PID reuse. Ghi PID/creation/root-match/member-check/wait-state, optional executable **basename** nếu API/quyền được xác minh. Không full paths/command lines/env/token/credentials; không Toolhelp/global process scan/host services/ACL/namedpipe enumeration. Process biến mất/access denied là observationUNKNOWN, không thay token/quyền hoặc retry để điền dữ liệu.
4. Không duplicate/giữ root/job handles qua lifetime gốc hoặc leak observer handle; đóng metadata handles ngay. Việc query/open handle có thể nhiễu timing: ghi overhead/giới hạn, không coi phép đo mới là causal proof của epoch cũ. Lỗi collector không chặn Stop/finally, không nớiFAIL; nếu không đủ cleanup tail thì bỏ observation/makeUNKNOWN chứ không kéo deadline. Không claim universal hardcancel cho synchronous APIs/compiler. Giữ observer chỉ trong own job, không default-null hJob để query job của host.
5. Pin DLL/source/exe/location/MVID/layout và baseline trước/sau; compile bằng Add-Type hiện có nếu cần, no dependency. Raw output boundedRAM; persist allowlist≤64KiB/operation và diagnostics≤16KiB, giữ mọiFAIL. Explicit env override guard, không clear env/context để vượt.

## A. Controls offline/synthetic trước

Tối đa8native synthetic one-shots tuần tự, max1fixture job, tối đa root+1child, watchdog≤15s/cap64KiB. Chỉ fixture executable/script đã pin có sẵn; không external network/services. Ít nhất root nhanh không descendant và root exit với descendant còn sống có chủ ý; case thứhai phải giữ nativeFAIL/forced + job/tree/counters cuối0. Có kiểm bounds/count/error/identity reuse/missing PID bằng pure fixtures nếu không tái hiện tự nhiên, ghi đúng giả lập chứ không Win32 thực. Không spawn nhiều child để ép overflow hoặc lặp hàng trăm lần săn race. Collector không bảo toàn semantics/pins/cleanup thì dừng phaseB.

## B. Đúng một local Docker query chỉ đọc để chẩn đoán

Chỉ sau controls hợp lệ và plan code+pins/observer scope đã seal, được thực hiện **một** CLI query qua diagnostic helper với exact absolute docker.exe/SHA hiện hành, endpoint `npipe:////./pipe/dockerDesktopLinuxEngine`:

`ps --all --no-trunc --filter name=^/wed-source-990d89fe669647638c38a62e1db60b7b-offline- --format {{.ID}}`

Đây là query read-only của namespace không có resource, **không** retry preflight để mở runtime admission. Request `exec_command require_escalated` nói rõ một scoped local Docker ps + observation own host job/PIDs,≤15s/64KiB, không mutation/source; không prefix PowerShell rộng hoặc giả quyền từ attempt trước. Tool từ chối thì dừng, không bypass transport/UI/Admin/ACL/settings. Không chạy version/info/token/time/port inventory, original helper A/B query thứhai, container inspect/run/create/start/exec/rm/pull/build/network/compose hoặc browser/TikTok/CDN/main.

Nếu không tái hiện residual, ghi **NOT_REPRODUCED_AT_SINGLE_OBSERVATION**, identity/cause lịch sửUNKNOWN rồi dừng; không chạy lại để có lỗi hoặcPASS. Nếu thấy PID root hoặc khác root, chỉ kết luận theo identity/wait/membership/timestamp thực; accounting+list không atomic, không mặc định signaled=accounting bug hoặc differentPID=source process. Không tự sửa helper/gate sau chẩn đoán hoặc runtime retry trong task.

## Bàn giao

HANDOFF/NEXT_REVIEW/manifest mới: delta collector tối thiểu+API references/layout/rights/error handling, source/exe/helper pins beforeafter, actual tool/native exits, case count và expectedFAIL vs testPASS, caps/overhead, phaseA observations, đúng0/1query phaseB, timeline/identity allowlist và cause confirmed/inference/UNKNOWN. Host tree cleanup proof riêng với daemon resource scope; không tạo resource thì không bịa resource removal. Không cộng suite cũ hoặc che forced queryFAIL bằng root0/final0. Giữ source authority/keys/grant/claim/main/gallery/deploy0/đóng.

Báo reviewer chat `01a14259-19b0-73f0-bd0c-0f5be84f6a88` theo ủy quyền chủ rồi **DỪNG**. Reviewer nghiệm thu sau bàn giao; frontend READY/chờ. Chỉ đề xuất hướng sửa có căn cứ nếu có, không tự thay semantics/bật runtime/source. Không thêm AUDIT/PROGRESS theo prompt lịch sử.
