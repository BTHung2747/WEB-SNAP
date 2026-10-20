# API local

Base `/api/v1`. OpenAPI được Nest tạo tại `/api/docs-json`. Cookie `ws_session`: ngẫu nhiên 256 bit, DB giữ SHA-256, HttpOnly, SameSite=Lax, path=/api; Secure cấu hình true cho HTTPS public. Job ID không cấp quyền.

Snapshot hiện `docs/openapi.json` có **20paths/24operations/21schemas**: phần30 thêm1GET `/api/v1/admin/ad-statistics` và schema `AdminAdStatistics`. Factory sinh qua controllers thật + `SwaggerModule.createDocument` + `describeContracts`/`createOpenApiDocument`, hai lần liên tiếp bytes khớp. **19paths/23operations/20schemas cũ và security definitions giữ canonical**, public11paths/12operations/12schemas không đổi; HEAD vẫn implicit handler hiện hành. Phần26 đã audit scoped23case metadata/0HTTP, phần27 nhận40case/87HTTP lịch sử; phần30 chỉ hẹp time-window/related controls, không rerun toànadmin/ads. Main chưa apply/migrate/xác minh hoặc public.

Bàn giao27 cuối gồm36ca/79HTTP chính và4ca/8HTTP bổ sung Origin trực tiếp
DELETE/logout:40PASS/87HTTP, đủ11target success; typecheck API/shared/p27
exit0. DELETE thiếu/sai Origin và logout sai Origin dù token đúng403/
CSRF_INVALID, DB/audit/token giữ; valid DELETE bodyfallback200/logout
header201. Không sửa runtime/contract/snapshot. Raw/tests/guards/restore/
limits tại TEST_REPORT và README6.17; đã audit độc lập27 scoped. Validator cuối
`validate-p27-origin-evidence.ps1` giữ frozen prose/matrix36/79 ban đầu và
currentdocs/source bổ sung, không đổi validators cũ để ép SHA mới.

GET `/session` tạo/reuse phiên và trả CSRF, nền tảng bật, `contact` string hoặc null (không bảo đảm email đã validation). Public mutations yêu cầu Origin đúng `APP_ORIGIN` và CSRF. Analyze/prepare có body strict nên phải dùng `x-csrf-token`; heartbeat/release/cancel/download-ticket còn nhận `{csrf}` trong body khi header không có. Admin có cookie riêng, token random + HMAC, lưu TTL 1 giờ trong Redis; mutation admin vẫn yêu cầu CSRF phiên khách. Không nhận cookie nền tảng.

## Hợp đồng OpenAPI public — phần24,03/10/2026

Base của bảng dưới là `/api/v1`. HTTP error public có đúng envelope
`{error:{code}}`, không có message/stack/source URL. `errorCode` trong status
job là kết quả xử lý bất đồng bộ, không phải HTTP error của request status.
Chi tiết tập mã theo từng status nằm trong snapshot; không coi mọi endpoint
có chung toàn bộ tập lỗi. Production SafeErrors phân loại:

- AppError giữ status/code của ứng dụng.
- HttpException giữ `getStatus()`; status404 trả `NOT_FOUND`, status khác trả
  `INTERNAL_ERROR`, không chuyển mọi HttpException thành500.
- Error không thuộc hai lớp trên fallback500/`INTERNAL_ERROR`.
- Khi headersSent=true, chỉ destroy response, không gửi JSON mới.

Phần25 đã đo cached Nest11.2.7/platform-express11.2.7/Express5.2.1/
body-parser2.3.0/router2.2.0: JSON lỗi với Content-Type application/json
trả400/INTERNAL_ERROR tại cả12 operation trong bảng (kể cả GET/HEAD với body),
URI `%E0%A4%A` tại9 operation có parameter cũng400/INTERNAL_ERROR trước
controller/ownership. HEAD không truyền body, kể cả lỗi. Đây là các fixture
đã thử, không khẳng định mọi malformed request đều400. Route không tồn tại
trả404/NOT_FOUND trong control lab, không thêm mã đó vào mọi404 job sở hữu.

| Operation | Success | Nhánh HTTP lỗi được mô tả |
|---|---|---|
| GET health |200 `{ok:true}` |400 parser/500 |
| GET session |200 `{csrf,supported,verified,contact,productName,heartbeatSeconds}` |400 parser/429/500; cookie thiếu/hết hạn tạo mới, không403 |
| POST jobs/analyze |202 `{jobId}` |400/403/429/503/500 |
| GET jobs/{id} |200 status job |400/403/404/410/500 |
| GET jobs/{id}/preview |200 JPEG hoặc PNG |400/403/404/410/500;404 có JOB_NOT_FOUND JSON hoặc tệp không mở được/body rỗng |
| POST jobs/{id}/prepare |202 `{jobId,state}` |400/403/404/409/410/429/503/500 |
| POST jobs/{id}/heartbeat |201 `{ok:true}` |400/403/404/410/500 |
| POST jobs/{id}/release |201 `{ok:true}` |400/403/404/500; không thêm410 |
| POST jobs/{id}/cancel |201 `{ok:true}` |400/403/404/410/500; metadata hết hạn→JOB_EXPIRED |
| POST jobs/{id}/download-ticket |201 `{url,expiresIn}` |400/403/404/410/429/500 |
| GET downloads/{ticket} |200/206 MP4 binary |400 parser/403/410/416/429/503/500 |
| HEAD downloads/{ticket} |200/206, không body |400 parser/403/410/416/429/500, mọi response không body |

