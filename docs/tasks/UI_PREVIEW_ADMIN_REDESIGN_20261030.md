# Giao diện tải, xem trước và quản trị — 30/10/2026

## Yêu cầu hiện hành của chủ

Sau phân tích link, hiển thị xem trước video hoặc từng ảnh để người dùng nhận ra nội dung đang tải. Hai ảnh tham khảo chỉ minh họa thumbnail/tiêu đề/nút tải và lưới ảnh; **bỏ lựa chọn tải có logo**, không sao chép mọi chức năng trong ảnh thành yêu cầu mới. Làm lại giao diện web bớt trống trải, đẹp và rõ hơn; áp dụng Taste Skill đã cài cho cả trang tải và quản trị. **Sau khi sửa xong phải chụp toàn bộ các màn hình chính cho chủ.** Không gọi bản mockup/fixture là web production đã sửa.

## Đánh giá trước sửa của root

Đã đọc AGENTS, CURRENT, skill và component hiện hành. CUA hiện đã truy cập được tab IAB `https://savlivo.online/`: root xem full-page trang tải và trang đăng nhập `/admin`, không đăng nhập hoặc đổi settings. Desktop dashboard trước đây trong ảnh chủ gửi chỉ là tham khảo lịch sử, không coi đã đọc phiên admin hiện tại. Screenshot hiện là viewport hẹp khoảng583px; chưa là audit1440px. Sau audit trả tab về trang tải.

- Brand hiện hành: nền`#f7f4ee`, mặt`#fffefa`, mực`#29241f`, accent đỏ đất`#b63d18`, font Segoe UI, logoWED SNAP. Giữ nhận diện và routes, cải thiện hierarchy/spacing/density/controls; không tự đổi framework/thư viện/fontngoài. Bộ tải tối đa1080p/copy nguồn và shortlink đang có patch local chưa deploy.
- Trang tải có hero, ô link, results rồi hướng dẫn/FAQ. Khoảng cách lớn và kết quả tách rời khiến thao tác kéo dài; chỉ số/nhãn phụ lặp, thiếu hình nhận diện ở TikTok. Hướng sửa: một vùng thao tác liền mạch, kết quả có media rõ ở gần ôlink; giảm khoảng trống và rút gọn hướng dẫn, responsive giữ dễ chạm.
- Admin đang dùng control/table xanh khác accent trang chính, nhiều trường dài và copy hướng dẫnREADME trong login. Cần đồng bộ tokens, header/nav/metric/table rõ, nhóm settings có tiêu đề/đơn vị/hướng dẫn ngắn, form/campaign editor dễ dùng. Giữ chính xác API/auth/statistics/settings semantics, không bịa dữ liệu hoặc tự đổi giá trị/cấu hình thật.
- Định hướng theo skill: công cụ tải cho người dùng phổ thông, gọn và dễ nhận diện nội dung; giữ accent thương hiệu, dùng React/Vite/Tailwind hiện có. DESIGN_VARIANCE5/MOTION_INTENSITY3/VISUAL_DENSITY5 cho trang tải; admin ưu tiên density và accessibility phù hợp, không áp ép mẫu landing. Motion nhỏ cho state/result/control và reduced-motion, không thêm package hoặc hoạt ảnh liên tục.

## Kết quả phân tích cần có

1. Video: thumbnail thật của đúng bài, tiêu đề, loại nguồn/thời lượng khi có, lựa chọn chất lượng nguồn≤1080p và hành động chuẩn bị/tải native theo trạng thái hiện có. Không bịa poster, viewcount/quality/watermark. Không thêm MP3 chỉ vì ảnh tham khảo có nútMP3. Ảnh không có sẵn thì báo rõ, không ảnh khác thay thế.
2. Bài ảnh: lưới thumbnail theo đúng thứ tự, đánh số và kích thước khi biết, chọn ảnh có trạng thái rõ, nút chuẩn bị/tải ảnh đúng selection hiện tại. Giữ **một ảnh/job** và cơ chế analyze mới khi chọn ảnh khác sauprepare; không tự thêm tảiZIP/tải tất cả/song song hoặc tạo nhiềujob. Preview không phải tệp tải chính và không đổi chất lượng tệp gốc.
3. Mọi idle/analyzing/selectable/queued/preparing/ready/failed/cancelled/expired còn đủ, lỗi/loading/thiếu thumbnail cófallbackhonest. Tách session–job–transferlease/CSRF/native link như cũ. Sponsored có nhãn/đóng được khi phù hợp, không phủ nút tải.

## Chia việc và quyền sở hữu file

### Chat giao diện hiện có — `01a13fb6-b8a9-7e50-92c9-81498edea16d`

Sở hữu **`apps/web/`** và phần bàn giaoUI trong tài liệu này. Đọc `.agents/skills/design-taste-frontend/SKILL.md` trước sửa. Audit source/layout trước rồi triển khai Home + result/video/photo + adminlogin/dashboard/campaigns/editor/settings và các CSS liên quan. Giữ code quality/default/1080 hiện có, không ghi đè patch backend. Giữ dependencies và React/Vite/Tailwind; không cài design system, không bổ sung MP3/ZIP/watermark option hoặc quảng báFB/X đã bật. Backend mới được mô tả ở phần contract bên dưới, không tự nối signedCDNURL vào`img`.

Có thể dùng fixture/API doubles sẵn có để dựng các trạng thái và dữ liệu minh họa, chỉ ở dev/harness, không bịa dữ liệu production. Ghi rõ screenshotfixture. Chỉ kiểm frontend delta, keyboard/focus/narrow/reducedmotion/loading/error và lifecycle liên quan; không rerun suite nguồn/lab lịch sử. Chụp toàn trang ít nhất: trang đầu, kết quảvideo, kết quảảnh, adminlogin, dashboard, campaigns/editor, settings; bản desktop khoảng1440 và các màn hình chính ởmobile390. Màn dài chụpfullPage, gallery có thể thêmảnhchi tiết. Lưu screenshot thậtPNG/index theo đường dẫn tuyệt đối đểroot hiển thị, không vẽ ảnhgiả thay screenshot.

Chỉ dùng CUA/browser được cho phép; đã xác nhận IAB dùng được. Không đổi settingsadmin production, không yêu cầu/mượn mật khẩu trong chat hoặc chụp secrets. Dùng local APIfixture cho adminloggedin khi cần. Không deploy/push/CI hoặc build/pullimage. Buildweb/typecheck cần thiết được phép, tuần tự; dùng cachetools hiện có. Hoàn tất handoff gồm files, lệnhactual, ảnhPNG/index, giới hạn và contractbackend chưa có. Không sửaCURRENT.

### Code tay to — `01a11517-a7fc-7e02-ae6c-80cfe5436ba0`

Sở hữu backend preview ở `apps/media/`, `apps/api/`, `apps/worker/`, `packages/shared/`, `apps/egress/` **chỉ khi thật sự cần**, cùng phần bàn giao backend trong tài liệu này. **Không sửa`apps/web/`** để tránh đụng chatUI. Không mở lại shortlink/quality test đã đạt chỉ vì taskmới; handoff trước ở`TIKTOK_SOURCE_QUALITY_20261030.md` cần giữ. Bổ sung thumbnailvideo TikTok thật và preview từngảnh theo dữ liệu nguồn qua transport hiện có; ảnhthu nhỏ phục vụpreview được phép, tệp tải chính vẫn nguyênbyte/stream.

Trước khi viết, kiểm thư viện/metadatathumbnail hiện có: genericYT đã ghi`preview`, TikTokvideo chưa lấy poster, ảnhphoto chỉ códescriptor khôngpreview. Dùng parser/HTTP/FFmpeg hiện có theo API chính thức, không dependency mới hoặc customimageengine. Chốt gọn phương án lấythumbnail/caps/cache/cleanup rồi code+offline delta. Nếu nhiềuảnh cần tăng ngân sách request/source đáng kể, ghi rõ và gửi phương án rootreview trước chạy nguồn; không âm thầm nới GET/CONNECT/deadline/bytes toàn hệ thống hay tải toàn bộ ảnh gốc chỉ để làm thumbnail.

## Contract tích hợp preview bắt buộc

- Public UI chỉ nhận **same-origin URL của API** gắn job/ownership/index hoặc ID opaque; không signedCDNURL/cookie/redirectURL/hash nguồn bí mật/base64HTML từ nền tảng. Mọi fetchnguồn đi qua egress/SSRF/DNS/TLS/size/deadline/closeguards. Không proxy URL tùyý do client đưa.
- Video tái dùng jobpreview route khi phù hợp. Ảnh cần contract rõ theoindex/selection/snapshot của bài: không nhầm ảnh khi reorder/freshmetadata đổi. Preview ràngbuộcphiên, hết hạn/cancel xóa cùngjob, chốngpath/symlink, MIME/magic/dims/bytes đúng, no-store/private. Không renderHTML/SVG từ nguồn. Không giữ source secrets qua selectable.
- Coder bàn giao đề xuấtfield/route cụ thể vào tài liệu này; root gửi cho chatUI để dùng. Frontend có thể dùng typed optionalpreview vàfallback để triển khai visual trước, không kết luận featurelive khi API chưa tích hợp. Nếu schema/contract cần đổi, làm đồng bộ/API/worker/media, không sửagolden lịch sử đểche.
- Chuẩn bịthumbnail không được chặn download hoặc gây tải nền vô hạn: có tổngrequest/bytes/disk/timecap, lazy/on-demand hoặc cache đúngscope nếu cần. Giữ máy8GB/dev và4GBVPS/concurrency1. Đo đủ nhỏ cho component đổi, không thêm observer/framework/testmatrix khôngcần.

## Nghiệm thu và dừng sau giao việc

Contract sớm đã chuyển chatUI: video`Job.previewUrl` nullable giữ route cũ, photo`format.previewUrl?: string|null` cùngorigin`/api/v1/jobs/:job/preview/:formatId`, JPEGcache-only/no-store/ownercheck. UI sở hữutypes vàlazy/fallback404/null. Backend được code/kiểm **offline** batchoptional có tổng8MiBdecoded,512KiB/response,128KiB/JPEG,16Minputpixels,6ssoft trongabsolute30s; không tự bậtnguồn/profile52–54 hoặcproduction. Optionalfail không được poison phaseproof của metadata/download, không bỏguard để vượt; phải chứng minh closure/accounting trướcwire. V1photo snapshot hiện chỉstructural, không gọi làcontentidentity; ảnh đãpreview cầnIDnguồnđãxácminh hoặc normalizedcontentdigest so vớifileprepare trongcaps, khôngthêmGET/khôngsohaiảnhlossykhácchuẩn. Phần chưađápứng phảighi integrationblocked, không bịaPASS. Cácđiểmnày đã gửi code tay to, chưa phải nghiệmthu implementation.

