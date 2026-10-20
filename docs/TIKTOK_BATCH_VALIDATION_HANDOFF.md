# Batch receipt–trace validation — bàn giao offline 11/10/2026

Successor `labs/tiktok/wholephoto-batch-validation/`; bằng chứng riêng
`docs/evidence/tiktok-batch-validation-20261011/`. F-BATCH-RECEIPT-TRACE-CONSISTENCY/P2
đã sửa và kiểm offline; trạng thái **CLOSED_OFFLINE_IMPLEMENTATION_PENDING_INDEPENDENT_REVIEW**.
Đây chưa phải kết luận kiểm toán độc lập hoặc nghiệm thu ảnh TikTok thật.

## Phạm vi mã và lý do dùng validator riêng

Đã đọc AGENTS, kế hoạch, kết luận/chỉ thị hiện hành, STRUCTURE và hồ sơ audit
policy C. Dùng aiohappyeyeballs2.7.1/public start_connection, JSON/math/Trace ledger,
Requests/urllib3, yt-dlp/FFmpeg và validator có sẵn. Thư viện TCP không biết hợp đồng
receipt/groupRecords/ownership của WED SNAP; phần tự viết chỉ là validator bounded,
exporter facts và fixture faults cần để kiểm hợp đồng này. Không viết TCP race,
DNS resolver, HTTP/TLS/parser/solver mới hoặc gọi helper private của thư viện.

API được đối chiếu official đúng pin:
[aiohappyeyeballs2.7.1 impl](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/impl.py).
Public API nhận loop/socket_factory/delay/interleave; không có max_concurrent.
Trong lượt này không đổi lời gọi/network behavior. Vendor commit
`4dfc926e30eea8d24c1a71602d73c0e9a895c191`, wheel SHA
`9243213661e29250eb41368e5daa826fc017156c3b8a11440826b2e3ed376472`, PSF-2.0,
J. Nick Koston/contributors, AGPL/Cobalt LICENSE/NOTICE và locks giữ nguyên.
Image cache `sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e`,
Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19 giữ; không build/pull/install.

Ba module mới: `batch_validation.py`, `validation_faults.py`, `validation_probes.py`.
Các bản sao được sửa: ownership/producer group fields, finalize, fixture routing,
worker injection, runner/gate và NOTICE/PROVENANCE. Candidate, DNS helper/worker,
operation coverage, TCP observer, accounting/linkage/order validators giữ byte SHA
của predecessor. Old lab `wholephoto-batch/`, apps, vendor/dependencies và lịch sử
không sửa. 30 file successor tạo full source inventory252 và runtime87.

## Producer và validation

Receipt version2 thêm `registryOwnerID` thực từ registry RAM. LIBRARY_SELECT
BEGIN/terminal có bounded opaque `contextOwnerID`; TCP/FIXTURE_TCP giữ groupIndex
chụp trước await. Trace terminal và group record dùng cùng một elapsed đo được,
không sửa timestamp hoặc dùng elapsed để sắp xếp events. Không thêm event rows,
rotate owner, nối worker↔proxy sharedCID/header hoặc nới trace admission.

Validator kiểm integer groups1..4 (không bool/float), groupRecords đủ/indices liên tục,
schema chính xác/numeric finite/bounds; chỉ group cuối successful. Failed groups
phải pending/live0 và socket đóng trước advance. Winner live1 là snapshot trước
handoff; receipt socketsLeft0 là snapshot sau tunnel, được kiểm riêng.

Toàn tập receipts phải khớp context có tunnel và registry owners trong raw trace,
không duplicate/missing/extra/disjoint owner hoặc orphan registry. Mapping
context↔registry lấy từ events producer; library group/operation index và paired
terminal phải khớp. SOCKET_CREATE/TCP operations thuộc đúng owner/group và nằm
trong interval LIBRARY_SELECT; q/active/elapsed/created/closed/live/pending/peak/suffix
khớp các facts đã ghi. Pair floor dựa DNS answer count/group position, kể cả pair
có winner đầu và chỉ tạo một socket; WINNER phải có TCP END thật. Missing toàn cặp
LIBRARY_SELECT bị từ chối ngay cả khi operation coverage còn COMPLETE.