Status có `id,state,errorCode,title,duration,metadataAcceptedAt,
metadataExpiresAt,items,previewUrl,mode,serverMeaning`. Tám state:
analyzing/selectable/queued/preparing/ready/failed/cancelled/expired. Title,
duration, errorCode, previewUrl và hai mốc metadata có thể null; formats có
size nullable. Hai timestamp là ISO date-time hoặc null. Metadata lựa chọn
hết hạn đồng bộ ở now≥deadline, tối đa120000ms từ acceptedAt, không renew
qua heartbeat/updatedAt/ownerUntil; chi tiết R9 phía dưới. Job terminal không
do metadata guard vẫn có thể trả200 với items rỗng/preview null. Không công
bố cleanup marker, token, source URL hoặc đường dẫn filesystem.

Analyze body strict có URL string tối đa2048; URL HTTPS, platform allowlist,
không userinfo/hash/port khác chuẩn được URL parser giữ lại. Prepare strict
có itemId/idempotencyKey UUID, formatId≤80 và pattern
`^[\w-]+(?:\+[\w-]+)?$`; job path id UUID. Ticket path64 ký tự hex. Prepare
idempotent có thể trả state hiện tại, không cam kết mọi202 đều queued.
Ticket URL là relative `/api/v1/downloads/<ticket>`; expiresIn tính bằng giây.

Cookie `ws_session` xác thực ownership, không phải job ID. Origin bắt buộc
cho public POST; security schemes mô tả cookie và CSRF header. Với bốn POST
có body-CSRF fallback, alternative cookie-only trong OpenAPI **vẫn cần csrf
trong body** cùng Origin hợp lệ; OpenAPI3 không biểu diễn điều kiện chéo
security/body nên mô tả và `x-csrf-alternatives` ghi rõ, không cho bỏ CSRF.
Body strict của analyze/prepare không nhận thêm csrf. Cookie/header secret
không có example trong tài liệu.

GET có Accept-Ranges/Content-Length/Content-Type video/mp4, Content-Range
cho206 và `bytes */size` cho416, Content-Disposition attachment và
Cache-Control private,no-store. HEAD kiểm tra ticket/session/rate/asset và
Range, không mở/stat file hoặc reserve budget/tạo lease; không mô tả
Content-Disposition hay503 budget. HEAD có Cache-Control no-store từ
middleware,200/206 Content-Length là độ dài range/file dù không có body;
416 có Content-Range. Mã lỗi HEAD nằm trong `x-error-codes` tài liệu, không
phải header HTTP mới. GET lỗi sau khi đã gửi headers có thể đóng stream;
không cam kết JSON thay cho stream đã bắt đầu. `server_finished` không
chứng minh trình duyệt lưu tệp.

Sinh/kiểm snapshot offline phần26: README6.16 và `scripts/test-admin-contract.ps1`
(lịch sử đã nghiệm thu, không rerun26 trong27). HTTP đối chứng hiện hành:README6.17.
Baseline3PASS/16FAIL thiếu hợp đồng→final19PASS/0FAIL cùng expected;
typecheck API/shared/tests-p24 exit0. Không chạy main/listen/health/session/
status/job/worker để sinh docs. Đây là metadata/Swagger/schema contract tests
với constructor/socket deny doubles; chưa kiểm HTTP GET/HEAD/backend live,
admin/ads OpenAPI đầy đủ hoặc tải nền tảng/public.

## Hợp đồng OpenAPI admin/ads — phần26,03/10/2026

Các status dưới đây là metadata/controller và nhánh AppError theo source.
POST mặc định201, kể cả login/logout dùng `@Res`; cached Nest được kiểm
bằng hàm chọn status thật và source router, không gọi HTTP business.
Tất cả response theo middleware `Cache-Control: no-store`.

| Operation (base `/api/v1`) | Success/schema | Bảo vệ | AppError theo source |
|---|---|---|---|
| GET ads |200 `AdsSelection` hoặc null |guest cookie; không CSRF |403 SESSION_REQUIRED |
| POST ad-events |201 `{ok:true}` |guest+Origin+CSRF header |400 INVALID_REQUEST;403 SESSION_REQUIRED/CSRF_INVALID;404 CAMPAIGN_UNAVAILABLE;429 RATE_LIMITED |
| POST admin/login |201 `{ok:true}` +Set-Cookie |guest+Origin+CSRF header; không cần admin |400 INVALID_REQUEST;403 SESSION_REQUIRED/CSRF_INVALID/LOGIN_FAILED;429 RATE_LIMITED |
| POST admin/logout |201 `{ok:true}` +clear cookie |guest+Origin+CSRF; không cần admin |403 SESSION_REQUIRED/CSRF_INVALID |
| GET admin/dashboard |200 `AdminDashboard` |chỉ admin cookie |403 ADMIN_REQUIRED |
| GET admin/settings |200 `AdminLimits` |chỉ admin cookie |403 ADMIN_REQUIRED |
| PUT admin/settings |200 `AdminLimits` |admin+guest+Origin+CSRF header |400 INVALID_REQUEST/PLATFORM_NOT_VERIFIED;403 SESSION_REQUIRED/CSRF_INVALID/ADMIN_REQUIRED |
| GET admin/campaigns |200 `AdminCampaignList` |chỉ admin cookie |403 ADMIN_REQUIRED |
| POST admin/campaigns |201 `AdminCampaign` |admin+guest+Origin+CSRF header |400 INVALID_REQUEST;403 SESSION_REQUIRED/CSRF_INVALID/ADMIN_REQUIRED |
| PUT admin/campaigns/{id} |200 `AdminCampaign` |UUID path required; admin+guest+Origin+CSRF header |400 INVALID_REQUEST;403 SESSION_REQUIRED/CSRF_INVALID/ADMIN_REQUIRED |
| DELETE admin/campaigns/{id} |200 `{ok:true}` |UUID path required; admin+guest+Origin+CSRF |400 INVALID_REQUEST;403 SESSION_REQUIRED/CSRF_INVALID/ADMIN_REQUIRED |

