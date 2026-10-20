# Bàn giao bước3b — gate completion proxy theo phase/job

Ngày15/10/2026. **PASS_OFFLINE_LATE_COMPLETION_GATE_PENDING_REVIEW_DEFAULT_OFF**. Tác giả đã sửa F-EGRESS-LATE-COMPLETION/P2 và kiểm offline; chờ reviewer độc lập. Không phải quyền thử nguồn hoặc nghiệm thu UI/main.

## Thay đổi và lý do

Requests2.34.2 có `HTTPAdapter.proxy_headers`; Node22.22.3 có `http.request`/crypto/AbortController; CPython3.12.12 có `BaseHTTPRequestHandler`/`http.client.parse_headers`. Các API này đảm nhiệm HTTP/proxy headers/parse/TLS hiện có. Chỉ tự viết hợp đồng correlation và gate nghiệp vụ vì thư viện không biết job/phase/ProcessGroup hoặc completion DNS/registry của WED SNAP. Không thêm dependency hay viết lại extractor/downloader/TLS/HTTP engine.

Parent tạo nonce mới và HMAC binding jobUUID+workerToken+phase+nonce trong RAM. Broker proxy cấp epoch/cap mới; child chỉ nhận nonce/cap qua env cho đúng phase, không nhận global secret. `PhotoProxyAdapter.proxy_headers` đặt Basic credential ở CONNECT, không origin header. TLS origin fixture từ chối Authorization/Proxy-Authorization nếu lọt qua. Không đưa credential/binding/epoch vào public packet/DB/log; signed URL/cookie vẫn chỉ RAM. Correlation kỹ thuật không phải source grant.

Kênh `POST /_wed/phase` dùng listener hiện có8888, không thêm service/port. Cần secret64hex và CIDR nội bộ khai báo rõ; kiểm cả interface local và peer cùng CIDR, chỉ subnet RFC1918/loopback/ULA, từ chối catch-all/link-local. Không có config thì từ chối trước child; main/Compose/settings chưa đổi, flags mặc định tắt. Endpoint không dựa riêng vào bearer để cho phép truy cập interface ngoài. HTTP control nội bộ không mã hóa; chỉ dùng namespace/mạng tin cậy đã giới hạn, secret không dành cho mạng công cộng.

Broker giữ tối đa64scope, absolute TTL30/180 không gia hạn;2CONNECT analyze/3prepare,28controlqueries/scope. Open/seal/poll/take/abort xác minh id/job/phase/epoch; seal cấm CONNECT mới, take chỉ một lần. Zero connections, missing/unknown/mismatch/replay/expired/overflow/channel error đều reject. Scope gắn actual Request context; accepted chỉ sau client/loop/registry/helper và serve thread đã đóng thật. Live uncertainty giữ bounded references và có thể từ chối admission khi đầy; không evict rồi coi là PASS. Harvest phân loại thread một lần để tránh race làm rơi completion.

Production parent giữ deadline từ trước control open/DB preflight/spawn. DB preflight race≤1s/remaining; không tuyên bố hủy được query Prisma đang đọc. Sau native0 và ProcessGroup0, registry còn bảo vệ đến khi đúng phase proof accepted/take và kiểm lại deadline/cancel/ownership. Control mỗi call≤1s (abort≤300ms) và remaining, response≤2048B/header4096; tối đa24poll, loop chỉ bắt đầu poll trong cửa sổ5s. Call cuối có thể dài thêm≤1s nhưng vẫn nằm trong absolute phase; không mô tả5s là hard end-to-end subdeadline. Thiếu proof không selectable/ready; staging dọn bằng ownership/lifecycle hiện có. Quarantine giữ token/lease/staging khi group chưa xác minh đóng; không signal lại group sau đã xác minh đóng.

Giữ GET nguồn2analyze+2metadataPrepare+conditional1JPEG, redirect0/retry0, setup10/policyC/groups4/max2/DNS raw256→ordered unique64/every-row public, HTTP10/20, metadata30/prepare180 hoặc app chặt hơn, JPEG/full decode/SHA. Admission8listener/1setup giữ scope đã công bố. Video TikTok/YouTube không bắt buộc photo credential mới.

## Bản mã và lệnh thực chạy

Namespace `docs/evidence/tiktok-photo-egress-step3b-20261015/`; runner `labs/tiktok/photo-egress-step3b/run.ps1`. Các lượt thực chạy là broker-1..3, typecheck-1..4, worker-1..3; giữ nguyên raw/intermediate. Lệnh tái lập offline, mỗi Evidence phải mới:

```powershell
& './labs/tiktok/photo-egress-step3b/run.ps1' -Mode broker -Attempt 3
& './labs/tiktok/photo-egress-step3b/run.ps1' -Mode typecheck -Attempt 4
& './labs/tiktok/photo-egress-step3b/run.ps1' -Mode worker -Attempt 3
```

Đây là lệnh các lượt cuối đã chạy, không chạy lại vào namespace frozen: runner từ chối Attempt đã tồn tại; review dùng receipt mới hoặc sao chép runner sang namespace riêng. `native.jsonl` lưu đầy đủ lệnh Docker/actual exit/UTC của lượt tác giả. Source cuối101file khớp broker-3/typecheck-4/worker-3 trước/sau. Baseline405file:398giữ/7delta có before+diff;3runtime mới `control.py`, `photo_proxy.py`, `proxy-phase.ts`. Processor/API/shared/schema/UI/locks/vendor10/RECORD/LICENSE/main Compose/lab cũ/history giữ byte. Provenance cập nhật module hash, không đổi vendor.

Proxy cache `sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10`: Python3.12.12. App cache `sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e`: Node22.22.3/Python3.11.2/Requests2.34.2. Không suy target proxy từ Python media.

## Kết quả thực và giới hạn

Final broker-3:15ca/exit0. Typecheck-4:exit0. Worker-3:22nhóm ca/exit0, actual production `processJob/runAdapter` và PrismaDB transitions, proxy/control/CONNECT/Requests/TLS/JPEG/ffprobe/full decode/SHA thật với origin giả. DNS raw rows và TCP đích được map loopback trong fixture, certificate CA fixture vẫn CERT_REQUIRED/hostname verification. Không chạy API server hoặc BullMQ consumer; không tuyên bố API E2E/live TikTok. YouTube chỉ high-level extractor fixture; video TikTok qua TLS fixture thật.

Happy job `159a9651-7e15-41d3-a760-7a23724f0785`: analyze→selectable→fresh prepare→ready, native0/0,4metadataGET+1JPEGGET. JPEG248B/SHA `45cea83ba1889b4f948c9fca05932a47ff2bb92723dd8fa798fcf14149c51e00`, ffprobe0/0/full decode0.

Late-CDN job `cb97d92e-e7e8-4724-b39e-648a24f5e87f`: staging đúng SHA/native0, proxy completion false, production parent reject→failed, staging dọn, không ready. Late analyze/native0 không selectable. Có missing/unknown/crossjob/crossphase/channel lỗi, absolute5s không reset (elapsed5013ms), PASS→exit20/hang cả2phase, cancel và ownership expiry trong lúc chờ proof. Broker kiểm replay/retention/expiry/zero-vacuous/closure flags/schema/ACL.

Quarantine dùng fault injection public ProcessGroup observer, không phải host thật lỗi: giữ preparing/staging/token; xác minh actual child PID đã mất, fixture bỏ protected token và làm lease expired rồi real sweep dọn. Sentinel/active transfer lease của job khác giữ. Ca cuối cố ý proxy exit33 sau CDN bytes: media native0 nhưng parent reject; app suite exit0. `service.json` cuối có active2 là snapshot trước deliberate process crash, không được dùng làm proof accepted; actual proxy exit33 và cleanup own IDs chứng minh runtime đã dừng. Không restart/retry.

Runtime tuần tự: proxy+TLS fixture/helper/control96MiB/.25/PIDs96, app/media/worker512MiB/.75/PIDs160, fixturePG128+Redis64=tổng800MiB. Generator512 chạy riêng/dọn trước runtime. Broker networknone96MiB/.25/PIDs64; typecheck512/heap256. RO/nonroot/dropALL/NNP/privateIPC/no extra swap/internal/no ports/watchdog; ownResourcesLeft0/noOOM. Không đo peakRSS. Broker1/typecheck1/worker1–2 có proxy PIDs160 trung gian do common runner, đã sửa final broker3=64/worker3=96; không dùng guards trung gian làm nghiệm thu cuối.

Không TikTok/CDN/DNS ngoài/install/build/pull/claim/reset/renew/retry/main activation/deploy. Fixture không là watermark hoặc human PASS mới;5ảnh nguồn đã human accepted giữ nguyên.

## Bàn giao review

Chạy verifier read-only với receipt mới và kiểm manifest/seal; đọc actual native/group/gate/job association, không chỉ packet PASS. Docs insert nối audit3→dispatch3b; không sửa verifier/golden cũ để thích nghi delta mới. Review F-EGRESS-LATE-COMPLETION trước khi xét UI bước4/nguồn bước5; chưa triển khai các bước đó.