NOT_STARTED/failure/deadline/cancel/epoch/admission/reap/trace incomplete không mở
file gate. Missing/UNKNOWN không được chuyển thành0; conflict có reason code/PARTIAL,
native20. Validator không đổi input và đọc private proxy evidence dưới UID65534;
worker UID1000 vẫn không đọc được private0600. Tệp provisional chỉ được giữ khi
native/file/trace/operation/batch/accounting/ownership đều đạt. Rejection dọn
image.jpg/part do lượt tạo, không đụng unrelated/preexisting SHA.

Origin receipt/TLS detail/correlation vẫn UNKNOWN. CONNECT200/owner mapping không
chứng minh TLS/client receipt hoặc đã tải được ảnh nguồn.

## Kiểm thực chạy

Final source snapshot SHA `c88e49d41528782a79fa05fccf86665f7f1115c11a56980f66325cb6a3a36288`; every source-before/after và runtime inventory
được đối chiếu cùng bản mã. Đây là bộ kiểm mới thực chạy, không chỉ đọc log lịch sử.

| Bộ kiểm | Số ca | Native và kết quả |
|---|---:|---|
| Hợp đồng accounting/index giữ nguyên |78| harness0; native0/20 theo kỳ vọng cũ |
| Derived batch mappings |4| stall→winner3, fast7, winner đầu; fast45 bounded prefix8/suffix37 UNKNOWN và connector20 |
| Policy C kế thừa |55| harness0; cleanup/coverage/epoch/admission/deadline giữ kỳ vọng |
| Receipt–trace validation mới |55| 1control native0,54negative native20; input không đổi/FD4→4 |
| Targeted whole fresh |8| worker/proxy0, JPEG hợp lệ provisional; validator20/dọn ownJPEG |
| Whole pipeline kế thừa + mới |48+8| 4control native0; negatives native20 theo kỳ vọng; harness0 |
| Cold source-policy import/trust |1 lần| networknone96MiB/source0; không gọi nguồn |

Targeted faults: groups0, records[], disjoint context, disjoint registry, duplicate
owner, missing whole library pair, pending record mismatch và rejection với keep.bin
có sẵn. Trace/operation/accounting/file contract vẫn PASS ở cả8; chỉ batch gate
FAIL/PARTIAL. `targeted-result.json` và `assessment.json` lưu từng native exit/reason.
Case giữ keep.bin đối chiếu SHA; image.jpg/part do lượt tạo không còn sau rejection.

Initial `run-1-normal`/`validation-1` có control+53 validation trước lần siết pair
floor/TCP END; đều PASS kỳ vọng nhưng không tính vào proof final. Raw/source hashes
giữ; `code-initial/` phục dựng đúng bytes hai module từ patch cục bộ, tất cả252 SHA
khớp snapshot initial (cách phục dựng ghi rõ trong snapshot.json). Final control
`run-2-normal` và `validation-2` dùng đúng hash cuối; code-validation-2,
code-contracts-1 và code-policy-1 giữ snapshot252 file riêng.

Lệnh thực chạy từ D:\WED SNAP, qua bundled PowerShell7:

```powershell
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/prepare.ps1
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/wire.ps1
pwsh -NoProfile -File labs/tiktok/wholephoto-batch-validation/run.ps1 -Attempt 1 -Case normal
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/run-validation.ps1 -Attempt 1
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/preserve-initial.ps1
pwsh -NoProfile -File labs/tiktok/wholephoto-batch-validation/run.ps1 -Attempt 2 -Case normal
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/run-validation.ps1 -Attempt 2
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/run-probes.ps1 -Kind contracts -Attempt 1
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/run-probes.ps1 -Kind policy -Attempt 1
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/run-policy.ps1 -Attempt 1
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/run-targeted.ps1
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/run-suite.ps1 -Start 20
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/run-gate.ps1
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/inspect-final.ps1
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/record.ps1
pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/run-verification.ps1
```