Các operation có500/INTERNAL_ERROR cho unknown/datastore Error và `default`
safe envelope cho HttpException giữ status theo classifier phần25.
`x-app-error-codes` chỉ liệt kê AppError của nhánh nghiệp vụ, không thu hẹp
`ApiError.error.code` thành enum loại mất lỗi framework cùng status.
Update/delete row không tồn tại không có AppError404 trong source: không
bịa NOT_FOUND/CAMPAIGN_UNAVAILABLE cho nhánh đó. Parser admin/ads chưa đo
HTTP phần26; không suy mọi malformed request đều400 hoặc copy toàn bộ
HttpException unit statuses vào từng endpoint.

Login, campaign, limits và ad-event body strict: trường `csrf` thêm vào body
bị validator từ chối; request thành công phải dùng `x-csrf-token`. Hàm auth
có body fallback nhưng không vượt strict body. Logout và DELETE campaign
không parse strict body, nhận `{csrf}` khi thiếu header: alternative
cookie-only trong security **vẫn yêu cầu csrf trong body và Origin hợp lệ**.
Admin GET không cần guest/CSRF; login/logout không cần token admin hiện có.
Không có cookie/token example hay mật khẩu thật trong snapshot.

GET ads có query `placement` tùy chọn, đúng chuỗi `sponsor` chọn sponsor;
thiếu/giá trị khác chọn banner, không báo enum-invalid. Output projection
`id,title,imageUrl,targetUrl,linkType,placement` hoặc null. Sponsor chọn
campaign enabled/đúng lịch trước atomic Redis SET NX EX600 theo phiên cookie;
không campaign không tiêu claim, banner không chịu cooldown. GET có tác
dụng phụ bảo thủ: mất response vẫn tiêu claim, không prefetch/retry để né.
Phần26 chỉ đối chiếu source/pure placement expression, không chạy Redis
hay chứng minh atomic claim mới. Ad-event strict UUID `id,campaignId`,
type impression/click, rate60/60s/phiên và createMany skipDuplicates giữ
event đầu tiên. Login giữ rate5/300s/IP, scrypt và Redis admin token3600s.

Campaign input strict: title1..120, imageUrl optional-nullable, targetUrl
HTTPS≤2048, linkType sponsored/affiliate, placement banner/sponsor, enabled
boolean, startsAt/endsAt ISO date-time theo Zod, weight integer1..100.
Production còn kiểm startsAt<endsAt và HTTPS refinement (protocol/userinfo/
port/host prefixes); OpenAPI3 structural schema không biểu diễn hết các
refinement. Tests gọi `campaignSchema`/`httpsUrl` production, không copy
validator; không xem URL validator này là DNS/egress/SSRF nghiệm thu.
Output campaign gồm cả10field scalar Prisma; imageUrl nullable được trả,
DateTime serialize ISO; persisted linkType/placement vẫn string, không
thu hẹp thành input enums. Ads linkType cũng persisted string.

`AdminLimits` có đúng17field required/strict; không defaults/patch body:

| Field | Bounds/type |
|---|---|
| maxDuration |integer1..600 |
| maxBytes |integer1024..209715200 |
| maxInputBytes |integer1024..262144000 |
| analyzeTimeout / prepareTimeout |integer5..30 /10..180 |
| sessionTtl / releaseGrace / readyTtl |integer5..3600 /1..120 /5..600 |
| sweepSeconds / leaseTtl / retryGrace |integer1..30 /30..90 /1..120 |
| transferMax |integer5..1800 |
| monthlyBytes |integer0..9007199254740991 |
| diskStopPercent / queueLimit |integer10..80 /1..20 |
| acceptJobs |boolean |
| enabledPlatforms |array tối đa4; youtube/tiktok/facebook/x; phải thuộc VERIFIED_PLATFORMS runtime khi PUT |

GET settings trả limits sau parse/filter verified; PUT còn kiểm động
VERIFIED_PLATFORMS và ghi audit trong transaction. OpenAPI mô tả bằng
extension, không đóng enum theo environment lab. Không đổi hard caps.

Dashboard chỉ có groups `{state,_count}`, leases `{state,_count,_sum:{bytes}}`,
budget `{month,charged}`, failed `{id,platform,errorCode,updatedAt}`,
events `{campaignId,type,_count}`, queue `{waiting,active}`, verified string[].
Bytes và charged được service đổi BigInt thành string (kể cả số vượt
MAX_SAFE_INTEGER); null sum bytes thành "0", errorCode nullable, updatedAt
ISO date-time. Persisted state/platform/type vẫn string. Không thêm CTR,
time aggregation, CPU/RAM hay doanh thu vào response hiện có.

