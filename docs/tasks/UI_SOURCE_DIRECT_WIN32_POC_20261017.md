# PoC containment bằng Win32 trực tiếp — giao backend

17/10/2026, Asia/Saigon. Chủ chọn **“cái 1 đi”** sau hai phương án thay Vanara: (1) gọi Windows API trực tiếp; (2) CsWin32. Phạm vi mới là helper/PoC offline riêng dùng toolchain đã có, không phải quyền cài SDK/compiler hoặc chạy nguồn. Backend thực hiện; reviewer chỉ nghiệm thu sau bàn giao, không chạy test song song.

## Quyết định và điểm xuất phát

- Chọn direct Win32, **không tải/cài/load Vanara, CsWin32 hay NuGet mới**. Nghiên cứu thư viện trước đó vẫn giữ nguyên làm hồ sơ phương án đã xem xét; quyết định trực tiếp của chủ thay đề xuất chờ tải hai package.
- Chỉ viết lớp nối cần thiết cho Windows Job Object/process/pipe/handle; không xây lại framework Win32. Trước code, kiểm dependencies và khả năng compiler/runtime sẵn có trong phạm vi component. Có thể dùng PowerShell Add-Type nếu xác minh hoạt động bằng toolchain hiện có. Không tự cài compiler/SDK/module khi thiếu.
- [Review nghiên cứu](../evidence/ui-source-containment-research-review-20261017/ASSESSMENT.md) là đầu vào; [review native fix](../evidence/ui-source-owner-native-fix-review-20261017/ASSESSMENT.md) giữ hiệu lực: orphan mới MITIGATED_FAIL_CLOSED, containment NOT_IMPLEMENTED, owner chưa dùng được.
- Không sửa assessment lịch sử thành phê duyệt interop mới. Task này cấp phạm vi triển khai tối thiểu direct interop **chỉ trong PoC tách biệt**; chưa cho thay gate/native owner.

## Phạm vi file

- Code/helper/fixture mới: `labs/tiktok/ui-source-direct-win32/`.
- Evidence mới: `docs/evidence/ui-source-direct-win32-20261017/backend/`; tạo các attempt riêng, không overwrite FAIL.
- Đọc có chọn lọc native process/capture và source pins hiện hành để tương thích hợp đồng. Không sửa 16 file trong `labs/tiktok/ui-source-owner-native/`, glue/prelaunch, app, lockfile hoặc manifest/golden cũ. Ghi before/after pin của native owner để chứng minh không đổi.
- Reviewer quản lý CURRENT; backend ghi HANDOFF của mình. Không nhân bản prompt vào AUDIT/PROGRESS.

## Cổng trước implementation

1. Ghi toolchain/architecture/runtime thực tế và khả năng compile local, không suy không có tool chỉ từ một cache thiếu. Nếu không có cách compile an toàn bằng thành phần đã cài, dừng báo chính xác thứ thiếu để chủ quyết định.
2. Đối chiếu P/Invoke signatures, constants, x64 structure size/alignment, BOOL/DWORD/SIZE_T/pointer, Unicode/mutable command line, SetLastError và handle lifetime bằng tài liệu/header/source **chính thức Microsoft**. Lưu URL/version/commit hoặc hash nội dung tham chiếu và bảng đối chiếu layout kiểm được. Không đoán offset hay chép declaration từ blog bên thứ ba. Được đọc tài liệu/header nguồn công khai; không tải/cài SDK hoặc binary package mới.
3. Nêu phần tự viết và lý do: chủ chọn tránh dependency sau khi đã xem Vanara/CsWin32; chỉ interop/glue cần cho PoC. Nếu API/layout/hành vi không xác minh được, giữ UNKNOWN và báo, không lấp bằng giả định.

## Thiết kế cần chứng minh

- Job riêng, unnamed, handle không inherit, kill-on-last-close; gắn job **ngay lúc tạo process** qua `PROC_THREAD_ATTRIBUTE_JOB_LIST`. Không fallback Start/assign hoặc suspended/assign khi create-at-job thất bại. Không breakaway, nâng quyền hoặc can thiệp job của host.
- Kiểm nesting thực tế của môi trường; lỗi/không hỗ trợ phải fail closed, không coi API tồn tại là đã chạy được. Chỉ áp dụng cho owned pinned child commands; Job Object không được quảng cáo là sandbox chống mọi broker/service bên ngoài.
- EXE tuyệt đối đã xác minh, không shell, cửa sổ ẩn; giữ ranh giới executable/argv. Kiểm empty/spaces/quotes/backslashes/Unicode theo quy tắc runtime đích, không dùng dữ liệu thật hoặc bí mật làm argv test.
- Inherit đúng stdin/stdout/stderr cần thiết bằng handle-list đã xác minh, không leak job/parent/pipe ends. Thu bounded output, timeout và reader cleanup rõ ràng; không giả anonymous pipe hỗ trợ overlapped I/O.
- Phân biệt root exit, stream EOF, job ActiveProcesses và handle/reader closure. Root exit0 hay Dispose không chứng minh tree closed. Làm rõ thứ tự lấy exit code/đóng owned process references/query job theo semantics chính thức; bất kỳ phần nào chưa rõ phải UNKNOWN, không PASS.
- Thu Win32 error ngay tại failure, ownership một nơi, dọn cả partial-create/attribute list/buffers/process/thread/job/pipe. Không log raw secrets. Không kill PID đoán/reused hoặc cây process không sở hữu.

