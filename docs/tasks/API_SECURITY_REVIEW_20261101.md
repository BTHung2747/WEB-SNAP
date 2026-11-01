# Rà soát API/security trước release — 01/11/2026

## Backend — code tay to

Phạm vi: kiểm toán chỉ đọc trên working tree ngày01/11, kết thúc đọc lúc12:04VN/05:04UTC. Chưa sửa runtime, dependency hay candidate; chưa commit/push/build/publish/deploy. Candidate57 vẫn là DRAFT chờ UI QR, không phải release đã đóng băng. Đây là review hữu hạn, không bảo đảm không còn lỗ hổng.

### Kết quả và thứ tự xử lý đề xuất

**Chưa chứng minh lỗi high/critical trong phạm vi đọc.** Có một rủi ro cấu hình P2 và hai điểm P3 bên dưới; không đánh đồng chúng với exploit đã tái hiện.

| ID / mức | Vị trí và trigger | Bằng chứng, tác động, giới hạn | Sửa tối thiểu đề xuất, chưa thực hiện |
|---|---|---|---|
| API-01 / P2, rủi ro cấu hình | `infra/production/Caddyfile:57`; `apps/api/src/services/support-image.ts:36–44`; `apps/api/src/services/support.service.ts:24`. Upload hợp lệ, sau khi gửi xong body, decoder và giao dịch DB cùng tiến gần ngân sách cho phép. | Caddy chờ header10s; decoder dùng chung≤8s; DB maxWait2s và transaction timeout5s. Có đường được ứng dụng cho phép lâu hơn10s sau body. Proxy có thể đóng trước kết quả handler; có thể báo thất bại dù write đã commit nếu trùng ranh giới. **Chưa tái hiện bằng Caddy, chưa chứng minh commit sau ngắt.** Upload guard20s tự nó không chứng minh xung đột: Go bắt đầu chờ header sau khi gửi xong cả body. | Chốt ngân sách hậu-body với headroom và chỉ cân chỉnh route upload hoặc ngân sách handler trong task riêng; không tăng timeout global theo phỏng đoán. Kiểm một request chậm có kiểm soát qua Caddy đúng bản khi có binary ở release gate. Kiểm client-disconnect/commit riêng nếu chọn thay đổi transaction. |
| API-02 / P3, tối ưu tài nguyên | `apps/api/src/services/support.service.ts:11–13,26,44–49`; `support-contract.ts:3,15–18`. Anonymous GET `/support`, hoặc QR có ID64hex nhưng không khớp, khi row chứa saved+pendingQR. | Mỗi lượt đọc toàn JSON Settings rồi Zodparse cả hai PNGbase64, kể cả public off hoặc ID không khớp. Hai slot2MiB tương đương tối đa5,592,408 ký tự base64, cộng config. Không thấy rate tại hai route này. Chi phí DB/deserialize/parse lớn hơn response off rất nhiều; QR public cũng không dùng download-budget. **Không có bằng chứng leak draft hay đo tải/DoS**; cap hàng dữ liệu vẫn hữu hạn. | Ưu tiên projection JSONB phía DB để lấy đúng config/savedQR trước parse; public off không lấy binary, mismatch không lấy pending. Prisma `select:value` đơn thuần vẫn lấy toàn JSON, không giải quyết. Nếu thêm rate phải giữ public semantics, consistency/pending→Save/off; không thêm cache process thiếu invalidation. |
| API-03 / P3, cấu hình không có hiệu lực | `apps/api/src/security/support-upload.ts:47`; lock `busboy1.6.0`, `multer2.4.0`. Multipart hợp lệ có hơn32 cặp header mỗi part, còn dưới byte cap. | Mã chính thức Busboy1.6.0 dùng hằng2000 cặp/16KiB header, không đọc `limits.headerPairs`; Multer truyền limits xuống Busboy. Vì vậy cấu hình32 không cung cấp guard được ghi. Đây là kết luận source-level, **chưa chạy probe multipart**. Auth-before-parser, fields0/parts1, tổng2MiB+64KiB và deadline vẫn tồn tại; không phải bỏ hết cap. | Ghi đúng giới hạn hiệu lực và bỏ claim32 nếu không phải yêu cầu bắt buộc. Nếu32 là contract bắt buộc, chọn upstream có API thực thi và kiểm một case vượt32; không tự viết multipart parser, không tự nâng thư viện trong audit. |