Thực chạy26: baseline3PASS/20FAIL thiếu contract → cùng matrix23PASS/0FAIL;
typecheck API/shared/tests-p26 exit0, refs/inventory/canonical preservation
và factory/snapshot khớp. Pure Zod validators cùng3expression production
trích nguyên AST (ad-event/verified/placement), output/schema fixtures và
Prisma DMMF được khai báo. Không11HTTP success, auth/datastore/ads cooldown
runtime mới hay parser admin/ads proof. Xem README6.16 và TEST_REPORT.
Frozen validators24/25 ràng buộc snapshot nguồn ở thời điểm cũ: giữ lịch sử,
không sửa để ép current26 xanh; suite/evidence26 kiểm nguồn hiện hành.

## HTTP đối chứng admin/ads — phần27,03/10/2026

Thực chạy **36case/79requests PASS**, có ít nhất1success HTTP đúng status/
schema/headers ở mỗi11operation admin/ads. GETsession là1request fixture
thêm ngoài11operation target. Dùng Nest/AppModule/controllers/services/auth/
SafeErrors/middleware production theo main với PostgreSQL/Redis thật trong
lab riêng; không main.ts, worker, job API hoặc Internet. Factory document
khớp canonical snapshot26 trong cùng app nhưng không sinh/đổi snapshot mới.
AdminHTTP cũ/tests-admin và9P20 vẫn là lịch sử, không chạy lại các suite đó.

Đã đo login201, cookie HttpOnly/SameSite=Lax/path=/api (Secure=false của lab
loopback), Redis adminTTL3600s và logout201 thu hồi token/clear cookie.
Ba admin GET chỉ cookie admin, không guest/Origin/CSRF đều200; sau logout
đều403 ADMIN_REQUIRED. Profile thiếu guest/admin/Origin/token và header sai
ưu tiên body đúng trả403 theo nhánh source. Body strict login/settings/
campaign/ad-event thêm csrf trả400; login bodyfallback-only cũng400 sau
CSRF vì strict body. Logout/DELETE nhận bodycsrf+extra khi khôngheader,
header đúng+bodyextra cũng thành công; không bỏ Origin/token. Các controls
là profile đại diện và các route được liệt kê trong raw, không toàn Cartesian
mọi header/body/auth combination trên từng operation.

Campaign create/list/update/delete được đối chiếu DB/audit actors/actions,
imageUrl omitted→null, explicitnull, ISO Date. PUTsettings17field khớp
GET/DB; reject cap/fraction/missing/extra/strictcsrf và PLATFORM_NOT_VERIFIED
không đổi settings/audit. PUT/DELETE invalidUUID400 trước auth; UUID hợp lệ
nhưng rowmissing trả500 INTERNAL_ERROR (Prisma P2025 qua SafeErrors), không404.
Không đổi validator/classifier/auth để ép PASS.

GETads guest-only/noCSRF trả banner projection với query thiếu/banner/other,
null khi chưa có campaign hoặc không có sponsor; không seed cooldown/đợi600s/
rerun sponsor race/expiry. Ad-event201, sequential eventUUID retry không
thêm row/đổi impression đầu; click riêng có row. CSRF/strictbody/UUID/type/
campaign-unavailable lỗi không insert; dashboard thấy2events thật.
Login dùng đúng5requests chạm rate branch, event counter7 dưới60; không
flood hoặc nghiệm thu429/rate policy mới trong27.

Dashboard fixture DB trực tiếp gồm3jobs/1asset/2leases/1budget, không tạo
media/file/queue/worker/transfer. Dùng persisted fixture state/platform để
kiểm string, failed.errorCode null/khácnull, DateISO và bytes/charged strings
9007199254740993/9007199254740995 vượt safeinteger; zero bytes là "0".
Đây là aggregation/serialization proof, không lifecycle hoặc tải nền tảng.
Settings/budget snapshot được restore deepEqual trong finally; chỉ fixture
IDs/actor/keys được dọn, queue waiting/active0 giữ nguyên. Password/hash/
cookie/CSRF/token/HMAC chỉ memory/redact, không raw credential URL.

Lab mới `wed-snap-admin-http-lab`:1cached node+PG+Redis, internal network/
noports/privatePID/node sourceRO/rootfsRO, tổng giới hạn800MiB. Guards
resolved+actual và current_database/cluster/address/Redis CLIENT INFO db15/
run_id trước migration/fixtures; clientgenerate tmpfs private, migration
chỉ DB wed_snap_admin_http_test. Lượt guard đầu0HTTP lệch inet::text /32 là
harness, đã sửa host(inet) và giữ raw riêng; baseline business có thể PASS
và thực tế36/0, không ép runtime FAIL. Typecheck API/shared/tests-p27 exit0;
lab đã removed,2volumes/logs và frozen24–26 giữ. Chờ audit độc lập27.

Chưa chứng nhận parser admin/ads malformed faults, TLS/Secure=true/public,
production load/Internet/browser/native viewability/lifecycle/main apply.
Không toànR8/P2/P4/P0–P6. README6.17/TEST_REPORT có commands/evidence.
Validator24–26 frozen ràng buộc docs/source thời điểm cũ; bảo toàn artifact
và hashes, không sửa hoặc rerun chúng để ép docs27 khớp SHA cũ.

## IP và rate limit (R1/R2)

API dùng danh tính IP theo từng request tại `security/client-ip.ts`; Express `trust proxy` vẫn tắt. Compose chỉ định `TRUSTED_PROXY_HOSTS: web` cho API. Chỉ địa chỉ peer socket khớp IP của service được cấu hình mới có quyền chuyển tiếp **một IP hợp lệ** qua `X-Forwarded-For`. Resolver nội bộ cache 5 giây, timeout 1 giây; DNS lỗi sau khi cache hết hạn loại địa chỉ tin cậy cũ, quay về IP socket. Không tin cả subnet private, số hop, hoặc header `Forwarded`/`X-Real-IP`. Chuẩn hóa IPv4-mapped IPv6 để cùng IP có một bucket.

