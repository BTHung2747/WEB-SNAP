# Bàn giao nối trace vào lab ảnh — 10/10/2026

**Offline toàn wiring PASS; lượt nguồn duy nhất FAIL ở metadata, chưa tải ảnh.** Client CONNECTION_SETUP timeout10,018081s/body0. Proxy ghi DNS_LOOKUP6,353045s, IPv4 attempt1 TIMEOUT10,036571s rồi attempt2 END0,421074s; CONNECT200 được gửi sau các chặng đó. Trace đủ9rows/1CID/incompletefalse/active0. Root cause mạng sâu hơn, TLS chi tiết và correlation theo ID client↔proxy vẫn UNKNOWN.

Nguồn bài7678209751167110421 chưa có fresh bodyID/metadata/file JPEG/review trong lượt này. Metadata5ảnh PASS ngày09/10 là lịch sử, không phải kết quả mới. Main OFF/deploy0/gallery chưa tích hợp; video vẫn2/3/mẫu3NEEDS_VISUAL_REVIEW.

## Code và thư viện

Lab mới `labs/tiktok/photo-trace/`, không sửa apps/, photo/setup-trace lab cũ hoặc dependencies:

- `proxy_entry.py` import proxy/TraceSink đã kiểm; thêm registry bounded, health receipt số, readiness và final counters. Handler delegates nguyên hành vi cũ; sink256rows/run32/CID, tracked receipts tối đa64CID, overflow/incomplete fail closed. SIGTERM → shutdown ở thread khác serve_forever → server_close → chờ active tối đa15s → summary trước cleanup. Grace này chỉ thu receipt, không tăng timeout nguồn; nếu còn active/incomplete thì exit30/UNKNOWN.
- `worker_entry.py` import parent/worker/picker có sẵn. Cổng trước prepare qua adapter stdin của IPC do lab sở hữu: receipt số phải readable, ownerUID65534, cap/incomplete hợp lệ mới cho lệnh prepare đến worker. Không thêm request/parser/HTTP/TLS. Worker vẫn giữ anonymous cookie/signedURL chỉ RAM trong một child; đây chưa phải gallery hai phase ứng dụng.
- `fixture_origin.py` chỉ được import khi stageoffline; http.server+ssl/socketserver, body/challenge/JPEG generator tái dùng từ photo/sitecustomize, chạy Requests thật qua proxy. Socket facade riêng của fixture ánh xạ public stand-ins sau guard vào HTTPS loopback; source dùng socket/getaddrinfo thật. Offline CA fixture chỉ thêm vào bundle gốc, verifyTrue; live không có CA/control fixture.
- `offline_pipeline.py` kiểm pipeline/negative gates và tái dùng18case photo regression. `finalize.py` kiểm receipt sau shutdown bằng UID65534 sở hữu private proxy trace, đối chiếu counters/rows/closed/schema; client rows kiểm trong packet public và host verifier kiểm raw private.
- `hash_gate.ps1` chuẩn hóa path/hash thành PSCustomObject, sort path rồi JSON; stale/missing/duplicate phải FAIL. `run.ps1` pin64source/deps trước/sau, cache/runtime/mount/ownership/guards, physical topology và native cleanup. Receipt6 mới mở lượt nguồn; không sửa receipt5 để ép PASS.
- LICENSE/NOTICE mới giữ AGPL-3.0; Cobalt của imput và contributors commit a636575b09de1fc55d9b8cd98cac88f5f2f16b42 giữ tại labphoto/vendor, NOTICE/PROVENANCE/lock cũ nguyên hash.

Thư viện hiện có đủ DNS/socket/TLS/HTTP/extraction/image validation; chỉ thêm glue/observer/receipt/hash gate. Không dependency/build/pull/install, solver/browser/chroot, parser/transport mới hoặc private-library monkeypatch. Các files/SHAs và runtime inventory ở evidence; toàn64file set sau nguồn bằng offline6, không chỉ so hash những file có sẵn.

