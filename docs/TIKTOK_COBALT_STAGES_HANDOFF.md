# Đo chặng request Cobalt TikTok — 08/10/2026

**Lượt28s trước không tái hiện; chặng bị chờ của lượt đó vẫn chưa biết.** Một lượt nguồn mới hoàn tất proxy/TLS/header/body, nhưng body1.462byte có cấu trúc JS challenge và thiếu JSON video. Cobalt metadataFAIL/exit20 sau1,867066s. Đã dừng, download0, chưa có tệp/giải mã/hình/tiếng/watermark; không mẫu2/3, retry, solver, browser hoặc deploy.

## Kiểm toán trước sửa và lựa chọn API

Đọc AGENTS/PLAN/STRUCTURE, nghiệm thu độc lập mới nhất, PROGRESS/handoff, lock Undici6.24.1 và code egress. Raw lượt trước chỉ có METADATA_DEADLINE/decoded0, không có connection milestones. Không thể gán timeout đó cho DNS/TCP/TLS/header từ raw cũ. Không chạy nguồn trong phần kiểm toán.

Nguồn chính thức đúng version: [DiagnosticsChannel](https://github.com/nodejs/undici/blob/v6.24.1/docs/docs/api/DiagnosticsChannel.md), [ProxyAgent API](https://github.com/nodejs/undici/blob/v6.24.1/docs/docs/api/ProxyAgent.md), [Dispatcher.connect](https://github.com/nodejs/undici/blob/v6.24.1/docs/docs/api/Dispatcher.md), implementation [proxy-agent](https://github.com/nodejs/undici/blob/v6.24.1/lib/dispatcher/proxy-agent.js), [client](https://github.com/nodejs/undici/blob/v6.24.1/lib/dispatcher/client.js), [request](https://github.com/nodejs/undici/blob/v6.24.1/lib/core/request.js). DiagnosticsChannel được ghi experimental; pin API và kiểm bằng kết nối fixture thật, không chỉ giả lập publication của channel.

ProxyAgent dùng defaultPool để CONNECT rồi connector Undici bọc TLS lên socket tunnel. CONNECT đi onUpgrade, không phát request:headers thông thường. Vì vậy chỉ nghe channel header sẽ bỏ sót CONNECT200. Dùng clientFactory công khai, tạo **cùng Pool và options mặc định**, bọc Promise của Pool.connect() để ghi status/time rồi trả nguyên kết quả/socket hoặc lỗi. Không viết HTTP/TLS transport mới, patch internals, thêm dependency hoặc đổi TLS/proxy tùy đoán.

Egress vẫn image8bc0a567…7f10/code production bất biến: publicDNS/IPvalidation → TCP tớiIP đã kiểm → CONNECT200 → relayTLSopaque. Observer client không thấy riêng DNS và TCP nguồn bên trong egress; 403 cũng không phân biệt policy/DNS/unreachable. Không thêm log/code vào egress hoặc đọc packet/header TLS thô.

## Chặng đo được và giới hạn

| Chặng | API và giới hạn |
|---|---|
| Kết nối proxy | client:beforeConnect/connected roleproxy; kết hợp DockerDNS+TCP. ProxyHTTP nên không có handshakeTLSproxy. |
| CONNECT | Pool.connect start/result/status; gồm queue, kết nối proxy, DNS/TCP nguồn và response phía egress. Không gọi riêng là DNS nguồn. |
| TLS nguồn | CONNECT200→client:connected roleorigin với encrypted/authorized=true; sau secureConnect và HTTPcontext init. Không đổi CA/SNI/cipher. |
| Header | request:bodySent là gửi/queue cục bộ→request:headers cuối. sendHeaders là trước write. Không chứng minh remote nhận request hoặc thời gian xử lý thuần của server. 103 được ghi, không coi là header cuối. |
| Body | Reader bắt đầu, chunk giải nén đầu, EOF; giữ cap8MiB/response16MiBtotal. Wire-body-complete tách decoderEOF; không tách byte encrypted đầu với header đầy đủ. |

Connection channel không hứa tương quan chặt với request. Observer giới hạn một metadata worker tuần tự, lọc proxy/origin trong RAM; lượt này một sourceGET, không suy thành profiling nhiều request đồng thời. Mốc monotonicms **có overhead subscriber/CPU/ghi snapshot**, không là benchmark latency mạng thuần.

src/stages.mjs là glue mới, transport chỉ nối observer và mốc reader; main lưu snapshot nhỏ để còn dấu vết nếu bị OSwatchdog cắt. Chỉ event/role/time/status/TLSboolean/mã lỗi ASCII đã lọc/bytecount được xuất; không request/path/query/rawheaders/error-message/socket/address/cookie/token. Cap128event, unsubscribe khi close; observerfault không mở nguồn. Snapshot thuộc directory own mới. Decoder/classifier/parser/sourceplay selection giữ nguyên.

## Offline và một nguồn mới

Imagecached vẫn sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6; không build/install. Offline256MiB/network-none/user1000/RO/defaultseccomp/capdrop/no-new-privileges/privateIPC. Nodehttp/https/net dựng proxy/HTTPS giả ở loopback, CA/keyfixturelocalhost riêng; **không đổi trust live**. Fixture CA10năm để tránh expiry sớm; key chỉ là credential thử nghiệm trong lab, không key/tài khoản nguồn.

Offline1 exit0: CONNECT chờ, TLS chờ, header chờ, body chờ, thành công và cap/unsubscribe đạt;9caseCobalt/Brotli/caps/hash/redaction/watchdog cũ vẫn đạt. Sau đó tinh chỉnh phân biệt HTTP103 với finalheader và mốc reader; snapshot ba file đã chạy offline1 giữ. **Offline2 bản cuối exit0**, cùng năm case đạt, 103 thật không nhận nhầm; host/runtime hash/deps và OS30swatchdog PASS. BusyNode bịSIGKILL/child−9, quan sát30,080589s (timeout30s, overhead80ms). Hai container offline dọn0left.

live-hypothesis.json ghi trước nguồn: phân biệt kẹtCONNECT/TLS với TLSverified nhưng chờheader/body. Gate chỉ nhận offline2 đúng **29hostfiles/21runtime sourcefiles** và1.271 installeddeps/binaries; deps so với lượt trước giữ. Không nhận PASSdraftoffline1 cho bản cuối.

Live đúng một analyze, targetID7692808825228807442/inputtácgiả đượcgiao; resolver pinned vẫn canonical@i/video/{postId}. Một originGET và CONNECT nội bộ cần cho request đó, không thêm probe/HEAD hoặc retry:

| Khoảng đo mới | ms theo observer |
|---|---:|
| ProxyDNS+TCP (159,903→187,740) |27,837|
| CONNECT start110,808→response200 tại505,990 |395,182|
| CONNECT200→TLSverified613,808 |107,818|
| Locallysent648,011→header200 tại803,508 |155,497|
| Decodedreader1018,199→EOF1113,520 |95,321|

TLSencrypted/authorized=true, observerfaultfalse/drop0,20event, networkstageCOMPLETE. HTTP200/text-html/br/Content-Length688nén, **1.462byte giải nén**, bodySHA09938e2eda73fe82e5a5d826096bafe3bb4b53043ec49f8bf361da3e5c8af362. Classifier pinned yt-dlp (không solver) thấycs/wci/rci=true, JSONchallenge vàdigestfields=true, Pleasewait=true, rehydration=false; captcha-marker cũfalse. Vì vậy **response mới có cấu trúc JS challenge**, không có JSONvideo Cobalt yêu cầu; parser trảCOBALT_fetch.fail. Không kẹt trướcheader trong lượt này.

Metadata worker20/1,867066s, timeoutfalse; body/parser/helper1,700433s. Native docker attach/runner/outer20, UTC08/10 **03:47:59.988–03:48:03.131**, VN08/10 **10:47:59.988–10:48:03.131**. MetadataFAIL thì dừng; download0, ffprobe/fileSHA/decode/visual/audio/watermark NOT_RUN, không mẫu khác. BodySHA là hashresponse, không hashvideo/chứng cứ watermark.

**Không hồi tố:** transport mới hoàn tất không chứng minh chặng timeout28s trước; bodycũ1462 không có hash/payload để đối chiếu nên chưa chứng minh giống responsechallenge mới. Chưa biết vì sao challenge được cấp (IP/session/TLSfingerprint/chính sách/biếnđộng nguồn), remote nhận request lúc nào hoặc riêngDNS/upstreamTCP. TLSverified không buộc nguồn cấp video.

## Lệnh và preservation

~~~powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 1
# Tinh chỉnh103/readerstart, khôngrebuild:
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 2
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage live -Sample 1 -FixtureAttempt 2
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_stages.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_stages.ps1
~~~

Đây là lệnh đã chạy, không yêu cầu chạy lại evidence đãcó. Chứng chỉfixture tạo bằng .NETCertificateRequest trong workspace, không installtool/thaytrustWindows. RuntimeDocker tuần tự: live512+96=608MiB≤1GiB; memoryswap/cpu/PIDs, UID, ROmounts/rootfs, SSRFpublicDNSown-egress/TLS, privateIPC/PID, capdropALL/no-new-privileges/defaultseccomp/noports vẫnGuard kiểm trướcstart. MetadataOS30s/Abort28s/classifier2s/8–16MiB giải nén giữ; prepare180s/input250MiB/output200MiB không chạy. Cleanup ownID+runlabel:2offlinecontainers và2livecontainers/2networks,0left.

Evidence mới docs/evidence/tiktok-cobalt-stages-20261008/: baseline2.068file, chỉ5lab+AUDIT/PROGRESS cũ đổi; observer/tests/fixture/handoff/verifier mới đúngphạmvi. Oldraw/manifests/golden/verifiers/handoffs/history/archive giữ bytes/SHA. Predecessor79artifact kếthừa docs-onlyAUDIT successor nghiệmthu độc lập, copychain kiểm chính xác;78artifact còn lại khớpbaseline. ProvenancePROGRESS cũ đã cóledgerdoc-only giải thích; không sửa lời “unknown” trong raw/handoff đóngbăng để hồi tố. Khôngrerunhistory/thaygolden épPASS.

Ứng dụng chính/YouTube/API/UI/DB/lifecycle/production không sửa; TikTok0/3/P0/no-buttonE2E chưanghiệmthu. Metadatafixture/networkCOMPLETE không phải tải thànhcông. Bước tiếp cần nhiệm vụ riêng dựa trên responsechallenge đãđo và ràng buộc hiện hành; không tựbật solver/cookie/account/proxy/TLSbiếnđổi hoặc gọi thêm nguồn.
