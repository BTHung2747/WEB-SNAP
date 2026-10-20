# Photo app source executor — 15/10/2026

**PASS_SOURCE_EXECUTOR_PREPARED_OFFLINE_PENDING_REVIEW**. Successor `labs/tiktok/photo-app-source-executor/` có đường chạy nguồn thực được viết sẵn, không còn stub nguồn luôn từ chối. Lượt này chỉ chạy offline/import/default-deny/dry-run; sourceGrant=false, sourceExecutionStarted=false, sourceCalls=0. Chưa chạy external bridge, public DNS, TikTok/CDN, browser combined hoặc kiểm watermark tệp mới. Không sửa apps/shared, main/settings/Compose/env/schema, host hoặc dependency/image.

## Mã và ranh giới tái sử dụng

25 file successor: runner và16 file common (gồm source pins),8 file fixture riêng. API/BullMQ public Worker gọi nguyên production processJob/runAdapter/ProcessGroup/gate3b, photo adapter/core/Requests/Cobalt/FFmpeg hiện có. 128 đường dẫn source distinct giữ nguyên byte; exact SHA từng file ở `source-final.json`, từng tool ở `tool-final.json` trong evidence. Không parser/solver/HTTP engine mới, không install/build/pull. Lab glue cần thiết để tạo topology riêng, điều khiển một workflow, giới hạn consumer và thu diagnostics đã che dữ liệu.

Common `driver.ts` dùng target thật; `selection.ts` đối chiếu full summary/count5/order/dimensions/itemKeys/snapshot với historical expectation rồi lấy itemId/formatId mới từ API. `worker.ts` dùng durable wx job/phase, concurrency1/maxStalledCount0/maxStartedAttempts1/queueage10. `media_entry.py` reexec Python -I cùng PID/group rồi delegate core; `media.py` ghi native exit và diagnostics trước packet. `proxy_entry.py` dùng production egress.Server, `proxy_collect.py` quan sát actual owned broker context; không dùng global health thay phase proof. Callback không đổi quyết định transport. Hai child analyze/fresh prepare độc lập; signed URL/cookie nguồn trong RAM.

Nguồn chỉ mount common, không `/offline`, media_site, fake DNS/TCP/CA/body hoặc fixture ID/SHA. Isolated import thực tế kiểm14 module, hash/path; distro sitecustomize/apport43d811…8b1e đã phân biệt với fixture. TypeScript probe biên dịch cú pháp4 module, không là full typecheck. Ba Python entry và hai TS entry thiếu flag đều exit78 trước IO/network. Runner thiếu `-ExecuteSource` từ chối trước source pins/random secret/attemptdir/Docker; dry-run cũng không hiệu ứng phụ. Source128 pins được kiểm trước tạo attemptdir; test runner kiểm source/tool hash trước và sau. Đây là code pin, không phải hệ thống cấp quyền mới.

## Lệnh thực chạy và kết quả

Từ `D:\WED SNAP`, dùng PowerShell7:

```powershell
& ./labs/tiktok/photo-app-source-executor/run.ps1 -Mode imports -Attempt 5
& ./labs/tiktok/photo-app-source-executor/run.ps1 -Mode offline -Attempt 3
& ./labs/tiktok/photo-app-source-executor/run.ps1 -Mode source -Attempt 20
& ./labs/tiktok/photo-app-source-executor/run.ps1 -Mode source -DryRun -Attempt 20
```

Hai lệnh đầu actual0; lệnh source thiếu switch actual78, không source-20; dryrun0/resources0. Final offline3/imports5 cùng25tool hash. Happy job `a902e6d7-8e5f-4d21-b4ed-61c95d05c32d`: hai native child0/group0 → phase proof true → registry release, analyze2/freshmetadata2/JPEG1. Fixture JPEG248B/SHA `45cea83ba1889b4f948c9fca05932a47ff2bb92723dd8fa798fcf14149c51e00`,2ffprobe0/full decode0, native local HEAD không tạo lease/fullGET/Range206 đúng. Happy chỉ là ảnh xanh64x64 giả lập, không ảnh TikTok.