## Thử nghiệm offline tuần tự

Chỉ fixture vô hại bằng Node/Python/toolchain đã có; mỗi ca watchdog tối đa15s, từng job một, tối đa4 fixture processes/job, đặt job memory cap256MiB nếu semantics đã xác minh. Fixture dài có tự thoát an toàn trong tối đa5s nếu containment chưa hoạt động. Không chạy nhiều suite/service; nếu cap/toolchain không đáp ứng, ghi FAIL/HOLD và đề xuất thay vì tự nâng ngân sách.

Các nhánh cần bằng chứng thực, không chỉ mock/happy-path:

1. Root exit0 và nonzero; argv round-trip; root exit khác tree-closed decision.
2. Root thoát trước detached child/grandchild; descendant đã đóng stdio vẫn còn sống; chứng minh job xử lý trường hợp orphan cũ.
3. Descendant giữ pipe mở/output trễ; timeout và output-cap; EOF/drain/reader closure có deadline, không unbounded read/task còn treo.
4. Create/attribute failure, nested-job hoặc assignment restriction nếu môi trường cho phép tái hiện an toàn; fault injection phải ghi rõ là giả lập, không gọi nó là lỗi Windows quan sát thật.
5. Cleanup bình thường và owner bị kết thúc đột ngột trong fixture riêng để kiểm kill-on-last-close. Observer **không giữ duplicate job handle** khiến last-close test mất ý nghĩa; dùng owned process handles/identity để quan sát exit. Không kết thúc host Codex, terminal cha, service hoặc process ngoài fixture.
6. Repeated bounded cycles kiểm handle/reader/resource leaks. Đếm/count/query là evidence có phạm vi, không suy universal guarantee.

Nếu case không thể chạy an toàn/đúng quyền, ghi NOT_RUN và lý do; không sửa expected để ép PASS. Không rerun68/95/34 ca cũ khi chưa có delta vào các component đó.

## Bàn giao và điều kiện dừng

HANDOFF cần có: file delta; API/layout provenance; toolchain/compile thực chạy; source/binary SHA và command tái hiện; từng case expected/observed/child ExitCode/duration/job-tree/pipe-reader cleanup; memory/caps/handle observations; before/after16 native pins; manifest artifact; FAIL/UNKNOWN/NOT_RUN; giới hạn của PoC và đề xuất tích hợp riêng.

Child exit lấy từ process handle/.NET Process.ExitCode thực tế, không dùng LASTEXITCODE của shell thay thế. Không gọi compile thành công hoặc suite exit0 là containment đạt. Backend báo kết quả về reviewer rồi dừng; chưa tự tích hợp hoặc mở gate.

**Không Docker/pull/build image/service/browser/probe/TikTok/CDN/source HTTP/DNS; không dependency mới/global settings/live signer/approval/grant/claim/main/gallery/deploy.** Target bài cũ ảnh02 chỉ là lựa chọn nội dung, không là quyền chạy nguồn. Frontend vẫn READY/chờ. Muốn thử nguồn sau này cần review môi trường/code và lệnh launch mới của chủ.

## Nguồn chính thức định tuyến

Reviewer đã kiểm cơ sở attach-at-create; backend phải đọc thêm đúng declarations/layout/API dùng, không coi danh sách này đã thay việc xác minh:

- [Microsoft: tạo process trong Job Object](https://devblogs.microsoft.com/oldnewthing/20230209-00/?p=107812/).
- [UpdateProcThreadAttribute: JOB_LIST/HANDLE_LIST và lifetime](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute).
- [CreateProcessW](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw), [Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects), [Nested Jobs](https://learn.microsoft.com/en-us/windows/win32/procthread/nested-jobs).
- [Job accounting](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_accounting_information), [Extended limits](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_extended_limit_information), [Anonymous pipes](https://learn.microsoft.com/en-us/windows/win32/ipc/anonymous-pipe-operations).
