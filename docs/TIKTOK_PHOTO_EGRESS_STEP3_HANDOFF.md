# Bàn giao proxy bước3 — 15/10/2026

**PASS_OFFLINE_EGRESS_POLICY_PENDING_REVIEW_NOT_SOURCE_READY**. Đã port DNS v4/policyC/ownership vào apps/egress và kiểm actual CONNECT/TLS/JPEG trong fixture. Chỉ offline; main/photo/proxy flag chưa bật, chưa build image hoặc gọi TikTok/CDN. Cần review code và các giới hạn tích hợp bên dưới trước bước UI/nguồn; không tự thực hiện bước4/5.

## Mã, mapping và pins

Ba delta cũ: `apps/egress/src/egress.py`, `Dockerfile`, `README.md`; before/diff trong [evidence](evidence/tiktok-photo-egress-step3-20261015/). Toàn apps/media/worker/API/shared/web/egress allowlist/main Compose/env/settings/DB và các nguồn/evidence/claims cũ ngoài ba delta giữ. Baseline489file có486giữ nguyên và3delta được giao; không chạy lại historical verifier rồi sửa golden để che delta.

[Mapping trước port](evidence/tiktok-photo-egress-step3-20261015/SOURCE_MAP.md), [provenance từng file](../apps/egress/PROVENANCE.json). `src/tiktok_policy` chỉ gồm admission/counts/helper/IPC/diagnostic, candidate/batch policy/validation/operation coverage và request-scoped ownership/runtime. Không copy proxy_entry/common/stage/authority/claim/fixed sample/path. Helper chỉ hostname, bỏ mode/address/delay fixture và `/poc` path; direct Popen object là authority, không đọc trace-file PID. Các import thành package-relative. Registry/trace truyền rõ từng request, không Trace.current. Batch policy giữ các hằng/thuật toán đã kiểm; thêm server lifecycle/physical thread harvest là glue ứng dụng.

Vendor **aiohappyeyeballs2.7.1** nguyênbyte10file từ bản đã có, PSF-2.0/J. Nick Koston và contributors; original METADATA/WHEEL/RECORD/full license giữ. PINNED_HASHES.json khóa SHA256 từng source file, PROVENANCE mapping origin/fromSHA/toSHA; **không gọi đây là pip hash lock/wheel mới**. Không install/download/build/pull hoặc đổi version. Full AGPL-3.0 cho glue port từ lab đã có trong apps/egress/LICENSE; NOTICE và Docker COPY metadata/giấy phép đầy đủ, recipe chưa build. [API chính thức đúng phiên bản](evidence/tiktok-photo-egress-step3-20261015/API_REFERENCES.md).

Thư viện đảm nhiệm DNS/TCP/race/cancel/loser bằng `socket.getaddrinfo` trong owned subprocess và public `aiohappyeyeballs.start_connection`; SelectorEventLoop.sock_connect observer chỉ delegate API public, không HTTP/TLS/TCP implementation mới. Phần tự viết cần cho WED SNAP: every-row admission, budget policy, ownership/request registry, trace/receipt/fail-closed và server lifecycle.

## Phạm vi cờ và bảo vệ

`TIKTOK_EGRESS_POLICY_ENABLED` chỉ `1` rõ ràng, mặc định tắt. Cờ tắt không import module/vendor mới và giữ stock path. Cờ bật chỉ chọn connector mới cho host thuộc allowlist gốc và suffix tiktok.com/tiktokcdn.com/tiktokv.com/byteoversea.com/ibytedtos.com. Không thêm domain hoặc bypass public-IP/TLS. CONNECT không thấy path nên policy ảnh hưởng cả TikTok video. Non-TikTok vẫn dùng sequential resolver/socket cũ.

**Admission server khi cờ bật** giới hạn8 active handlers và pending closure,1 DNS/connect setup đồng thời; áp cho listener cả non-TikTok để không sinh thread vô hạn trước khi biết CONNECT hostname. Đây là thay đổi admission chung cần reviewer đánh giá phạm vi, không tuyên bố mọi hành vi non-TikTok dưới tải giữ nguyên tuyệt đối. Cờ tắt không có limit mới. Nhánh transport ngoài phạm vi/parser/443/allowlist/tunnel idle30s/max240s giữ; unit kiểm YouTube/non-policy và flag-off bằng stock path/TCP thật qua mapping loopback, không là nguồn YouTube.

