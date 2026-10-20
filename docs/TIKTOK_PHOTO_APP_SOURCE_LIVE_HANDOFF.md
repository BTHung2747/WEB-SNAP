# Một lượt nguồn qua ứng dụng — 15/10/2026

**FAIL_STOPPED_AT_ANALYZE / NO_FILE**. Đã thực hiện đúng một invocation của runner đã nghiệm thu, theo lời giao nguồn mới của chủ. Không retry, không sửa mã hoặc tăng Attempt; prepare không chạy. Đây là nguồn thật thất bại, khác ba ca fixture đã đạt. Không bật main/gallery hoặc deploy.

## Lệnh thực chạy, thời gian và hash

PowerShell7 tại D:\WED SNAP:

```powershell
& ./labs/tiktok/photo-app-source-executor/run.ps1 -Mode source -ExecuteSource -Attempt 1
```

Native outer exit1, không watchdog timeout; UTC13:37:53.2266346→13:38:32.1926266 ngày15/10, Việt Nam20:37:53→20:38:32;38.9703092s bao gồm khởi tạo/cleanup. Không chạy lại offline/import/build/install/pull. Preflight actual128source+25tool khớp bảnreview; source-1 trước đó chưa có. Runtime inspect cả4cachedimages0. RunnerSHA `8222439ed066b3943443b96bea3a7b02dbd299704612fbe0c201148f265d36e2`, tool-listSHA `ac29abc7f54129f63b241fda6b746802649d2a949563f7fddcfbd27b5938e27f`, source-listSHA `cfad2083b2ebdcc780eb2ec63c09cf77b2df6226a2707994c98d0ea9b22b9e7e`;128source/25tools vẫn nguyênbyte sau lượt chạy.

Authorization mới và TASK: `docs/evidence/tiktok-photo-app-source-executor-source-dispatch-20261015/`. Lượt này sourceGrant=true, executionStarted=true, mộtworkflow job `efca3326-b504-464b-80fe-63db38150e75`; không dùng grant lịch sử. Canonical album7678209751167110421/index2 giữ; chưa có metadata hợp lệ để chọn descriptor index2 hoặc mở prepare.

## Điều đã quan sát

Analyze được API nhận202. Một child analyze PID/PGID168, actualcoreExit1, parentexit1/signalnull/groupLive0. Gatefalse/codeNATIVE, registryProtectedtrue trước gate và releasefalse sau groupstop; worker_failed CONTENT_UNAVAILABLE. Workflow FAIL_STOPPED/ANALYZE/JOB_TERMINAL sau5.2667s từ workflow; consumer shutdown0. API shutdown143 có chủ ý; app container1; proxy container0. Runner không tạo completion.json PASS vì native test1.

Diagnostics actual: **1metadata GET attempt**,0image attempt,0observed HTTP responses,0decoded bytes; HTTP status UNKNOWN. effective connect10/readceil20/total29.971589499s. CONNECTION_SETUP BEGIN→ERROR/OS_ERROR sau0.130143s; HTTPAdapter.send PROXY_ERROR sau0.130866s. Whitelist exception classes requests.ProxyError→urllib3.MaxRetryError→urllib3.ProxyError→builtins.OSError. Tên MaxRetryError là lớp wrapper của urllib3, không chứng minh đã retry; adapter giữretry0 và chỉ1diagnostic attempt. REQUEST_SEND/RESPONSE_HEADERS/body không có terminal quan sát. TLSverify requestedtrue; chưa đo được originTLS thành công.

Một owned proxy completion phaseanalyze/acceptedfalse/threadClosedtrue/clientClosedtrue/traceIncompletefalse. Proxy result listenerClosedtrue/serveThreadClosedtrue/serveFailedfalse/completedConnectionCount1. Collector nguồn chỉ lưu projection hẹp này, **không có detailed DNS/TCP/CONNECT trace hoặc reasonCode của proxy**. Vì vậy cause được chứng minh chỉ là lỗi proxy trong nhóm thiết lập kết nối trước HTTPresponse; DNS/TCP/CONNECT/originTLS riêng, proxy HTTP status và nguyên nhân từ chối cụ thể **UNKNOWN**. Không kết luận TikTok chặn, timeout, DNS overcap, TLS lỗi hoặc Cobalt parser lỗi. Không biết GET thực sự ra wire bao nhiêu; wireGET UNKNOWN, không lấy0responses hoặc1attempt thay thế.

