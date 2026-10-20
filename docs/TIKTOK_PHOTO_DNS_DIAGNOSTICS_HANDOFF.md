# Receipt nguồn và DNS helper diagnostics — 11/10/2026

**FIXED_OFFLINE_PENDING_INDEPENDENT_REVIEW.** Successor: `labs/tiktok/photo-dns-diagnostics/`. Evidence: `docs/evidence/tiktok-photo-dns-diagnostics-20261011/`. Nhiệm vụ này không gọi TikTok/Internet DNS, tạo claim, retry/reset, bật main/gallery hoặc deploy.

## Phần sửa và thư viện

- `receipt_labels.py` + `worker_entry.py`: bỏ nhãn source=false/fixture=true hardcode; stage xác định nguồn/fixture, cờ đánh dấu ngay trước pipeline xác định invocation thực sự bắt đầu. `analyzeInvocations` không là số GET; `sourceAnalyzeAttempts` chỉ tính stage source. `sourceCalls` của source là `UNKNOWN_USE_REQUEST_ACCOUNTING`. Không đổi stage metadata/prepare, native exit/error/ownership.
- `dns_diagnostic.py` + `dns_ipc.py`: observer tại object IPC sau `json.loads`, trước mapping lỗi có sẵn. Chỉ lấy status/code đã whitelist, type, số answers và timing/nativeexit/reaped/pipes/group sau cleanup. Không giữ hostname/IP/URL/cookie/token/raw response/message/repr/stack. `helperThreads` cũ được lọc integer1–96 hoặc null; chứng cứ COMPLETE yêu cầu identity fields đúng kiểu, threads1. Helper native0 không đủ cho PASS. Unknown/malformed/missing hoặc trace incomplete không PASS.
- Trace dùng `Trace.observe` đã có, giữ exception chính khi trace thất bại; các pipe/process/group vẫn đóng/reap. Với dữ liệu hợp lệ nhưng evidence không đủ, ném DiagnosticIncomplete sau cleanup. Mã/helper DNS, parser/transport/TLS/TCP/race không viết lại.
- `finalize.py`: thêm receiptLabelGate và dnsDiagnosticGate vào điều kiện chấp nhận ảnh; thiếu/mâu thuẫn phải reject20 và xóa đúng own output, giữ unrelated/preexisting.
- `run.ps1` mặc định disabled; mọi stage khác offline reject20 trước Docker/network. `common.stage_policy` chặn source cả Python entry. `source_contract.ps1` successor chỉ còn inventory/hash functions, không ClaimSourceAllocation hoặc API mở nguồn. Không sửa runner/claim của lab cũ.

