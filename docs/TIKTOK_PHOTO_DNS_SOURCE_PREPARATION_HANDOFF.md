# Preparation trial ảnh nguồn với DNS diagnostics — 11/10/2026

**PASS_PREPARATION_OFFLINE_PENDING_INDEPENDENT_REVIEW; SOURCE_BLOCKED.** [Kế hoạch](TIKTOK_PHOTO_DNS_SOURCE_TRIAL_PLAN.md), lab preflight `labs/tiktok/photo-dns-source-preparation/`, evidence `docs/evidence/tiktok-photo-dns-source-preparation-20261011/`. Không source allocation/claim/network nguồn. Không sửa lab đã nghiệm thu, production, dependencies hoặc consumed claims/root latch. Hai receipt findings CLOSED_OFFLINE_CONFIRMED theo audit mới, không nghiệm thu mạng/ảnh nguồn.

## Lệnh thực chạy và phần tái dùng

Shell bundled `C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe -NoProfile -File <script>`, cwd D:\WED SNAP, script dưới trong evidence preparation.

| Lệnh | Kết quả/phạm vi |
| --- | --- |
| prepare.ps1 | Baseline32.299files; chụp source384/runtime91/code-reviewed; không runner nguồn |
| wire-preflight.ps1 | Harness riêng, adapter probe kế thừa fixture public API, không đổi runtime |
| run-preflight.ps1 -Attempt1 | Networknone512MiB/CPU.75/UID65534/pids96/RO/privateIPC/capALL/NNP; native0,24checks |
| inspect.ps1 | Exact1own container absent/network creation0/main image giữ |
| insert-docs.ps1 | Chỉ chèn AUDIT/PROGRESS, lịch sử nguyên byte |
| verify.ps1 -Capture; verify.ps1 | Freeze manifest riêng rồi readonly; actual checks/exits/UTC-VN trong verification-capture.json/verification.json |

Preflight dùng Requests HTTPAdapter.send/Session.mount/Response và urllib3.HTTPResponse tại seam fixture đã có để trả bytes giả; **không socket HTTP/DNS tên thật**, 3fake adapter sends (metadata2+prepare1). Giới hạn request3/prepare2 bị từ chối trước send; connect/read forwarding verifyTLS/proxy/stream có hiệu lực như fixture gốc; cookieẩn danh RAM/session-close, URLpath/query/cookie giả redacted; HEAD/auth/cookieheader/URL không phép reject trước send. SSRF public/private mixed DNS set và stock hostname allowlist gọi pure functions không socket. Metadata bodyID/dimensions fixture contract dương/âm được kiểm, không metadata nguồn.

Ba DNS case chọn từ `test_diagnostics.dns_case` đã kiểm (không rerun37fullhistory): numeric helper OK, AI_NUMERICHOST getaddrinfo error, trace raise với primary OSError giữ identity. Helper là child thật được reaped, pipesclosed/group0/upstreamSockets0/FD-thread baseline; numeric không Internet DNS, socketpair chỉ local IPC. Same-helper validators được tái dùng: outer UNKNOWN rejectPARTIAL; numericOK COMPLETE/resolutionPASS; DNS_ERROR native0 nhưng resolutionFAIL, tracefail không PASS. Nhãn source/offline synthetic yêu cầu typed invocation1 khi packet và count0 khi chưa bắt đầu; không source entry.

Cold imports proxy_entry/worker_entry/finalize giữ fixtureModulesLoaded=[], trustSHA9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f. Current Python sourceblock được kiểm, runner defaultOFF chỉ static-read. **Không chạy source_policy_probe lịch sử**, source CLI hoặc old source command. Cold imports hiện tại không chứng minh source control/env của future executable: gate đó NOT_RUN và phải kiểm sau wiring. Không full metadata→JPEG mới trong preparation;7freshfixtures đã nghiệmthu chỉ đọc hồ sơ. Fake adapter bytes không tệp JPEG/ảnh nguồn.