DNS kiểm mọi raw row trước dedup: raw≤256, ordered unique≤64, family/kind/proto/canon/port/numeric/IPv6 flow-scope/public/mapped-private; suffix private/duplicate sai vẫn DENY. IPC strict duplicate-key/nonfinite/version/count/closure/trace linkage; input16KiB/output32KiB có cap trong khi đọc. Helper RLIMIT_AS64MiB trong cgroup proxy96MiB; process/pipe/session group direct-owned, TERM/KILL/wait/reap và group0 trước ALLOW. Không ALLOW danh sách bị cắt.

Setup dùng một absolute10s từ `Request.connect`, gồm vendor check/chờ setup slot/DNS/mọi nhóm. DNS+TCP chỉ dùng end−1;1s reserve cho handoff/cleanup, **không bảo đảm TLS xong1s**. PolicyC nhóm tối đa4,2endpoint/nhóm,delay.25/interleave0,q≤2/reap.1; admission minimum pair1/single.6. MaxLive≤2 **mỗi connector registry**, không nói toàn proxy chỉ2socket khi nhiều tunnel đã thắng. Cả admitted set được kiểm trước socket đầu. Không reset deadline giữa nhóm; không fallback/retry khi admission/deadline/trace/library lỗi. Suffix chưa thử giữ UNKNOWN; group-cap test có2endpoint chưa thử, không coi chúng đã connect FAIL.

Trace RAM/request≤256rows/128KiB encoded; bounded16completion receipts, không quota lifetime chung. Socket/task/loop/helper/request có owner riêng; cleanup vẫn chạy khi trace open/write/flush/close lỗi. CONNECT200 cần DNS receipt/native exit0/reap/pipes/group/trace và library tasks/losers đúng. Sau shutdown/close, serve thread join đúng worker Thread object rồi mới phát completion accepted: marker trong thread không tự chứng minh thread đã thoát. Per-request CLOSURE_BARRIER giữ physical worker/socket evidence.

**Giới hạn cross-process:** proxy completion là kết quả kết nối/closure; chưa có transaction giữa proxy–media. Nếu observer lỗi sau khi tunnel đã chuyển bytes, không thể thu hồi bytes đã gửi. Fixture parent gate toàn proxy receipts sau child0 trước công nhận pipeline. Code bước này không thay media/worker để thêm side channel; chưa quảng cáo runtime application có thể rollback file theo một late proxy diagnostic. Reviewer cần chốt yêu cầu này trước nguồn/activation. TLS opaque; proxy không quan sát HTTP status/decoded body/CDN cause, số đó lấy ở media/origin fixture, không suy từ TCP winner.

## Môi trường và kiểm thực chạy

Target proxy Python **3.12.12** đo thực trong cached image **sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10**, OpenSSL3.0.18; public library version/signature được capture trong unit-5/capability.json. Không suy target từ3.11. Media dùng image cache **sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e**, bản3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/Cobalt pinned đã nghiệm thu; core versions gate chạy trong mỗi CLI. Không thay image hay dependency media.

Unit proxy/helper96MiB/.25, networknone/nonroot65534/rootfsRO/dropALL/NNP/privateIPC/no extra swap. Pipeline proxy+TLS fixture+helper **chung96MiB/.25**, media512MiB/.75, tổng runtime608MiB; generator512MiB dọn trước runtime cuối. Không nói mỗi process riêng96MiB. Internal network, không publish port, media/tmpfs/data riêng, OS timeout225s toàn harness và child33/183s ngoài phase30/180. Không đo peakRSS; state noOOM và caps enforce. Own container/network IDs/labels/remove/absence receipts từng lượt, không volume/prune/đụng main.

Giả lập chỉ ở DNS getaddrinfo rows và public loop.sock_connect destination→loopback; mọi raw row vẫn qua production guard. Production proxy/parser/tunnel/admission/IPC/public library/socket/selectors và TLS/HTTP Requests/urllib3 là thật. HTTPS origin fixture dùng stdlib SSL/HTTP server, cert/SAN/CA/key chỉ lab. Media override **public** Requests certificate/pool hooks để dùng CA fixture, CERT_REQUIRED/hostname verification giữ; không HTTPAdapter giả trong pipeline. Không nới production SSRF/TLS. Fixture key là key dùng một lần công khai trong namespace, không cookie/token/account/certificate thật của người dùng.

Lệnh PowerShell thực:

