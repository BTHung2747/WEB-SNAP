# Bàn giao runner/collector bước5, chỉ offline

15/10/2026. Runner ở `labs/tiktok/photo-app-source-step5/`. **Chưa có quyền nguồn và không có source executor bật được**: `sourceGrant=false`, `sourceExecutionStarted=false`, `sourceCalls=0`. Kết quả cuối/hash/actual exits tại evidence và verifier; chỉ final exact fingerprint được dùng để review, không dùng các PASS chức năng của attempt FAIL để nghiệm thu.

## Phạm vi mã và thực thi

Không đổi apps/shared/locks/vendor/DB schema/Compose/env/main hoặc lab/evidence cũ. Baseline128đường dẫn dedup từ danh sách155hash kế thừa UI4 được giữ byte; không lặp155 thành155file distinct. Chỉ15file lab mới (runner/gate/consumer/media delegate/collector/offline fixture/importprobe/source-disabled/topologyJSON). Không cài/build/pull image, không browser/UI build hoặc test lịch sử13768/34/22/14.

Lab consumer dùng BullMQ5.81.5 public Worker gọi production processJob/runAdapter/ProcessGroup/gate3b nguyênbyte. `maxStalledCount:0`, `maxStartedAttempts:1`, concurrency1 là cấu hình **lab consumer**, không sửa maxStalledCount1 của consumer main. Durable `open('wx')` theo job/phase trước processor; child `O_EXCL|O_NOFOLLOW` trước core là hàng rào phụ. Không release phase fence khi crash/restart; chỉ một workflow/job được bind ở namespace đó. Đây không phải source permission/claim/cold ledger. Job quá10s theo BullMQ timestamp bị deny trước processor; sourceUrl/phase/workflow deadline/stop state cũng được kiểm. API enqueue vẫn attempts1/jobId theo phase.

Media entry delegate đúng `photo_adapter.main` và wrap public `analyze_album/prepare_photo` để truyền optional diagnostics dict sẵn có. Không viết parser/downloader/Requests HTTP/TLS/cookie/solver mới, không private library monkeypatch. Collector ghi trước CLI PASS, enum/numeric/opaque16hexIDs whitelist; URL field bỏ hoàn toàn cảpathname/query. Thiếu/invalid/incomplete receipt gây native failure/no ticket; kill trước finally ghi UNKNOWN ở kết quả parent, không bịa0requests. Packet/core exit/group/proof là các bằng chứng riêng.

Collector cap512KiB/receipt,≤2metadata analyze/≤2metadata+1image prepare,128boundary rows/32Operations; Worker events≤256/64KiB buffered line và proxy completion≤64rows. Proxy collector gắn actual owned Request context/broker entry, không PID/log/global health làm authority. Chỉ case/phase/opaqueowner/closureflags được ghi; nonce/cap/epoch/binding/global secret không ra log/DB/upstream. Core row attempt được cấp trước Adapter.send; HTTP status/decoded bytes là quan sát response, **wireGET vẫn UNKNOWN** nếu không có capture origin. CONNECT không đếm GET. Origin counters ở offline dùng riêng để đối chiếu fixture, không mang sang nguồn thật.

Deadline: startup60 ở runner+independent Python gate; workflow250 tính monotonic trước API analyze và không reset giữa phase/proof; queue10 vừa client poll clamp vừa consumer-before-processor; local20 gồm HEAD/fullGET/Range; cleanup ứng dụng20, Docker cleanup20 với per-call WaitForExit còn lại; nguồn metadata30/prepare180/HTTP10–20/caps giữ hoặc app chặt hơn. Host runner deadline360/reserve20/testcap320 và container OS watchdog360, Python gate outer320. Independent gate ngoài Node eventloop bắt workflow end, ghi stopped và kiểm PID/pgrp/startTicks trước TERM→KILL2; không dùng grace cleanup để cho thành công. Production group bound6/quarantine/ownership/lease giữ. Không tự xóa file khi closure chưa chứng minh; native timeout của Docker được coi UNKNOWN/FAIL, không suy cli-killed nghĩa containerđãđóng.

Sweeper của production được lab consumer gọi1s, tương ứng settings DB **lab mới** sweepSeconds1 để kiểm cleanup20, không đổi main hoặc lifecycle code. Lab DB user/password công khai dành fixture, global controlsecret mới RAM được scrub khỏi native/docker guard logs. FixtureCA key chỉ disposable, không tài khoản/cookie thật.