Ưu tiên: root quyết định API-01 trước freeze/release; API-02 có thể sửa hẹp projection với kiểm off/pending/mismatchedID; API-03 sửa claim/cấu hình hoặc mở task upstream nếu cần guard32. Chưa có quyền từ báo cáo này để tự sửa hoặc mở thêm vòng kiểm.

### Đường thực thi đã đối chiếu

- Đọc đầy đủ `apps/api/src/auth/session.ts`, `security/client-ip.ts`, `security/rate-policy.ts`, `main.ts`, `validation.ts`, `filters/safe-errors.filter.ts`; các service session/admin/jobs/downloads/ads/support, support-contract/support-image/support-upload, preview-cache và controller session/jobs/downloads/support. Đọc helper admission; phần URL/Range/rate/password/limits của shared core; tiktok-short; assetDescriptor của tiktok-photo; các đoạn nối phase/child/preview-publication của worker adapter. Kiểm cấu hình cookie/proxy/resource/volume trong Compose và Caddyfile production.
- Session token32byte được băm trong DB, admin token kèm HMAC+Redis TTL. Write routes đi qua exact Origin+CSRF; adminwrite còn kiểm admin. Cookie HttpOnly/SameSiteLax/path`/api`, production Securetrue. Không thấy cơ sở để báo CSRF/auth bypass từ các đường đã đọc. Không xác minh live cookie/TLS trong lượt này.
- `own()` truy vấn cả jobID và sessionID; status/preview/prepare/ticket đều dùng nó. Native download kiểm ticket hash, expiry và session sở hữu; GET mở lease/budget dưới lock, kiểm lại state, path/size; HEAD không tạo lease. Descriptor chỉ chấp nhận `<jobUUID>/image.jpg` hoặc `media.mp4`. Không có URL/path tùy ý trong API preview/download. Chưa chạy race hoặc tải thiết bị trong lượt này.
- Preview đọc cache cố định, kiểm UUID/key/schema/size/SHA, `O_NOFOLLOW` và realpath; route kiểm job ownership, terminal/expiry và format thuộc job. Parent chỉ công bố index sau exit0/group reap+phase proof; tách optional proof khỏi metadata proof. Đã đối chiếu interface, **không audit lại toàn ProcessGroup/egress/media/DNS implementation**.
- Support upload: guard kiểm admin+Origin/CSRF trước Multer,10/min/admin và1active/process; cap tổng được đo bằng Transform trong khi đọc; MIME+magic+FFmpeg thực, cap output/deadline/kill-wait-close; không filename/URL/shell tùy ý. Public chỉ trả savedQR khi enabled; private draft cần admin; pending/delete chỉ công bố qua Save. Không đổi contract này.
- Client identity chỉ tin một XFF hợp lệ từ peer đúng danh sách proxy; production Caddy thay XFF, bỏ Forwarded/X-Real-IP. Redisrate dùng atomic Lua INCR+EXPIRE. Môi trường thêm CDN/proxy trước Caddy cần đánh giá identity riêng; đây không phải bằng chứng bypass hiện tại.
- API nhận TikTok URL exactallowlist; short/canonical chuẩn hóa có kind/ID. Worker xóa controlsecret khỏi child, tạo phase riêng và failclosed proof. Campaign HTTPS URL chỉ trả cho client, không phải serverfetch SSRF từ đoạn API đã đọc; không review lại rendering frontend trong phần này.

### Thư viện và nguồn chính thức đã kiểm

Lock thực đọc: Nest11.2.7, Express5.2.1, Multer2.4.0, Busboy1.6.0, qs6.16.0, body-parser2.3.0, cookie0.7.2, path-to-regexp8.4.2. Không chạy `npm audit`, không cài/nâng dependencies và không tuyên bố đã rà toàn advisory graph.

