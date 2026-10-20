# Đề xuất bước5: một ảnh TikTok qua ứng dụng

15/10/2026. **PROPOSAL_ONLY_PENDING_REVIEW**. `sourceGrant=false`, `executionStarted=false`. Lượt này chỉ đọc source/receipts và tính lại fingerprint metadata lịch sử; không test/browser/Docker/network/TikTok/CDN/DNS ngoài, không tạo container/network/DB/claim/cold. Core1/integration2/egress3+gate3b/UI4 đã được reviewer nghiệm thu offline, không biến thành quyền nguồn.

## Mục tiêu và fingerprint

Đúng **một workflow, một job, index2, một JPEG** tại canonical:
`https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421`.

BodyID phải là `7678209751167110421`. Theo `input_photo()` hiện có, metadata thực đi tới `https://www.tiktok.com/@adne_la.veil/video/7678209751167110421`, một phép normalize trước request, không thử thêm URL. Không shortlink/query/resolve phụ/ảnh khác/all5/ZIP/audio/video/thumbnail.

Danh sách kế thừa có155dòng hash/128đường dẫn khác nhau (27dòng web lặp), đã đối chiếu hash với backend3 đã nghiệm thu; danh sách và fingerprint nằm ở [source-before.json](evidence/tiktok-photo-app-source-step5-proposal-20261015/source-before.json). Fingerprint file này được chốt trong [scope.json](evidence/tiktok-photo-app-source-step5-proposal-20261015/scope.json). Source/API/lifecycle/locks không sửa trong đề xuất. Trước lượt thực thi tương lai phải kiểm hash mounted/imported modules và image đúng fingerprint; nếu delta mới cần preflight/review đúng delta, không sửa golden để ép khớp.

Tính offline bằng public `photo_contract.summary/format_id`, chỉ dùng dimensions/index của evidence cũ, không tải/đọc HTML mới. Kết quả khớp5itemKey và snapshot `8fa38af83f8dc423d4d78b8044d5d7b26ae3fdef9ec73eab59fe04f8475c2127`; index2 2132×2132, itemKey `1ad98a37c98bc40e86e1093bf8ec20ab94a1479ead88228728881b32d04e3497`, format lịch sử `ttp1_02_8fa38af83f8dc423d4d78b8044d5d7b26ae3fdef9ec73eab59fe04f8475c2127`. Đây là **cấu trúc lịch sử**, không metadata hiện tại hoặc pixel identity. Chi tiết [historical-expectation.json](evidence/tiktok-photo-app-source-step5-proposal-20261015/historical-expectation.json).

Fresh analyze phải đúng ID/photo/count5/thứ tự/dimensions/itemKeys/snapshot lịch sử đã chốt; khác hoặc index2 thiếu thì dừng trước prepare, không đổi lựa chọn. Lấy actual itemId/formatId **từ public descriptor mới** tại index2 rồi so expectation, không gửi UUID/itemId cũ. Prepare là child khác/fresh RAM session, core tái kiểm toàn snapshot/bodyID/format trước conditional JPEG. Snapshot chỉ ràng buộc cấu trúc: ảnh đổi nội dung nhưng cùng kích thước có thể không bị phát hiện.

SHA file index2 lịch sử `62308e76366aece0368f8c326f6430669fa4601ff1d963bb99378507091f5a8b`,322655B chỉ là đối chiếu lịch sử. Tính SHA mới từ file thật; nếu khác ghi bytes changed/identity UNKNOWN, giữ file để review và dừng phần còn lại, không thử nguồn khác để khớp hash. Không gọi khác byte là lỗi transport đã chứng minh hoặc tuyên bố watermark chỉ từ snapshot. Human review5ảnh cũ đã accepted và không hỏi lại; không dùng nó làm review tự động của file mới.

## Cache, code và topology dự kiến

Đây là pins **đọc từ accepted backend3 receipts**, không Docker inventory mới hoặc bảo đảm image chưa bị dọn. Trước thực thi phải image-inspect read-only; thiếu image/capability thì dừng, không pull/build/install.