`save-code.ps1` thực chạy Kind validation/Attempt2, contracts/1, policy/1.
`pwsh` ở đây là executable
`C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe`.
Script wrappers lưu Docker command/native actual exit/UTC-VN/state/guards/source
before-after, kể cả childFAIL20/proxy containment30/timeout/cancel. Harness0 chỉ nói
expectations đúng; không đổi những native failures thành packet/file PASS.
Gate TestCanonical/TestRuntime/capture/Verify và verifier capture rồi readonly
được ghi riêng; revalidation không là rerun whole pipeline.

Bộ whole lần đầu dừng ở attempt59/observer-order-reopen: native main-before exit1
vì named pipe dockerDesktopLinuxEngine không tồn tại ở thời điểm06:13:27–30UTC.
Chưa tạo container/network, worker/proxy/validator chưa chạy; nguyên nhân vì sao
Docker API biến mất chưa xác định. Không restart hoặc đổi host. Đến09:09UTC kiểm
chỉ đọc image cache trả exit0; `resume-suite.ps1` chạy17 ca còn thiếu ở attempts100–116,
giữ raw/progress/suite-failure-59 nguyên bản và final source hash. Không lặp39 ca
đã đạt; manifest giữ cả precreateFAIL1, không tính nó là validator hoặc file FAIL.
Lệnh thêm thực chạy: `pwsh -NoProfile -File docs/evidence/tiktok-batch-validation-20261011/resume-suite.ps1`.

## Ngân sách, cleanup và preservation

Policy C không đổi: setup10s/end−1reserve; pair1..2s/singleton.60/reap.10/delay.25/
interleave0/4groups tối đa; không tăng timeout để thử source. Connect10/read20,
metadata30/prepare60,≤2 metadataGET+conditional1 JPEG GET, redirect0/retry0/HEAD0;
metadata8MiB/response–16MiB tổng, image input20MiB/output16MiB/workflow36MiB,
8192dimension/16Mpixel và full JPEG decode giữ. Trace256/owner32/map64/helper1 giữ.

Chạy tuần tự; proxy96+worker512=608MiB, CPU.25+.75; validator96 khi hai roles đã dừng,
UID65534/1000, read-only root/source mounts, swap=RAM, cap-dropALL/NNP/privateIPC,
pids64–96, internal fixture networks/no hostports. Probe512/networknone và cold
policy96/networknone. SSRF guard toàn DNS public set/TLS/byte/deadline vẫn giữ.
CA giả chỉ ở offline fixture; cold source branch kiểm original trust, không tải nguồn.

Exact recorded IDs: 203 containers/132 networks, đối chiếu với
toàn ID inventory hiện tại đều không còn. Cleanup check label run của chính lượt,
không sweep tài nguyên người khác. Main image
`sha256:e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b` giữ.
Baseline19.138 file lịch sử đối chiếu toàn SHA; chỉ hai docs có successor insert-only
với before copies/base64 offsets/hashes. Old audit manifest/successor, raw/golden/
verifier/codecopies/humanreview/lifecycle giữ; không sửa golden để ép PASS.

Source claim vẫn consumed, SHA
`cfb1d25d0f9eac42063d44686751a18d6069bcdd6ccfcd6dfdedf10e632748a7`.
Không TikTok/InternetDNS nguồn/HEAD/retry/reset claim/ảnh2/album/browser/solver/
fallback/main/gallery/API E2E/deploy/DB/settings/host change. Source runner vẫn
unconditionalOFF kể cả offline gate PASS. Original source metadata5/prepareFAIL20/
body0 và43IP khác/network root causeUNKNOWN giữ; chưa có ảnh nguồn decode/SHA/visual.
Video2/3, sample3 NEEDS_VISUAL_REVIEW giữ.

## Bước tiếp hiện hành

[Prompt kiểm độc lập](evidence/tiktok-batch-validation-20261011/NEXT_PROMPT.md).
Reviewer cần phân biệt hash revalidation, fixture replay, fresh whole pipeline và
source. Offline finding fix chưa mở quyền source trial/main/gallery/API E2E/deploy.
UTC ghi kết luận 2026-10-11T09:19:05.5720928Z; VN 2026-10-11T16:19:05.5778428+07:00. Native timestamps chi tiết ở mỗi run.