- [Multer GHSA-q7qp-rjg7-q26m](https://github.com/expressjs/multer/security/advisories/GHSA-q7qp-rjg7-q26m): version2.4 nằm trong range `>=2.0.0,<2.5.0`, nhưng advisory yêu cầu asynchronous fileFilter. Filter tại support-upload:48 callback đồng bộ, fields0/files1 và auth trước parser; không xác lập đường khai thác advisory ở đây. Không tự nâng2.5 chỉ dựa range.
- [Multer GHSA-535w-7cp7-47q4](https://github.com/expressjs/multer/security/advisories/GHSA-535w-7cp7-47q4): affected<2.3.0; lock2.4 ngoài range và fieldArrayIndexLimit0/fields0. Không ghi CVE này thành finding.
- [Express GHSA-qw6h-vgh9-j6wx](https://github.com/expressjs/express/security/advisories/GHSA-qw6h-vgh9-j6wx): range5 prerelease<5.0.0 hoặc4<4.20.0; lock5.2.1 ngoài range. Không thấy API redirect đến URL người dùng trong service được đọc.
- [Busboy1.6.0 multipart](https://github.com/mscdex/busboy/blob/v1.6.0/lib/types/multipart.js#L21), [Multer2.4.0 middleware](https://github.com/expressjs/multer/blob/v2.4.0/lib/make-middleware.js): căn cứ API-03, dùng parser có sẵn, không đề xuất tự viết parser.
- [Caddy2.11.7 transport](https://github.com/caddyserver/caddy/blob/v2.11.7/modules/caddyhttp/reverseproxy/httptransport.go#L376), [go.mod](https://github.com/caddyserver/caddy/blob/v2.11.7/go.mod), [Go1.26.0 Transport](https://github.com/golang/go/blob/go1.26.0/src/net/http/transport.go#L209): căn cứ semantics API-01. Version image build thực chưa chạy trong lượt này; release phải kiểm binary thật.

### Lệnh thực chạy, tái sử dụng và giới hạn

- `Get-Content AGENTS.md`; đọc CURRENT đầu vào và các file/đoạn đã liệt kê bằng `Get-Content` có đánh số, `rg --ignore-file .ignore` trong đúng component. Không quét toàn evidence/workspace.
- Đọc lock bằng `Get-Content package-lock.json -Raw | ConvertFrom-Json -AsHashtable`, lọc đúng7package phía trên: thành công. Lượt đầu không dùng `-AsHashtable` lỗi do property rỗng ở lock; đã đổi reader, không sửa lock.
- Một số probe đường dẫn cũ (`infra/Caddyfile`, `services/validation.ts`, `compose*.yaml` với literal Windows) không tìm được; dùng đường đúng `infra/production/Caddyfile`, `apps/api/src/validation.ts`, `compose.yaml`, `compose.production.yaml`. Output batch lớn bị truncation đã đọc lại theo component, không dùng phần bị mất làm bằng chứng.
- `git diff --cached --name-only`: exit0, indexrỗng tại12:04VN; chỉ đọc. Tra primarysource/advisory bằng webread, không tải/chạy mã nguồn ngoài.
- Tái dùng, không rerun: [backend coverage](../../lab-runs/support-handoff-20261101/final-coverage.json) —8nhóm offline+2focused được nhận; [UI→API/PG/Redis thật](../../lab-runs/support-ui-real-20261101-8d3c8d2e5988434aaef53b8b0a08d736/final-coverage.json) —1journey/Vite bridge, off/oldQR404 và cleanup. Đọc đầu hai receipt để xác nhận scope; **không rehash/rerun** coverage trong audit này. Kết quả preview offline được giữ tại hồ sơ [release integration](UI_BACKEND_RELEASE_INTEGRATION_20261031.md), không chạy lại.
- **0 functional test mới,0 Docker/native process,0 request ứng dụng/source,0 dữ liệu/settings main thay đổi.** Không fuzz/bruteforce/load/pentest, không bank/QR thật, TikTok/CDN/worker/source; không Caddy adapt/validate/TLS trong lượt này. Chưa review lại toàn worker/egress/media, migration/lifecycle history hoặc UI; root có phần review riêng.
- Chỉ thêm báo cáo này; không đổi runtime, CURRENT/PLAN (root sở hữu), golden/evidence/candidate cũ. Không có tài nguyên lab tạo ra để cleanup. Bàn giao root cập nhật CURRENT bằng link và quyết định fixplan; không tự mở nguồn/release.

## Root — UI/infra và quyết định tổng hợp

Đã nhận báo cáo backend. Root tự đọc lại SupportService/guard/decoder/lock/Caddy và đối chiếu advisory Multer + source Busboy chính thức. Đồng ý phân loại ba điểm trên; chưa có bằng chứng high/critical, auth bypass, draft leak hoặc DoS đã tái hiện trong phạm vi này. Không coi review hữu hạn là chứng nhận an toàn toàn hệ thống. Root UI/infra và thao tác CUA được ghi tại [review riêng](PRE_RELEASE_REVIEW_20261101.md); chủ đã duyệt bố cục QR, không redesign thêm.

Làm rõ API-03: Busboy dùng hằng2000 để ngừng ghi thêm cặp header vào object, **không có nghĩa gửi vượt32 hoặc2000 sẽ được reject theo tùy chọn này**; header byte-size16KiB mới là giới hạn parser đang kiểm. Không thêm nhận định “bypass mọi cap”, vì auth/aggregate/file/part/deadline vẫn tồn tại. Advisory Multer được upstream ghi rõ synchronous fileFilter không bị ảnh hưởng; callback hiện tại đồng bộ. Không nâng dependency chỉ để xử lý một đường async không được sử dụng.

### Fix plan đã giao sau review, chưa thực hiện

1. API-01: thống nhất ngân sách header hậu-body cho **chỉ POST exact uploadQR**, giữ10s của API khác và guard20s; chọn headroom hữu hạn (25s) nếu source Caddy đúng bản hỗ trợ cấu hình route. Tái dùng snippet/import chính thức nếu tránh lặp proxyheader; không làm mất sanitize XFF/forwarding, caps hoặc cancellation. Caddy native vẫn phải adapt/validate ở release; chưa có binary local thì ghi NOT_RUN, không dựng stack/pull chỉ để kiểm.
2. API-02: query JSONB parameterized/projection lấy config + savedQR ID cho public metadata; không chuyển saved/pendingPNG vào Node khi off hoặc đọcmetadata/IDkhôngkhớp. PublicQR chỉ chọn binary của ID đang saved và enabled ngay trong truy vấn để tránh TOCTOU; privateQR vẫn auth và pending semantics. Dùng Prisma API hiện có, không migration/volume/cache stale/framework mới. Kiểm hẹp PG thật off/pending/save/mismatch/oldID và shape khôngbinary; tái dùng upload/auth/decoder/UIjourney đãđạt.
3. API-03: bỏ tùy chọn không có hiệu lực và ghi rõ giới hạn upstream16KiB/2000-recording; đây là đính chính guard/claim, không tự viết parser hoặc nâng package. Thêm một phép kiểm nhỏ với parser thật chỉ khi cần xác nhận byte-limit; không lặp suite8nhóm. Giữ raw evidence/handoff cũ nguyên và thêm correction ở successor, không sửa golden/manifests.

Code tay to sở hữu backend/infra và test hẹp cần thiết, không sửa giao diện đã duyệt. Sau fix phải bàn giao diff + actual checks + giới hạn, root review rồi mới freeze candidate. Chưa commit/push/CI/publish/deploy từ quyết định này.

Trạng thái sau bàn giao: [successor và root nghiệm thu](API_SECURITY_FIXES_20261101.md#root-nghiệm-thu-successor) đã nhận phần mã/PG và đính chính parser; cấu hình Caddy được nhận source-only, native gate vẫn còn trước publish. Không thay các finding/audit ban đầu thành testPASS lịch sử; chuyển chốt candidate, không mở vòng scan/test mới.

### Bàn giao successor, chưa là nghiệm thu root

[Bản sửa và kiểm PostgreSQL hẹp 01/11](API_SECURITY_FIXES_20261101.md): giữ nguyên kết luận audit ở trên; phân biệt fixturePASS với native Caddy/production NOT_RUN. Root review successor trước freeze.