| Thành phần | Image đã thực chạy offline | Cap kế thừa |
|---|---|---|
| API+worker+media+client lab chung | `sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e` |512MiB/CPU0.75/PIDs160/user1000:1000|
| Proxy+DNS/helper/control | `sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10` |96MiB/CPU0.25/PIDs96/user65534:65534|
| PostgreSQL riêng | `sha256:38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74` |128MiB/CPU0.25/PIDs64/user999:999|
| Redis riêng | `sha256:a9cc41d6d01da2aa26c219e4f99ecbeead955a7b656c1c499cce8922311b2514` |64MiB/CPU0.25/PIDs32/user1000:1000|

Tổng runtime800MiB, tuần tự trên RAM8GB, không browser/Vite cùng chạy; không suy peakRSS từ cap. Các process API/worker/client/media **chia sẻ**512MiB. RO/nonroot/dropALL/NNP/privateIPC/no extra swap, tmpfs hữu hạn/media64MiB kế thừa đúng backend3. Không publish DB/Redis/proxy/API; client local trong cùng app container gọi127.0.0.1:3000, không chiếm cổng main. DB `photo_source_step5`/Redis namespace/media UUID mới hoàn toàn, không dữ liệu hoặc settings DB main. Lab-only settings theo defaults hiện hành và chặn ở min(app,photo caps); đề xuất30/180 nằm trong trần đã giao, không ngầm kế thừa fixture20/40 rồi gọi đó là30/180 hoặc sửa main.

Cached images có code cũ; Dockerfile đã sửa không nghĩa image đã rebuild. Tái dùng readonly source mounts đúng155file và legacy entrypoint `/app/infra/media_adapter.py`, modules `/app/apps/media/src/tiktok`, API/worker/shared/prisma như offline. Proxy mount current `/app/egress.py` và modules/vendor tương ứng hoặc entrypoint source đã mount rõ; không để CMD cached chọn code cũ. Bắt buộc kiểm `__file__`/module hash/extractor hash và sys.path trong preflight offline tương lai, không để `.infra/tiktok` cũ shadow source hiện hành. `PYTHONPATH` production modules, không thư mục fixture.

Topology đề xuất: một network **internal** chỉ app/PG/Redis/proxy; một bridge egress riêng **không internal**, chỉ proxy được nối để DNS/public443. App chỉ có internal network, không host network/extra route/socket Docker: media không ra Internet trực tiếp. Alias `egress` ở internal; media hardcoded `http://egress:8888`, Requests `trust_env=False`, không fallback direct. Không dùng bridge external cũ của main. Hai network phải private/non-overlap, được kiểm từ create/inspect tương lai; chưa tạo hoặc kiểm connectivity ở lượt này. Nếu host không enforce được isolation thì dừng, không nới host/SSRF/TLS.

Proxy cùng listener8888 nhưng control chỉ chấp nhận **cả local interface và peer** trong internal CIDR chính xác do Docker cấp, không catch-all/link-local hoặc external CIDR. `TIKTOK_EGRESS_CONTROL_NETWORKS` chỉ ở proxy; global control secret mới64hex sinh RAM cho proxy và trusted parent/API, không dùng secret main, không envfile/artifact/log. Parent bỏ global secret khỏi child, cấp nonce/cap mới mỗi phase qua env; Basic chỉ CONNECT, không upstream header. Open/seal/poll/take/abort và private epoch/binding vẫn RAM, không lấy từ public API/DB hoặc log. Capability/session/health chỉ cấu hình/khởi động, không proof phase.

Proxy vẫn every raw DNS row≤256 trước ordered dedup≤64, all-public, aiohappyeyeballs2.7.1/policyC/groups4/max2/setup10/end−1, helperIPC/memory/reap và completion sau physical closures; admission8listener/1setup giữ. Không thêm domain khi CDN bị từ chối; `EGRESS_DOMAINS` lab chỉ subset TikTok/CDN allowlist hiện có, không đưa wildcard/source mới. TLS end-to-end kiểm CA hệ thống/hostname, không fixture CA hoặc verifyFalse. Allowlist/domain policy nguyên tắc không thay; deny/malformed/private/overcap/trace incomplete đều dừng.

## Harness successor còn phải làm sau review và nguồn grant mới

