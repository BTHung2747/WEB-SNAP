# Mẫu3 — connection boundaries, 09/10/2026

**Mẫu3 metadata/file contract PASS, native exits0. Tệp gốc còn NEEDS_VISUAL_REVIEW toàn486,593s.** Mẫu1+2 giữ nghiệmthu2/3; chưa no-button/shortlinkAPI E2E/TikTokmain/deploy. Lượt này PASS không chứng minh nguyên nhân READ_TIMEOUT lịch sử đã sửa.

## API và observer

Đã đọc AGENTS/PLAN/STRUCTURE/AUDIT/PROGRESS/decode-budget handoff. [Requests2.34.2 adapters](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py) và [transport adapters](https://requests.readthedocs.io/en/latest/user/advanced/#transport-adapters) hỗ trợ subclass/init_poolmanager/proxy_manager_for. [urllib3-2.8.0 pools](https://urllib3.readthedocs.io/en/2.8.0/reference/urllib3.connectionpool.html) công khai ConnectionCls; [connection API](https://urllib3.readthedocs.io/en/2.8.0/reference/urllib3.connection.html) có connect/request/getresponse. [PoolManager source đã ghim](https://github.com/urllib3/urllib3/blob/2.8.0/src/urllib3/poolmanager.py) nêu local scheme mapping cho override. Dùng copy per-manager, không mutate shared mapping/private _new_pool/_validate_conn/_tunnel.

ObservedAdapter gọi super để tạo ordinary PoolManager/ProxyManager, rồi local mapping tới pool subclasses có ConnectionCls observer. Mixin chỉ delegate super, return/rethrow nguyên object. Không viết client HTTP/TLS/parser mới, không đổi pool key/header/cookie/verification/retry. ContextVar scope từng request, reset finally; UUID-derived opaque IDs. ConnectionID là library connection object, không raw socket; reconnect cùng object sẽ có setup mới, reused flag được xác định từng request qua public is_closed và setup đã quan sát.

Log chỉ boundary/event/code-class whitelist/elapsed/public connection.timeout và IDs, max128events/observer, max6terminals/summary; không URL/host/header/cookie/token/message/repr/stack/socket data. Log failure/truncation đánh incomplete, không thay library exception để ghi log. Full JSONL ở own output; packet chỉ summary. ssl.SSLError/SSLCertVerificationError có fixed whitelist labels, không verify_message. Bounded body read/byte/deadline guards giữ.

CONNECTION_SETUP nhóm DNS/proxy TCP/CONNECT/TLS, không đo riêng từng chặng. REQUEST_SEND có thể bao gồm lazy setup nếu plain HTTP; HTTPS library thường preconnect. RESPONSE_HEADERS đo getresponse return/error, không tuyên bố body đã đọc xong. Timeout số lấy từ public connection.timeout tại entry; read ceiling chuyển xuống thư viện và actual read timeout có thể khác nhau. Adapter.send aggregate chứa thêm manager/context/log overhead, không phân bổ phần dư thành chặng chưa đo.

## Offline và guards

Node HTTP/HTTPS/net loopback fixture tái sử dụng mẫu server/tunnel sẵn trong test_stages.mjs, chỉ network-none/loopback. Client là Requests/urllib3 thật; fixture CA stages-cert/key chỉ dùng kiểm offline, source verifiedTLS/default trust không đổi. Fixture timeout0,25/0,3/total2s để kiểm delay/lỗi nhanh; sourceconnect10/read20 giữ.

PASS: proxy không trả CONNECT→SETUPERROR; TLS stall→SETUPERROR; untrusted fixture cert→SETUPERROR; header delay→RESPONSE_HEADERSERROR sau setup/send END. Status/body/error code bằng stock adapter. Sentinel TimeoutError exact object giữ ở cả3methods. Hai request cùng origin reuse cùng connectionID và không setup lại; đổi origin(port) dùng connectionID/setup mới. Shared stock mapping giữ. Node server exit0, sockets/timers cleanup, sourceRequests0.

Suite offline1 cũng qua read20/phaseclamp/absolute-parent markers/decode remaining−10/exhausted0spawn/native errors/reap/owned cleanup/caps/hash/short full pipeline và OS watchdog. Known-valid486s benchmark một lần: full decode31,054611s/rc0/timeout169,609064s; full pipeline worker0/parent0/prepare32,920091s/SHAf587381808e3f189ee0125e31a040d17d9f2c4100dde9738e169c93f7c3592bb input/output khớp. Đây là fixture, không TikTok/visual PASS.

Imagecache5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6; egress8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10. Cobalt commit/AGPL3/upstream/libs giữ.52host/44source/1364deps-binaries; runtimeSHAe6ff13d07f2a221c6322e393486d1f904173a65261824eec1960761614472ed4 offline/benchmark/live khớp. Không install/build/host/production/UI/API/DB/lifecycle.

Giữ source512MiB/CPU0,75/PIDs96/user1000+egress96MiB/CPU0,25/PIDs64/user65534,total608MiB; memoryswap=memory/rootfsRO/sourceRO/outownRW/privateIPC/PID/capdropALL/NNP/defaultseccomp/noports/own internal+outbound/SSRF/TLS. Metadata30/2GET/8MiB response16MiB total; prepare180/conditional1MP4GET/input250MiB/output200MiB/duration600; connect10/read20/remaining clamp/full decode−10reserve/redirect0/retry0/HEAD0/fallback0 giữ. Anonymous cookieRAM/no account/actualImpersonationfalse.

## Nguồn mẫu3 và tệp thật

Một analyze URL dài @nguye003/video/7692288554839313682; Cobalt xác minh fresh bodyID/video/duration từ RAM. Format play-bitrateh264_540p_1544395, không downloadAddr watermarked. Không resolve shortlink/request phụ.

| Kiểm | Kết quả thực |
|---|---|
| Metadata |2GET200;1462+429880=431342byte;duration486s;1,568390241s<30|
| MP4 |1GET200;input/output93936477byte;connect10/readceiling20/totalremaining179,979801s|
| MP4 boundaries |setup0,184797s/timeout10;send0,030732s/timeout10;response0,040011s/timeout20;END/OK|
| Adapter aggregate |0,388236s; không tách TCP/CONNECT/TLS|
| Reuse |metadata request2 same connectionID/no setup; MP4 new ID|
| Prepare operations |download5,101896/output0,039065/probe0,118908/contract0,014007/decode34,503776/hash0,859198s|
| Decode |full FFmpeg/rc0/timeout164,670436s=remaining−10|
| Container/codec |MP4_ISO_BMFF/isom/H2641024×576+AAC|
| Duration |format486,593/video486,566667/audio486,591995;metadata486/delta0,593≤tol0,75s|
| Bytes/SHA256 |93936477;ad15bd84bf9f97ea6b2b2d990f3e9f998d6731b536badcd61a22c7d25ef78118|
| Outcome |prepare40,707040108s<180;worker/parent/container/runner/outer0;runtimehashPASS/metadataAcceptedtrue|

Boundarylog16events/3requestIDs/2connection-objectIDs, no ERROR/incomplete. Setup vẫn là nhóm; tất cả trả thành công ở lượt này. Historical READ_TIMEOUT boundary/cause vẫn UNKNOWN; không quy một PASS thành observer/read20 đã sửa mạng/TLS/cause. Source decode>30 hỗ trợ policy mới, nhưng không hồi tố nguyên nhân earlier file đã cleanup.

## Video gốc để review

[MP4 gốc](evidence/tiktok-cobalt-connection-boundaries-20261009/sample-3/video.mp4) đã trình bày inline và open_in_codex requested(toolqueued). Chưa có continuous full-clip/perceptual audio/watermark review; không suy queued/codec/decode thành human acceptance.

Cần phát toàn486,593s (~8phút06,6s), xem hình/nghe tiếng và kiểm watermark TikTok mọi phần/các góc/đoạn kết; giữ logo/chữ tác giả có sẵn. Tệp nguồn không crop/blur/remux/transcode/xóa logo. visual-assessment/candidate-result giữ NEEDS_VISUAL_REVIEW, accepted/fullVideo/perceptualAudio/watermark=false. Hai review cũ giữ2/3. Human review về sau dùng successor gắn SHAad15…8118, không hồi tố raw. Đủ3mẫu cũng không tự bật main/deploy hoặc chứng nhận no-button/shortlinkAPI E2E/mọi URL.

## ActualUTC/VN, lệnh và evidence

UTC08/10 tương ứng VN09/10/2026:

| Lượt | UTC | VN | Exit/cleanup |
|---|---|---|---|
| offline1 |18:33:16.562–18:34:08.752|01:33:16.562–01:34:08.752|0/own1container0left/network0|
| known-valid/full486 |18:37:06.268–18:38:14.763|01:37:06.268–01:38:14.763|0/own1container0left/network0|
| source |18:39:59.677–18:40:43.269|01:39:59.677–01:40:43.269|0/own2containers+2networks0left|

Sourcecleanup UTC18:40:46.996/VN01:40:46.996. SequentialRAM8GB/exact IDs/runlabels/guard beforestart, không touch main hoặc existing resources.

~~~powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -Sample 3 -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage benchmark -Sample 3 -FixtureAttempt 3
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage live -Sample 3 -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_connection_boundaries.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_connection_boundaries.ps1
~~~

Lệnh là hồ sơ thực, không hướng dẫn retry/overwrite. Source budget một analyze đã dùng; không request/HEAD/fallback/solver/account/browser/production thêm. Evidence docs/evidence/tiktok-cobalt-connection-boundaries-20261009/ giữ baseline2780files/before snapshots/provenance/APIreview/loopback-errors-reuse-stock-identity/receipts/runtime/guards/nativeUTC-VN/knownvalid/fullpipeline/sourcevideo/probe/decode/hash/operations/connections/visualpending/successor/manifest. Chỉ5lab+AUDIT/PROGRESS cũ đổi; observer/serverfixture/test/verifier/handoff mới đúng lab. Old raw/golden/verifiers/history/apps/video/humanreviews1+2 giữ SHA.

Doc patch tool preflight đầu lỗi JavaScript string trước mọi ghi; record giữ, không source rerun. Verifier mới xác minh kỹ thuật và trạng thái review còn thiếu, không sửa verifier/golden lịch sử để ép acceptance. Bước tiếp chỉ review tệp đã có; không mainapply/deploy hoặc API E2E tự mở.