## Lệnh và môi trường

Trong PowerShell7, mỗi Attempt mới, runner từ chối reuse evidence. Lệnh final (không chạy lại vào namespace frozen):

```powershell
& './labs/tiktok/photo-app-source-step5/run.ps1' -Mode offline -Attempt 10
& './labs/tiktok/photo-app-source-step5/run.ps1' -Mode imports -Attempt 7
```

`-Mode source` trả78 trước tạo attemptdir/randomsecret/Docker/network; Python source_entry.py cũng deny78 vô điều kiện. Không env/argument tự mở nguồn. `source-topology.json` chỉ plan disabled: canonical @adne_la.veil/photo/7678209751167110421/index2/count5/snapshot8fa38a…c2127; nguồn path chưa executable. Historical-expectation.json copy bằng byte từ proposal giữ dimensions/itemKeys/SHA cũ; không dùng SHA cũ để fake nguồnPASS, không resolve phụ/query/shortlink/index khác. Sau exact fingerprint review mới có thể xét nhiệm vụ nguồn riêng; không tự tiếp tục từ offlinePASS.

Docker cache inspect thực trước test, all pins:

| Thành phần | Image SHA256 | Guard |
|---|---|---|
| app/API+consumer+media+driver chung | d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e |512MiB/.75/PIDs160/user1000|
| egress+TLSfixture/helper/control |8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10|96MiB/.25/PIDs96/user65534|
| PostgreSQL |38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74|128MiB/.25/PIDs64/user999|
| Redis |a9cc41d6d01da2aa26c219e4f99ecbeead955a7b656c1c499cce8922311b2514|64MiB/.25/PIDs32/user1000|

Runtime tổng800MiB, sequential RAM8GB; generator512 chạy riêng/networknone/dọn trước runtime; imports512/networknone chạy sau runtime. Internal network, không ports/external bridge/Internet/DNS ngoài; nonroot/RO/privateIPC/dropALL/NNP/no extra swap/tmpfs/media64MiB và own IDs/labels cleanup. Không peakRSS claim. Cached image chứa code cũ: readonly mounts128source hiện tại và media entry lab được hash, không giả imageđãrebuild.

## Ca kiểm và ranh giới

Suite offline có10nhóm, mỗi workflow happy tối đa một analyze child+fresh prepare child/một index2/JPEG. Production Nest API→BullMQ actual→lab hardened consumer→production processor/parent/gate→CLI delegate→Requests/Cobalt/yt-dlp→CONNECT/TLS fixture→FFmpeg/contract/SHA thật. Fake DNS public rows/TCP mapping/CA/origin chỉ trong offline entry, không sourcemode. Browser combined NOT_RUN; không coi API-driven thành browser E2E hoặc TikTok thật.

1. Happy một job hai phase,2+2metadata+1JPEGGET tại origin giả; phase diagnostics2/3attempts/response200/byte totals, native0/group0/prooftrue trước ready. Actual local HEAD không source/không lease; fullGET/Range đúng JPEG/MIME/name/SHA; JPEG248B/SHA45cea83ba1889b4f948c9fca05932a47ff2bb92723dd8fa798fcf14149c51e00,2ffprobe0/full decode0 lưu trong prepare diagnostics. Không pixel/watermark sourcePASS.
2. Restart consumer và enqueue redelivery thật của cùng phase khi sourceUrl còn hợp lệ: durable fence deny trước processor/child, origincounter không tăng.
3. Public Worker.getNextJob giữ job bằng lock250ms, skipLockRenewal/closeforce rồi lock Redis hết hạn thật; hardened consumer maxStalled0 làm queuejob failed, không secondprocessor/child hoặc nguồn thêm. Đây là fixture expired Redis lock, không tuyên bố đã gây mọi dạng host crash/stall.
4. Missing diagnostics: receipt incomplete/attemptsUNKNOWN, nativeFAIL/jobfailed/no ticket/cleanup.
5. Missing proxy proof: core/native0 nhưng parent gatefalse/jobfailed/no ticket; diagnostics thành công riêng không là kết quả workflow.
6. Cancel khi child fault chờ trước metadata: kill/group0/cleanup, thiếu finaldiagnostics ghi UNKNOWN, không fakePASS.
7. POST ambiguity: API thật đã202, fixture **bỏ completion ở driver** bằng delay; không phải backend HTTP header timeout đã đo. AnalyzePOST1/no resend/no prepare/cancel đúng ownership. Không dùng lỗi này để suy nguồn đã nhận GET.
8. Absolute workflow fault3s (<250) độc lập Node: supervisor đánh stopped/TERM identitychecked, client không gửi prepare sau deadline; cleanup cửa sổ riêng, không reset success budget.
9. Local fault20ms (<20s): exhausted trước HTTPstart bị deny, không requestlocal mới.
10. Queue10s không consumer, hết hạn rồi consumer tới muộn phải deny trước processor/child/source; giữ actual elapsed và counters.