Hiện **chưa có source runner ứng dụng cho workflow này**. Không chạy `photo-ui-step4/run.ps1 -Mode backend` tới nguồn: nó tạo2job, origin giả, count/SHA cố định và fault injection. Không trình lệnh trỏ wrapper chưa tồn tại như công cụ đã chạy được. Consent ở cuối giao tạo successor nhỏ, offline gate trước, rồi mới một workflow nguồn nếu đạt. Lượt chuẩn bị này không tạo/sửa source wrapper hoặc lab.

Phần tái dùng: cache/mount/hash gate/guards/own-ID cleanup, production Nest API và BullMQ consumer/concurrency1, runAdapter/ProcessGroup/lifecycle, photo core/Requests/cookiejar/Cobalt picker/FFmpeg/validator và gate3b. Không import whole Cobalt/F2/TikTokPy, parser/solver/transport mới; pins yt-dlp2026.8.19(extractorSHA3257…c9e)/Requests2.34.2/urllib3-2.8.0/brotli1.2.0/Cobalt commit a636575b09de1fc55d9b8cd98cac88f5f2f16b42/vendor2.7.1/LICENSE/NOTICE/locks giữ. Runtime versions lấy từ receipts và `versions()`; không tuyên bố FFmpeg apt version mới chưa đo, preflight tương lai capture version bằng binary cache không source.

Phần phải bỏ/thay ở successor: không mount/import `sitecustomize.py`, `media_site.py`, `proxy_service.py` fixture; không `EGRESS_STEP3_FIXTURE`, `EGRESS_TLS_MEDIA_FIXTURE`, fake libc getaddrinfo, ObservedLoop.sock_connect map loopback, private CA hook, fault Request/Broker, fake challenge/body/cookie/CDN origin, YouTube fake extractor, PASS→exit/hang injection, fixed fixture ID/file/SHA/count/assertions và proxy-count origin giả. Dùng production server_class/egress thực, OS DNS/public transport/CA; ghi observed target và capability. Không chỉ tắt một env flag rồi giả đã bỏ toàn fixture.

Accounting/log collector cần nối tối thiểu trong **lab successor**: trusted wrapper quanh public WED `analyze_album/prepare_photo` chuyển `diagnostics={}` sẵn có vào nguyên hàm core, giữ production CLI/contract/native exit; không monkeypatch private Requests/urllib3 hoặc viết HTTP engine. Chỉ whitelist phase/request ordinal/method/status/decodedBytes/effectiveTimeout/codes/opaque boundaryIDs/timing. Thu dict trong finally, Operations/boundaries và actual native/group/gate events trước tmpfs cleanup, bounded evidence (metadata/request rows≤5, boundaries≤128 mỗi child, numeric JSON aggregate≤512KiB đề xuất). Diagnostic ghi thiếu/thất bại thì receipt incomplete→workflow FAIL, không thay exception bằng message/stack. Collector này chưa viết/kiểm; cần offline preflight đúng hash sau khi được giao.

`Budget.sent()` là **attempt được budget cấp trước Adapter.send**, không chứng minh HTTP tới origin. Proxy thấy CONNECT/TLS opaque, không đếm GET. Dùng rows/boundary send/header status/decoded bytes để đối chiếu từng phase; ghi actual wire GET UNKNOWN nếu timeout/kill trước response, không biến thiếu chứng cứ thành0 hoặc PASS. Bounded max attempts2+2+1 và adapter retry0 bảo đảm upper bound; status thực và số response đã thấy tách riêng. Metadata không cộng bytes hai lần khi chuyển image mode (`network_total` không reset). Core có diagnostics hook nhưng CLI hiện không xuất dict; proxy completion chi tiết cũng chỉ RAM. Successor cần sanitized collector bên proxy theo actual owned context (không log epoch/cap/binding) cho closure/DNS stats; collector mất bằng chứng không được dùng health/count chung thay proof. Việc thu log không cấp nguồn thêm.

Giữ BullMQ enqueue attempts1/jobId theo phase và processor claim bằng job lock+state+workerToken. Không consumer/handler thứ hai, không restart policy; source-worker mất/lock uncertainty/stalled thì cancel/stop cả lượt, không chủ động requeue. Offline preflight phải chứng minh một analyze child và một prepare child tối đa, missing accounting/gate deny trước mở nguồn; nếu không enforce được budget toàn workflow thì chưa chạy.