API đối chiếu: [socket v3.11.2](https://raw.githubusercontent.com/python/cpython/v3.11.2/Lib/socket.py), [socketserver v3.11.2](https://github.com/python/cpython/blob/v3.11.2/Lib/socketserver.py), [shutdown](https://docs.python.org/3.11/library/socketserver.html), [signal](https://docs.python.org/3.11/library/signal.html), [Requests v2.34.2 Adapter.send](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py), [urllib3-2.8.0 extension](https://urllib3.readthedocs.io/en/2.8.0/reference/urllib3.connection.html), [importlib source loader](https://docs.python.org/3.11/library/importlib.html#importing-a-source-file-directly)/[runpy](https://docs.python.org/3.11/library/runpy.html). Python docs3.11 hiện là patch mới hơn; runtime/source tag và installed hashes xác minh3.11.2, không đổi pin từ docs latest.

## Wiring/ownership/guards

Proxy và worker đều dùng cache **sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e**. Preflight thực ở96MiB xác nhận Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/Brotli1.2.0, API installed-sourceSHA và core23file khớp. Không giả định image egress cũ Python3.12 tương đương.

Proxy96MiB/CPU0,25/UID65534/pids64; worker512MiB/CPU0,75/UID1000/pids96; tổng608MiB/swap=RAM. RootfsRO/privateIPC/capdropALL/NNP/defaultseccomp, source mountsRO/own outputsRW/tmp32MiB, không port host. Offline cả hai networks internal; worker chỉ private, proxy nối private+secondary nội bộ, origin HTTPS chỉ loopback trong proxy. Live secondary proxy outbound, worker chỉ private, không direct Internet. Native topology inspect trước start; offline bypass test trên test-address bị chặn.

Trace private vẫn **UID65534/mode0600**, workerUID1000 không đọc được; proof permission-check đo đúng PERMISSION_DENIED. Health số UID65534/mode0644 đọc qua readonly mount, không chứa URL/IP/token; chưa chmod private trace hoặc đổi privilege. Finalizer96MiB/user65534/network-none chạy sau khi hai role chính đã dừng, nên không cộng vượt608MiB. Raw client trace privateUID1000 giữ riêng, được host verifier đọc kiểm.

Giữ DNS order/all-answer public-IP guard/allowlist/CONNECT443/header16KiB/tunnel240-idle30/clientconnect≤10/read≤20/TLS verification; không IPv4 ưu tiên/DNS/host/proxy/allowlist/timeout relax/reset budget/retry. DNS_LOOKUP span gồm getaddrinfo+guard+observer overhead; DNSdeadline UNKNOWN. TCPdeadline là monotonic trước call+socket timeout quan sát, không OS deadline mới. Proxy200 END chỉ là sendall thành công, không client nhận200/TLS PASS. Không sharedCID, không ghép chắc bằng timestamp/thứ tự; inference từ topology đơn nhất phải ghi riêng.

## Lệnh thực và FAIL được giữ

Bundled pwsh -NoProfile -File từ D:\WED SNAP:

| Lệnh/namespace | Actual exit và kết quả |
| --- | --- |
| preflight.ps1 lần parse |1 trước Docker; lỗi delimiter biến PS; source0 |
| preflight.ps1 đã sửa |0; cache/API/core thực96MiB |
| run.ps1 -Stage offline -Attempt1 |1 trước Docker; alias Mount xung đột New-PSDrive |
| offline -Attempt2 |container/runner1; fixture runpy đổi argv0 làm guard không định nghĩa FakeSession, không metadata/file; cleanup0 |
| run-import-check.ps1 |0/network-none; runpy classfalse/importlib classtrue, source0 |
| offline -Attempt3 |1; metadata fixturePASS nhưng worker không đọc được proxy trace0600 khácUID, chưa imageGET |
| run-permission-check.ps1 |0/network-none; stat/read1byte không xuất nội dung, chứng minh UID/mode/readability |
| offline -Attempt4 |1; metadata/cổng receiptPASS, origin fixture thiếu FIXTURE_MEDIA_FILE ở send-time, image fixtureFAIL |
| offline -Attempt5 |0;11network cases+18regression+actual shutdown/trace PASS; chưa hash-order unit |
| live -Attempt5 |1 **trước Docker/network/worker/GET**; gate so JSON thứ tự không ổn định mặc dù62path/hash đều khớp; live-gate-1 giữ |
| offline -Attempt6 |0; toàn wiring mới +4hash-gate cases PASS,64source/deps match |
| live -Attempt6 |**runner/parent/container20**, metadataSOURCE_TIMEOUT; worker−9/SIGKILL fail/reap; một analyze thực |
| record-result.ps1/coverage |0; chỉ đọc raw/hash/cleanup/main, không thêm nguồn |

Hai fixture bugs runpy/importlib và env-at-send đều có cause cụ thể từ thư viện/fixture đã có. Mọi snapshot lỗi/raw/counters/native trước được giữ; sửa glue mới và kiểm lại trong namespace mới, không golden/history rewrite. Gate blocked trước nguồn không được gọi là một GET hoặc functional source failure; tổng **actual sourceAnalyzeAttempts1**, prepared metadataGET budget1, conditional imageGET0.

Final offline6:11 full network fixture cases (normal; image DNS/TCP/cert/TLSstall/HTML fail; wrong-body/redirect/privateDNS; health missing/incomplete), SSRF deny và worker no-bypass; cap256/per32, trace I/O identity, missing-summary reject; parent PASS→nonzero/hang/deadline cleanup;18photo regression/bodytimeout/caps/pixels/ownership và4canonical hash cases. Đây là fixture, không source metadata/file PASS. TLS-stall fixture dùng connect10/read20 thật, không scale timeout. Parent mini deadline0,3s là negative fixture, không nguồn.

Successfixture metadata2GET/image1GET, bodyID/type/index đúng, JPEG64×64/magic/MIME/ffprobe1frame/full decode/native0/SHA3c94b9a6bbfab0c44c02d0c520dca952e23dc7a396e30a6ef3b0fe00bcc0cc3e. Proxy final111rows/19connections/incompletefalse/active0/unhandled0. File fixture không được hiển thị thay nguồn. Runtime/core/deps hashes trước/sau đúng; source-coverage-after.json xác nhận cả tập64file sau nguồn bằng receipt6 và source-hashes raw offline/live cùng SHA.

## Lượt nguồn thực

Budget chốt trước nguồn: analyze1/metadata≤2prepared GET trong30s, decoded8MiB/response16MiB total. Fresh bodyID/typephoto/ordered entry1 + trace gate hợp lệ mới conditional1imageGET60s/input20MiB/output16MiB/workflow36MiB; redirect/retry/HEAD0. Cookie/signedURL RAM. Không ảnh2/album/audio/video/browser.

Input public /@adne_la.veil/photo/7678209751167110421. Worker ghim chuyển /photo/→/video/ theo thư viện hiện có; prepared target /@adne_la.veil/video/cùngID là kết quả từ code pin, không phải origin header/body quan sát. Không GET @i hoặc resolve phụ.

**Metadata FAIL SOURCE_TIMEOUT:**1preparedGET attempt, effective connect10/read20/total29,916444s; HTTPAdapter.send READ_TIMEOUT10,020143s, exact classes Requests.ReadTimeout/urllib3.ReadTimeoutError/builtins.TimeoutError. CONNECTION_SETUP ERROR10,018081s/TIMEOUT_UNKNOWN; không REQUEST_SEND/RESPONSE_HEADERS terminal, HTTPstatusUNKNOWN/body0. Origin GET chưa quan sát, không tuyên bố origin đã nhận GET hoặc nguồn trả200. FreshbodyID/type/photo descriptors chưa quan sát; imageGET0, prepare/file/magic/MIME/ffprobe/decode/SHA/visual/watermark nguồn NOT_RUN.

**Proxy quan sát độc lập**, CID2366d9777f704d28:

| Span | Outcome thực |
| --- | --- |
| DNS_LOOKUP |END6,353045s; all-answer guardPASS;53IPv4/0IPv6 records, không log IP/host |
| UPSTREAM_TCP_CONNECT attempt1 |IPv4/TIMEOUT10,036571s, timeout10 |
| attempt2 |IPv4/END0,421074s, timeout10; giữ DNS order |
| CONNECT_200_SENT |END sau sendall0,026749s |
| TUNNEL_CLOSE |PEER_EOF/handler elapsed16,924501s |
| Final summary |9rows/1CID/active0/incompletefalse/unhandled0 |

Có bằng chứng first upstream TCP attempt TIMEOUT và DNS_LOOKUP span dài. Proxy phải hoàn tất các chặng đó trước200, tổng setup vượt clientconnect10 trong trial này; **phù hợp giả thuyết client hết ngân sách trước proxy200**. Không sharedID hoặc đồng bộ start spans, nên correlation client↔proxy theo ID và exact substage client UNKNOWN; không coi inference là nguyên nhân chắc của ảnh1 lịch sử. Không biết vì sao DNSspan dài/TCP địa chỉ đầu timeout; không quy CDN/IPv6/firewall/DNS resolver/TLS/read20.

Pipeline/container/runner20; worker−9 theo parentFAILkill/reap, không gọi decodekill. Docker wait tool0 trả container20. Proxy0/trace-validator0/cleanup0; trace PASS không đổi metadataFAIL. Source cleanup UTC **2026-10-09T19:18:11.0377348Z**, VN **2026-10-10T02:18:11.0384174+07:00**. Remove3owned containers (proxy/worker/validator)+2owned networks, final label inspection0left, main image **sha256:e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b** giữ.

## Hồ sơ và hướng tiếp

Evidence mới `docs/evidence/tiktok-photo-trace-integration-20261010/`: baseline3617/before, provenance, lỗi bootstrap/các offline attempts/proofs, finaloffline6receipt, live-gate preflightFAIL, sample-1raw/cause/budget/guards/runtime/client+proxy trace/fullsummary/actualexits/cleanup, whole-setcoverage, successor/manifest/verifier. Chỉ AUDIT/PROGRESS prepend; history/raw/manifests/human reviews cũ giữ nguyên.

Dừng nguồn theo nhiệm vụ, chưa có file để hiển thị/review. Hướng tiếp là một nhiệm vụ **offline hẹp** rà cách phối hợp ngân sách setup/cancel giữa Requests và proxy DNS+sequential connects, ưu tiên public API/thư viện; mô phỏng DNSspan+firstattempt timeout trước late fallback. Chưa có bản sửa kết nối đã kiểm; mọi thay đổi scheduling/order/deadline phải được review riêng, giữ SSRF/TLS/caps, không tăng timeout hay ưu tiên IPv4 theo đoán. Chưa mở trial nguồn tiếp hoặc deploy từ kết quả này.