Collector unit6ca dùng URLfake có token cảpath/query, schema/rowbound/unsafeenum/missing/UNKNOWN; không URLthật/cookie/HTML. Isolated import probe Python-I (networknone) xác minh actualmodule paths/hashes/versions từ source, không media_site hoặc labsitecustomize. Cached `/etc/python3.11/sitecustomize.py` hash43d81125d92376b1a69d53a71126a041cc9a18d8080e92dea0a2ae23be138b1e chỉ try import apport hook, đã đọc bytes; không nhầm là fixture. Không tuyên bố production source topology đã chạy chỉ nhờ importprobe.

Caps DNS256→unique64/everyrowpublic/HE2.7.1/policyC/setup10/end−1/admission8/1setup, JPEG8/16metadata+20imageinput+36prepare/16output/full decode, perphase proof/caps/twochild/cookieRAM được production giữ; không chạy lại toàn ma trận boundary/byte historiques không bị sửa. Tests chạm hook/glue mới, không bịa “test lại8MiB payload” nếu chỉ kế thừa enforcement/codehash.

## Raw FAIL/intermediate

Giữ imports1 sandbox pipe denied, imports2/3 reject sitecustomize do giả định đường dẫn sai; imports4 đo hook hệ thống và import đạt. Offline1 consumer import BullMQ bare path từ/fixture fail trước metadata; offline2 collector chưa whitelist nhãn fixed HTTPAdapter.send nên receiptfail; offline3 happy đạt nhưng labconsumer thiếu cadence sweeper nên cleanupfail; offline4 deadlinefault0.5s hết ngay khi bootconsumer; offline5 suite10 bước đầu đạt nhưng hashgate từ chối vì tác giả sửa watchdog khi đang chạy, không dùng làm finalPASS; offline6 suite10 đạt nhưng finally tạo session11/rate429→nativeFAIL; offline7 đủ10/native0/sourcehash đạt trước bổ sung hostcleanupdeadline; offline8 đủ10/hostcleanup đạt trước bổ sung consumerqueue10/clamp; offline9 đủ10/native0 trước khi bỏ stackframes ở failurecollector. Log lỗi cuối chỉ whitelist class/operator/fixedcode, Python entry không in traceback; rawFAIL cũ giữ nguyên đúng yêu cầu. Không sửa raw hoặc nới rate/guard để épPASS. Final10 và import7 mới là exacttool/source baseline cho review.

## Điều kiện chưa mở

sourceGrant/sourceExecutionStarted/sourceCalls đều false/false/0, main/photo/proxy flags không bật trên stackchính; chỉ env riêng lab bật fixture. Source executor vẫn disabled, không tạo approval/cold/claim/reset/renew hoặc hỏi lại human5ảnh. Actual source target/body/count/snapshot/CDN hiện tại, wire GET khi thiếu chứng cứ, cache availability sau khi bị dọn, external topology isolation thật và watermark filemới đều chưa nghiệm thu. Nguồn riêng phải có review fingerprint và chỉ thị mới cụ thể; không dùng consent draft cũ/role log làm phép.

Bàn giao verifier read-only/manifest/fullcoverage/read-only/source-final/test-final/raw FAIL và receipts prepend nối proposal-audit→prepare-dispatch. Reviewer chỉ cần kiểm exactfinaldelta lab, actual10+6cases/native/group/proof/closure và source-disabled; không lặp ma trận lịch sử. Nếu có finding, sửa offline trước; nếu đạt thì reviewer mới trình chủ một lượt nguồn cụ thể. Chưa main/gallery/deploy.