Root xemdiff/kết quả và ảnh thật sau bàn giao, không lặp bộtest mặc định. Việc xây/chụp bản mới không đồng nghĩa đãdeploysavlivo.online. Phát hành sau review và luồng preview/download thật cần thiết. Theo chỉ thị mới của chủ: **giao xong và không còn việc độc lập thì dừng lượt**, không wait/poll lặp hoặc tự mở thêm vòngtest trong khi chờ.

Đã giao và nhận trạng thái chạy bằng một snapshot tức thời: chatUI turn`01a18c2f-0ac0-7411-8b31-9fc59d8aa9f0` inProgress, xác nhận auditảnh/source, sửaHome/admin, fixture/build/screenshot; backendpreview turn`01a18c2f-bfd0-7272-bd98-14fe54feafd9` inProgress. Root trả tabuser về`https://savlivo.online/`, không đăng nhập/đổiadmin. Chưa có handoff/ảnhsau sửa/deploy. Shortlink coder báo hoàn tất offline7Python+4TS/focusedsuccessor, chưa reviewroot/pháthành trong nhiệm vụ này. Root dừng sau giao, không chờ/poll lặp.

## Backend preview contract — đề xuất triển khai30/10

- Video giữ `status.previewUrl: string|null` cùng origin `/api/v1/jobs/:jobId/preview`.
- Photo mỗi `status.items[].formats[]` thêm optional `previewUrl: string|null`, URL cùng origin `/api/v1/jobs/:jobId/preview/:formatId`; formatId đã có index/snapshot. Không dùng sourceCDNURL trong `img`, không gửi cookie/query nguồn.
- URL chỉ đọc cache JPEG đã tạo trong job lúc analyze; GET không fetch nguồn, tạo job hoặc retry. UI có thể dùng `loading=lazy`, fallback khi null/404. Owner/session, job state/expiry và formatId/snapshot phải hợp lệ trước open; private/no-store/nosniff, không HTML/SVG/path tùy ý/symlink. Preview không phải tệp tải native, không phát sinh transfer lease của download.
- Cache/thumbnails optional: thiếu hoặc hết quota thì null/404 honest, không chặn metadata/select/prepare. Xóa cùng thư mục job theo lifecycle hiện có; route từ chối ngay cancelled/expired/failed. Tệp tải chính và một ảnh/job giữ nguyên.
- Nguồn request mới cần profile riêng, không nới canonical/short/prepare profile cũ. Metadata private hiện có URLs ảnh gốc chứ chưa chứng minh có thumbnailfield; không tự chế CDNquery. Root đã duyệt **code/offline** cho video1poster, album≤50attempts nhưng tổng8MiBdecoded/512KiBresponse/soft6s trong analyze30s, outputJPEG≤128KiB/tổng≤8MiB. Đây chưa là quyền gọi nguồn hoặc bật trên main.

## Bàn giao backend preview30/10 — offline, chờ review

**Đã triển khai:** `apps/media/src/tiktok/preview_cache.py`, nhánh analyzevideo/photo, `photo_proxy.py`; `apps/worker/src/adapter.ts`, `proxy-phase.ts`; `apps/egress/src/tiktok_policy/control.py`; `apps/api/src/services/preview-cache.ts`, `jobs.service.ts`, `controllers/jobs.controller.ts`. Fixture ở `labs/tiktok/source-quality-offline/test_preview.{py,cjs}`, dùng thêm mode `preview` của runner cũ. Không sửa `apps/web/`, CURRENT, DB/schema, dependencies, image hoặc cấu hình main trong phần việc này.

- Video lấy một URL poster từ `info.thumbnails` của extractor đã ghim; photo dùng URL ảnh riêng đã có từ picker Cobalt, giữ thứ tự format/index/snapshot. Không chế URL thumbnail hoặc viết parser mới. Ảnh quá lớn/không đủ quota thì fallback, không tải mọi original đầy đủ để làm preview.
- Mặc định **tắt**, chỉ khi worker và egress được cấp `TIKTOK_PREVIEW_ENABLED=1` trong một nhiệm vụ sau. Sau metadata hợp lệ/session đóng, child gửi count đã chọn qua pipe; parent tạo profile `tiktok-preview-cache`, selection `pv1_count_binding` ràng buộc job/token/nonce/URL đầu vào. Canonical2/short4 và prepare profiles không đổi; CONNECT đếm riêng với GET, capCONNECT bằng số candidate đã chọn (video1/photo≤50). Không cấp52/54 cho mọi analyze và không cấp nguồn trong lượt này.
- Preview có capability/proof riêng. Child chỉ ghi JPEG và `previews.pending.json`; parent đợi nativeexit0/group0, mandatorymetadataACCEPTED rồi optionalACCEPTED mới link/unlink không ghi đè thành `previews.json`. Redirect/byte/MIME/timeout/proofreject hoặc nativeexit20 đều không xuất bản cache. Optional lỗi được dọn và giữ metadata hợp lệ; cleanup/group chưa xác nhận vẫn fail closed theo guard hiện có.
- Quota optional:≤512KiB/response,≤8MiBdecoded tổng (một byte phát hiện overflow theo reader cũ),≤50GET/không retry/redirect,≤16Minputpixels; JPEG320×320 có đệm giữ tỉ lệ,≤128KiB/ảnh/tổng≤8MiB, index≤24KiB. Quota6s mềm nằm trong analyze30s: chỉ mở khi parent còn≥9s; capability hết hạn≤min(now+8s,analyzeEnd−1s), fetch/normalize dừng≤min(now+6s,capEnd−2s). HTTP helper fork riêng dùng Session mới saufork, không có subprocess decoder con; parent kill/reap khi body bị chặn. Chỉ fork khi Python threadcount và `/proc/self/task` đều1, nếu không thì không có preview. FFmpeg subprocess cũng dùng phần deadline còn lại; không nới connect/read hoặc thay HTTP/TLS/backend.
- API cache-only theo contract ở trên; xác thực phiên/sở hữu, state/expiry và format đang thuộc bài trước đọc. File/index không symlink, bytes/SHA/JPEGmagic đúng; private/no-store/nosniff. Không có sourceURL/token/cookie trong manifest/DB/publicdata; GETpreview không gọi nguồn/không tạo transferlease. Cache đi cùng thư mục job và cleanup lifecycle cũ; cancelled/expired/failed bị từ chối ngay. Pending không được phục vụ.
- Photo lưu SHA256 của RGB320×320 chuẩn hóa **trước** JPEG lossy vào manifest nội bộ. Freshprepare dùng cùng FFmpeg normalization trên JPEG gốc đã qua full contract, so trước publish ảnh tải, không thêmGET; cùng kích thước nhưng khác pixel bị từ chối và dọn ảnh lượt đó. Không so JPEGpreview lossy với ảnh gốc. Không có preview thì giữ structuralV1 + UNKNOWNcontentidentity; đây không phải proof toàn bộ nội dung/nguồn hay watermark. Hai bản JPEG cùng nội dung nhìn gần giống nhưng pixel khác có thể fail closed; nguồn thật chưa kiểm. Tệp ảnh chính không resize/reencode.

**Lệnh thực chạy:** `& .\labs\tiktok\source-quality-offline\run-pair.ps1 -Mode preview` bằng image cache `sha256:5b994d8c9c4ed29ce550f0d60539a8071a2f2e233d9c840013c45802c08a7ba3`. Một container networknone/user1000/rootfsRO/capdropALL/no-new-privileges/privateIPC/CPU0,75/RAM512MiB/swap512MiB/pids96, chạy tuần tự. Gate cuối gồm11nhóm Python +11nhóm parent/API và `tsc -p tsconfig.json --noEmit`, actualouter/container0;25pins khớp sau chạy. `ProcessGroup`/child/extractor/Cobalt/FFmpeg/APIcache thật; DB/sourceHTTP/proofchannel là doubles, không phải nguồn/TLS/SSRF end-to-end mới.

**Evidence chuẩn:** [gate cuối](../../lab-runs/tiktok-quality-preview-offline-20261030-bceec901a8294e95bd87f2b9f21423cd/final-coverage.json), [Python](../../lab-runs/tiktok-quality-preview-offline-20261030-bceec901a8294e95bd87f2b9f21423cd/preview-python-result.json), [parent/API](../../lab-runs/tiktok-quality-preview-offline-20261030-bceec901a8294e95bd87f2b9f21423cd/preview-ts-result.json), [nativeexits](../../lab-runs/tiktok-quality-preview-offline-20261030-bceec901a8294e95bd87f2b9f21423cd/native.jsonl), [cleanup](../../lab-runs/tiktok-quality-preview-offline-20261030-bceec901a8294e95bd87f2b9f21423cd/cleanup.json). Thời gian thực17:21:46–17:22:31VN (10:21:46–10:22:31UTC); cgrouppeak353935360B≈337,54MiB/pidspeak41. Blockingbody5s bị helperkill/reap sau0,20266s với deadline0,2s; không còn child. Fixture đã qua metadata→preview→freshprepare/fullJPEGdecode/originalSHA; album2ảnh đúng thứ tự/chọnảnh2; same-size contentchange bị từ chối; nativePASS→exit20 và cancelSIGTERM không xuất bản cache. ProofPENDING bị chặn theo poll/deadline riêng, không làm metadataFAIL. Không khẳng định đã đợi đến expiry vì pollbudget có thể dừng trước.

Lượt đầu `7417cf18…1749d0` giữ nguyên: **10nhómPython+8parent/API** đã đạt nhưng typecheckexit2 vì nullable stdout; đã sửa. Successor `0d27d460…627252` đạt10+11/tsc trước hardening helper; gate cuối trên thay thế phạm vi runtime, không sửa evidence cũ. SourceGET thực0, cleanup/scopedabsence0 và không OOM. Không chạy lại suitequality/shortlink/Youtube lịch sử.