## Workflow và ngân sách sau khi được cấp quyền

1. Offline preflight trên successor cuối: dependencies/hash/mount/no-fixture/context/proxy proof/deadline/diagnostic sanitize/one-job/cleanup. Mạng external chưa attach và không URL nguồn trong smoke. Không tiêu thụ/reset bất kỳ grant/claim/cold lịch sử.
2. Khởi động topology riêng, giữ nguồn chưa thực thi tới khi preflight/hash/guards đạt. Local `GET /api/v1/health`, `GET /api/v1/session`, capability true/CSRF/cookie chỉ RAM; prepare internal proof config đúng. Không gọi nguồn để “kiểm mạng”.
3. Một `POST /api/v1/jobs/analyze` với canonical trên; API→queue→production consumer→child analyze. Poll `GET jobs/:id` và heartbeat15s nội bộ; chỉ selectable sau native0+group0+accepted proof đúng phase. Kiểm fresh public album theo expectation; ERROR/UNKNOWN/diff dừng trước prepare.
4. Một `POST jobs/:id/prepare` với actual itemId/formatId của index2 + fresh idempotencyKey, không gửi lại khi timeout. Worker child mới fresh metadata≤2GET; strict bodyID/snapshot/index rồi conditional1JPEGGET. Chỉ ready sau JPEG contract/SHA/native0/group0/exact accepted proof; lỗi không ticket.
5. Một `POST jobs/:id/download-ticket`, giữ cookie/CSRF/ticket RAM, chỉ chấp nhận URL same-origin `/api/v1/downloads/…`, không log ticket/path token. Local HEAD1 (handler GET có nhánh HEAD, đã được kiểm offline) kiểm200/MIMEimage/jpeg/attachment filenamejpg/length và không tạo lease. Local fullGET1 streaming/cap16MiB vào file evidence exclusive; so bytes/SHA với asset packet/owned file. Không browser fetch-blob. Nếu file SHA khác lịch sử: đánh dấu changed/giữ file/dừng, không thử nguồn khác. Khi đủ điều kiện, local RangeGET1 (`bytes=0-99`) so206/Content-Range/đúng100byte, tách lease tạo bởi GET với HEAD0lease; không GET lại JPEG ở CDN.

| Phạm vi | Trần và tiêu chí |
|---|---|
| Source analyze |≤2metadataGET, deadline30s, decoded8MiB/response+16MiB total|
| Source prepare |fresh≤2metadataGET trong30s, conditional1JPEGGET, tổngprepare180s|
| JPEG/bytes |JPEGinput≤20MiB; prepareinput≤36MiB/output≤16MiB; analyze input≤16MiB, toàn workflow decoded≤52MiB; app nhỏ hơn thắng|
| Item/HTTP |item≤60s và≤prepareEnd−10reserve; full decode≤30s clamp/reserve5 như photo_file hiện có; connect≤10/read≤20 clamp absolute remaining|
| Source tổng |≤5GET attempts; HEAD0/redirect0/retry0, không fallback/ảnh khác/preview/audio/resolve phụ|
| Local API/control |GET/HEAD/Range/heartbeat/DB/control **không** là nguồn và không cấp source budget; control caps/TTL/percall1s hiện có giữ|
| Startup/execution/cleanup |startup/preflight≤60s không nguồn; workflow absolute≤250s từ POSTanalyze đầu gồm queue≤10s/phase+30+180+local≤20; cleanup≤20s; OS watchdog360s kế thừa, không reset deadline khi đổi phase hoặc chờ proof|

Phase hết hạn là FAIL/stop ngay, không dùng grace cleanup làm thời gian thành công. Parent SIGTERM→SIGKILL2s, group-unconfirmed bound6s giữ quarantine/token/file/lease như hiện có. Chưa enforce runtime các orchestration subdeadlines250/20 trong lượt chuẩn bị; cần successor offline chứng minh. Không lấy offline fixture20/40 làm phép đo source30/180; source runtime app limit chặt hơn luôn thắng.