Vite ghi đè `X-Forwarded-For` bằng peer socket thật và bỏ `Forwarded`, `X-Real-IP`, `X-Forwarded-Host`, `X-Forwarded-Proto` do khách gửi. Gọi trực tiếp API từ peer khác không được đổi bucket bằng header giả. Cấu hình trống không tin forwarding. Tên proxy/IP chính xác có thể cấu hình bằng Compose override; không dùng wildcard/CIDR. Thiết kế hiện hỗ trợ đúng **một proxy**. Nếu thêm reverse proxy ở P5, phải thiết kế lại ranh giới và chạy lại test trước khi tin header; xem [hướng dẫn Express](https://expressjs.com/en/guide/behind-proxies/). Không suy từ IP socket sau Docker/NAT thành địa chỉ gốc bên ngoài NAT.

| Thao tác | Hạn mức cố định | Thời điểm chặn |
|---|---|---|
| Tạo session mới | 10/60 giây/IP | Trước insert Session; cookie hợp lệ chỉ đọc, không tiêu hạn tạo |
| Analyze | 10/60 giây/phiên và 30/60 giây/IP | Trước admission và insert DownloadJob |
| Login | 5/300 giây/IP | Dùng chung qua các cookie; trước xác thực mật khẩu |
| Cấp download-ticket | 10/60 giây/phiên và 5/60 giây/job | Sau kiểm tra owner/ready, trước insert DownloadTicket |

Counter Redis tăng nguyên tử, cửa sổ TTL bắt đầu ở lần đầu; các lần bị từ chối vẫn tính vào bucket đã kiểm tra, không tự retry. Vượt rate trả **429 `{error:{code:"RATE_LIMITED"}}`**, không tạo row mới. Admission đầy cũng trả 429 nhưng code **`QUEUE_FULL`**, không được coi là bằng chứng rate limit. Hạn tạo ticket không áp dụng lại cho request Range: dùng cùng ticket vẫn theo TTL/lease cũ và hạn download 60 request/phút/phiên hiện có. Không thay vòng đời tệp hay media limits.

| Endpoint | Dữ liệu/ý nghĩa |
|---|---|
| POST `/jobs/analyze` | `{url}` → 202 `{jobId}`; HTTPS allowlist, rate limit, admission |
| GET `/jobs/:id` | state, title, duration, items/formats, previewUrl, errorCode, metadataAcceptedAt/metadataExpiresAt (ISO hoặc null); chỉ chủ phiên; metadata selectable hết hạn trả410 |
| GET `/jobs/:id/preview` | ảnh được worker kiểm tra magic và giới hạn 2 MiB, qua egress; không lộ signed URL |
| POST `/jobs/:id/prepare` | `{itemId,formatId,idempotencyKey}` →202; IDs được server cung cấp, key UUID |
| POST `/jobs/:id/heartbeat` | gia hạn owner hợp lệ; không kéo dài metadataTTL hoặc ready TTL; selectable hết hạn trả410 |
| POST `/jobs/:id/release` | bắt đầu grace |
| POST `/jobs/:id/cancel` | hủy xử lý; không xóa file đang có lease |
| POST `/jobs/:id/download-ticket` | URL ticket ngắn hạn, gắn owner + lựa chọn; nhiều Range được phép |
| GET `/downloads/:ticket` | MP4 attachment, 200/206; lỗi403/410/416/429/503/500 theo nhánh; có transfer lease/reservation |
| HEAD `/downloads/:ticket` | 200/206, body rỗng; lỗi403/410/416/429/500, không503 budget, không lease/reservation |
| GET `/ads?placement=banner\|sponsor` | session cookie hợp lệ; banner chọn campaign; sponsor atomic grant tối đa1/600s/phiên, còn lại null |
| POST `/ad-events` | `{id,campaignId,type}`; UUID event dedup, type impression/click |
| POST `/admin/login` | `{email,password}`; giới hạn 5 lần/5 phút/IP, scrypt |
| POST `/admin/logout` | thu hồi token cookie |
| GET `/admin/dashboard` | counts theo state, lease bytes, budget, queue, lỗi đã che URL, events campaign |
| GET `/admin/ad-statistics?from=…&to=…` | window UTC và impressions/clicks/CTR theo campaign, adminCookie/noCSRF, tối đa90×24h; bỏ cả hai→7×24h đến servernow |
| GET/PUT `/admin/settings` | toàn bộ object limits, schema strict, bounded, audit |
| GET/POST `/admin/campaigns` | danh sách/tạo campaign |
| PUT/DELETE `/admin/campaigns/:id` | cập nhật toàn bộ/xóa, audit |
| GET `/health` | DB và Redis ping |

GET sponsor giữ nguyên route/method/response (`Ad` hoặc `null`) nhưng có tác dụng phụ cooldown bảo thủ: xác thực session từ cookie, chọn campaign enabled/đúng lịch trước, rồi Redis `SET ads:sponsor:<session-hash> 1 NX EX 600`. Không dùng ID phiên do khách cung cấp. Các tab cùng cookie dùng chung claim; banner không đọc/tiêu/gia hạn claim; không campaign hợp lệ không tiêu claim. Khi response bị mất, bị ad blocker chặn sau cấp grant hoặc tab đóng, cooldown vẫn tiêu; không refund và không tự retry để mở hộp khác. Không dùng GET này để prefetch. API chính gửi Cache-Control no-store. GET không thêm CSRF POST; đây là ngoại lệ có tác dụng phụ được ghi rõ, không thay chính sách CSRF của ad-events/các mutation khác. Redis lỗi trả lỗi bình thường; Home bỏ qua lỗi ads để luồng tải tiếp tục.

POST ad-events giữ cookie+Origin+CSRF, rate60/phút/phiên và event UUID dedupe. Insert chống trùng tại DB (`createMany` với `skipDuplicates`), giữ event đầu tiên, kể cả retry đồng thời/đổi type; không ghi đè campaign/type của ID cũ. Lỗi thống kê không được cản tải.

Campaign: `title`, `imageUrl` (HTTPS hoặc null), `targetUrl` HTTPS, `linkType` sponsored/affiliate, `placement` banner/sponsor, `enabled`, `startsAt`, `endsAt` (ISO8601), `weight` 1..100. Không nhận JavaScript/HTML. Banner hiện dùng URL ảnh HTTPS; không có endpoint upload file trong bản local này.

Settings gồm `maxDuration`, `maxBytes`, `maxInputBytes`, `analyzeTimeout`, `prepareTimeout`, `sessionTtl`, `releaseGrace`, `readyTtl`, `sweepSeconds`, `leaseTtl`, `retryGrace`, `transferMax`, `monthlyBytes`, `diskStopPercent`, `queueLimit`, `acceptJobs`, `enabledPlatforms`. Giá trị cụ thể/trần trong `packages/shared/src/core.ts`. Không cho admin bật nền tảng ngoài `VERIFIED_PLATFORMS`.

## Thống kê quảng cáo theo khoảng thời gian — phần30, chỉ lab đã kiểm chứng

GET `/api/v1/admin/ad-statistics` dùng cookie admin hiện hành; thiếu/hết hạn→403 `{error:{code:"ADMIN_REQUIRED"}}`. GET không yêu cầu guest cookie/Origin/CSRF, không tạo Session, không ghi settings/budget/audit/event. Auth được kiểm trước query. Giữ `Cache-Control: no-store` và error envelope/filter hiện hành.

`from` và `to` cùng bỏ hoặc cùng có: string scalar tối đa64ký tự, ISO datetime có timezone (`Z` hoặc offset), ngày lịch hợp lệ; URL-encode dấu`+` của offset. Chuẩn hóa UTC; khoảng **[from,to)** tính từ **AdEvent.createdAt**, `from<to`, tối đa **90×24giờ** (đúng90ngày được phép). Reject query key khác/array/duplicate/ngày không tồn tại/no timezone/missingone/equal/reversed/overlimit→400 `INVALID_REQUEST`. Không liên quan lịch `startsAt/endsAt` của campaign. Bỏ cảhai→server chốt `to=now`, `from=to−7×24giờ`, trả đúng window đã dùng. Một cặp rỗng không tương đương bỏquery.

200 JSON (số liệu dưới đây là fixture lab, không phải lượt quảng cáo thật):

```json
{
  "window": {"from":"2026-01-01T00:00:00.000Z","to":"2026-01-02T00:00:00.000Z","timezone":"UTC"},
  "rows": [
    {"campaignId":"11111111-1111-4111-8111-111111111111","title":"p30-A","impressions":2,"clicks":3,"ctrPercent":150},
    {"campaignId":"22222222-2222-4222-8222-222222222222","title":"p30-B","impressions":0,"clicks":1,"ctrPercent":null}
  ]
}
```

Rows gồm **mọi campaign hiện có**, cảdisabled/0events, theoid tăng dần; nếu chưa có campaign→`rows:[]`. Chỉ đếm `type=impression/click`; kiểu persisted khác bỏ. `impressions/clicks` số nguyên≥0; `ctrPercent=clicks/impressions×100`, không clamp/round trongAPI, null khiimpressions0 (kể cảclick-only). UIhiện“—” cho null, format1chữsố thập phân vàwindowUTC servertrả; dữ liệu/label cũ được xóa khi đổiwindow/loading/invalid. Không dùng dashboard lifetimecounts làm thống kê window.

500 `INTERNAL_ERROR` cho unexpected/datastore exceptions theo SafeErrors; không bịa404campaign hoặc403CSRF/rate mới cho GET. OpenAPI default giữ phân loại framework hiện hành; không tuyên bố mọi parserfault của endpoint mới đã thử hoặc đều400. Snapshot/HTTP/browser/DB lab30 và typecheck đã được audit30 nhận scoped theo bằng chứng lịch sử; **main chưa apply**. Lệnh tại README6.20/TEST_REPORT. Schema/Prisma migrations/auth/rates/dedupe cũ không đổi.

**Giới hạn dữ liệu raw — phần31 chức năng đã audit nhận scoped; phần32 đã nghiệm thu tài liệu/F31.1 đóng.** Worker đã có TTL AdEvent **30×24giờ**, tính UTC theo `createdAt < now−30×24giờ`; đúng cutoff được giữ ở lượt đó. Source31 giới hạn mỗi sweep một batch tối đa500 IDs theo `createdAt,id`, xóa đúng IDs và kiểm lại cùng cutoff; phần dư chờ lượt sau. TTL áp dụng mọi type, kể cả type khác impression/click. Khi cutoff của lượt sau tiến lên, event từng đúng cutoff có thể thành eligible; 500 là giới hạn batch, không phải chứng nhận tốc độ/scan/lock hoặc thời hạn purge toàn backlog.

Endpoint vẫn nhận window tối đa90ngày và chỉ aggregate **raw rows còn tồn tại**. Không tái tạo lịch sử đã purge, không cung cấp lifetime statistics; counts0 trong window vượt retention không chứng minh không từng có lượt xem/click thật. Rows expired còn chờ batch cũng có thể xuất hiện trước lượt purge kế tiếp. Payload/query/window/CTR và UI không đổi. Lab31 có control HTTP production/PG/Redis trước-sau purge, không chạy lại matrix/browser30 hoặc chứng nhận main đã áp dụng source31.

## Metadata lựa chọn — R9, source đã sửa; migration mới chỉ áp dụng lab03/10/2026

| Hạn | Mốc / chính sách |
|---|---|
| Metadata analyze chưa dùng | `metadataAcceptedAt` được processor ghi khi chấp nhận kết quả trong khóa/transaction; `metadataExpiresAt` tối đa acceptedAt+120000ms. Hết hạn tại now≥deadline |
| Hạn sớm của nguồn | Chỉ nhận `sourceExpiresAt` từ adapter tin cậy: Unix epoch milliseconds nguyên an toàn; lấy min với120s. Hạn đã qua lúc publish→expired/JOB_EXPIRED, không selectable. Python production hiện không trả trường này; không đoán signed URL/query |
| Selectable cũ thiếu mốc | Một trong hai trường null→hết hạn bảo thủ. Không backfill bằng updatedAt/ownerUntil; cần analyze mới |
| Owner/page | sessionTtl/releaseGrace hiện hành; heartbeat chỉ đổi ownerUntil/releaseAt, không đổi hai mốc metadata |
| Ready / transfer | readyTtl600s và transfer/Range deadline/lease hiện hành độc lập; không expire prepare đã nhận hợp lệ chỉ vì metadata hết hạn |
| Lịch sử | Title/duration và retention hiện hành không phải cache lựa chọn; R9 không đổi retention24h |

Status, preview, heartbeat và prepare kiểm tra đồng bộ dưới job lock, không
đợi sweeper30s. Selectable hết hạn chuyển expired/errorCode JOB_EXPIRED,
xóa MediaItem/formats và sourceUrl; commit rồi trả410 `{error:{code:"JOB_EXPIRED"}}`.
Status không trả lại lựa chọn/preview expired; preview kiểm tra và mở handle
trong cùng khóa, `Cache-Control: private, no-store`. Sweeper dùng cùng guard,
dọn preview/cache theo lifecycle. Cancel job metadata đã expired cũng trả410
JOB_EXPIRED; cleanup vẫn pending độc lập cancelRequested. Ownership, Origin/
CSRF và rate/admission vẫn áp dụng; 404/403/429 không được đổi thành410.

Prepare kiểm tra TTL trong transaction giữ job lock cùng transition queued.
Hết hạn chưa prepare→không enqueue/asset/adapter prepare; repeated status/
heartbeat/prepare không hồi sinh. Queued/preparing/ready đã được nhận trước
hạn vẫn xử lý; cùng key/format retry sau metadata deadline dùng job cũ, không
tạo thêm asset/invocation. Format xung đột vẫn409. Ticket/stream dùng asset và
transfer lease hiện hành, không đọc metadataTTL. Analyze mới tạo job và mốc mới.

Schema thêm hai cột nullable/index bằng migration additive
`202610030001_metadata_deadline`; không backfill. Migration/client chỉ đã chạy
trong `wed_snap_metadata_test` và tmpfs lab; **main chưa migrate/apply**. Xem
README6.12/TEST_REPORT cho lệnh và bằng chứng local. Không coi fixture
sourceExpiresAt/byte8192 là signed URL hoặc tải nền tảng thật.

## Cancel và cleanup — phần23, main chưa migrate/apply

POST `/jobs/:id/cancel` giữ cookie ownership/Origin/CSRF và201 `{ok:true}`
cho normal cancel. Lặp trên cancelled/cancelRequested=true giữ201, không
ghi lại updatedAt/owner/metadata deadline/cleanup marker. Metadata hết hạn
(kể cả cancel là endpoint đầu tại120000ms) commit expired rồi410 JOB_EXPIRED;
status-expired→cancel cũng410, không revive. Session/CSRF/ownership errors
giữ403/404 như cũ.

`cancelRequested` chỉ là yêu cầu hủy. `cleanupCompletedAt` nullable là nội bộ
DB, không thêm field response API:NULL pending/unknown, chỉ ghi sau rm folder
thành công và MediaItem/cache được xóa. TerminalNULL được sweeper lấy dù
cancelRequested=true/noasset/no worker. LegacyNULL được dọn một lần, không
backfill từ updatedAt/flag hủy. Lỗi rm/commit giữNULL để retry lượt sau, log
cleanup_failed chỉ jobId/code; lỗi một job không chặn job khác.

Sweeper giữ job→asset locks, terminal/deleting admission fence, kiểm tra
token/process/transfer lease trước xóa. Preparing phải dừng process trước
cleanup; live transfer file giữ đến lease/finalize theo lifecycle hiện hành.
Hủy ngăn ticket mới, transfer đã bắt đầu vẫn tiếp tục độc lập. Done terminal
không rm/gia hạn updatedAt lặp. Purge24h vẫn dựa updatedAt, thêm cleanup done;
title/duration lịch sử không phải cache lựa chọn.

Migration additive `202610030002_cleanup_completed` thêm nullable timestamp/
index chỉ apply DB `wed_snap_cleanup_test` và client tmpfs trong phiên03/10;
R9 migration cũng có trong DB cleanup mới. Main chưa kiểm chứng migration/
client/source mới. Xem README6.13/TEST_REPORT cho lab guards/lệnh/doubles.

Lỗi: `{error:{code}}`. 400 INVALID_URL/UNSUPPORTED_PLATFORM/UNSUPPORTED_CONTENT/FORMAT_UNAVAILABLE/INVALID_REQUEST; 403 SESSION_REQUIRED/CSRF_INVALID/ADMIN_REQUIRED/LOGIN_FAILED; 404 JOB_NOT_FOUND; 409 IDEMPOTENCY_CONFLICT; 410 JOB_EXPIRED; 416 INVALID_RANGE; 429 RATE_LIMITED/QUEUE_FULL; 503 CAPACITY_UNAVAILABLE. AUTH_REQUIRED/CONTENT_UNAVAILABLE/LIMIT_EXCEEDED/SOURCE_TIMEOUT/WORKER_INTERRUPTED xuất hiện trên trạng thái tác vụ failed. Không lộ stack, đĩa, cookie/header nguồn. Log worker chỉ phase/id/code/byte.

Download policy: tệp MP4 nguồn gộp sẵn hoặc H.264 + AAC qua HTTPS, FFmpeg copy ghép local. Không hỗ trợ HLS/DASH manifest tải bằng FFmpeg, DRM, livestream hoặc conversion. URL source được phân tích lại lúc prepare; format không còn thì lỗi, không fallback vô hạn. Không lưu signed media URLs trong DB. Source post URL bị xóa khi job ready/thất bại/hết hạn.

### Retention worker metrics34 — không đổi hợp đồng HTTP

AuditLog chỉ nhóm actor=`worker` AND action=`worker.metrics` có policy mới30×24h/UTC/strict createdAt<cutoff/≤500 một batch mỗi sweep/ordercreatedAt-id/delete recheck cùngscope-cutoff. Admin settings/campaign audits và mọi nhóm khác giữ nguyên, không có TTL AuditLog chung. Không đổi payload/query/window/CTR/dashboard/OpenAPI/auth hoặc event dedupe. Thêm index `[actor,action,createdAt,id]` bằng migration chỉCREATE INDEX, mới apply ownlab34/main chưa apply.

34PG-helper/manualsweep13PASS/typecheck đã kiểm toán độc lập nghiệm thu scoped/F34.H1coverage đóng64artifacts;33logging scoped/32F31.1đóng/31AdEvent scoped giữ. Đồng bộ bằng chứng lịch sử, không rerun34. Không runtime HTTP mới/worker scheduler/load/main/public/fullR10/P4/P0–P6 từ phần34. README6.23/TEST_REPORT giữ phân biệt explicit clock/real-clock manual sweep và cleanup finally/Stop.

### Worker scheduler35 — không đổi HTTP hoặc source policy

Ownlab35 child entrypoint thật tự boot500/timer500/timer1 với1001eligible,11PASS/0HTTP/một tsc worker-shared-tests35; chỉ fixtureSWEEP_SECONDS2/effectivelimits2, source default30/concurrency1 giữ. Periodic PG rowlock qua4273.065ms/81samples không second retention DELETE trong cửa sổ đã đo; SIGTERM idle actualexit0/connectionsclosed. Không chứng nhận mọi instant/branch/livejobs/lease/inflight shutdown/main cadence/load/SLA/platform/public/fullR10/P3/P4/P0–P6. NoAPI/browser/businessfixtures hoặc đổi auth/schema/OpenAPI/HTTPcontract trong35.

OwnDBwed_snap_worker_scheduler_test/Redis10 server riêng/cached3services800MiB/rootfs-sourceRO/privatePID/internal/noports;4existing migrations/clienttmpfs chỉownlab/main chưaapply. F35.H1PIDs64 native thread failure giữ raw; chỉownlab app192 và cùngexpected/test/source final11PASS, không productionbugfix. Cleanup proof từ Matrixfinally/postEmpty, Stop chỉidentity/config+stop/removeowncontainers giữvolumes/network/raw. README6.24/evidence35;34đãnghiệmthu/F34.H1đóng/35đãaudit nghiệmthu scoped.

Offline35 capture exit0 UTC12:52:53.252/61artifacts, đối chứng actualcoverageSHA exit0 UTC12:53:46.806;1212protectedpaths ngoài6docs/production0. Supplement/live-doc completion sau frozenhandoffcopies giữ riêng. Không HTTP mới hoặc thay hợp đồng từ offlineproof này.
### Worker shutdown36 — không thay HTTP contract

Main.ts sửa hẹp sau baseline thực: await sweep periodic đang chạy trước đóngresources, stopping chặn timer mới/shutdownPromise chung. Ownlab36 V4 cùngexpected/test9PASS2FAIL→11PASS/exit0, tailSessiongone/freshgiữ khichildcònsống; PG/Redis/consumer0 vàpostexit>2fixtureintervalsnochange. Own36StopStoresEmptytrướcstop, cleanupfixturevẫnởMatrixfinally. 35 đãaudit scoped;36chờaudit, rawcácobserverFAILgiữ. Không HTTP mới/đổi schema/contract/auth; snapshot/APIpayload khôngđổi. Chỉfixture2s/emptyjobs/ownDB+Redis9/800MiB/noports/sourceRO; khôngmainapply/default30/load/job-transferinflight/public/platform/fullR10/P3/P4/P0–P6.