**Nguồn API đúng phiên bản/lý do:** [FFmpeg5.1.9 scale/pad](https://github.com/FFmpeg/FFmpeg/blob/n5.1.9/doc/filters.texi), [FFmpeg CLI](https://github.com/FFmpeg/FFmpeg/blob/n5.1.9/doc/ffmpeg.texi), [ffprobe](https://github.com/FFmpeg/FFmpeg/blob/n5.1.9/doc/ffprobe.texi); [Requests2.34.2 HTTPAdapter.send](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py); [yt-dlp2026.08.19 TikTok thumbnails](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/extractor/tiktok.py); [Python3.11 Process/Pipe/kill/join và fork warning](https://docs.python.org/3.11/library/multiprocessing.html). Tái dùng parser/HTTP/decoder đã ghim, chỉ tự nối quota/capability/cache và HTTP-only deadline helper vì readtimeout của thư viện không là absolutebodydeadline. Fork chỉ trong Linuxchild đơn luồng và không tái dùng Session đã có; không dùng private socket/TLS patch hoặc dependency mới.

**Chưa làm/bước tiếp:** root review diff/pins/gate và chuyển contract cho UI; UI sở hữu fixture/screenshots, backend không tạo screenshot thay UI. Chưa test preview với TikTok/CDN/own-egress thật hoặc contentdigest trên ảnh nguồn, chưa bật flag/apply/build/deploy. Luồng tải gốc/videoYoutube không đổi trong delta này, không có claim kiểm nguồn mới. Chỉ sau review/quyền riêng mới chọn một mẫu nguồn, đo actualGET/decodedbytes/closure/lifecycle, xác nhận preview đúng với ảnh tải gốc và nguồnshort/canonical hiện hành; không tự chạy trong lượt này.

## Bàn giao UI sáng — 30/10

Home/video/photo và admin login/dashboard/campaigns/editor/settings đã sửa trong `apps/web/`, giữ dependencies, patch source-quality có sẵn và lifecycle/native download. Photo dùng optional preview cùng origin, fallback/lazy và selection chung; mobile có điều khiển theo cuộn. Chưa deploy hoặc thay dữ liệu production.

Bàn giao chuẩn: [frontend/HANDOFF.md](../evidence/ui-preview-admin-redesign-20261030/frontend/HANDOFF.md). Có16 PNG fullPage CUA desktop1440/mobile390, [gallery](../evidence/ui-preview-admin-redesign-20261030/frontend/index.html), manifest kích thước, request fixture và kết quả trạng thái. PNG chuyển từ JPEG CUA, giữ nguyên decoded pixels; tất cả có nhãn dữ liệu minh họa. Typecheck/build frontend và diff-check đạt; keyboard/selection/disabled/null404/narrow đã kiểm fixture. Reduced-motion mới được review CSS, chưa runtime emulation. Backend preview/download nguồn thật chưa nghiệm thu, không dùng ảnh fixture làm bằng chứng featurelive. Không sửa CURRENT; dừng sau bàn giao.

## Review của root và kế hoạch sửa thiết kế — 30/10/2026

### Phạm vi và kết luận

Chủ yêu cầu kiểm chứng, nhận xét giao diện còn đơn điệu/một màu/trống và **lập kế hoạch trước khi code tiếp**. Root đã trực tiếp xem đủ 16 PNG trong gallery bàn giao, đọc `MediaPreview.tsx`, các đoạn render Home, CSS Home/admin, trạng thái fixture và manifest ảnh; đối chiếu dependencies và phạm vi diff. Đây là review bản build cục bộ có API double, không phải kiểm preview TikTok hoặc tài khoản admin production.

Nhận phần tiến bộ của UI: có khung nhận diện video/ảnh, gallery chọn một ảnh, cùng-origin preview guard, fallback null/404, khóa lựa chọn sau prepare và native download anchor. Bàn giao của chat UI báo typecheck/build exit0, keyboard/selection/mobile đạt; root tái dùng kết quả đó, không chạy lại build hoặc bộ test. Root không xác nhận mọi lifecycle/backend đã đạt chỉ từ ảnh và báo cáo này. Preview backend đã có bàn giao offline riêng ở trên, chưa được root nghiệm thu end-to-end; flag mặc định tắt, chưa deploy.

**Chưa chốt nghiệm thu thẩm mỹ.** Bộ ảnh hiện đủ dùng làm mốc trước sửa. Không phát hành bản này như kết quả cuối của yêu cầu “bớt đơn điệu, trống trải”.

### Finding từ ảnh và mã hiện hành

| Mức ưu tiên | Quan sát cụ thể | Tác động / hướng sửa |
| --- | --- | --- |
| P1 trải nghiệm | Home luôn giữ nguyên hero lớn và form dù đã có kết quả (`Home.tsx`, `.hero`). Ảnh video mobile đặt preview khoảng sau 740px chiều cao, nút chuẩn bị còn sâu hơn. | Chuyển sang bố cục gọn khi có job; nội dung và hành động trở thành vùng chính. Không chỉ tăng cỡ chữ/đổi màu. |
| P2 thị giác | Nền kem, mặt gần trắng, viền be và đỏ đất lặp từ hero tới FAQ/admin, khác biệt sáng tối yếu. Trạng thái idle thiếu hình ảnh hoặc đồ họa đặc trưng. | Giữ logo/accent, bổ sung mảng than đậm và vùng nền nhạt có chủ đích, minh họa chức năng nhẹ. |
| P2 bố cục | Ảnh03: gallery nằm trong cột trái, cột phải chỉ có vài control; phần dưới cột phải trắng lớn. Video cũng có poster lớn hơn lượng thông tin đi kèm. | Video dùng poster theo tỷ lệ thực với chiều cao giới hạn; gallery dùng toàn bề ngang và thanh thao tác ngắn. |
| P2 khả năng đọc | Nhãn quality nối codec, tiếng, 1080p, mặc định, cao nhất và kích thước vào một option. Ảnh02/10 cho thấy nội dung bị cắt trong select. Chữ phụ nhiều chỗ chỉ10–12px. | Tách thông tin bổ sung thành badge/dòng mô tả ngoài select; tăng chữ phụ hữu ích lên13–14px. Chỉ hiển thị chất lượng từ API. |
| P2 mobile | `.photo-selection .selection-info` sticky cả tiêu đề, select, ghi chú và nút, kèm `scroll-margin-top:340px`. | Chỉ ghim thanh hành động ngắn, giữ không gian xem ảnh và focus. Chưa kết luận lỗi che focus runtime; cần kiểm đúng điểm này sau sửa. |
| P2 admin | Trang quản trị vẫn dùng khung trang giới thiệu, header cao và nhiều thẻ cùng kiểu. Dashboard chưa làm nổi bật lỗi/trạng thái; cấu hình mobile cao2844px trong bộ ảnh. | Bố cục quản trị riêng, điều hướng rõ, bảng/KPI gọn, nhóm form và đơn vị dễ đọc. Không thêm biểu đồ thiếu dữ liệu. |
| Giới hạn bằng chứng | Fixture lặp cùng ảnh cho các vị trí1–4, ảnh5 cố ý404. | Đủ xem layout/fallback, chưa chứng minh nhận diện đúng từng ảnh nguồn. Lượt visual sau dùng các ảnh minh họa khác nhau có quyền sử dụng; vẫn ghi fixture. |

### Hướng thiết kế đề xuất

Đọc brief: công cụ tải nội dung phổ thông, cần hình ảnh làm trọng tâm và thao tác nhanh; admin phục vụ vận hành. Áp dụng Taste Skill đã cài theo redesign có thay đổi bố cục, giữ nhận diện và nội dung sản phẩm. Dials đề xuất: trang tải variance6/motion3/density6; admin ưu tiên density7, motion2. Đây là kế hoạch, chưa là lệnh triển khai.

- Giữ WED SNAP, logo và đỏ đất `#b63d18` cho hành động chính. Nền sáng sạch, mặt trắng rõ hơn; dùng than đậm `#252a2e` cho một vùng nhận diện và điều hướng admin, nền cát nhạt cho hướng dẫn. Màu trạng thái thành công/cảnh báo/lỗi có chữ và icon, không chỉ phân biệt bằng màu. Kiểm tương phản trước chốt token cuối.
- Typography vẫn dùng font hệ thống hiện có. Tiêu đề có nhịp rõ, nội dung14–16px, chữ phụ13–14px; hạn chế nhãn IN HOA nhỏ. Radius8–14px và bóng nhẹ chỉ tại vùng thao tác chính. Không bo/đổ bóng mọi khối giống nhau.
- Trạng thái chưa nhập có minh họa SVG/CSS nhỏ về đường dẫn → video/ảnh → tệp, nằm trong vùng giới thiệu, không cản form. Không giả thumbnail, số lượt tải hay dữ liệu nguồn. Tái dùng icon/CSS trong repo, không cần thư viện/ảnh stock/dịch vụ mới.

### Bố cục cần sửa theo màn

1. **Home ban đầu:** header gọn; tiêu đề và form tạo một vùng thao tác tập trung. Khung nhập rộng khoảng760–860px ở desktop, CTA rõ, nền tương phản với vùng xung quanh. Đồ họa chỉ hỗ trợ nhận diện. Bỏ khối empty-state riêng nếu chỉ lặp lại lời hướng dẫn; gộp vào công cụ. Giữ anchor/copy pháp lý và trạng thái nền tảng thật. Hướng dẫn3 bước thành dải ngắn, FAQ thấp hơn, không dùng nhiều khối rỗng để lấp trang.
2. **Sau phân tích:** thu phần giới thiệu thành một dòng, ô link thành hàng gọn; đưa vùng kết quả sát dưới. Video: poster khoảng240–320px rộng trên desktop, giữ `object-fit:contain`, chiều cao tối đa hợp lý cho video dọc; cạnh đó là tiêu đề, thời lượng, quality ngắn, badge thông tin và một CTA theo trạng thái. Không giữ hero lớn phía trên kết quả. Mobile ưu tiên tiêu đề/preview/quality/CTA, không buộc đi qua toàn bộ phần quảng bá lần nữa.
3. **Bài ảnh:** tiêu đề/count ở trên, gallery dùng bề ngang chính; grid4 cột khi đủ rộng,2 cột mobile, không ép tỷ lệ ảnh gốc vào khung khiến khó nhận diện. Đánh số, dấu chọn và focus rõ. Thanh hành động hiển thị ảnh đang chọn và nút chuẩn bị/tải; mobile chỉ ghim phần ngắn khoảng80–112px, ghi chú không sticky. Giữ một ảnh/job và cùng selection/idempotency hiện tại; chưa thêm ZIP/tải tất cả.
4. **Admin:** desktop có điều hướng trái khoảng200–220px với đúng Tổng quan/Quảng cáo/Cấu hình, nội dung nền sáng và header thấp. Mobile chuyển thành điều hướng ngang; không tạo route/tính năng mới. KPI gọn, số có thứ bậc, bảng lỗi/trạng thái có badge và giải thích dễ hiểu, vẫn giữ mã lỗi khi cần. Không tự dựng chart/health metric mới.
5. **Admin login, chiến dịch, cấu hình:** login gọn với vùng thương hiệu tương phản; chiến dịch gom bộ lọc thành toolbar và editor rõ ranh giới. Cấu hình giữ đủ15 trường và nguyên payload/default; thêm cách đọc MiB/GiB/phút ở dòng trợ giúp trong khi đơn vị nhập/API giữ nguyên. Giảm padding lặp, giữ nhóm fieldset và nút lưu dễ tìm. Không tự sửa settings production hoặc thêm cơ chế xác thực mới.
6. **Chuyển động:**150–220ms cho hover/focus/thay đổi panel, chỉ opacity/transform nhẹ; không vòng lặp nền hoặc thêm thư viện. Reduced motion phải được kiểm runtime sau sửa.

### Thứ tự làm và cổng đủ dùng

1. Làm bản bố cục đầu tiên cho Home idle + video result và admin dashboard, desktop/mobile. Xem ảnh các màn này trước để xác nhận hướng mới đã khác rõ; chưa mở vòng hoàn thiện tất cả nếu vẫn chỉ đổi màu.
2. Áp dụng cùng token vào gallery/login/chiến dịch/editor/settings và các trạng thái còn lại. Giữ hooks/lifecycle/auth/CSRF/preview guard/native download; chỉ sửa phần trình bày và điều hướng thị giác trong phạm vi này.
3. Chỉ kiểm delta: một typecheck/build frontend cuối; smoke fixture chọn đúng ảnh → khóa sau prepare → native link, fallback404/null; keyboard/focus, narrow viewport và runtime reduced motion. Không lặp test nguồn/backend đã đạt. Nếu tìm thấy lỗi mới, kiểm đúng lỗi đó.
4. Chụp fullPage các8 màn ở1440×900 và390×844, thêm một ảnh vị trí cuộn thanh hành động mobile. Input/CTA ở màn đầu Home; sau analyze vùng kết quả và hành động chính dễ tới ngay. Mobile không tràn ngang trang hoặc che control/focus. Nhãn quality không mất thông tin cần quyết định. Bộ ảnh minh họa phải phân biệt được các vị trí, không lặp một ảnh để coi là kiểm đúng nội dung.
5. Review thiết kế bằng ảnh trước/sau và luồng thao tác. Backend preview thật/activation/release là bước riêng sau review tương ứng; ảnh fixture không thay cho bằng chứng đó. Lượt này không chạy nguồn, bật flag, build image, push hoặc deploy.

**Trạng thái cuối lượt:** hoàn tất review UI có giới hạn và kế hoạch sửa; chưa sửa mã ứng dụng hoặc giao vòng code mới. Root cập nhật CURRENT rồi dừng.

## Chủ giao triển khai thiết kế sau review — 30/10/2026

Chỉ thị mới: “áp dụng skill uiux đã dc cài đặt để thiết kế đi nếu bạn cảm thấy nó chưa phù hợp bạn cũng có thể tự chọn skill khác”. Đây là quyền triển khai kế hoạch thiết kế ở trên, thay trạng thái chỉ lập kế hoạch của lượt trước.

Tiếp tục dùng `.agents/skills/design-taste-frontend/SKILL.md`: phù hợp redesign trang tải, áp dụng chọn lọc cho admin theo AGENTS; chưa có nhu cầu thêm skill hoặc dependency. Định hướng: công cụ tải nội dung cho người dùng phổ thông, hình ảnh làm trọng tâm, thao tác gọn, phân mảng sáng/than đậm rõ và giữ logo/accent thương hiệu. Yêu cầu lần này là thay đổi bố cục và độ tương phản nhìn thấy rõ, không dừng ở đổi màu hoặc thêm khoảng cách.

Giao chat UI hiện có `01a13fb6-b8a9-7e50-92c9-81498edea16d` tiếp tục sở hữu `apps/web/` và handoff UI. Làm trước Home idle/video result/dashboard ở desktop/mobile, tự xem ảnh để chỉnh nếu còn đơn điệu rồi áp dụng gallery/login/campaign/editor/settings trong cùng nhiệm vụ; không cần hỏi lại cho các lựa chọn trình bày trong kế hoạch. Giữ các patch source-quality/shortlink/backend contract hiện hành, không sửa backend hoặc CURRENT. Dùng stack/dependencies hiện có. Không deploy/push/CI, build/pull image, thay settings production hay chạy nguồn.

Giữ bộ ảnh trước sửa; tạo namespace successor riêng cho ảnh sau sửa, gallery/index và handoff có đường dẫn tuyệt đối. Chỉ kiểm frontend delta cần thiết, reduced-motion runtime và các điểm hẹp/focus/sticky/quality label đã finding. Không mở lại suite backend/nguồn hoặc tạo thêm framework kiểm thử. Bàn giao đủ các màn chính desktop/mobile và giới hạn fixture, dừng sau hoàn tất.

Root gửi việc cho đúng chat UI, ghi nhận dispatch một lần rồi dừng khi hết việc độc lập, theo chỉ thị chủ; không polling hoặc mở vòng kiểm mới trong khi chờ.

## UI successor sau review — mã đã sửa, browser QA bị chặn

Đã triển khai bố cục Home gọn theo job, video poster/control sát nhau và quality badge ngoài select; gallery toàn bề ngang/actionbar mobile ngắn; admin sidebar212px, KPI/bảng/form gọn, trợ giúp MiB/phút giữ payload. Giữ dependencies, lifecycle/preview guard/native anchor/source-quality và một ảnh/job. Typecheck/build đạt; output cuối49modules/4.83s. Không sửa backend/CURRENT hoặc deploy.

**Chưa hoàn tất nghiệm thu UI hoặc có ảnh sau sửa:** CUA trả `Local browser use is disabled in Work settings` trước đặt viewport/tạo tab. Đã hỏi chủ bật lại, chưa có xác nhận; không vượt cài đặt bằng công cụ khác. Chưa tự xem được Home/video/dashboard bước đầu, chưa kiểm runtime narrow/focus/sticky/reduced-motion và chọn ảnh trên successor. Không dùng16PNG cũ làm ảnh mới. Bàn giao/giới hạn/bước tiếp tại [frontend-successor/HANDOFF.md](../evidence/ui-preview-admin-redesign-20261030/frontend-successor/HANDOFF.md), [index trạng thái](../evidence/ui-preview-admin-redesign-20261030/frontend-successor/index.html).4JPEG calibration tự tạo khác nhau đã sẵn sàng cho fixture; server riêng đã dừng. Tiếp tục kiểm/chụp đúng namespace mới khi CUA được bật.

## Chủ sửa lại định hướng kết quả video/ảnh theo ảnh tham khảo — 30/10/2026

**Chỉ thị hiện hành, ưu tiên hơn bố cục result trong plan trước:** Chủ chỉ rõ bản mới vẫn bố trí sai phần kết quả và yêu cầu xem kỹ hai ảnh tham khảo ban đầu. Root nhận phần diễn giải trước quá thiên về form thông số: poster lớn, select quá dài, nhiều badge và chú thích kỹ thuật không đáp ứng mẫu chủ muốn. Chưa chốt bản successor này.

### Bằng chứng và nguyên nhân đã xác định

- Root đã mở lại trực tiếp cả hai attachment ban đầu: `C:/Users/LENOVO/AppData/Local/Temp/codex-clipboard-8ff45351-c9dd-4b73-a0e9-7b47973d79b4.png` (video) và `C:/Users/LENOVO/AppData/Local/Temp/codex-clipboard-1c143cfd-b5a3-4055-9fe0-5af655f9495d.png` (album). Video là thẻ gọn, thumbnail/tiêu đề trái và cụm nút xếp dọc phải; album là grid ảnh với nút ngay dưới mỗi thumbnail. Không phải màn form kỹ thuật kéo toàn chiều ngang.
- Ảnh mới chủ gửi `codex-clipboard-8a0b0855-1fde-49fb-88ae-f9baef8bcc88.png`: input có `/photo/7680791073106595089`, kết quả lại là video fixture27s/MP4/1080p. Root đọc `apps/web/dev/preview-fixture.cjs`: nhánh `jobs/analyze` lấy loại từ `ref.searchParams.has('photo')`, không dùng `body.url`. Vì vậy tại trang `/`, link ảnh vẫn nhận payload video mẫu. Đây là lỗi fixture/bản demo; chưa chứng minh API production nhầm loại. Home hiện render theo `items[0].kind` từ API, không có bằng chứng cần sửa backend cho finding này.
- Root CUA đã hoạt động trở lại: đọc AX và screenshot production thành công; trong lượt này mở riêng `http://127.0.0.1:5196/` xác nhận bản fixture có nhãn, không submit link/chuẩn bị/tải. Tab kiểm riêng đã đóng, trang chủ của người dùng giữ nguyên. Code là cơ sở xác định nhánh fixture ở trên, không gọi là root đã chạy luồng ảnh thật.
- Đã tra web và đọc trực tiếp [SSSTik.io](https://ssstik.io/) và [SnapTik.app](https://snaptik.app/en3), chỉ đối chiếu trang công khai/luồng nhập và mô tả chức năng; chưa submit link hoặc kiểm kết quả tải của họ. Không đánh đồng các domain mang tên tương tự là cùng dịch vụ. Bằng chứng chính cho bố cục result là hai ảnh chủ cung cấp.

### Phương án sửa cụ thể, giao chat UI thực hiện

1. **Video:** result card giới hạn khoảng800–960px và cân giữa; desktop chia hai vùng rõ. Trái thumbnail khoảng128–160px kèm tiêu đề ngắn2–3 dòng; phải các hành động xếp dọc, rộng vừa tay bấm. CTA dùng lifecycle hiện có: chuẩn bị MP4 → đang chuẩn bị → native tải MP4 khi ready, thêm thao tác thử link khác theo analyze/cancel hiện có. Nếu có nhiều chất lượng, giữ lựa chọn nhỏ gọn/tuỳ chọn phụ, không biến thành form chiếm toàn bề ngang.
2. **Bỏ sự lặp:** không bày cả hàng ba badge, lặp lại label MP4 phía dưới select và đoạn giải thích codec/luồng dài. Chỉ giữ một dòng chất lượng cần quyết định; thông tin phụ thật sự cần có thể để phần chi tiết gọn. Không bịa1080p/default khi API không có dữ liệu. Không thêm MP3 hoặc tải có logo từ ảnh tham khảo.
3. **Album:** header gọn, dưới là grid thẻ ảnh khoảng4–5 cột desktop,2 cột mobile. Mỗi thẻ gồm thumbnail, số ảnh và nút rõ ngay bên dưới. Không dùng một select ảnh và một CTA ở xa làm thao tác chính. Nút trên thẻ gọi cùng luồng prepare với đúng formatID; một ảnh/job, một thao tác pending, khoá thẻ khác sau prepare, native link chỉ xuất hiện ở đúng ảnh ready. Tránh `setFormat(id); prepare()` đọc state cũ: bind formatID trực tiếp vào handler dùng chung hoặc giải pháp tương đương an toàn. Giữ ảnh nguyên tỷ lệ/contain, không crop để giả bố cục.
4. **Fixture dùng được bằng ô link:** canonical `/photo/` phải tạo payload album và `/video/` tạo video từ URL submit tại trang thường, không đòi chủ biết `?photo`. Query ép trạng thái chỉ dùng cho kiểm đặc biệt, phải có nhãn rõ. Các link không được fixture mô phỏng thì báo chưa mô phỏng, không trả video1080p mặc định cho mọi input. Không gọi nguồn thật. Hướng dẫn bản local phải nêu rõ ảnh calibration/API mẫu, không thể tải tệp thật.
5. **Kiểm đúng delta:** canonical link ảnh ở trang thường ra gallery không MP4/quality video; link video ra card video. Bấm thẻ ảnh3 phải prepare đúng format3, không dùng selection cũ, không tạo nhiều job hoặc mở tải hàng loạt. Kiểm narrow/focus và trạng thái ready/native anchor; tái dùng test còn đúng, không lặp suite backend. Chụp rõ4 màn result video/photo desktop/mobile sau sửa, giữ nguyên ảnh/evidence cũ. Cập nhật HANDOFF/index của successor với namespace ảnh mới nếu cần; không đánh đồng fixture với nguồn thật.

Phạm vi sửa lần này tập trung **result Home và fixture**, không tiếp tục redesign admin hoặc mở lại chất lượng/backend/source. Giữ React/Vite/Tailwind/dependencies, ownership UI, CSRF và các vòng đời đã có. Không push/CI/deploy hoặc settings production. Root ghi nhận lỗi, giao đúng chat UI hiện có và dừng khi hết việc độc lập.

## Bàn giao result hộp thoại theo ảnh chủ — 30/10/2026

Đã áp dụng thêm chỉ thị trực tiếp của chủ: phân tích xong hiện hộp thoại, không đổi bố cục trang nhập phía sau. Video card880px/thumbnail144px trái, nút dọc phải; album5cột desktop/2cột mobile, nút dưới từng ảnh. `prepare(formatId)` bind trực tiếp ID ảnh, một ảnh/job, ready chỉ đúng ảnh có native link. Admin/backend/CURRENT không sửa trong delta này.

Fixture tại trang `/` đã dùng `body.url`: link ảnh chủ ra gallery, canonical video ra video; link chưa mô phỏng báo422 rõ. Typecheck/build cachetools exit0 (49modules/3.15s), diff-check đạt. CUA IAB kiểm Tab→ảnh3→Enter: đúng1POST format03,4ảnh khác khóa/1nativeJPGanchor, không bấm tải. Đóng/Esc trả focus; trang nền giữ nguyên chiều cao; mobile không tràn ngang dialog. Giới hạn vẫn fixture/calibration, không nguồn hoặc deploy.

Bàn giao chuẩn: [result-dialog/HANDOFF.md](../evidence/ui-preview-admin-redesign-20261030/result-dialog/HANDOFF.md). [Gallery PNG mới](../evidence/ui-preview-admin-redesign-20261030/result-dialog/index.html) có4màn result desktop/mobile +2ảnh focus/ready, giữ ảnh/evidence trước. Server local5196 giữ chạy để chủ test theo yêu cầu, tab kiểm riêng đóng/viewport reset. Root review ảnh và diff trước tích hợp; dừng sau bàn giao.

## Đồng bộ nền và chuyển động toàn trang — chủ phản hồi 31/10/2026

Chủ gửi ảnh hộp thoại trắng trên nền hero than đậm, nhận xét không đồng bộ background và chuyển động web quá đơn giản. Root đã đọc [bản sửa motion hiện có](../evidence/ui-preview-admin-redesign-20261030/result-motion-20261031/HANDOFF.md), trực tiếp xem hai screenshot video/album desktop của bản đó và đọc CSS Home/shared/layout/admin. Bản này đã có header than chì, mặt sáng pha cam và chuyển động hộp thoại; không giao làm lại y hệt hoặc gọi ảnh chủ là trạng thái mới nhất. Root chưa trực tiếp xem chuyển động chạy, không suy animation mượt chỉ từ screenshot. Cần tiếp tục hoàn thiện sự thống nhất giữa trang và hộp, đồng thời bổ sung chuyển động có chủ đích ngoài hộp thoại.

### Định hướng thực hiện tiếp

- Giữ đúng bố cục kết quả chủ đã chọn: modal, video thumbnail/tiêu đề trái và hành động dọc phải; ảnh có nút dưới từng thumbnail. Giữ bố cục trang nhập phía sau, tránh tự chuyển lại inline result hoặc dựng layout khác. Không mở vòng redesign admin mới.
- Tiếp tục Taste Skill đã cài; tăng motion từ mức3 lên mức5 phù hợp brief mới. Dùng chung token cho page/surface/raised/panel/border/shadow/accent, chọn một họ neutral thống nhất. Modal và form là cùng loại surface, header/panel dùng cùng than chì; giảm cảm giác ghép thêm bằng viền, radius và bóng đồng bộ. Tránh phối thêm nền cát vàng, xám xanh và hồng cam tùy khối. Không đơn thuần tô header tối rồi coi là đồng bộ cả web.
- Loại bớt lớp thẻ lồng trong thẻ ở cụm video-actions nếu không mang thông tin; khoảng cách/thumbnail/CTA cần gọn như ảnh tham khảo, có thứ bậc rõ. Backdrop đủ tách modal nhưng không xóa hết ngữ cảnh; blur vừa phải, có nền đặc fallback. Không thêm khối trang trí để che sự trống.
- **Nhịp vào trang:** logo/nav, nội dung hero và form xuất hiện theo thứ tự ngắn; khoảng lệch60–80ms, tổng không quá500ms, dịch chuyển8–14px. Chạy một lần, không chạy lại vì gõ link/poll job. Input/CTA luôn sẵn dùng ngay, không animation delay thao tác hoặc làm text biến mất kéo dài.
- **Tương tác:** input focus, nút hover/press, link underline, thumbnail/ảnh chọn phản hồi thống nhất khoảng160–220ms. Không cần xoay icon đóng90° hoặc phóng ảnh gây cảm giác cắt nội dung. Hover nâng1–2px chỉ trên pointer fine; keyboard có focus tương đương.
- **Tiến trình:** phản hồi analyzing/queued/preparing/ready có chuyển trạng thái ngắn và loading tương ứng nếu đã có điểm render phù hợp; không bịa phần trăm, thời gian hay tiến độ tải. Giữ nguyên nội dung thật, thời điểm enable/disable, cancel và native anchor. Modal mở/đóng khoảng240–320ms; nội dung/media theo sau40–60ms; gallery stagger giới hạn tổng200ms ngay cả album dài.
- **Phần dưới trang:** hướng dẫn/FAQ có reveal một lần khi xuất hiện, dùng native CSS hoặc IntersectionObserver chỉ khi thật sự cần. FAQ có phản hồi mở/đóng gọn, giữ semantics details/summary. Không scroll listener/poll, parallax, autoplay nền hoặc animation vô hạn để tạo cảm giác “nhiều hiệu ứng”. Admin chỉ nhận các token/control feedback dùng chung nếu an toàn, không thay nội dung/logic.
- Ưu tiên CSS/React/controls đã có. Dependencies hiện chỉ React/ReactDOM, chưa có Motion/GSAP; choreography cần ở trên không đủ lý do cài thêm. Không tự viết animation engine, focus-trap hoặc thay native dialog. Nếu cần API/option mới, xác minh tài liệu chính thức đúng browser/stack rồi ghi nguồn trong handoff.

### Kiểm và bàn giao đủ phạm vi

Chat UI hiện có sở hữu code; root chỉ sửa task/CURRENT và gửi follow-up. Tái dùng build và checks không đổi, chỉ chạy typecheck/build sau delta cuối và smoke entry→mở/đóng video/ảnh, keyboard/focus/narrow, ảnh3→đúng format nếu chạm handler. Kiểm thực chuyển động tại ít nhất desktop/mobile, mô tả cụ thể những gì đã thấy; screenshot không phải số đo FPS. Reduced motion phải tắt toàn bộ phần mới; nếu CUA không hỗ trợ media emulation thì ghi NOT RUN phần runtime, không đổi OS preference toàn cục và không tự xây harness chỉ để lấp báo cáo. Không thêm lần gọi nguồn hoặc test backend.

Lưu ảnh mới Home idle + video/album desktop/mobile, dùng fixture có nhãn và giữ ảnh cũ. Cho chủ xem bản local để cảm nhận chuyển động; không chỉ gửi ảnh tĩnh rồi tuyên bố mượt. Không deploy/push/CI, build image/dependency mới hoặc settings thật. Root giao xong dừng khi hết việc độc lập.

## Root nghiệm thu bản đồng bộ Home — 31/10/2026

Chủ yêu cầu “nghiệm thu thử xem nó có khác gì không”. Root đọc [handoff home-cohesion](../evidence/ui-preview-admin-redesign-20261030/home-cohesion-20261031/HANDOFF.md), CSS và StudioReveal, rồi trực tiếp kiểm CUA bản local5196. Không kiểm production hoặc chạy lại build/test backend. Tái dùng báo cáo code UI typecheck/build exit0/49modules/4.26s; đó là lệnh của chat UI, không phải lệnh root chạy lại.

**Kết luận:** nhận delta đồng bộ màu và tương tác có giới hạn; có thay đổi thật, nhưng mức thay đổi thị giác vừa phải, bố cục chính vẫn gần bản trước theo yêu cầu giữ trang nhập/modal. Không gọi là thiết kế mới hoàn toàn hoặc tự suy chủ đã ưng thẩm mỹ. Không phát hiện lỗi chặn mới trong các thao tác smoke này.

- Root runtime: form và dialog cùng trắng `rgb(255,255,255)`, hero/header cùng than chì `rgb(37,42,46)`. Video-actions không background/border-shadow lồng riêng; backdrop40%/blur2px. So với ảnh chủ gửi, header trắng đã thành than chì, nền hướng dẫn cát được thay neutral và lớp phủ nhẹ hơn. Màu sáng/tối vẫn là ngôn ngữ chính, không có thay đổi lớn về hình thức.
- Root bắt được nhịp entry đang chạy sau reload: logo opacity.963/translateY.879px; nav.840/3.851px; intro/form.5/12px; delay0/60/120/190ms, duration280–300ms. Đây là mẫu trạng thái computed thực, không số đo FPS hoặc video. Modal có transition280ms; tại thời điểm bắt đầu close, `open=false` nhưng display còn block, focus đã về `video-url`. Không tuyên bố đo đủ đường cong exit từ một mẫu.
- Root submit đúng2link qua form fixture ở trang thường: canonical video → thumbnail/quality/nút dọc; canonical photo → album5thẻ/nút từng ảnh, không MP4-quality video. Không click prepare/download. Nút đóng desktop và Escape mobile đều đóng, focus về ô link.
- Root mobile390×844: album2cột, dialog clientWidth=scrollWidth320px, page375px≤viewport390; screenshot ổn định có5thẻ và fallback ảnh5 có chủ ý. Một capture ngay lúc đổi viewport bị scale tạm, giữ nguyên và ghi rõ không dùng làm bằng chứng layout. Ảnh ổn định ở05. Không tái chạy format3/ready lease vì handler không đổi và bằng chứng trước vẫn phù hợp.
- Reduced-motion runtime vẫn NOT RUN, đã đọc CSS gating/override; không đổi OS và không claim mọi thiết bị mượt. Root không chạy lại admin/source/download, không thay setting hoặc deploy. Đã reset viewport, đóng tab root tạo; server/tab của chủ giữ nguyên.

Bằng chứng root: [checks.json](../evidence/ui-preview-admin-redesign-20261030/reviewer-cohesion-20261031/checks.json), [Home desktop](../evidence/ui-preview-admin-redesign-20261030/reviewer-cohesion-20261031/01-home-desktop.jpg), [Video desktop](../evidence/ui-preview-admin-redesign-20261030/reviewer-cohesion-20261031/02-video-desktop.jpg), [Album desktop](../evidence/ui-preview-admin-redesign-20261030/reviewer-cohesion-20261031/03-album-desktop.jpg), [Album mobile ổn định](../evidence/ui-preview-admin-redesign-20261030/reviewer-cohesion-20261031/05-album-mobile-settled.jpg). Ảnh JPEG CUA nguyên bytes, fixture/calibration, không phải ảnh TikTok thật.

Chưa giao vòng code mới vì smoke không phát hiện lỗi mới cần sửa. Bản local sẵn cho chủ cảm nhận chuyển động; production savlivo.online chưa deploy thay đổi này. Dừng sau báo cáo.

## Tinh chỉnh hover theo mẫu Taste Skill — 31/10/2026

Chỉ thị mới sau nghiệm thu: chủ thấy hover rung mạnh, yêu cầu áp dụng skill đã cài và tham khảo các web đã dùng skill tương tự. Đây là delta tiếp theo, thay trạng thái chưa giao code ở đoạn trên; không mở lại redesign toàn trang hoặc backend.

**Finding từ mã, chưa phải đo hover runtime:** style.css dòng143 nâng nút2px; home.css dòng119 nâng photo-card2px. Khi con và cha cùng hover, vị trí nút có thể cộng dồn4px; :active còn đổi sang +1px. Loại chuyển động vị trí là bản sửa trực tiếp cho cảm giác nhảy mà chủ báo. Không cần dựng thêm lab hoặc thư viện.

**Tham khảo đã xác minh:** [trang Taste Skill](https://www.tasteskill.dev/#) mục Built with Taste Skill liệt kê [Floria](https://floria-landing-page.vercel.app/) và [Collective OS](https://collectiveos.vercel.app/). Root mở trực tiếp cả hai bằng CUA, xem screenshot và DOM/computed styles; không đăng ký, submit form hay tải asset. Floria CTA dùng transition-colors150ms và hover đổi background, transform none lúc đọc; Collective OS hero có reveal/active, nhưng CTA có hover:-translate-y-0.5, nên không lấy chuyển động nâng nút đó cho WED SNAP. Chưa đo thời gian reveal hoặc FPS của hai mẫu, không suy mượt từ ảnh tĩnh. Đây là mẫu được website skill giới thiệu, không chứng nhận chúng không có lỗi hay dùng đúng phiên bản local của ta. Linear/Raycast đã mở trang công khai nhưng không có căn cứ nói dùng Taste Skill; không dùng làm bằng chứng áp dụng skill.

### Giao chat giao diện thực hiện

- Tiếp tục skill local .agents/skills/design-taste-frontend/SKILL.md, giữ token và bố cục home-cohesion đã nghiệm thu. Gỡ hover translate/scale/rotate khỏi nút và photo-card; rà đúng selector của Home/shared/admin để tránh cha–con chuyển động cộng dồn. Dùng màu/viền/bóng nhẹ140–180ms, không transition:all, không đổi kích thước/hitbox khi hover. Bỏ cả press translate hiện tại nếu nó tạo nhảy; phản hồi nhấn có thể bằng màu/bóng. Keyboard focus vẫn rõ, selected/disabled vẫn đúng trạng thái.
- Giữ motion có chủ đích đã có: entry một lần, mở/đóng modal và stagger media, reveal hướng dẫn/FAQ. Không tăng độ trễ input/CTA, không thêm lắc/nảy/magnetic/parallax, ảnh zoom hoặc hiệu ứng nền lặp. Không sao chép nội dung, số liệu hay assets của các mẫu. Không mở redesign admin; shared controls chỉ nhận phản hồi ổn định.
- Ưu tiên CSS/dependencies hiện có; không cần Motion/GSAP cho delta này. Giữ lifecycle, CSRF, formatID một ảnh/job, native download và fixture có nhãn. Không gọi nguồn, thay settings thật, push/CI/build image hoặc deploy.
- Chỉ kiểm delta sau sửa: frontend build cần thiết, CSS không còn hover positional transform trên control/card, bàn phím/focus và video/album fixture khi cần. Nếu CUA không có thao tác hover/media-emulation được hỗ trợ thì ghi rõ giới hạn, không bịa đã kiểm runtime hoặc tự dựng harness. Tái dùng checks không đổi; không chạy lại prepare/download/backend.
- Lưu successor handoff ngắn và ảnh/video nếu công cụ hỗ trợ đủ để chủ đối chiếu; giữ bằng chứng cũ. Ghi rõ thay đổi nào đã làm và chưa deploy. Chat UI sở hữu mã/handoff, root sở hữu CURRENT. Giao xong root dừng khi hết việc độc lập.

## Root kiểm delta hover — 31/10/2026

Chủ yêu cầu kiểm bản mới. Chat UI đã hoàn tất, root đọc [hover-stable/HANDOFF.md](../evidence/ui-preview-admin-redesign-20261030/hover-stable-20261031/HANDOFF.md), diff của đúng lượt qua chat và selector shared/Home/admin/layout. Nhận phần sửa mã: bỏ hover -2px/press +1px trên control, bỏ hover -2px trên photo-card, transition chỉ màu/viền/bóng160ms. Selected/disabled/focus, entry/modal/stagger giữ nguyên. Không phát hiện finding mã mới trong delta. Không suy toàn bộ thiết kế đã ưng từ thay đổi hover.

Tái dùng typecheck/build UI exit0/49modules/6.20s và focus geometry do chat UI đo; root không chạy lại build hoặc gọi nguồn. Marker shell exit1 cuối chat UI là rg không có matches, không phải build thất bại. Hover/active giữ chuột và reduced-motion runtime vẫn NOT RUN vì API không hỗ trợ; bằng chứng bàn phím không thay bằng chứng hover.

Root thử mở local5196 nhưng gặp ERR_CONNECTION_REFUSED; đọc trạng thái xác nhận server UI cũ đã kết thúc1073807364. Đã dùng lại fixture và bản build có sẵn, copy riêng artifact web/calibration nhỏ sang reviewer-hover-20261031 để không ghi đè log/evidence cũ, không build mới. Server root báo UI_FIXTURE_ONLY nhưng CUA lần mở tiếp vẫn timeout; không có analyze/prepare/download hoặc ảnh browser mới trong lượt này. Không đổi firewall/OS hay dùng đường vòng trình duyệt. Dừng server kiểm do root tạo và đóng tab lỗi riêng. Không coi lỗi xem thử là bằng chứng lỗi production hoặc lỗi CSS.

Bước tiếp theo đủ phạm vi: chủ cảm nhận hover ở bản local khi mở được trước chốt phát hành. Chưa deploy UI lên savlivo.online; không tự mở thêm vòng code/test hoặc giao lại việc đã hoàn thành khi không có finding mới.

## Chủ yêu cầu chạy web để test — 31/10/2026

Theo chỉ thị mới, đã mở lại server fixture bằng Node nền ẩn ngoài sandbox, chỉ bind127.0.0.1:5196, PID25064. Không sửa mã ứng dụng, không build lại hoặc deploy. Dùng artifact reviewer-hover-20261031/web đã copy từ bản UI đạt; log riêng trong cùng namespace. CUA đã mở thành công trang Home, xác nhận stylesheet index-DY6NJxw2.css và nút Phân tích link transform none/transition màu-viền-bóng160ms. Không analyze/prepare/download; không gọi nguồn. Đây khép lỗi mở preview của lượt sandbox trước, không phải phép đo hover.

Giữ tab bản local hiển thị cho chủ test, đóng các tab lỗi riêng. Ảnh thực: [01-running-preview.jpg](../evidence/ui-preview-admin-redesign-20261030/reviewer-hover-20261031/01-running-preview.jpg); computed: [preview-check.json](../evidence/ui-preview-admin-redesign-20261030/reviewer-hover-20261031/preview-check.json). Banner phân biệt minh họa/local, nguồn và admin giả lập. Production savlivo.online nguyên; hover giữ chuột/reduced-motion runtime vẫn chưa được root kiểm. Dừng để chủ thao tác.

## Thử mặt kính mờ cho hộp kết quả — 31/10/2026

Chủ gửi ảnh codex-clipboard-cad12fca-5703-4441-8066-a85386f4f891.png và yêu cầu thử làm mờ/trong suốt. Ảnh cho thấy nền trang phía sau đã mờ, nhưng thân modal vẫn trắng đặc và header là thanh than đặc; chỉ tăng blur nền sau không giải quyết đúng chỗ chủ đang chỉ. Lượt này thay đổi chất liệu bề mặt modal, không đổi bố cục video/album hoặc trang nhập.

Chat UI tiếp tục Taste Skill local: quy tắc glass ở mục3/6 và phần web approximation phù hợp chỉ thị mới. Dùng CSS đã có, không thêm thư viện. Đã đối chiếu [MDN backdrop-filter](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/backdrop-filter): cần nền bán trong suốt mới thấy lớp phía sau; [prefers-reduced-transparency](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-reduced-transparency) hỗ trợ chưa đồng đều, nên không dựa duy nhất vào media query để đảm bảo dễ đọc.

- Làm một bản thử glass neutral cho result-dialog video và album: nền trắng/xám rất nhạt bán trong suốt khoảng75–85%, backdrop blur khoảng12–18px, viền sáng1px/highlight inset và bóng vừa. Điều chỉnh bằng ảnh thực, không chỉ sửa một con số rồi coi đã khác. Header dùng cùng họ surface bán trong suốt, giảm ranh giới thanh than/ruột trắng; màu heading/icon đóng/focus/viền đổi đồng bộ và đủ tương phản. Không nhuộm thêm màu ngoài token hiện có.
- Blur ở lớp nằm sau bề mặt, không filter blur hoặc giảm opacity cả hộp. Chữ, thumbnail/ảnh, select/native options và nút tải giữ sắc nét; CTA accent giữ nổi bật. Vùng nhập/hero phía sau còn nhận ra nhưng không đọc xuyên qua gây nhiễu. Có thể giảm blur trên mobile để nhẹ; không animate blur/backdrop-filter, không thêm lớp lọc chồng lên mọi card.
- Giữ hover/press đứng yên, entry/modal/stagger hiện có, keyboard/Escape/trả focus, một ảnh/job/formatID/native anchor và các trạng thái. Fallback solid fill khi không hỗ trợ backdrop-filter và khi giảm transparency; vẫn đủ đọc nếu không có blur. Không thay OS preference hoặc gọi bản web này là Apple Liquid Glass chính thức.
- Chỉ kiểm delta CSS/build frontend cần thiết; xem thực video và album desktop/mobile, đối chiếu trước/sau, focus/đóng. Không prepare/download/nguồn/backend hoặc lặp suite cũ. Nếu media emulation không có thì ghi rõ runtime NOT RUN, không dựng harness. Lưu successor handoff và ảnh4màn result; ảnh fixture không thay nguồn thật.

UI sở hữu mã/handoff, không sửa CURRENT. Giữ baseline5196 (root đã mở process Node PID25064 ngoài sandbox) và artifact/evidence cũ; không giết hoặc ghi đè bản chủ đang xem. Bản glass thử riêng5197 bằng cùng fixture nếu cần, chạy helper nền ẩn ngoài sandbox khi cần quyền localhost, không build/pull image hoặc dependency mới. Chụp rồi giữ một tab mới cho chủ thử và bàn giao link thật sau khi truy cập được. Không deploy/push/CI/settings production hoặc redesign admin. Root gửi việc rồi dừng khi hết việc độc lập.

## Chủ hủy kính mờ, yêu cầu duyệt phác thảo trước — 31/10/2026

Chỉ thị mới ưu tiên: không trong suốt nữa; vấn đề là bố cục video/các nút quá dài và xấu. Phải đưa vài bản phác thảo để chủ duyệt trước khi sửa giao diện thực. Root đã dừng chat UI; UI hoàn nguyên riêng delta glass trong home.css về hover-stable, giữ snapshot glass riêng, không reset Git hoặc đụng thay đổi của người khác. Không build/test/server mới cho việc hủy đó. Baseline5196 giữ nguyên.

Root mở lại hai ảnh tham khảo gốc; video cần thumbnail/tiêu đề sát cụm tải gọn, hành động phụ nhẹ hơn, album nút dưới từng ảnh. Không đưa lựa chọn có logo/MP3. Tiếp tục Taste Skill theo hướng công cụ tải nội dung có hình ảnh làm trọng tâm, kiểm kích thước/thứ bậc hành động trước hiệu ứng.

Đã tạo [bộ phác thảo HTML tĩnh](../../design/result-layout-drafts-20261031/index.html) ngoài apps/web; không đổi ứng dụng hoặc backend. Mở local5198 bằng Python http.server bind127.0.0.1, process7736 nền ẩn; CUA xác nhận truy cập/chuyển cả3tab A/B/C, giữ tab cho chủ. Tất cả nút mô phỏng không gọi API/tải tệp; ảnh/title/27s/quality là minh họa, không số đo nguồn thật.

- A: gần mẫu chủ gửi, thumbnail trái/cụm tải phải, bỏ header đặc và nút phụ dài. Desktop hộp520px/nút248×44px.
- B: thẻ ngang, cover sát tiêu đề, chất lượng và nút tải gom vào footer gọn. Desktop hộp600px/nút178×44px.
- C: thẻ dọc than chì nhỏ, cover lớn ở trên, chất lượng và tải cùng hàng. Desktop hộp364px; không kính mờ.

Đã đọc DOM desktop1280px cho kích thước A/B, kiểm responsive khung406px không tràn, chụp các ảnh chi tiết ở khung mặc định. Ảnh desktop khi override bị mờ do capture nên không dùng để phán chất lượng; ảnh duyệt là [A-detail](../../design/result-layout-drafts-20261031/A-detail.jpg), [B-detail](../../design/result-layout-drafts-20261031/B-detail.jpg), [C-detail](../../design/result-layout-drafts-20261031/C-detail.jpg). Đây là phác thảo tĩnh, không chứng minh lifecycle/download/backend; không chạy build hoặc suite ứng dụng. Viewport reset, tab bản B giữ mở.

Chờ chủ chọn A/B/C hoặc ghép thành phần cụ thể. Chưa giao triển khai bố cục nào; chỉ sau duyệt mới giao chat UI áp dụng. Không deploy/push/CI hoặc thay settings production.

## Chủ duyệt B và giao triển khai — 31/10/2026

Chủ chọn rõ “b ĐI”. Đây là quyền áp dụng phương án B vào video result trong apps/web, thay trạng thái chờ duyệt. Nguồn chuẩn là `.variant-b` trong [phác thảo](../../design/result-layout-drafts-20261031/index.html) và [ảnh B](../../design/result-layout-drafts-20261031/B-detail.jpg); không đổi sang A/C hoặc glass.

- Modal video desktop khoảng600px, phần trên thumbnail khoảng90×96px sát tiêu đề/metadata; bỏ thanh header than đặc và poster/cụm nút chiếm hai nửa rộng. Tiêu đề nhỏ/gọn ở đầu thẻ và nút đóng rõ. Giữ ảnh contain/không cắt mất thông tin nếu tỉ lệ thực khác ảnh phác thảo.
- Footer neutral sáng chứa chất lượng, CTA khoảng178×44px và Đổi link dạng text-action. Khoảng cách vừa, không kéo CTA/secondary ngang nửa modal như bản cũ. Mobile thu gọn tương ứng B: cover nhỏ sát title, quality cạnh CTA, Đổi link xuống hàng nhẹ; tối thiểu44px hit area và không tràn.
- Dữ liệu phác thảo không vào ứng dụng: title/thumbnail/platform/duration/options lấy từ job thật hoặc fallback hiện có. Giữ thông tin cần chọn quality/codec/audio trong label hoặc phần thông tin gọn đang có; không cắt mất khác biệt quan trọng chỉ để ép width, không tự đoán/parselabel thành metadata giả. Không thêm MP3/tải có logo hoặc khẳng định nguồn luôn1080p.
- Bố cục mới giữ mọi state/selectable→queued/preparing→ready/failed/cancelled/expired, CSRF/lease/cancel. Selectable vẫn Chuẩn bị MP4; chỉ ready mới native anchor tải thật. Chuẩn bị/đổi link không đổi nghiệp vụ. Entry/modal animation và hover160ms đứng yên giữ nguyên.
- Phạm vi video result/shared header phải scoping riêng để không đổi album, admin, trang nhập hoặc backend. Glass đã hủy/hoàn nguyên. Skill/dependencies hiện có, không library mới. Chỉ kiểm build frontend và smoke video fixture/keyboard/focus/narrow cần cho delta; album chỉ một đối chiếu nếu shared selector bị chạm. Tái dùng kiểm tải/nguồn không đổi.
- Lưu successor handoff/ảnh video desktop/mobile và mở bản áp dụng ở5197 cho chủ, không ghi đè baseline5196 hoặc phác thảo5198/evidence cũ. Fixture có nhãn, không nguồn/prepare/download thật. Chạy server nền ẩn ngoài sandbox nếu cần localhost và xác minh truy cập trước bàn giao. Không push/CI/build image/deploy/settings production. UI sở hữu code/handoff, root sở hữu CURRENT; hoàn tất bàn giao rồi dừng.

## Chủ yêu cầu thử Tailwind cho bản B — 31/10/2026

Chủ gửi ảnh codex-clipboard-69429740-80a7-441c-ad71-d1a4f0afe30b.png và hỏi “sao nó lại thế này bạn thử dùng tw xem nào”. Hiểu theo ngữ cảnh UI là Tailwind CSS; triển khai bằng Tailwind hiện có, không đổi phương án B sang thiết kế khác. Root đọc [handoff B](../evidence/ui-preview-admin-redesign-20261030/video-layout-b-20261031/HANDOFF.md): build/typecheck exit0/3.60s, nhưng CUA chat UI bị disabled nên chưa nhận QA hình ảnh. Không gọi việc build đạt là chủ đã chấp nhận bố cục.

Finding cụ thể: B thực dùng grid `minmax(0,1fr) 178px 64px`, select width100%; phần nhãn dài chiếm toàn cột còn lại. Phác thảo B desktop để select ngắn bên cạnh label, có khoảng trống và nút gọn; chuyển nguyên label đầy đủ vào ô select rộng làm thay đổi tỷ lệ. Đây là lựa chọn bố cục hiện tại, chưa có bằng chứng CSS không tải hoặc Tailwind bị hỏng. Screenshot cũng thể hiện đúng dạng B đã code, nhưng chủ chưa ưng tỷ lệ/chiều dài.

Tailwind3.4.17 đã có ở package.json và config content src; style.css có directives base/components/utilities trước CSS thủ công. Theme cũ còn accent #4169e1/ink #17233d, khác token UI hiện tại, nên không dùng `bg-accent/text-ink` một cách mù quáng hoặc đổi theme toàn app. Đối chiếu [Tailwind v3 grid](https://v3.tailwindcss.com/docs/grid-template-columns) và [custom styles/arbitrary values](https://v3.tailwindcss.com/docs/adding-custom-styles); dùng token CSS trong utilities cho riêng video.

### Giao chỉnh delta

- Dùng Tailwind utilities trực tiếp cho bố cục/spacing/sizing của video B, với class tĩnh để build quét được. Gỡ đúng các rule custom video đã được thay để không để selector specificity/order ghi đè; không chồng thêm !important hoặc chuyển cả app sang Tailwind, không thay thứ tự CSS toàn cục chỉ để thắng cascade. Native dialog/backdrop/motion cũ có thể giữ CSS cần thiết.
- Giữ hộp tối đa khoảng560–600px; cover90×96 desktop/74×84mobile sát title, tiêu đề16–18px nếu đủ. Giảm khoảng trắng phần trên, giữ nhãn header nhỏ và close44px. Footer dùng control có chiều rộng chủ đích, không cho quality/select kéo hết phần dư. CTA fit nội dung khoảng160–178×44px, icon16–18px, Đổi link là text-action nhỏ có44px hit area. Không chỉ chuyển cú pháp sang TW mà output vẫn y nguyên ảnh chủ phàn nàn.
- Quality: giữ native options với label thật, có selected label đầy đủ trong dòng thông tin gọn thấy được khi ô bị hẹp; không giấu thông tin chỉ ở title/tooltip, không regex tự đoán codec/resolution hoặc đổi API. Có thể select khoảng180–210px desktop, còn lại cân khoảng cách footer; mobile wrap hợp lý, không ép control tràn/đẩy nút tải thành thanh dài. Đối chiếu phác thảo B và ảnh phản hồi, không thêm badge bịa hoặc thông tin mock.
- Không glass, không nhảy hover/press, không MP3/tải có logo. Giữ album/admin/trang nhập/backend, preview thật/fallback, state/CSRF/lease/formatID/native ready anchor và source quality nguyên. Chỉ thay trình bày video; dependencies/lockfile/Tailwindv3 giữ nguyên.
- Build frontend delta một lần sau sửa và đối chiếu markup/compiled utility thật. CUA root lần này cũng disabled; nếu UI không có browser thì ghi rõ và bàn giao bản local để chủ thử, không tuyên bố có screenshot/app review hoặc lặp hỏi bật quyền. Không chạy lại nguồn/prepare/download/suitebackend hoặc tạo harness mới. Khi có CUA thì chụp video desktop/mobile và keyboard/focus đủ delta, không chạy cổng lịch sử.
- Giữ artifact B trước sửa/baseline5196/phác thảo5198; successor riêng cho bản TW, dùng5197 sau khi xác minh đúng PID riêng của UI và dừng/restart đúng server đó nếu cần. Không kill process root hoặc xóa evidence. UI code/handoff, root CURRENT. Không push/CI/build image/deploy/settings production; bàn giao link thật và kết quả/giới hạn rồi dừng.

## Bốn concept dùng ảnh đã tải, chờ chủ duyệt — 31/10/2026

Chủ tiếp tục phản đối bố cục rời rạc/nút không đều, yêu cầu3–5phương án dùng một ảnh đã tải trước đó và áp dụng skill đã cài cùng skill nổi tiếng. Chỉ thị mới thay việc tiếp tục vá B/Tailwind bằng duyệt thiết kế trước. Root đã nhắn chat UI dừng; chat xác nhận giữ snapshot Home.tsx/home.css, giữ server và không build/test/deploy thêm. Chưa giao áp dụng concept mới.

Root đọc Taste Skill local và tham khảo [frontend-design chính thức Anthropic](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md), không cài thư viện/plugin mới. Nguồn ảnh là `native-image.jpg` của [lượt ảnh02 đã nghiệm thu](../evidence/tiktok-photo-source-fixed-live-review-20261015/ASSESSMENT.md), cùng byte đã truyền qua web26/10: JPG2132×2132/322655B/SHA62308e…5a8b. Copy nguyên byte sang thiết kế, không tải TikTok mới. Thông tin27s/1080p của màn video chỉ minh họa, không phải số đo của ảnh.

Đã tạo [gallery duyệt](../../design/result-concepts-v2-20261031/index.html), [brief/tokens/giới hạn](../../design/result-concepts-v2-20261031/DESIGN.md) và [manifest](../../design/result-concepts-v2-20261031/manifest.json). Bốn hướng:01chia đôi cân đối,02ảnh trung tâm,03thẻ ngang thấp,04khung tối; mỗi hướng có màn video và ảnh, nút chính180×44px/chất lượng gọn. `node design/result-concepts-v2-20261031/render.cjs` exit0, xuất8SVG/8PNG/8ảnh cận bằng sharp có sẵn; root trực tiếp xem cả4video và ảnh01, chỉnh03 để select và CTA cách16px. Đây là phác thảo SVG/PNG trên nền screenshot có sẵn, không phải screenshot app mới hoặc kiểm browser/lifecycle. Không chạy build/suite/backend/nguồn.

Gallery tĩnh phục vụ ở http://127.0.0.1:5199/ bằng Python nền ẩn PID1804, chỉ localhost; giữ5196/5197/5198 nguyên. Có tab01–04,video/ảnh và xem cận. CUA trước đó disabled, không bypass hoặc claim kiểm tương tác. Đợi chủ chọn bản/chi tiết trước giao chat UI triển khai; chưa sửa apps/web, push, CI hoặc deploy.

## Chủ duyệt mẫu01, áp dụng chia đôi cân đối — 31/10/2026

Chủ trả lời trực tiếp “mẫu 1 đi”. Đây là quyền triển khai mẫu01 vào kết quả video và ảnh theo bộ vừa trình, thay trạng thái chờ duyệt; không còn tiếp tục thiết kế B/Tailwind cũ. Nguồn chuẩn: [video01](../../design/result-concepts-v2-20261031/01-balanced-video-detail.png), [ảnh01](../../design/result-concepts-v2-20261031/01-balanced-photo-detail.png), [DESIGN.md](../../design/result-concepts-v2-20261031/DESIGN.md). Thẩm mỹ được duyệt, chức năng vẫn cần giữ đúng mã hiện hành.

- Chat UI áp dụng ảnh contain bên trái, title/metadata/quality/hành động theo cùng trục phải. Desktop khoảng680px, ảnh khoảng288px, gap28px/padding24px; chiều cao theo nội dung thật. CTA khoảng180×44px, select có chiều rộng riêng, action đổi link dạng chữ với hit area44px. Không kéo nút hoặc select ra hết khoảng dư, không glass/hover nhảy. Mobile chuyển một cột, ảnh giới hạn chiều cao, controls wrap vừa màn hình.
- Giữ lựa chọn đủ các ảnh của album và nút gắn đúng ảnh/formatID; mẫu một ảnh không cấp quyền bỏ các ảnh còn lại hoặc gộp tải. Giữ nhãn định dạng đầy đủ từ API, không hardcode1080p/MP4/27s. Preview thật/fallback và mọi lifecycle/CSRF/lease/cancel/native-ready anchor giữ nguyên. Không đổi Home idle/admin/backend hoặc policy nguồn.
- Dùng React/Tailwind3 và dependency hiện có. Dọn đúng rule videoB đã thay, không reset code người khác hoặc chồng override. Demo fixture dùng ảnh Lights thật có sẵn trong thư mục concept, ghi rõ minh họa; không chèn ảnh mẫu vào production hoặc tải nguồn mới.
- Kiểm frontend build/typecheck và smoke đúng delta: video/album, hẹp, keyboard/Esc/focus/reduced-motion nếu browser hỗ trợ. Chụp desktop/mobile nếu CUA khả dụng; nếu disabled ghi giới hạn, không bypass/claim QA hoặc hỏi chủ bật lại. Không nguồn/prepare/download thật, suitebackend, dependency mới, push/CI/buildimage/deploy.
- Giữ snapshot/evidence/baseline5196 và gallery5199, dùng5197 cho bản áp dụng của UI; xác minh truy cập trước bàn giao. Handoff ngắn ghi file đổi, lệnh thực chạy, ảnh/giới hạn và link local. Root cập nhật CURRENT; giao xong dừng, không polling lặp.

## Chủ nhận bố cục01, sửa riêng ô chọn chất lượng — 31/10/2026

Chủ báo “ổn rồi” nhưng ảnh `codex-clipboard-abef4e66-1d2c-46d9-a245-f57f51fecdd1.png` cho thấy dropdown chất lượng cắt tên định dạng và menu xanh native không đồng bộ. Giữ mẫu01; không redesign tiếp hoặc coi đây là lỗi tải. Root đối chiếu Home.tsx319–323 và styles/home.css: select chứa nguyên f.label, width140px/text-overflow:ellipsis, có dòng label đầy đủ bên cạnh. Đây là nguyên nhân clipping quan sát được; chưa claim bản đang mở5196 là artifact mới5197. ChatUI đã bàn giao mẫu01/build/browser smoke theo compact status; root chưa chạy lại hoặc nghiệm thu browser lượt đó.

Dependencies web hiện chỉ React19.1.1 và Tailwind3.4.17, chưa có headless select/React Aria/Radix. Thay vì viết lại listbox/focus bằng JS hoặc cài thư viện, ưu tiên tùy biến native select bằng `appearance: base-select` cho select và `::picker(select)` trong feature query phù hợp. Đã đối chiếu tài liệu chính thức [Chrome branded select](https://developer.chrome.com/docs/modern-web-guidance/guides/forms/branded-select-styling) và [picker layouts/fallback](https://developer.chrome.com/docs/modern-web-guidance/guides/forms/custom-select-picker-layouts). Browser chưa hỗ trợ giữ native fallback; không hứa mọi trình duyệt có menu giống nhau.

Giao chatUI sửa hẹp ô chất lượng: mặt trắng/viền mềm/radius đồng bộ mẫu01, option cao tối thiểu44px, selected có dấu nhận biết và nền cam nhạt, hover nhẹ không nhảy. Đủ bề rộng trong cột phải, label đọc đầy đủ/wrap khi hỗ trợ; không quay lại select140px ellipsis dài hoặc kéo cả modal/nút. Giữ f.label/formatID thật và semantics/onChange/disabled, không đoán resolution/codec bằng regex/hardcode hoặc thay lựa chọn mặc định. Không tự dựng combobox/listbox hay thêm dependency nếu native enhancement không đủ: báo hạn chế cụ thể.

Kiểm nhỏ nhất: build frontend một lần sau delta, browser mở picker desktop và320px nếu có CUA, đổi1080/720 fixture xác nhận đúng value/label bằng bàn phím, Esc đóng picker trước dialog/không kích prepare, disabled không đổi. Đọc tính năng support thật và native fallback; chụp menu đang mở và đóng nếu công cụ bắt được, không giả ảnh native popup. Giữ demo ảnhLights và fixture label; không nguồn/prepare/download thật, album/admin/backend/deploy. Bản áp dụng5197, link đúng được nêu rõ; baseline5196/gallery5199 nguyên. Bàn giao gọn rồi dừng.

## Chủ duyệt giao diện hiện tại, chốt đợt chỉnh — 31/10/2026

Chủ xác nhận trực tiếp “giao diện được rồi đấy”. Chốt mức chấp nhận thẩm mỹ cho giao diện chủ vừa xem; dừng redesign/motion/control bổ sung. Compact status chatUI hiện idle/completed, báo menu đã khớp chiều rộng trigger và tên dài xuống dòng, bản local5197. Root ghi nhận bàn giao và lời duyệt, không chạy lại build/browser/nguồn hoặc suy lời duyệt thành kiểm backend/production. Ambient URL của chủ vẫn5196, chưa đối chiếu artifact/hash bản đang xem; không tự thay baseline hoặc coi production đã có UI mới. Giữ snapshot/server/bằng chứng, không push/CI/buildimage/deploy khi chưa giao bước đó. Đợt thẩm mỹ khép, chỉ mở lại nếu có lỗi cụ thể hoặc yêu cầu mới.