Mã tự nối chỉ orchestration probe/plan/hash verifier; transport/DNS/helper/race/parser/validators runtime không viết lại. Tham khảo đúng [Requests2.34.2 HTTPAdapter](https://raw.githubusercontent.com/psf/requests/v2.34.2/src/requests/adapters.py), [urllib3-2.8.0 HTTPResponse](https://raw.githubusercontent.com/urllib3/urllib3/2.8.0/src/urllib3/response.py), [CPython3.11.2 subprocess](https://raw.githubusercontent.com/python/cpython/v3.11.2/Lib/subprocess.py); dùng API public hiện có, giữ Popen/selectors/helper đã kiểm. Dependency lock đọc, không thêm dependency/build/install/pull/host change.

Preflight hoàn tất UTC2026-10-11T15:36:25.9815474Z/VN22:36:25+07. Toàn probe FD4→4/thread1→1; từng DNS case FD7→7/thread1→1. Native helper0 trong cả ba ca; response OK/PASS, DNS_ERROR/FAIL và tracefail OK/FAIL được phân biệt trong receipts, không suy nguyên nhân nguồn từ fixture.

## Hash, guards và bảo toàn

Mã runtime đọc nguyên bản `photo-receipt-consistency`, source384/runtime91/referenceSHA e5512492bb8c1ac4e3b85f9c8078cc4098b526c581b9cc7a6b8840faebfdf641 before/after giống audit. Prep module `preflight.py`, `adapter_probe.py` ghim riêng trong preflight-code và actual mounted preparationSources; runner hash riêng. Không coi referenceSHA là future wired source gate.

Image cache sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e; Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/aiohappyeyeballs2.7.1; main image sha256:e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b. Docker networknone/RO/user/caps/swapRAM/privateIPC/pids/nohostports/owned mounts giữ. Lệnh chạy tuần tự máyRAM8GB; preflight512≤1GiB, future whole608MiB. Validator/golden/manifest/evidence lịch sử không đổi; baseline kiểm tất cả file trước phiên và docs before/insert reconstruct nguyên byte.

Preparation không tạo mock claim/allocation vì chưa cần kiểm thuật toán mới; design không có gate mở nguồn. Atomics và typed quota/task latch cần mock probes trong nhiệm vụ wiring sau review, trước bất kỳ source allocation thật. Không đổi old/new consumed root latch/claims, không reset/reuse hoặc UUID khác để lách quota.

## Điều kiện còn thiếu để nguồn

Plan chốt đúng một analyze publicphoto7678209751167110421,≤2metadataGET/30s/8–16MiB; metadata/bodyID/typephoto/images hợp lệ mới conditional1JPEGGET/60s/input20MiB/output16MiB/workflow36MiB. Giữ connect10/read20 clamp/setup10/end−1reserve/policyC/SSRF/TLS/bytecaps/trace/helper/user/runtime608MiB. Lỗi bất kỳ dừng, không HEAD/retry/fallback/ảnh2.

Future executable chưa tồn tại: phải nhiệm vụ wiring riêng, defaultOFF, exact source/runtime/image/trust/mount hash gates **của chính code sau wiring**, cold env/source-import isolation, fresh wholefixture/negatives/native/cleanup và mock typed quota+atomic task-root latch/claim-before-egress; review độc lập, rồi human nguồn task riêng mới allocation/claim/source command. Blueprint trong plan có placeholders và không runnable hiện tại; preflightPASS không authorization.

DNS diagnostic whitelist đi theo connector receipt→validator, strict outer/nested cleanup; thiếu giữ UNKNOWN/PARTIAL; helper0 không DNS PASS. Invocation/workflow khác preparedGET/sendBEGIN; sourceCalls nguồn UNKNOWN_USE_REQUEST_ACCOUNTING và requestAccounting ghi attempts/status/bytes thực. File technicalPASS vẫn cần humanreview hình/watermark. Nguồn cũ FAIL trướcTCP, responsecodeUNKNOWN_NOT_RETAINED/networkrootcauseUNKNOWN; video2/3/mẫu3reviewchờ/gallery-main/API E2E-deploy chưađạt. [Bước tiếp chỉ kiểm độc lập preparation](evidence/tiktok-photo-dns-source-preparation-20261011/NEXT_PROMPT.md).
