# TikTok photo source trial — 11/10/2026

Trạng thái **OFFLINE_EXACT_CODE_PASS / SOURCE_METADATA_FAIL_STOPPED**. Chủ đã giao một allocation mới. Runner riêng đã triển khai tại `labs/tiktok/photo-source-trial/`; đúng một invocation nguồn đã chạy, claim consumed giữ nguyên. Không có JPEG nguồn hoặc đánh giá watermark.

## Mã và lựa chọn thư viện

Successor sao chép 31 module lab registry-closure đã kiểm, thêm `source_contract.ps1` và `source_preflight.py`. Chỉ đổi wiring/stage/default disabled, allocation/quota, atomic claim, exact hash gate, metadata acceptance và evidence; không đổi transport, parser, solver, DNS helper, race, HTTP/TLS hoặc dependencies. Tái dùng core/photo/picker/validator, Requests2.34.2, urllib3-2.8.0, yt-dlp2026.8.19, aiohappyeyeballs2.7.1 và FFmpeg trong image cache. Runtime giữ LICENSE/NOTICE/pins, không build/pull/install.

Public APIs đã đối chiếu đúng phiên bản: [Requests HTTPAdapter/send](https://raw.githubusercontent.com/psf/requests/v2.34.2/src/requests/adapters.py), [aiohappyeyeballs start_connection](https://raw.githubusercontent.com/aio-libs/aiohappyeyeballs/v2.7.1/src/aiohappyeyeballs/impl.py), [.NET FileMode.CreateNew](https://learn.microsoft.com/en-us/dotnet/api/system.io.filemode?view=net-8.0). Thư viện đảm nhiệm HTTP/connection race và extractor; lớp PowerShell chỉ cần tự viết vì task yêu cầu quota, ownership và claim nguyên tử trước egress. Không chép private helper hoặc viết extractor mới.

Gate đóng băng kiểm source316/runtime90 và proof hashes của **chính bản mã** vừa kiểm offline, image pin, typed quota, fixture/source isolation và trust pin. Allocation bị từ chối nếu sai bodyID/type/target/quota/task/scope/image/hash, thêm trường hoặc thiếu proof. Default runner disabled; source phải có allocation+gate hợp lệ. Root task latch và namespace claim dùng CreateNew/Flush(true) trước Docker/network; duplicate, crash/cancel không rollback. Root latch ngăn đổi allocation để mở thêm lượt. Cookie/signed URL RAM-only; log source URL toàn phần được che.

Source hash before/after/final offline: `fc2e8183348d4cd646a9904d833427b01cdf071bf08a4340aa86f8f5b4659011`.
Lab image: `sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e`.
Trust: `9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f`.

## Lệnh và kiểm offline thực chạy

Các script dưới ở `docs/evidence/tiktok-photo-source-trial-20261011/`, chạy bằng bundled pwsh `-NoProfile -File`; native/output/time lưu trong từng namespace.

1. `prepare.ps1`, `wire.ps1`, `wire-preflight.ps1`: tạo successor, không sửa old labs/apps/vendor/lock. Lần prepare đầu từ chối folder đã có file source_contract; chỉnh điều kiện tạo trong preparation script, không ghi đè lịch sử.
2. `run-preflight.ps1 -Attempt 1..4`: các code snapshots riêng giữ nguyên. Preflight1 còn label preparation/runner NOT_IMPLEMENTED sai; preflight2 sửa label, preflight3 rồi4 tương ứng các wiring bổ sung. **Chỉ preflight4** là bản cuối:16 synthetic checks +9 cold checks, Docker network-none512MiB/UID65534/native0/source0/claim0.
3. `test-claims.ps1`: lần1 FAIL1 do fixture alias array làm thay hash snapshot trong RAM; không source bytes/real claim/network thay đổi. Failed test và failure receipt giữ. Deep-copy fixture rồi attempt2 đạt19ca. `test-claims-final.ps1` đạt19ca trên hash cuối: malformed/missing/wrongtarget/quota/hash/proof/boolean/defaultOFF/duplicate/crash/cancel. Cancel chỉ own helper PID, hidden process; không real claim.
4. `run-offline.ps1`:7 fresh fixtures trên mã trung gian. `run-offline-final.ps1`:7 fresh whole pipeline trên **mã cuối**, attempts20–26: normal0/metadata2+JPEG1/full decode/SHA; wrong-body, redirect, health-missing, preexisting worker20/validator20; closure-live/missing worker0/proxy0 nhưng validator20 và xóa own JPEG. Không dùng packet PASS thay native0. Old whole67 không rerun.
5. `run-gate.ps1`: Capture103/Verify104/native0. `offline-gate.json` frozen trước source. `run-source-once.ps1` kiểm Verify0 lần nữa rồi tạo allocation và gọi runner đúng một lần.

Các fixture chỉ chứng minh contract/guards/integration offline, không metadata/file/TLS nguồn. Không dùng preflight mã khác mở nguồn. Code copies preflight1–3 và code-final giữ đủ coverage để đối chiếu FAIL→PASS và thay đổi wiring.

## Quota/guards không đổi

Public photo bodyID7678209751167110421/typephoto/ảnh1. Một workflow≤2 metadata prepared GET/30s/8MiB response–16MiB total decoded; conditional≤1 JPEG GET/60s/input20MiB/output16MiB/workflow36MiB/8192dimension/16Mpixel/static1frame/full decode. Redirect/retry/HEAD0. Metadata fresh phải đúng bodyID/type, count và image1 dimensions hợp lệ, HTTPS qua picker/transport guards. Không ảnh2/album/shortlink/video/audio/fallback.

Setup10/end−1reserve/policyC pair1–2/singleton.60/reap.10/delay.25/interleave0/max2sockets/4groups/prefix8/answers64/helper1/trace256-owner32-map64; connect≤10/read≤20 clamp remaining. Proxy96+worker512=608MiB, CPU.25+.75, validator96 sau roles stop; UID65534/1000, rootfsRO/swapRAM/capALL/NNP/privateIPC/pids64–96/nohostports, private internal worker + controlled proxy egress/all-DNS-public/TLSverify. Không browser/account/profile/solver hoặc main changes.

## Nguồn thật: FAIL, dừng đúng stage

Lệnh thực tế (paths không chứa signed URL):

```powershell
pwsh -NoProfile -File labs/tiktok/photo-source-trial/run.ps1 -Stage source -AllocationPath "D:\WED SNAP\docs\evidence\tiktok-photo-source-trial-20261011\source-f5435d4dc3cd4f3f90f344dc8782441b\allocation.json" -GatePath "D:\WED SNAP\docs\evidence\tiktok-photo-source-trial-20261011\offline-gate.json"
```

Bundled executable và argv chính xác nằm `source-command.json`; đây là ghi chép **không phải lệnh được phép chạy lại**. Start12:20:07.3015950Z/end12:20:24.1986354Z, VN19:20:24+07. One source invocation; runner20/worker container20/proxy0/validator20. Source wrapper ghi native20; tool invocation trả1. Owned failed worker child−9/signal9 do parent cleanup, không exit0. Metadata packetFAIL/CONTENT_UNAVAILABLE.

Prepared metadata GET1, adapter attempts1, observed REQUEST_SEND_BEGIN0/END0/header0/status UNKNOWN/decoded bytes0; prepare GET0. `sourceCalls=UNKNOWN_USE_REQUEST_ACCOUNTING` không là source0 hoặc receipt origin.

Client CONNECTION_SETUP ERROR/OS_ERROR0.595715s/timeout10; HTTPAdapter.send PROXY_ERROR0.598679s với classes whitelist Requests.ProxyError→urllib3.MaxRetryError/ProxyError→OSError. Proxy có DNS_HELPER BEGIN→ERROR0.533674s, native helper0, reapedtrue/group0/pipesclosedtrue/response87bytes. Không DNS_RESULT/TCP_CONNECT/socket/CONNECT200; batch NOT_STARTED. Registry owner UNKNOWN và batch receipt PARTIAL vì không tới registry; không dùng PARTIAL thay thành PASS.

**Đã chứng minh:** proxy DNS helper báo lỗi trước address result/TCP; client setup fail. **Chưa biết:** helper response code không lưu nên không phân biệt DNS_ERROR/ANSWER_CAP hoặc lỗi khác; native helper0 không là DNS resolution PASS. DNS/network root cause, TLS origin, HTTP status/header/body TikTok đều UNKNOWN. Không kết luận TikTok trả challenge/200 hoặc policyC sửa/không sửa mạng. Child isolation file không có vì child bị kill; không suy successful child-isolation từ proxy isolation. Proxy source-safe/trust và guard/state có evidence riêng.

Không JPEG, ffprobe/decode/SHA/visual nguồn NOT_RUN. Không có ảnh để trình review. Nguồn thất bại nên không retry/reset claim/chạy ảnh khác.

## Cleanup, bảo toàn và hướng sau

`inspect-final.ps1` đọc-only exact IDs:49 containers/30 networks không còn; main image `sha256:e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b` giữ. Lần inspector đầu dùng nhầm tag wed-snap-api, image inspect1 và receiptFAIL được giữ `cleanup-final.json`; sửa riêng evidence inspector về tag thực wed-snap-app:local rồi `cleanup-final-2.json` PASS0. Không đổi source code/gate hoặc thử nguồn lại.

Old claimSHA `cfb1d25d0f9eac42063d44686751a18d6069bcdd6ccfcd6dfdedf10e632748a7` giữ; new allocation claimSHA `35f2c62bb3f2d520b949e7eabd0fe96d78e13ce1d8bb8eee1d4a17e441110f78` và root task latch consumed giữ. Baseline27.020 files/fullcoverage new manifest/source316 được verifier readonly kiểm, AUDIT/PROGRESS chỉ insert successor. Không sửa historical manifest/golden/verifier/codecopies/human-review/claims. Hai findings closure/receipt vẫn đóng offline; historical45IPv4/43UNKNOWN và root cause UNKNOWN giữ.

Verifier capture đầu FAIL20/check89 phát hiện thao tác chèn docs đã đổi một newline trong prefix AUDIT. `AUDIT.prefix-failure.md` và `verification-capture.json` giữ; `restore-doc-prefix.ps1` khôi phục đúng prefix gốc, suffix lịch sử nguyên byte. `verify-v2.ps1` chỉ đổi tên receipt capture để không ghi đè FAIL; giữ mọi predicate/baseline/gate/hash. Capture2 rồi readonly verification kiểm fullcoverage; self manifest và hai terminal receipts được loại khỏi tự-hash, failed capture đầu vẫn nằm manifest. Không chạy lại test chức năng hoặc nguồn trong bước đóng hồ sơ.

Bước đề xuất: task **offline-only** bổ sung mã response DNS helper whitelist (status/code/answerCount, không hostname/IP/message) tại IPC observer trước chuyển thành OSError, kiểm getaddrinfo lỗi/cap/deadline/cleanup trên library pinned. Chưa cấp source retry hoặc claim mới. Ảnh nguồn chưa nghiệm thu; một ảnh cũng không album/gallery/main/API E2E. Video2/3/mẫu3 NEEDS_VISUAL_REVIEW giữ. Không deploy.