- `& 'D:\WED SNAP\labs\tiktok\photo-egress-step3\run.ps1' -Mode capability -Attempt 1`
- `run.ps1 -Mode unit -Attempt 1` rồi2,3,4,5 theo sửa wiring/thêm closure và packaging cuối.
- `& 'D:\WED SNAP\labs\tiktok\photo-egress-step3\pipeline.ps1' -Attempt 1` rồi2,3,4 theo lỗi fixture/chốt source cuối.

| Lượt | Kết quả/giới hạn thật |
|---|---|
| capability-1 | Exit0/Python3.12.12; trước mount vendor, library=NOT_MOUNTED_YET đúng thời điểm |
| unit-1 | Exit1/DNS_ERROR: harness thiếu DNS fixture env/PYTHONPATH cho helper. Có thử stdlib resolution hostname fixture trong networknone, không có đường ngoài; không coi là nguồn TikTok thử mới |
| unit-2 | Exit0/26ca trên port ban đầu |
| unit-3 | Exit0/34ca thêm library groups/cancel/legacy/fault handler; trước physical worker join refinement |
| unit-4 | Exit0/34ca sau physical thread barrier |
| unit-5 | **Exit0/noOOM,34ca trên toàn29file egress cuối**, sau full LICENSE/COPY packaging |
| pipeline-1 | Proxy readiness FAIL: uid65534 không đọc fixture key0600 tạo bởi uid1000; media nguồn chưa chạy; raw giữ, sửa quyền riêng key fixture |
| pipeline-2 | Exit0/photo2+2+1/TLS/JPEG, trước thread refinement/video probe |
| pipeline-3 | Exit0/photo2+2+1 + video analyze2 metadata, physical thread closure đúng; trước full license COPY cuối |
| pipeline-4 | **Exit0/noOOM trên29egress+29media file cuối**, all4proxy completions accepted/workerThreadClosed/clientClosed/loopClosed; photo4metadata+1JPEG, video2metadata; native media children0/0/0 |

Gate cuối: [unit34](evidence/tiktok-photo-egress-step3-20261015/unit-5/results.json), [TLS proxy](evidence/tiktok-photo-egress-step3-20261015/pipeline-4/proxy-result.json), [media phases](evidence/tiktok-photo-egress-step3-20261015/pipeline-4/media-result.json), [actual exits/UTC](evidence/tiktok-photo-egress-step3-20261015/pipeline-4/native.jsonl), [completion UTC/VN](evidence/tiktok-photo-egress-step3-20261015/pipeline-4/completion.json). UTC05:48:55/VN12:48:55 ngày15/10 là completion pipeline cuối, không giả thời gian mỗi phase bằng host tổng.

34ca gồm raw256dups/257/65unique/mixed/private/suffix/mapped/invalid/ordered/schema JSON/deadline/memory; real helper/IPC/oversize/malformed/PASS packet→native20/hang/cancel/reap; public HE pair winner maxLive2/loserclose/group2/epoch late-factory/cancel/pre-spawn budget/suffix reject/group4 suffix UNKNOWN;20request liên tiếp+3concurrent không quota lifetime hoặc owner chéo; registry/receipt/trace contradiction; full handler trace error403 không fallback, request mới200; trace I/O bốn loại không ngăn đóng socket; legacy YouTube và flag-off transport, domain scope.

Pipeline thật fixture có analyze photo0→fresh prepare0 chọn ảnh2:2+2metadataGET+1JPEGGET, prepare input1242B/output248B, two ffprobe0/full FFmpeg decode0/SHA **45cea83ba1889b4f948c9fca05932a47ff2bb92723dd8fa798fcf14149c51e00**. [JPEG thực qua proxy](evidence/tiktok-photo-egress-step3-20261015/pipeline-4/prepared-image.jpg). Video TikTok analyze0/duration2/formats qua cùng policy/TLS; không tải MP4 trong probe hẹp này. Không source/human visual/watermark PASS mới; mẫu5ảnh cũ đã accepted, không hỏi lại.

## Bàn giao tiếp

[Prompt nghiệm thu độc lập](evidence/tiktok-photo-egress-step3-20261015/NEXT_PROMPT.md). Kiểm admission chung8 và late-completion giới hạn trên, ownership/thread barrier, hard timeout/cleanup claims, deps/API/SHA/license và source cuối. Không tự chuyển sang UI/Taste, nguồn/cold/claim/reset/renew/retry hoặc activation/deploy. AUDIT/PROGRESS prepend đúng receipt nối audit bước2 và dispatch bước3; history/golden không sửa. Code/proxy offline PASS không phải main image đã build hoặc app/nguồn E2E accepted.
