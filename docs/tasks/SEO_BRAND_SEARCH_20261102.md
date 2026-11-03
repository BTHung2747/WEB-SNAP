# Nhận diện và hiển thị Google cho WED SNAP — 02/11/2026

## Phạm vi chủ giao

Trước khi cập nhật Lightsail, chủ bổ sung logo của web, lời giới thiệu ở kết quả tìm kiếm và cách để Google tìm thấy website; ảnh YouTube là tham khảo về cách hiển thị. Giữ thương hiệu **WED SNAP**, tên miền chính **https://savlivo.online/** và dấu `w.` màu cam đang dùng; không redesign giao diện đã duyệt hoặc hứa có knowledge panel/thứ hạng như YouTube.

Task này bổ sung candidate sau `add52bc1723f58aade8abbb42bc831f2a2071c0d` (CI41333031820 đã đạt), chưa apply lên VPS. Các image add52bc1 nếu đã pull có thể giữ làm candidate chức năng trước; không nói chúng đã chứa SEO. Target vẫn source2ec8034, dữ liệu/env/settings/volumes giữ nguyên; rollback refs đã có trong `lab-runs/tiktok-release-final-20261102/root-target-preflight.json`.

## Audit trước sửa

- `apps/web/index.html`: chỉ title/theme/viewport, chưa favicon/description/canonical/social tags.
- `apps/web/src/App.tsx`: useEffect ghi đè title chung; nội dung Home/Legal phụ thuộc session. Không để Google chỉ thấy trạng thái chờ kết nối hoặc yêu cầu API để đọc phần giới thiệu.
- `Header.tsx` và `layout.css`: nhận diện hiện tại là chữ `w.` trên nền accent; chưa có asset logo/favicon riêng. `apps/web/public/` chưa có.
- `infra/production/Caddyfile`: SPA fallback chung, CSP chặt; API/download có chính sách timeout/forwarding/cancellation đã nghiệm thu. Giữ các chính sách này.
- Stack React19.1.1/Vite7.3.6/Tailwind3.4.17; ưu tiên API chuẩn/React/Vite hiện có. Không cài framework, SEO plugin hay runtime image service mới.

## Kết quả cần có

1. Favicon PNG vuông96×96 (URL ổn định), icon điện thoại180×180 và asset thương hiệu từ dấu `w.` hiện có. Có thể có SVG nguồn; primary favicon dùng PNG theo tài liệu Google hiện hành. Ảnh chia sẻ PNG dùng cùng nhận diện, không lấy logo YouTube/TikTok. Dùng công cụ xuất ảnh đã có, không thêm dependency chạy production.
2. Copy theo chỉnh sửa của chủ02/11: tên hiển thị **WED SNAP**, alternateName **WEDSNAP**, domain `savlivo.online`. Home title: **WED SNAP – Lưu video, giữ khoảnh khắc**. Description/og:description/twitter:description: **Giữ lại những khoảnh khắc bạn yêu cùng WED SNAP. Tải video và ảnh TikTok không dính logo nền tảng, lưu video YouTube về thiết bị với chất lượng từ nguồn.** Cụm không dính logo chỉ watermark do TikTok thêm vào; chữ/logo có sẵn trong nội dung tác giả vẫn giữ nguyên. Copy ảnh chia sẻ có thể dùng **Điều bạn thích, giữ lại bên mình.** cùng tên WED SNAP và YouTube · TikTok. Giữ giới thiệu đúng chức năng; giới hạn nguồn≤1080p vẫn nêu ở nội dung thật, không thêm Facebook/X/MP3/chất lượng gốc vô hạn hoặc đổi bố cục UI đã duyệt để nhét slogan.
3. Head có title/description/canonical/social image và site-name nhất quán; trang công khai có title/description riêng khi cần. Không để App ghi đè metadata bằng title chung. Tên/logo và thông tin `WebSite` crawl được theo tài liệu Google; dùng cách tương thích CSP, không nới `script-src`/thêm unsafe-inline cho script để nhét JSON-LD.
4. Phần giới thiệu/cách dùng công khai đọc được mà không phải tạo job/tải nguồn hoặc phụ thuộc API session. Chọn thay đổi nhỏ nhất, ưu tiên tách phần marketing tĩnh đang có khỏi gate session; giữ bố cục và lifecycle tải/auth/CSRF/native links. Không chuyển sang SSR framework hoặc thêm prerender service.
5. `robots.txt`, sitemap chỉ các URL công khai/canonical có thật; không job/ticket/API/admin/fixture hoặc lastmod giả. `/admin` và API/private có noindex phù hợp ở response thật; không coi robots/noindex là bảo vệ truy cập. Tránh SPA fallback khiến robots/sitemap/icon bị trả HTML200 hoặc đường dẫn rác bị index như trang chủ. Caddy/static thay đổi phải được review và native validate ở release như gate hiện có.
6. Tài liệu ngắn để chủ mở Search Console, thêm Domain `savlivo.online`, xác minh TXT ở Cloudflare bằng giá trị Google cấp; sau deploy mới gửi sitemap và yêu cầu index trang chủ. Không bịa token xác minh, sửa DNS hoặc dùng tài khoản Google khi chưa có thao tác chủ.