Mọi lỗi/partial/unknown metadata, accounting, control proof, native exit/signal, nguồn/CDN/DNS/TLS/cap/deadline, snapshot/file contract/SHA đều dừng. Không retry POST có thể đã enqueue, HEAD tới nguồn, reset/renew claim, restart worker, thay proxy/network/source hoặc browser/solver/account cookie để thử vận may. Source request chưa rõ khi kill ghi UNKNOWN; quyền lượt đã bắt đầu không tự hồi lại khi lỗi.

## Bằng chứng và cleanup cần có ở lượt tương lai

Receipt UTC/VN gồm source/image/module/lock/vendor hashes actual, target requested+normalized+bodyID, job/phase opaque association, one-child/phase, native exit/signal và group0, proxy phase accepted/closure, attempt/response/decodedBytes/HTTP timeout quan sát được. Không URL ký/path/query/cookie/headers/full HTML/stack/repr hoặc env secret. Public UUID/format fingerprints được lưu; nonce/cap/epoch/binding/ticket/cookie không ra public log/DB. Báo rõ chặng setup TCP/CONNECT/TLS chưa tách được là UNKNOWN, không gọi elapsed send là riêng read wait.

File mới phải JPEGmagic/mime,1mjpeg stream/1frame/dimensions đúng metadata,2ffprobe0/full ffmpeg decode0/SHA/size, no crop/blur/reencode. Trình đúng file đã tải để xem chữ/logo gốc và watermark TikTok thêm; giữ NEEDS_VISUAL_REVIEW nếu chưa review file mới. Metadata PASS, technical file PASS, native local transfer/server_finished và human visual là các mức khác nhau. Browser UI→backend combined **không nằm trong đề xuất API-driven này**, ghi NOT_RUN; không suy UI fixture đã là source browser E2E.

Giữ actual JPEG cùng sanitized evidence sau khi xác minh native0/group0/proof/lease; chỉ dọn own container/network/media UUID bằng IDs+run labels sau physical closure, không theo tên/prefix rộng hoặc registry lịch sử. Không xóa trước group/active transfer lease đóng; quarantine/incomplete thì báo blocker/retained own IDs, không giả cleanupPASS. Kết thúc kiểm source-gate đóng/queue không job mới/own resources0, exact native exits/noOOMDocker; nếu cleanup chưa đủ ghi UNKNOWN/FAIL. Không main settings/DB/schema/Compose/env/host/install/build image/pull/deploy.

## Prompt chấp thuận ngắn để reviewer trình chủ sau review

> Tôi cho phép tạo successor lab theo [đề xuất bước5](TIKTOK_PHOTO_APP_SOURCE_STEP5_PROPOSAL.md), giữ fingerprint danh sách155hash trong [scope](evidence/tiktok-photo-app-source-step5-proposal-20261015/scope.json), kiểm offline đúng mã trước rồi chạy đúng1workflow API/BullMQ cho `https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421`, index2/mộtJPEG. Source tối đa2+2+conditional1GET, HEAD/redirect/retry0; giữ30/180s, caps, own-egress/TLS/SSRF và800MiB. Lỗi dừng, không tái dùng/reset grant cũ hoặc thử ảnh khác; native local download riêng, giữ file để review. Không bật main/gallery hoặc deploy.

Đây là **bản nháp lời chấp thuận**, không lời của chủ đã nhận, không lệnh chạy, không được dùng để tạo quyền/claim. Chưa gửi câu hỏi này tới chủ; reviewer phải kiểm đề xuất và phần còn thiếu trước. Không cần thêm hệ thống approval/cold/claim nhiều tầng chỉ để thử1workflow; mọi record consumed trước giữ nguyên.

Ghi chú số lượng: [successor count-note](evidence/tiktok-photo-app-source-step5-proposal-count-note-20261015/note.json) làm rõ155dòng/128file distinct, không thiếu coverage hoặc sửa source-before/golden. Primary evidence13artifacts/155external đã sealed giữ nguyên; các external docs thay đổi ở successor được ghi before/after riêng, không reseal/ép hash cũ. Cần dedup path cho bookkeeping successor, không thay code/runtime trong lượt này.
