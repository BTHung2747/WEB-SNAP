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