## Kiểm và bàn giao

Giao code tay to thực hiện patch hẹp. Trước sửa phải kiểm deps/API đúng phiên bản và đọc Taste Skill theo AGENTS; chỉ dùng quy tắc nhận diện phù hợp, giữ UI đã duyệt. Không sửa CURRENT hoặc docs root.

Kiểm tối thiểu: web typecheck/build một lượt, kiểm asset dimensions/file thực, HTML/head/canonical/robots/sitemap và route/noindex với công cụ hiện có. Kiểm public content khi session thiếu và bảo toàn API/guard bằng diff; không chạy TikTok/YouTube, không lab nguồn hoặc suite lịch sử. Chỉ thêm test nếu trả lời khoảng trống cụ thể; không dựng framework SEO.

Bàn giao exact changed paths/diff, lệnh thực và kết quả, giới hạn crawler/Google chưa kiểm, asset preview để root xem, và handoff ngắn trong `lab-runs/seo-brand-search-20261102/`. Không stage/commit/push/CI/image/publish/deploy/DNS; root review rồi mới chốt successor và gửi lệnh VPS mới. Giữ untracked `apps/web/dev/` cũ nguyên.

## Nguồn chính thức đã đối chiếu

- [Google favicon](https://developers.google.com/search/docs/appearance/favicon-in-search): favicon vuông, URL ổn định, crawl được; PNG96 lớn hơn khuyến nghị48. Có favicon không bảo đảm Google hiển thị.
- [Tên website](https://developers.google.com/search/docs/appearance/site-names): WebSite name/url trên homepage, tên nhất quán với nội dung; hệ thống Google quyết định hiển thị.
- [Mô tả tìm kiếm](https://developers.google.com/search/docs/appearance/snippet): Google có thể dùng meta description hoặc tự tạo snippet từ nội dung.
- [Sitemap](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap): URL tuyệt đối/canonical, submit là gợi ý, không bảo đảm indexing.
- [Xác minh Search Console](https://support.google.com/webmasters/answer/9008080): Domain property dùng DNS verification, giá trị do Search Console cấp.
- [Yêu cầu crawl lại](https://developers.google.com/search/docs/crawling-indexing/ask-google-to-recrawl): dùng URL Inspection/sitemap sau public, không bảo đảm index ngay.

## Trạng thái

Candidate đã bàn giao; xem [HANDOFF](../../lab-runs/seo-brand-search-20261102/HANDOFF.md). Root quản lý review và cập nhật tiến độ; chưa stage/commit/push/CI/deploy SEO hoặc thay DNS.

## Root review candidate

Root đọc tracked diff và các file mới, kiểm đủ18sourcepins đều khớp manifest. Đã xem PNGfavicon96 và share1200×630 thật: dấu `w.`/tên WED SNAP/accent nhất quán, không cắt chữ. Tái dùng build-hydrated actual0/typecheck/Vite/React và artifact-check PASS; không rerun suite hoặc nguồn. APIproxy block chỉ thêm noindex, CSP nguyên; Home handlers/hooks giữ byte sau đổi import phần tĩnh. [Root receipt](../../lab-runs/seo-brand-search-20261102/root-review.json).

CUA inventory nay có browser hoạt động, không còn Worksettingsdisabled. Bản tĩnh `hydrated-web/` được phục vụ tạm tại loopback5215; lượt đầu sandbox socket-denied/old error-tab bị URLpolicy chặn đọc, không sửa policy hoặc truy cập dataURL. Sau server được mở qua cơ chế tool chuẩn và HTTP200, tab mới4 mở đúng trang. DOM có title/meta description cuối chủ/og:site_name/canonical đúng, một h1, controls disabled khi chưa session; screenshot giữ bố cục. Captured warn/error logs `[]`; session-effect nhận404HTML từ static server nên hiện lỗi JSON là giới hạn của phép kiểm khôngbackend, không phải liveAPI/sourcePASS. Không analyze/prepare/download TikTok/YouTube. Tab4 đã đóng; server session96466 đã kết thúc sau Ctrl+C (exit1 do interrupt), URL preview không được giữ làm deliverable.

Caddy route/header thực chưa được chạy vì coder không có cachedbinary/image. Root giao delta hẹp vào existing CI **trước publish**: native webimage/Caddy2.11.7, networknone và loopbackHTTP để kiểm public200/adminnoindex/staticMIME/redirect308/unknown404/APIupstreambranch; không TLS hoặc nền tảng nguồn. Giữ adapt/validate gate cũ, cleanup exactnames và bounds. Chưa nhận handoff delta CI; không thêm framework/deps/source hoặc build local. Chỉ commit/release successor sau root review delta này; rollout vẫn chờ backup/drain qua SSH và giữ nguyên dữ liệu target.

### Root nhận delta CI

[Handoff gate](../../lab-runs/seo-brand-search-20261102/ci-route-gate/HANDOFF.md): đúng2source `.github/workflows/release.yml` + `scripts/check-release-routes.py`. Root đọc full diff/helper, đối chiếu20sourcepins (18SEO+2gate) đều khớp, tái dùng YAML/Bash parse0 và purePython311grammar/Head/redaction khôngsocket đã đạt. Không chạy lặp build/web/source. Gate dùng chính app/webimage cùng release; web networknone và Pythonclient chungnetns/loopbackHTTP, khôngport/API/egress/nguồn thật. Có22case + readiness≤20,256KiB/response/2MiBtotal,5s/request/50sdeadline/55salarm và outertimeouts,128MiB mỗi role, exacttrap/alwayscleanup. API502 chỉ chứng minh không rơi vào staticfallback khi upstream vắng, không là API/sourcePASS. Nativeversion/adapt/validate cũ vẫn giữ trước gate/publish.

Nhận candidate để chốt exact20sourcepaths + CURRENT/taskSEO/taskTikTokroot, giữ mọi dirty/untracked khác ngoài index. Chưa có CI/runtime HTTP result tại thời điểm review; sẽ dispatch đúng một release successor sau commit/push, không apply VPS trước actualchecks/digests. Rollback target cũ vẫn giữ theo receipt2ec8034; imageadd52bc1 không gắn thành đã có SEO.

### Git/CI thực và finding HTTP

[Git receipt](../../lab-runs/seo-brand-search-20261102/release/root-git-receipt.json): exact23paths (20source+3rootdocs), sourcepinsmatch/indexsetchecked/diffcheck0, commit/push `df2fe21cdd67a7624c7c1127a0573b3494f364b2` PASS; không stage phần khác. Một dispatch [CI41372939142](https://github.com/BTHung2747/WEB-SNAP/actions/runs/41372939142), attempt1/job125047080583: build app/web/egress, compiled/static identity và Caddy2.11.7 native version/adapt/validate thực đều success. HTTPgate **FAIL**, publishSKIPPED, exactcleanupsuccess; chưa có immutable image release của candidate này.

[Fixed log](../../lab-runs/seo-brand-search-20261102/release/root-ci-failure-lines.txt): `MISSING_1` (`/assets/missing-release.js`), `code=CSP`, `status=404`. 19case trước đó đã qua:5public/2admin/6asset/5redirect/MISSING_0. Không phải lỗi tải TikTok hoặc HTMLpublic; response lỗi từ file_server thiếu CSP đang được gate yêu cầu. MISSING_2 và APIcase phía sau chưa thực hiện, giữ UNKNOWN. Không giảm expectation hoặc bỏ check để làm xanh.

Root đã đối chiếu [Caddy handle_errors](https://caddyserver.com/docs/caddyfile/directives/handle_errors) và [header/defer](https://caddyserver.com/docs/caddyfile/directives/header), giao code sửa hẹp error responses để giữ status404/502 và CSP/securityheaders/noindex, bodyplain cố định khôngURI/exception. Giữ originalAPIproxy/guards và22case nguyên; không dependency/framework/nguồn mới hoặc tự build/pull/CI. Base sửa là df2fe21; FAILED logs/manifests cũ giữ nguyên. Root review delta rồi phát hành successor, chưa apply Lightsail/DNS.

### Root nhận Caddy error fix

[Handoff](../../lab-runs/seo-brand-search-20261102/caddy-error-headers-fix/HANDOFF.md):1path Caddyfile SHA947a24c9…9131. Root đọc patch/sourcecheck, kiểm pin mới và19source đãfreeze khác đều khớp, không sửa helper/22case để néFAIL. `handle_errors` có đúng CSP/securityheaders normalchain, thêm noindex/no-store/plaintext và body literal; duy nhất placeholder err.status_code giữ status404/502, không phản chiếuURI/message/trace/id. Normalchain/APIproxy byte giữ; responseJSON4xx/5xx đã được upstream trả không tự biến thành genericerror.

Tái dùng sourceassertions0 về normalchain/CSP/placeholder; không rerun build/source. Native adapt/validate/22HTTPcases sau sửa vẫn chưa chạy ở mốc nhận; chốt commit/push exact Caddyfile+hai rootdocs và CI successor. FailedCI41372939142 và20frozenpins đầu giữ lịch sử; không gắn trạng tháiPASS mới cho bản cũ. VPS/env/settings/volumes/DNS chưa đổi.

### Successor CI đạt và immutable release

[Git receipt](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/root-git-receipt.json): root stage/commit/push đúng3paths (Caddyfile+CURRENT+taskSEO), commit `ad3429a76aa60deb4046e59f326cc3b5317746c3` PASS, index sau commit trống; mọi thay đổi khác giữ ngoài stage. Một [dispatch](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/root-dispatch-receipt.json) nhận CI41374277391/attempt1/job125051049501.

[CI41374277391](https://github.com/BTHung2747/WEB-SNAP/actions/runs/41374277391) **completed/success**: build app/web/egress cùng source, compiled/static identity, Caddy2.11.7 native version/adapt/validate, HTTPgate, publish ba image và cleanup đều đạt. [HTTP proof](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/root-http-gate.json) giữ nguyên22case trước đó: PASS/23HTTPrequests/58645responsebytes/sourceRequests0. Nhánh missingJS/PNG404 đã có CSP; expectedAPI502/noindex/khôngstaticfallback đạt khi không có upstream, không là bằng chứng liveAPI/TLS/TikTok hoặc thử upload chậm. Lỗi CI41372939142 vẫn giữ FAIL lịch sử.

[Ba immutable image refs](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/root-release-images.json) lấy từ đúng joblog/tag/source mới, nativeversion/validconfig được quan sát thực. Đây là bộ phát hành có cả sửa TikTok và logo/SEO; không dùng bộadd52bc1 làm bản đã chứa SEO. [Bốn lệnh preload](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/lightsail-preload-commands.txt) fetch đúngad3429a và pull ba ref mới, chưa checkout/env/up. Chưa nhận kết quả chạy VPS; target cũ2ec8034/rollback refs giữ. Bước tiếp theo sau preload đạt: tắt nhận job mới, chờ job/queue/lease và tài sản còn tải được về0, sao lưu env/compose/DB, rồi apply bộref cùng source; không reset/migrate lại/đụng volumes/PG/Redis. Đã đọc admission/assetExpired hiện có để tránh bắt đầu transfer mới trong lúc drain; không sửa lifecycle hoặc chạy nguồn thêm. DNS/SearchConsole làm sau deploy và kiểm public thật.

### Preload VPS: đã xác nhận egress và web

Ảnh terminal do chủ gửi `codex-clipboard-9485438f-a503-4356-ade8-250ecc8ffb9a.png` hiển thị pull thành công đúng hai immutable refs egress `26fc0aa9…a1e7a` và web `c7060f63…dffa6` của CI41374277391. Đây là ảnh do chủ cung cấp, không phải root SSH trực tiếp. Chưa thấy kết quả app hoặc fetch ad3429a trong ảnh; gửi hai lệnh chỉ đọc để xác nhận object nguồn và app image đã có trên VPS. Chưa maintenance/drain/backup/checkout/env/up; không coi pull thành deploy hoàn tất. Bước tiếp sau khi đủ preload là maintenance và sao lưu theo runbook, giữ nguyên dữ liệu/cấu hình/volumes.

### Preload VPS đã đủ, chuyển maintenance và drain

Ảnh tiếp theo của chủ `codex-clipboard-ab184cdd-61e4-46ce-aea2-82590928de01.png` xác nhận source object ad3429a/title đúng và app RepoDigests có đúng ref 4e1d4aa1…4a22a. Cùng hai pull egress/web đã thấy, preload đủ; không suy HEAD hoặc container đang chạy đã đổi. [Receipt target](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/root-target-preload.json). Root không SSH trực tiếp.

Bước hiện hành: chủ mở /admin, bỏ Nhận tác vụ mới và Lưu cấu hình; giữ nền tảng/giới hạn khác. Sau đó chạy [lệnh đếm readonly](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/lightsail-drain-check.sh) trong API cũ: kiểm settings=false, ba job states, live started leases, tài sản available còn có thể bắt đầu tải (đếm bảo thủ kể cả owner đã hết), và sáu loại queue chưa hoàn tất. Dùng API getJobCounts đã đối chiếu [mã BullMQ5.81.5 chính thức](https://github.com/taskforcesh/bullmq/blob/v5.81.5/src/classes/queue-getters.ts#L182); không tự diễn dịch khóa Redis hoặc clear queue. Chỉ in số đếm/cờ, trần15s, DRAIN_CLEAR nếu tất cả0; khác thì DRAIN_WAIT, không tự stop/backup/apply. Source, schema, core lifecycle và runbook đã đọc; chưa chạy lệnh trên target hoặc tạo lượt nguồn mới. Bước sau DRAIN_CLEAR là dừng các role đúng runbook, sao lưu và apply cùng ba refs; chưa có kết quả maintenance/drain/backup/deploy.

### VPS đã drain, chuẩn bị sao lưu

Ảnh chủ gửi `codex-clipboard-b91fee52-0b57-48f5-9a37-5ad63b716722.png`: acceptJobs=false; jobs/transfers/downloadableAssets đều0; queue wait/active/delayed/prioritized/paused/waiting-children đều0; marker DRAIN_CLEAR và shell prompt đã trở lại. [Receipt](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/root-target-drain.json); không có numeric exit được chụp, root không SSH trực tiếp.

Gửi hai khối thao tác theo runbook: [stop](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/lightsail-stop.sh) kiểm HEAD2ec8034/checkout sạch rồi dừng đúng worker/API/proxy; [backup](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/lightsail-backup.sh) từ chối nếu các role còn Running, tạo thư mục mới0700 trong /var/backups/wed-snap, sao env/compose0600 và source/image refs, pg_dump custom + pg_restore--list vào file, sao Caddy/data+config từ container đã dừng, hạn chế quyền bản sao và in SHA/đường dẫn. Không in secrets, không stop PG/Redis/egress, không down/volume removal/reset/migration; diff prisma2ec→ad3429a rỗng. Backup đang chuẩn bị, chưa có kết quả target hoặc restore/offsite proof.

Kiểm cú pháp root: Bash sandbox đầu lỗi khởi động MSYS NtCreateDirectoryObject/0xC0000022, không chạy body; chạy lại parser qua executor chuẩn exit0. Đã kiểm cả outer heredoc và nội dung hai body bằng Bash -n, không chạy Docker/VPS hoặc nguồn. Đây là kiểm cú pháp, không phải backup thành công. Chờ ảnh SERVICES_STOPPED/BACKUP_READY cùng đường dẫn và SHA trước checkout/env/up; giữ maintenance.

### Backup chưa có marker, cần kiểm tra readonly

Ảnh chủ `codex-clipboard-ba31e79e-b1db-4a65-8acb-687235b25cc7.png` có SERVICES_STOPPED và đã dán toàn bộ backup, sau đó shell prompt trở lại nhưng không thấy SHA/BACKUP_READY hoặc stderr. Không xác nhận backup thành công; numeric exit/điểm dừng/tệp hiện có chưa biết. Chưa checkout/env/up.

Root đọc lại chính script đã gửi và đối chiếu [Docker Compose exec](https://docs.docker.com/reference/cli/docker/compose/exec/): -T chỉ bỏ TTY, interactive mặc định vẫn giữ; pg_dump trong sudo bash heredoc không tách stdin có thể hút các dòng shell phía sau. Đây là thiếu sót của lệnh root, chưa là bằng chứng cause thực trên target; cũng có thể một guard test đã dừng. Giữ nguyên lightsail-backup.sh làm bản lệnh đã chạy, không hướng dẫn chạy lại nguyên bản. [Ba lệnh chẩn đoán readonly](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/lightsail-backup-diagnostic.sh) lấy exit của lệnh trước nếu chưa có lệnh xen kẽ, trạng thái năm container và tối đa20dòng tên/kích thước tệp dưới /var/backups/wed-snap. Không đọc nội dung env/DB/cert, không restart/stop thêm hoặc dump lại.

Sau khi có kết quả sẽ hoàn tất backup tại đúng bước, tách stdin rõ (pg_dump dùng docker exec không -i; chỉ pg_restore nhận stdin từ file). Không coi Bash -n đã đạt là kiểm được lỗi runtime stdin. Backup/restore/offsite/deploy vẫn chưa được chứng minh; website đang tạm ngừng theo maintenance đã giao.

### Đã thấy dump hiện có, chuyển hoàn tất backup

Ảnh chủ `codex-clipboard-ece82af0-4b8f-4e26-a96e-456c1caba7ab.png` ghi LAST_COMMAND_EXIT=0; worker/API/proxy exited/running=false, PG/Redis running=true. Một thư mục backup ngày02/11 có production.env907B, compose7063B, database.dump23698B, images823B và source41B; không thấy database-list hoặc chứng chỉ. [Receipt](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/root-target-backup-partial.json). Quan sát khớp pg_dump đã chạy và phần body sau bị stdin ăn, nhưng không có trace để khẳng định nguyên nhân. Chưa BACKUP_READY hoặc deploy.

[Khối hoàn tất](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/lightsail-backup-complete.sh) chỉ nhận duy nhất thư mục pre-update-20261102 hiện có, source2ec/dump23698B, cmp env+compose và ba role đã dừng; từ chối ghi đè file list/cert. Dùng docker exec -i với stdin chuyển rõ từ dump cho pg_restore--list và --file=/dev/null; đọc archive đầy đủ mà không đưa -d/kết nối DB. Đã đối chiếu [PostgreSQL16 pg_restore](https://www.postgresql.org/docs/16/app-pgrestore.html): không -d thì sinh SQL ra file, list chỉ là mục lục, không gọi đây là restore drill. Sau đó sao Caddy/data+config, quyền root-only, SHA và BACKUP_READY. Trap in step cố định khi fail; không dump lại/ghi DB hoặc chạy nguồn. Bash -n phần body actual0; chưa thực thi target, backup/offsite/restore/deploy chưa được chứng minh. Script cũ và lỗi stdin giữ lịch sử.

### Backup ready, chuyển apply ad3429a

Ảnh chủ `codex-clipboard-d531a8dc-cd1c-4ec4-af38-18d290c674dd.png` có copy Caddy/data18.9kB/config2.05kB, SHA dump và BACKUP_READY; shell prompt trở lại, không BACKUP_INCOMPLETE. [Receipt backup](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/root-target-backup-ready.json) lưu SHA256 c6b52888…f7b8d/23698B. Vì marker ở sau hai pg_restore read-only, chúng đã hoàn tất theo set-e; không coi đó là khôi phục DB thực hoặc bản sao ngoài VPS. Không chép đoán tên thư mục có ký tự khó phân biệt từ ảnh; các lệnh tiếp chỉ nhận duy nhất thư mục ngày02/11 đang có.

[Khối cập nhật](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/lightsail-update.sh): kiểm backup/env khớp, HEAD2ec và checkout sạch, worker/API/proxy dừng, ba key image đơn nhất, preview vắng/0; checkout ad3429a dưới ubuntu, sed thay đúng APP_IMAGE/EGRESS_IMAGE/WEB_IMAGE bằng refs cùng CI41374277391, kiểm env0600root:root và Compose config--quiet. Giữ secrets/contact/CIDR/budget/bốn cờ TikTok và settings/volumes; schema diff không có migration, Compose diff chỉ forward preview mặc định0. Không đổi PG/Redis.

Chỉ sau CODE_ENV_READY dùng [khối start](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/lightsail-start.sh): check source ad3429a, up--wait120/no-deps/no-build/pull-never đúng egress/api/worker/proxy, stdin /dev/null, in UPDATE_READY và ps. --no-deps giữ PG/Redis đang chạy; không reset/down/clear hoặc nguồn thật. Hai body Bash -n actual0; chưa thực thi target. Sau ảnh kết quả sẽ kiểm identity/health/public thật rồi mới nhận job lại; nguồn TikTok đã nghiệm thu không tự chạy lặp. Rollback dùng nguyên env+compose/source/images backup và quay cùng bộ ba cũ, không sửa DB/Redis. Không dispatch thêm CI hoặc thay DNS/SearchConsole ở bước này.

### Deployment đã lên VPS, kiểm public đạt

Ảnh chủ `codex-clipboard-c8c4ff75-b1c0-49fc-a925-30f8e05ca98b.png` hiển thị UPDATE_READY, app/api+worker4e1d4aa…4a22a, egress26fc0aa…a1e7a, webc7060f63…dffa6 đúng bộ CI41374277391. API/proxy có health trong ps; worker/egress Up, không tự gọi chúng có healthcheck. PG/Redis vẫn created/up3ngày/healthy. Root không SSH trực tiếp; UPDATE_READY chỉ xuất sau guard HEADad3429a và up thành công. [Review tổng](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/root-deployment-review.json).

Root thực [8GET HTTPS](../../lab-runs/seo-brand-search-20261102/release-caddy-fix/root-live-http.json): home và query cùng8735B/title mới, health200/application-json/oktrue, favicon200/1895B/SHA a99e1a…3fa4 khớp bản duyệt, robots200/textplain, sitemap200/XML, admin200/noindex, URL lạ404/noindex; tất cả có CSP, Server đã bỏ. Không cookies/auth/source trong bộ HTTP. Lượt sandbox đầu DNS bị chặn trước response; lần executor chuẩn có thêm1GET home rồi lỗi local header reader (Contains sai collection), sửa đúng reader và hoàn tất8GET, không coi lỗi reader là lỗi website. Không build/CI/source thêm.

CUA root tab mới đầu nhận HTML/JS cũ có admin anchor; sau HTTP trực tiếp đúng bản mới và reload một lần, DOM title `WED SNAP – Lưu video, giữ khoảnh khắc`, description có TikTok không dính logo nền tảng, og:site_name WED SNAP/canonical/favicon đủ, bundle index-BcqLIS6c.js, không public admin anchor. Home hydrate/kết nối phiên, controls hoạt động/capability YouTube+TikTok; captured warn/error logs[]; không analyze/prepare/download. Admin root thấy login, không có phiên quản trị nên không tự gửi credentials hoặc sửa settings qua API. Đây là cache browser cũ đã xử lý bằng reload, không mở task code mới.

Triển khai/kiểm public đã đạt, nhưng acceptJobs cuối được xác nhận=false và chưa bật lại. Gửi chủ thao tác admin→Cấu hình→Nhận tác vụ mới→Lưu cấu hình, giữ nền tảng/giới hạn khác, Ctrl+F5 nếu tab cũ. Chưa coi hệ thống đã mở nhận job; không tải nguồn lặp chỉ để test lại. Bước SEO sau đó: chủ xác minh Domain savlivo.online bằng TXT Google cấp và gửi sitemap trong SearchConsole; chưa sửa DNS hoặc dùng Google account/token. Backup chỉ tại VPS, restore/offsite chưa chứng minh; không claim P5/P6 tổng hoàn tất.

### Bổ sung theo ảnh kết quả tìm kiếm — 02/11

Chủ gửi ảnh Google khi tìm “tải video tiktok về máy tính”, muốn tiêu đề và nội dung thể hiện chức năng rõ như các kết quả tham khảo. Đây là chỉnh copy SEO mới, thay title thiên khẩu hiệu của bản ad3429a đang chạy; không sao chép nguyên văn đối thủ, không đổi brand/logo/canonical, bố cục video hoặc thêm landing page hàng loạt.

Chốt copy cho candidate đang làm:
- Home title/title social: **Tải video TikTok không logo & YouTube HD – WED SNAP**.
- Description an toàn với chức năng hiện tại: **Tải video TikTok không logo, ảnh TikTok và video YouTube về điện thoại, máy tính. WED SNAP dễ dùng, không cần tài khoản, hỗ trợ chất lượng nguồn tới 1080p.**
- Chỉ khi nhánh MP3 đã nghiệm thu và được bật trong bản phát hành, description có thể đổi thành: **Tải video TikTok không logo, ảnh TikTok, video YouTube và nhạc MP3. Lưu về điện thoại, máy tính dễ dàng, không cần tài khoản; video tới 1080p từ nguồn.** Không quảng bá MP3 chỉ vì có nút hoặc fixture, không claim audio nguồn khi chưa có.
- Giữ H1 cảm xúc/thương hiệu đã duyệt; phần mô tả công khai dưới hero phải nói rõ tải video TikTok không logo, ảnh TikTok và video YouTube về điện thoại/máy tính. Khi audio thực sự được bật mới đưa MP3 vào visible copy. Không thêm đoạn dài lặp từ khóa hoặc nới layout/modal.

Dùng site metadata/shared HomePublicSections hiện có để head build-time, og/twitter và runtime hydration nhất quán; site.name/og:site_name/WebSite name vẫn WED SNAP. Trang khác giữ description/title riêng, không biến admin/legal thành trang từ khóa tải. Thay đổi copy gộp cùng task ảnh/MP3 đang giao code tay to; không một build/source/CI riêng chỉ vì câu chữ. Kiểm diff/static head của lượt build cần thiết kế tiếp; CURRENT/PLAN/rootdocs vẫn do root quản lý.

Đã đối chiếu [Google title links](https://developers.google.com/search/docs/appearance/title-link): title mô tả ngắn, brand rõ, không nhồi lặp từ khóa; Google tự chọn tiêu đề thực tế từ nhiều tín hiệu. [Google snippets](https://developers.google.com/search/docs/appearance/snippet): phần mô tả có thể lấy từ nội dung trang hoặc meta, thay theo truy vấn; không hứa nguyên văn/lên top. SearchConsole/TXT vẫn cần chủ thực hiện sau khi website công khai; chưa có verification token hoặc thao tác DNS mới. Copy trên mới được giao triển khai, chưa lên production.

Root đã đối chiếu candidate và HTML build tại [review chung](../../lab-runs/tiktok-photo-grid-audio-20261102/ROOT_REVIEW.md): copy trên hiện đã có trong source/head build-time/runtime, og/twitter và hero; canonical/site name giữ đúng. Chưa quảng bá MP3, chưa phát hành copy mới lên savlivo.online; chờ khép nguồn của gói chức năng chung, không tạo CI riêng cho copy.