Đối chiếu API public đúng [CPython3.11.2 socket.getaddrinfo](https://raw.githubusercontent.com/python/cpython/v3.11.2/Lib/socket.py), [Popen close_fds/start_new_session/wait/poll](https://raw.githubusercontent.com/python/cpython/v3.11.2/Lib/subprocess.py), [DefaultSelector/register/select/close](https://raw.githubusercontent.com/python/cpython/v3.11.2/Lib/selectors.py). Tái dùng thư viện và IPC JSON có sẵn; phần tự nối chỉ là nhãn, whitelist và kiểm bằng chứng thuộc dự án. Test fake IPC ủy quyền public Popen để spawn child fixture; không monkeypatch private API trong runtime. Không dependency/build/pull/install mới.

Pins giữ: Python3.11.2, Requests2.34.2, urllib3-2.8.0, yt-dlp2026.8.19, aiohappyeyeballs2.7.1, image `sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e`; LICENSE/NOTICE/locks/vendor nguyên byte theo baseline. Final source350/runtime91/hash `028f4e3d7b4fa40d91381e9231034e7564c18211399e370c84b13e6eb68a0d04`.

## Lệnh thực chạy và kết quả

Bundled pwsh: `C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe`. Các script dưới dùng `-NoProfile -File`, đường dẫn trong evidence mới.

| Lệnh | Kết quả thực |
|---|---|
| `prepare.ps1` | Chụp baseline29.153 files, copy successor; old code chưa sửa |
| `run-probes.ps1 -Attempt 1` | Container20/tool1, dừng sau16ca; fixture cancel thiếu cancel=True, trace END sau2,10s chứng minh thao tác thường chưa bị cancel |
| `run-probes.ps1 -Attempt 2` | 35ca/native0, code snapshot riêng |
| `run-whole.ps1` | 7fresh fixtures1–7 trên code trung gian, đạt kỳ vọng; giữ raw |
| `run-probes.ps1 -Attempt 3` | **Final37ca/native0**, UTC14:18:49/VN21:18:49+07; thêm lọc helperThreads/token giả và source Python entry bị chặn |
| `run-whole-final.ps1` | **Final7fresh fixtures11–17**, kết thúc UTC14:21:15/VN21:21:15+07; same final source before/after |
| `run.ps1 -Stage disabled` / `-Stage source` | Cả hai marker SUCCESSOR_SOURCE_DISABLED_NO_NETWORK/exit20, claim/network0 |
| `run-revalidate.ps1 -Attempt 1` | Container1: case control trùng `/out/control` do runner đã tạo; chưa validator |
| `run-revalidate.ps1 -Attempt 2` | Container1: copytree dừng trong worker trước proxy/validator; chứa observer UID1000/private |
| `run-revalidate.ps1 -Attempt 3` | **5ca/native0**, xác nhận UID65534 bị deny đọc private worker observer; chỉ copy các input validator cần, không nới permissions |
| `inspect-final.ps1` | Exact48containers/28networks không còn, main image giữ |
| `verify.ps1 -Capture`, rồi `verify.ps1` | Freeze manifest mới và readonly verification; kết quả machine-readable ở verification-capture.json/verification.json |

Các receipt native.jsonl ghi actual start/end UTC, container exit, stdout fixed/sanitized; completion có UTC/VN. Tool exit1 không thay container exit20 của probe1. `code-attempt-1`, `code-attempt-2`, `code-final`, raw/cause và các script lỗi revalidation đều giữ. Revalidation chỉ đổi harness sau lỗi fixture, **runtime cuối không đổi**; không dùng intermediate tests mở cổng nguồn.

37 probes gồm: source Python bị chặn; source/offline với workflow chưa bắt đầu/đã bắt đầu; bản sao raw mâu thuẫn bị reject và synthetic relabel giữ stage/error/exit/accounting; conflicts source/fixture/sourceCalls/count/bool; DNS numeric OK, getaddrinfo error bằng AI_NUMERICHOST, answer cap, child exit, response cap, absolute deadline/cancel, known ERROR/ANSWER_CAP/DEADLINE, unknown code, secret threads, missing status, wrong type, unknown OK code, malformed/missing JSON, trace write/raise/missing, primary exception identity; thiếu/sai diagnostic không được PASS. Helper processes thực với Popen/selectors; chỉ numeric/IPC giả, network-none. FD7→7/thread1→1 từng DNS case; helper reaped/pipesclosed/group0 và upstreamSockets0. Status ERROR được quan sát đầy đủ có thể evidence COMPLETE nhưng resolution FAIL; đây không phải metadata/DNS PASS.

## Fresh whole pipeline và file fixture

Normal: worker0/proxy0/validator0; metadata2GET + prepare1GET nội bộ, receipt source=false/fixture=true/analyzeInvocations1/sourceAnalyzeAttempts0/sourceCalls0. JPEG **2.170 byte,64×64,4.096pixels,1frame,magic jpeg/MIME image/jpeg/fullDecode PASS**, SHA `3c94b9a6bbfab0c44c02d0c520dca952e23dc7a396e30a6ef3b0fe00bcc0cc3e`.

Wrong-body/redirect/health-missing/preexisting: worker20/proxy0/validator20. Closure-live/missing: worker0/proxy0 nhưng validator20, own JPEG bị xóa. Runner test exit0 có nghĩa khớp expected negative, không filePASS. Các packet PASS vẫn provisional đến native child0/validator0/guards.

Revalidation5 dùng **copies** của normal fixture: control validatorReturn0 giữ JPEG; label conflict/DNS missing/unknown/native bool validatorReturn20/xóa own JPEG. Trace/operation/accounting/batch gates vẫn PASS để cô lập gate mới. Unrelated sentinelSHA `f630f2c173e4715bcce254c5a166449adc05729c2bcaa6b58f4e2f3b7fc21926` giữ trong mọi ca. Không fresh HTTP/worker/helper trong revalidation, không ảnh nguồn.

Guards giữ: metadata30/prepare60,≤2GET metadata/conditional1GET ảnh,redirect/retry/HEAD0,8MiB-response/16MiB-total metadata,20MiB-input/16MiB-output/workflow36MiB,8192dimension/16Mpixels. Setup10/end−1reserve, connect10/read20 clamp remaining, policyC pair1–2/singleton.60/reap.10/delay.25/interleave0/2sockets/4groups/prefix8/answers64/helper1/trace256-owner32-map64. Whole proxy96+worker512=608MiB,CPU.25+.75; validator96 sau stop roles. Probe512/networknone và revalidation96/networknone; RO/privateIPC/UID65534–1000/swapRAM/capALL/NNP/pids/nohostports giữ. Không thay host/WSL/Docker/seccomp hoặc trust; fixture CA chỉ trong fixture internal như trước.

## Bảo toàn và phạm vi nghiệm thu

Baseline29.153 files và toàn bộ source/runtime/code snapshots được successor verifier kiểm; AUDIT/PROGRESS insert bằng byte arrays, prefix/suffix lịch sử nguyên byte. Old/new claim/root task latch không sửa; old consumedSHA `cfb1d25d0f9eac42063d44686751a18d6069bcdd6ccfcd6dfdedf10e632748a7`, trial claimSHA `35f2c62bb3f2d520b949e7eabd0fe96d78e13ce1d8bb8eee1d4a17e441110f78`. Main image `sha256:e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b` giữ. Fullcoverage manifest mới loại self manifest và terminal verification receipts khỏi tự-hash; không sửa verifier/golden lịch sử đang ghim AUDIT cũ.

F-SOURCE-WORKER-RECEIPT-STAGE **FIXED_OFFLINE_PENDING_INDEPENDENT_REVIEW**. Source trial trước vẫn FAIL metadata/DNS_HELPER trước TCP; **không thể suy code DNS_ERROR hoặc ANSWER_CAP từ response87bytes**. Native helper0 không DNS PASS. DNS/network/root cause lịch sử UNKNOWN; raw source có nhãn sai vẫn giữ nguyên và không được retroactively gọi là fixture. Ảnhnguồn/file/visual chưa nghiệmthu; video2/3/mẫu3 NEEDS_VISUAL_REVIEW/mainOFF/gallery/API E2E/deploy chưađạt. Bước tiếp chỉ [kiểm độc lập offline](evidence/tiktok-photo-dns-diagnostics-20261011/NEXT_PROMPT.md), chưa cấp lượt nguồn mới.