Missing-proof native0 nhưng gatefalse → failed/no prepare; changed-structure actual metadata khác dimensions/snapshot → dừng SELECTION/no prepare. Tổng fixture8metadata+1JPEG; không request nguồn. Consumer exit0 từng ca; API shutdown143 có chủ ý, app CLI0 và proxy0 được ghi riêng. Proxy listener/serve/origin đóng; own containers/networks0, cleanup offline3=2.3683336s <20s. Imports5 chỉ networknone/app512MiB.

Raw imports1/imports4 giữ lỗi quyền Docker pipe trước create; không dùng làm PASS. Imports2–3/offline1–2 là intermediate với hash trước; chỉ imports5/offline3 mở gate offline cuối. Không chạy lại matrix10/6/14 hoặc historical suite. `verify.ps1` chỉ đọc/hash/receipt, không chạy Docker hay runtime; manifest giữ full coverage cả raw FAIL và intermediate.

## Giới hạn và bằng chứng

Runtime800MiB = app512/proxy96/PG128/Redis64; CPU .75/.25/.25/.25, user nonroot/RO/dropALL/NNP/privateIPC/noextraswap/noports. Generator512/networknone chạy trước và đã gỡ, không cộng đồng thời. App/proxy media/tmpfs/pids giữ. Startup60/workflow250/queue10/local20/appcleanup20/Dockercleanup20/outer360; metadata30/prepare180/HTTPconnect≤10/read≤20, decode remaining−10reserve, item60 và byte caps giữ. Caps không chứng minh peak RSS.

Collector ≤512KiB/128boundary/32operations/64proxy rows; bỏ toàn URL pathname/query/header/cookie/ticket/nonce/cap/epoch/binding/message/repr/stack. Append boundary giữa hai child được lọc đúng requestIDs hiện tại: analyze2 và prepare3 không cộng lặp. Attempts/HTTP responses/decoded bytes khác actual wire GET (UNKNOWN); CONNECT khác GET. Thiếu/partial diagnostics fail/UNKNOWN. API general logger bị tắt trong lab vì có thể format stack; driver ghi status số quan sát và native API exit riêng. Không dùng suppression này làm bằng chứng chặng lỗi chưa đo được.

Source topology code: app/PG/Redis chỉ internal, proxy thêm bridge egress riêng; exact internal CIDR kiểm local và peer, secret mới RAM đã che trong Docker evidence. Code kiểm bridge chỉ proxy/member count và cấm fixture mount/env. **Topology hai mạng chưa thực thi/NOT_RUN**; import hoặc dryrun không chứng minh real DNS/CONNECT/TLS/source response. Source proxy serve exception chỉ fixed failure flag; không phát message/stack.

## Lượt nguồn sau review, chưa được chạy trong nhiệm vụ này

Lệnh chuẩn bị sẵn, chỉ sau nhiệm vụ nguồn mới của chủ và review bản hash này; không cần sửa code:

```powershell
& ./labs/tiktok/photo-app-source-executor/run.ps1 -Mode source -ExecuteSource -Attempt 1
```

Canonical `https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421`, index2, một job/2child/≤2+2+conditional1sourceGET; HEAD/redirect/retry nguồn0. Native local HEAD/fullGET/Range tách nguồn. Fresh full summary khác/UNKNOWN → dừng trước prepare. Historical SHA index2 `62308e76366aece0368f8c326f6430669fa4601ff1d963bb99378507091f5a8b` chỉ đối chiếu: khác thì giữ tệp evidence và dừng NEEDS_REVIEW, không retry. SHA khớp vẫn cần review tệp mới; human accepted5ảnh cũ không hỏi lại hoặc tự áp cho tệp mới. Không ảnh khác/audio/preview/browser/gallery/main/deploy; không reuse/reset/renew claim/cold/grant cũ. Nếu source-1 đã có thì runner từ chối reuse; không tự tăng Attempt để thử lại.

Evidence: `docs/evidence/tiktok-photo-app-source-executor-20261015/`; NEXT_PROMPT yêu cầu kiểm độc lập rồi trình một hành động nguồn cụ thể. Chưa gọi nguồn hoặc tuyên bố source/app E2E/watermark PASS.