Metadata FAIL; prepare child/GETảnh/output/file/probe/decode/SHA/visual đều NOT_RUN hoặc không có. Không có ảnh thật mới để trình hoặc đánh giá watermark; humanaccepted5ảnh cũ giữ nguyên. Không coi metadatafixture hoặc cache ảnh cũ là kết quả lượt này.

## Guard/topology/cleanup thực

Lượt này đã tạo topology hai mạng: dedicated bridge Internalfalse chỉ1member là proxy; proxy2networks, app/PG/Redis mỗi bên1internal. Exact control internalCIDR kiểm local+peer; secret64hex RAM, native/guard raw đã che. Source chỉ common, không /offline/envfixture/fakeDNS/TCP/CA/body. Source TLS/SSRF/allowlist/everyraw256→unique64/policyC/setup10 giữ, không thay host/network backend/timeout.

Runtime guard snapshots800MiB app512/proxy96/PG128/Redis64, CPU .75/.25/.25/.25, PIDs160/96/64/32, nonroot/RO/dropALL/NNP/privateIPC/noextraswap/noports. Metadata30/prepare180/HTTP10–20/item60/whole250/queue10/local20/cleanup20/watchdog360 và bytecaps hiện hành giữ; chưa tiêu thụprepare. NoOOM tại cleanup-owner observations. Không suy caps là peakRSS. PG/Redis cònrunning khi gửi rm-f sau xác minh ownership; State.ExitCode0 ở snapshot của service cònrunning không là native serviceexit0.

Native rm4owncontainers+rm2ownnetworks/absent đều0; label/run `24251dbd4a494103b7c8646ec997d121`, cleanup2.8717411s<20/ownResourcesLeft0/volumes0. Child group closure và client/thread closure được ghi trước dọn; không fakeproof. Proxy đã stopped/exit0 trước rm; API143/consumer0/app1 ghi riêng.

## Evidence và giới hạn đóng băng

Runtime nguyên bản do đúng runner tạo: `docs/evidence/tiktok-photo-app-source-executor-20261015/source-1/`. Successor bàn giao/verifier/manifest mới: `docs/evidence/tiktok-photo-app-source-live-20261015/`, có bản sao lossless runtime và hash liên kết từng file với bản gốc. Không sửa565artifacts/manifest94e666…07f85/seal/verifier đã frozen; thư mục source-1 là phần **bổ sung sau seal** được TASK chỉ định, không thuộc coverage565 lịch sử. Vì vậy old verifier full-directory count hiện có thể fail do additive namespace và docs prepend; không sửa golden để vượt qua. Successor verifier kiểm từng historicalmanifest entry và các receipt mới riêng. Raw runner stderr là lỗi orchestration cố định Native test với vị trí PowerShell; không chứa mạng URL/token/cookie hoặc network exception message/stack. Source diagnostics chỉ lớp/mã whitelist/số/opaqueID, không HTML/header/signedURL/path/query.

Hướng kiểm offline tiếp do reviewer chỉ ra, đã đối chiếu **chỉ đọc**: source proxy_entry chỉ thêm `/repo/apps/egress/src` và vendor vào sys.path của parent. `apps/egress/src/tiktok_policy/dns_ipc.py:29` spawn `sys.executable -m tiktok_policy.dns_helper`, không truyền sys.path/env/cwd riêng, stderr DEVNULL. Guard source proxy không có PYTHONPATH như offline; cached image có WORKDIR/app và có thể thiếu hoặc chứa tiktok_policy khác. Module search path của child có thể khác parent. **Đây là giả thuyết tích hợp, chưa chứng minh cause của lượt này**: chưa biết child actual modulepath/hash/nativeexit; completion projection không giữ các trường đó. Không chạy probe/container mới, không sửa harness hoặc gọi nguồn để kiểm giả thuyết trong nhiệm vụ này.

Đã dừng đúng lần lỗi. Bước tiếp chỉ review chỉ đọc nguyên nhân/coverage/guards/native/cleanup; nếu cần diagnostic cụ thể, thiết kế và fixture offline trong successor sau giao việc riêng. Không nguồn mới, không chỉnh transport/timeout/limit theo phỏng đoán hoặc retry source-1.
