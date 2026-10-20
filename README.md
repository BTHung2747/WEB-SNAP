# WED SNAP

```powershell
cd "D:\WED SNAP"
```

Website tiếng Việt tải nội dung công khai mà bạn có quyền sử dụng. React + Vite + TypeScript + Tailwind; NestJS; PostgreSQL + Prisma; Redis + BullMQ; worker riêng với yt-dlp/FFmpeg. Toàn bộ runtime nằm trong Docker; không cần cài Node, PostgreSQL, Redis, yt-dlp hay FFmpeg trên Windows.

**Trạng thái local:** đã có tải YouTube thật, kiểm thử vòng đời và quản trị. YouTube được bật cho video công khai trong giới hạn; TikTok/Facebook/X và ảnh chưa kiểm chứng, giữ tắt. Đọc [tiến độ](docs/PROGRESS.md), [báo cáo adapter](docs/ADAPTERS.md) và [kiểm thử](docs/TEST_REPORT.md). Chưa deploy public, chưa mua dịch vụ.

## Bản đồ mã nguồn

- `apps/web`: giao diện trang tải và quản trị.
- `apps/api`: phiên, tác vụ, download, quảng cáo và quản trị.
- `apps/worker`: hàng đợi và vòng đời tài nguyên.
- `apps/media`: code lấy/tải video bằng yt-dlp/FFmpeg, gồm luồng YouTube đã kiểm chứng.
- `apps/egress`: proxy kiểm soát kết nối tới nguồn.
- `labs/tiktok/renderer`: thử nghiệm browser TikTok chưa tích hợp vào ứng dụng.
- `tests`: fixture và công cụ nghiệm thu; `docs/evidence`: bằng chứng đóng băng.

Xem [cấu trúc và bảng đường dẫn cũ–mới](docs/STRUCTURE.md). Muốn đọc code tải chính, mở [media_adapter.py](apps/media/src/media_adapter.py).

Một ledger evidence lớn đã được lưu nén nguyên bản để giảm dung lượng; xem [cách kiểm tra và khôi phục](docs/EVIDENCE_ARCHIVES.md) khi cần đối chiếu hồ sơ cũ.

## 1. Chuẩn bị

Mở Docker Desktop, chờ **Engine running**. PowerShell:

```powershell
cd "D:\WED SNAP"
docker version
docker compose version
docker info --format '{{.MemTotal}}'
```

Máy được kiểm tra với engine khoảng 2,84 GiB RAM. Không sửa `.wslconfig`. Worker local cố định concurrency 1; build và test tuần tự. Compose yêu cầu phiên bản hỗ trợ `!override` khi dùng file test (Compose ≥2.24.4).

## 2. Tạo `.env`

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\init-env.ps1
```

Script đọc `.env.example`, tạo mật khẩu PostgreSQL và secret admin ngẫu nhiên; **từ chối ghi đè `.env` đang có**. Nếu tiếp tục một phiên đã có `.env`, bỏ qua bước này. Không chia sẻ `.env`, không commit vào Git. `.env.example` không có mật khẩu mặc định.

Mở `.env` trong trình soạn thảo để cấu hình email `CONTACT_EMAIL` và tên hiển thị `PRODUCT_NAME`. Bản local này đã qua bộ mẫu YouTube: đặt `VERIFIED_PLATFORMS=youtube` nếu tạo môi trường mới; không thêm nền tảng khác trước khi đạt P0. Admin không thể bật nền tảng ngoài allowlist kiểm chứng của môi trường. Cấu hình admin đã lưu trong DB được ưu tiên hơn mặc định `.env`; đổi `.env` không ghi đè cấu hình DB. Khi chuyển IP triển khai, giữ trống và kiểm chứng lại trước khi bật.

Local dùng `APP_ORIGIN=http://localhost:5173`, `COOKIE_SECURE=false`. Khi public HTTPS phải đổi origin và `COOKIE_SECURE=true`. Địa chỉ `127.0.0.1` có thể hiển thị trang nhưng CSRF yêu cầu origin đã cấu hình; hãy dùng **localhost** nhất quán.

## 3. Build, khởi tạo CSDL và khởi động

```powershell
cd "D:\WED SNAP"
docker compose build api
docker compose build egress
docker compose up -d postgres redis egress
docker compose run --rm --no-deps api npm run migrate
docker compose up -d --no-build
docker compose ps
```

`api`, `worker`, `web` dùng chung image nên chỉ build một lần. Dependencies trong image Linux, không bind mount `node_modules` từ Windows. Migration được quản lý trong `prisma/migrations`, không dùng `db push` trên dữ liệu thật. Chạy migration lại là an toàn; không tự reset CSDL.

Địa chỉ:

- Trang tải: [http://localhost:5173](http://localhost:5173).
- Quản trị: [http://localhost:5173/admin](http://localhost:5173/admin).
- Health: [http://localhost:5173/api/v1/health](http://localhost:5173/api/v1/health).
- OpenAPI JSON: [http://localhost:5173/api/docs-json](http://localhost:5173/api/docs-json).
- API qua proxy `/api`. Chỉ cổng web bind `127.0.0.1`; PostgreSQL, Redis, API và egress không publish cổng.

## 4. Tạo admin

Sau khi migration xong, PostgreSQL/Redis đang chạy:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-admin.ps1
```

Nhập email và mật khẩu từ 12 ký tự. Mật khẩu được nhập ẩn, truyền vào container qua stdin, hash scrypt với salt ngẫu nhiên. Không ghi mật khẩu vào argv, `.env`, Git hay tài khoản mặc định. Script từ chối ghi đè admin có sẵn. Đăng nhập tại `/admin`, tạo chiến dịch hoặc điều chỉnh giới hạn. Cần có admin thực do bạn tự tạo; không có mật khẩu test cho môi trường chính.

## 5. Sử dụng và kiểm tra

1. Xem nền tảng **Đã bật** trên trang chủ. Nếu chưa có, đọc báo cáo P0; không bật chỉ vì yt-dlp có extractor.
2. Dán link HTTPS công khai, nhấn **Phân tích link**.
3. Chọn định dạng do nguồn cung cấp. Kích thước chưa biết ghi rõ.
4. Nhấn **Chuẩn bị tải**; worker chỉ chuẩn bị lựa chọn đó.
5. Khi ready, nhấn **Tải xuống**. Kiểm tra file trong danh sách tải của trình duyệt, mở xem hình và tiếng. UI không tuyên bố đã lưu thành công.

Nếu bấm tải trong trình duyệt Codex mà không thấy tệp, hãy mở **http://localhost:5173 trong Chrome hoặc Edge**, dán lại link và thực hiện lại các bước trên. Mỗi trình duyệt có phiên riêng nên không sao chép liên kết tải tạm sang trình duyệt khác. Trong Chrome/Edge, nhấn **Ctrl+J** để xem danh sách tải; tệp mặc định có tên `wed-snap-video.mp4`. Nút tải dùng liên kết trực tiếp; có thể nhấn chuột phải và chọn lưu liên kết. Tệp tạm đã hết hạn cần phân tích và chuẩn bị lại.

```powershell
cd "D:\WED SNAP"
Invoke-RestMethod 'http://localhost:5173/api/v1/health'
docker compose logs --tail 50 api worker
docker stats --no-stream
```

Không có quảng cáo vẫn tải bình thường. Quảng cáo chỉ mở khi nhấn, có nhãn tài trợ, hộp có nút đóng ngay; thống kê nội bộ không xác nhận doanh thu affiliate hay lượt xem YouTube.

## 6. Kiểm thử tự động trên volume riêng

**Dừng stack chính trước để giảm RAM**; dữ liệu vẫn giữ nguyên:

```powershell
cd "D:\WED SNAP"
docker compose stop
docker compose -f compose.yaml -f compose.test.yaml up -d postgres redis egress
docker compose -f compose.yaml -f compose.test.yaml run --rm --no-deps api npm run migrate
docker compose -f compose.yaml -f compose.test.yaml run --rm --no-deps api node_modules/.bin/tsx tests/reset-settings.ts
docker compose -f compose.yaml -f compose.test.yaml up -d --no-build
docker compose -f compose.yaml -f compose.test.yaml run --rm --no-deps api npm test
docker compose -f compose.yaml -f compose.test.yaml run --rm --no-deps worker python3 tests/egress_test.py
docker compose -f compose.yaml -f compose.test.yaml run --rm --no-deps api npm run test:integration
docker compose -f compose.yaml -f compose.test.yaml run --rm --no-deps api node_modules/.bin/tsx tests/admin.ts
docker compose -f compose.yaml -f compose.test.yaml run --rm --no-deps worker node_modules/.bin/tsx tests/lifecycle.integration.ts
docker compose -f compose.yaml -f compose.test.yaml run --rm --no-deps worker node_modules/.bin/tsx tests/deadline.integration.ts
docker compose -f compose.yaml -f compose.test.yaml run --rm --no-deps worker python3 tests/network_policy.py
docker compose -f compose.yaml -f compose.test.yaml -f infra/compose.capacity.yaml run --rm --no-deps api node_modules/.bin/tsx tests/capacity.integration.ts
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-crash.ps1
docker compose -f compose.yaml -f compose.test.yaml stop
docker compose up -d --no-build
```

Stack test tên `wed-snap-test`, địa chỉ `http://localhost:5174`, volumes `test_postgres/test_redis/test_media` riêng. Worker test dùng adapter fixture tạo video thật bằng FFmpeg: **không chứng minh hỗ trợ YouTube**. Script integration có guard origin/môi trường test. Không dùng `down -v` trên stack chính. Xem chi tiết phạm vi và ca còn thiếu trong docs/TEST_REPORT.md.

Test capacity dùng tmpfs 8 MiB riêng để vượt 80%, không làm đầy ổ WSL. Script crash cố ý SIGKILL worker/API của **wed-snap-test**; chỉ chạy sau bộ fixture và trước khi dừng stack test. Không dùng override capacity với `up`. Test lifecycle cần mặc định fixture retryGrace=3; luôn reset-settings trước khi khởi động/restart worker nếu vừa chạy smoke nguồn thật.

## 6.1. Kiểm thử riêng R1/R2, không gọi nguồn thật

API chỉ tin forwarding từ service `web` được khai báo trong Compose; Vite ghi đè header do khách gửi. Không bật `trust proxy=true`. Hạn mới: tạo session **10/phút/IP** (cookie hợp lệ không tiêu hạn tạo), cấp ticket **10/phút/phiên và 5/phút/job**. Analyze vẫn 10/phút/phiên + 30/phút/IP, login 5/300 giây/IP. Xem [chính sách IP và API](docs/API.md). Nếu đổi proxy, dùng tên service/IP chính xác trong `TRUSTED_PROXY_HOSTS`, proxy phải ghi đè header và chạy lại test; cấu hình hiện chỉ hỗ trợ một proxy.

Các lệnh dưới tạo project **wed-snap-rate-test**, DB `wed_snap_rate_test`, Redis DB 15 và volumes có prefix riêng. Image test `wed-snap-rate-test:local` tách khỏi image chính. Không dùng lệnh này để flood stack chính. Chạy từng lệnh xong mới chạy lệnh kế tiếp; worker dừng trong bộ rate test:

```powershell
cd "D:\WED SNAP"
$rateCompose = @('-p', 'wed-snap-rate-test', '-f', 'compose.yaml', '-f', 'compose.test.yaml', '-f', 'infra/compose.rate-test.yaml')
docker compose @rateCompose build api
docker compose @rateCompose up -d postgres redis
docker compose @rateCompose run --rm --no-deps api npm run migrate
docker compose @rateCompose stop worker
docker compose @rateCompose up -d --no-build api web
docker compose @rateCompose run --rm --no-deps api node_modules/.bin/tsc -p tsconfig.tests.json
docker compose @rateCompose run --rm --no-deps api node_modules/.bin/tsx --test --test-concurrency=1 tests/client-ip.test.ts tests/core.test.ts
docker compose @rateCompose exec -T web node_modules/.bin/tsx tests/rate-limit.integration.ts
docker compose @rateCompose run --rm --no-deps api node_modules/.bin/tsx tests/rate-limit.integration.ts --direct
docker compose @rateCompose up -d --no-build worker
docker compose @rateCompose run --rm --no-deps api npm run test:integration
docker compose @rateCompose run --rm --no-deps api node_modules/.bin/tsx tests/admin.ts
docker compose @rateCompose stop
```

Test rate dùng socket loopback khác nhau bên trong container đi qua **Vite thật → API thật**, không dùng X-Forwarded-For giả làm bằng chứng hai IP. Nhánh `--direct` chạy từ container peer khác, chứng minh API không tin header đó. Có kiểm tra row count, flood đồng thời, hai mã 429 khác nhau và dùng lại ticket cho Range. Dữ liệu Range seed chỉ là byte fixture, không chứng minh phát video. `--reproduce` chỉ dành cho baseline **trước sửa**, sẽ không PASS trên bản đã sửa. Không reset DB/flush toàn Redis/down-v; test chỉ xóa các counter rate ở Redis DB 15 sau kiểm tra. Volume vẫn giữ khi stop.

## 6.2. E2E R3/P3: release queued/preparing và worker SIGKILL

Chạy trong PowerShell Windows tại workspace thực tế. Mở Docker Desktop trước;
giữ các stack khác dừng sẵn để tiết kiệm RAM. Bộ lệnh này không start/stop stack
chính, không tạo lại `.env` và không xóa volume. Nếu chưa có `.env`, thực hiện
khởi tạo ở mục 2; nếu đã có thì giữ nguyên. Chạy **tuần tự**, chờ mỗi phase kết thúc:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Check
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Setup
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Release
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Crash
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Regression
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Stop
```

Project cố định `wed-snap-p3-test`; image app `wed-snap-p3-test:local`, proxy
`wed-snap-p3-egress:local`; PostgreSQL `wed_snap_p3_test`, Redis DB **14**.
Named volumes đều có prefix `wed-snap-p3-test_`: `test_postgres`, `test_redis`,
`test_media`, `p3_control`. PostgreSQL/Redis dùng image chính thức được khóa phiên
bản trong Compose. Script kiểm tra cấu hình đã resolve trước thao tác ghi và
kiểm tra labels/image/env/mount của container trước kill; helpers kiểm tra DB
thực tế/origin/Redis trước ghi dữ liệu test. Không thay tiền tố project/DB/volume
hoặc dùng fixture này với cổng 5173.

`Setup` build app rồi proxy riêng, migrate DB test, đặt quyền volume control bằng
container khởi tạo có CHOWN, rồi chạy typecheck toàn tests/backend. Worker runtime
vẫn user node, cap_drop ALL, concurrency 1 và giới hạn 80 process/thread như cũ.
`Release` analyze đạt selectable trước, giữ một child prepare đang sống để assert
job khác queued; sau release chứng minh không chuẩn bị/publish. Ca preparing
quan sát PID/start time/PID namespace và sự kiện xóa partial sau child exit.
`Crash` assert preparing/child/partial trước SIGKILL, xác nhận exit 137, restart
chỉ worker test; chờ process lease rồi dọn, theo dõi **70 giây** để phát hiện
prepare trùng sau BullMQ stalled recovery. Phase này không được rút ngắn thành
test analyzing URL delay cũ.

`Regression` chạy Range bằng runner one-off riêng để không cạnh tranh PID với
FFmpeg trong worker; tạm dừng worker test khi chạy lifecycle/deadline seed trực
tiếp, rồi kiểm tra API SIGKILL giữa transfer. Chỉ container API/worker test bị
kill; client one-off riêng được gỡ sau ca API crash. `Stop` giữ toàn bộ volumes.
Marker điều khiển/record có thông tin phiên test nằm trong volume control riêng,
không xuất vào Git/log. Bộ test chỉ dùng fixture local, không gọi YouTube hoặc
chứng minh hỗ trợ nền tảng. Không chạy lại toàn bộ rate/admin/UI/P0 ở đây.

Log ngày/môi trường/lệnh và giới hạn timeout nằm trong [PROGRESS](docs/PROGRESS.md)
và [TEST_REPORT](docs/TEST_REPORT.md). Khi phase lỗi, script dừng; đọc log/test
container trước khi tiếp tục, không reset DB/flush Redis/down-v/prune để chữa lỗi.

## 6.3. P3 active transfer: mất heartbeat độc lập và đổi budget

Dùng lại project/image/DB/Redis/media P3 riêng ở mục 6.2. Nếu chưa có image/DB
P3, chạy `-Phase Setup` ở mục đó trước; nếu đã có thì các lệnh dưới dùng lại
image và dữ liệu, không build/reset. Docker Desktop phải đang chạy. Thực hiện
tuần tự, không chạy chung một DB test với một suite khác:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Check
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Start
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Typecheck
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase ActiveTransfer
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase LeaseRegression
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Stop
```

`Start` chỉ khởi động project P3 với `--no-build --no-recreate`, inspect runtime
isolation và kiểm tra DB thực/Redis DB14/API health có timeout. Nếu container có
env/mount khác cấu hình test, guard dừng; không bỏ guard để tiếp tục. Stack chính
không được start/recreate/kill bởi các phase này. `ActiveTransfer` chạy one-off
runner riêng để giữ giới hạn RAM/PID worker, seed **byte fixture 32 MiB**, không
phải video/nền tảng. Runner đọc qua HTTP thật và so SHA-256 toàn bộ mẫu.

Trước trigger phải có asset available, lease started và response đang pause,
chưa đóng. Ca heartbeat dừng heartbeat, không gọi release/cancel, chờ ownerUntil
hết hạn và lease.expiresAt được server renew (nhịp thật 15 giây), kiểm tra số byte
server ở giữa reservation. Full stream phải đủ byte; Range lúc đang tải và trong
grace không kéo dài transferDeadline chung. Ca budget đổi monthlyBytes về 0 khi
lease đang sống; request mới 503/CAPACITY_UNAVAILABLE phải giữ nguyên số lease,
tổng reservation và charged, stream cũ vẫn renew và hoàn tất. Finalize/budget,
grace 5 giây và cleanup đều có assertion DB/HTTP/byte, không chỉ chờ sleep.

Settings test được lưu rồi khôi phục chính xác trong `finally`, kể cả khi test
lỗi. Suite chờ không còn lease started khác trước khi seed; không reset DB,
flush Redis hoặc giảm charged của các lượt test trước. LeaseRegression chỉ
Range/lifecycle/cleanup/8 race/deadline; không rerun R1/R2, R3 SIGKILL hoặc ads.
Worker test tạm dừng cho test registry seed rồi khởi động lại trong finally;
`Stop` giữ volumes. Kết quả và raw log trong PROGRESS/TEST_REPORT. Fixture chưa
nghiệm thu upstream faults, browser hoặc public.

## 6.4. P2: concurrent prepare bằng fixture riêng

Dùng harness P3 có sẵn ở mục6.2, không chạy chung DB test với suite khác. Các
phase dưới không build/migrate/reset/kill và không thao tác stack chính. Nếu chưa
có image/DB/control test, thiết lập mục6.2 trước; khi đã có thì dùng lại như sau,
chạy tuần tự trong PowerShell:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Check
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Start
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Typecheck
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase ConcurrentPrepare
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase PrepareRegression
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Stop
```

Guard resolve project/image/DB/Redis/media/control và inspect actual runtime,
named data volumes/network/fixture read-only trước ghi. Project cố định
`wed-snap-p3-test`, DB `wed_snap_p3_test`, Redis14, không dùng stack chính.
Typecheck chạy worker one-off với heap384MiB trong limit768MiB có sẵn để tránh
OOM256MiB của graph tests; không đổi heap runtime hoặc WSL/Docker. Runner riêng
và FFmpeg worker không cạnh tranh PID trong cùng container.

`ConcurrentPrepare` analyze fixture bình thường tới selectable. Blocker giữ
worker ở preparing; hai request target bắt đầu qua barrier và phải chồng thời
gian, cùng202/job. Kiểm tra cùng key và hai key khác nhau/cùng item-format theo
hợp đồng coalesce; retry queued/preparing/ready, xung đột format409. Gate riêng
ghi mọi prepare invocation trước partial (kể cả failed), marker process và
heartbeat; assert đúng1 invocation/asset/completion. Hai sentinel nối tiếp
chứng minh hai vòng sweeper thật khi target vẫn ready/owner hợp lệ. Full262144
byte pattern, prefix/suffix Range cùng ticket và grace cleanup có assertions;
fixture này không chứng nhận video/nền tảng. HTTP10s, toàn ca60s, gate45s,
state10s, sweeper/cleanup8s; finally dọn theo lifecycle và giữ settings/rows/log.

`PrepareRegression` chạy prepare fixture FFmpeg thường, HEAD/full/Range/suffix/
parallel/416; không rerun R1/R2/R3 SIGKILL hoặc active-transfer dài. Stop giữ
volumes. Raw log, cả attempt FAIL và PASS cuối, nằm trong PROGRESS/TEST_REPORT;
audit phần13 đã đóng local, upstream faults/browser/public vẫn chưa nghiệm thu.

## 6.5. Deadline adapter: analyze/prepare treo

Dùng harness P3 riêng có sẵn ở6.2; không chạy cùng DB test với suite khác.
Không build/reset/migrate lại khi đã có image/DB/control. Chạy tuần tự:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Check
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Start
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Typecheck
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase AdapterTimeout
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase PrepareRegression
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Stop
```

Guard resolved/actual project/image/DB/Redis/media/control như6.4. AdapterTimeout
chạy runner **exec trong worker test**, cùng PID namespace để đọc process identity
và cả process group; không tăng heap/container/PID limit runtime. Checker dùng
one-off heap384MiB có sẵn; regression FFmpeg/Range dùng runner riêng.

Suite lưu settings test rồi schema-valid override analyze5s/prepare10s/owner120s/
sweep1s, khôi phục deepEqual trong finally. Analyze treo phải analyzing/child
sống/partial trước deadline; hai ca prepare analyze bình thường tới selectable
rồi preparing/staging. Ca chuẩn nhận TERM và thoát, ca còn lại ghi nhận rồi bỏ
qua TERM với helper cùng group. Để timer runAdapter thật gây SOURCE_TIMEOUT;
không dùng release/cancel/manual kill hoặc HTTP timeout để gây lỗi.

PID/startTicks/namespace/PGID và heartbeat tiến là preconditions. Watch deletion
và `/proc` chứng minh không dọn partial khi group còn sống; failed/code, token/
lease, staging deleted, metadata/completion/invocation và thêm2 sweep iterations
được assert. Bounds: deadline+fallback2s+allowance4s cho death/failure, cleanup8s
sau death; HTTP5s, kiểm tra elapsed suite90s. Không coi timestamp quan sát là
kernel timestamp hay tuyên bố trực tiếp SIGKILL khi chỉ đo group chết~2s.

Finally dọn fixtures qua lifecycle, giữ rows/charged/control/log/volumes/settings
gốc; Stop chỉ test project. Raw mốc/request/process/byte/timeout và kết quả trong
PROGRESS/TEST_REPORT/audit14. Fixture không chứng nhận nguồn thật hoặc timeout/
ngắt mạng upstream; biên byte/duration/browser/public vẫn chưa nghiệm thu.

## 6.6. P2: biên input/output byte và duration bằng logic production

Dùng image/DB/control P3 có sẵn ở6.2, chạy tuần tự trong PowerShell. Các lệnh
này chỉ thao tác project `wed-snap-p3-test`; không chạy cùng suite khác hoặc
dùng với DB chính. Không cần build/migrate/reset hoặc cài công cụ Windows.

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Check
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase LimitsStart
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Typecheck
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase AdapterLimits
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase ByteLimits
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase PrepareRegression
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Stop
```

`LimitsStart` inspect cả container P3 đang dừng và các named volumes trước khi
khởi động API/DB/Redis/proxy test. Kiểm tra DB thật/origin/Redis/API và không còn
analyzing/queued/preparing hoặc active lease trước khi có thể tạo lại worker.
Chỉ worker test được tạo lại nếu còn thiếu bind production; nếu bind đã có thì
`--no-recreate`. Bind `infra` vào `/app/production` chỉ đọc, tách khỏi fixture tại
`/app/infra/media_adapter.py`. Guard đối chiếu path Windows với mount thực
`/run/desktop/mnt/host/d/WED SNAP/infra` của Docker Desktop và SHA-256 source;
không bỏ guard hoặc coi tên image/Compose là bằng chứng isolation đủ.

`AdapterLimits` chạy30 component cases trong worker one-off, nạp chính
`apps/media/src/media_adapter.py`. Chỉ transport/response, extractor/download producer
và kết quả ffprobe được stub; `BoundedYoutubeDL.urlopen`, bounded read, hook,
`valid(info)`, format filter và guard stat/duration sau download đều là code
production. Input cap8192: no Content-Length/chunked tại8191/8192/8193,
Content-Length8193 bị từ chối trước read, hai response và progress fragments
cộng dồn. Đọc tối đa thêm1 byte để phát hiện vượt cap. Output cap4096 dùng file
thật4095/4096/4097 trong `/tmp` container; metadata filesize=null để thực sự đi
qua guard sau download. Metadata filesize4097 có ca riêng FORMAT_UNAVAILABLE
trước download, không thay cho ca guard stat. Duration599/600 được phép,
601/unknown theo policy LIMIT_EXCEEDED; có recheck prepare và probe unknown.

`ByteLimits` chạy HTTP API/worker E2E cùng PID namespace với fixture byte nhỏ.
Analyze bình thường phải tới selectable; fixture prepare giữ gate để assert
preparing/staging, token/lease/owner/child còn sống và actual/reported size khớp.
4095/4096 ready và full HTTP200 đúng byte/hash;4097 failed/LIMIT_EXCEEDED do
processor, không available/completion. Watch partial deletion + `/proc` group
chứng minh group đã ngừng lúc cleanup. Fixture không trả sẵn mã giới hạn.

Schema hard caps600s/200MiB output/250MiB input giữ nguyên; E2E chỉ override DB
test bằng cap8192/4096 hợp lệ, owner120s/ready30s/sweep1s/retryGrace2s rồi restore
deepEqual trong finally. Dọn3 job qua lifecycle, giữ rows/charged/control/log/
volumes. Hai lượt tải hợp lệ charge8191 byte; không reset budget. Stop giữ volumes.

Component dùng response/probe stub và byte fixture không phải video/nền tảng:
không chứng nhận mạng/egress/codec/600s video thật hoặc mọi subprocess topology.
Không ghi file200/250MiB để thử trần vật lý; hard caps được assert qua schema,
logic byte dùng trần test nhỏ. Upstream faults/redirect/rebinding/browser/public
còn thiếu. Raw FAIL trước sửa, source baseline và PASS trong PROGRESS/TEST_REPORT.

## 6.7. P2/P3: socket upstream đóng body sớm và read timeout

Dùng harness/image/DB P3 có sẵn ở6.2/6.6. Chỉ chạy tuần tự; không khởi động,
dừng hoặc reset stack chính để chạy bộ này. Nếu chưa có môi trường P3 riêng,
thiết lập theo6.2 trước; `LimitsStart` kiểm tra actual containers/volumes và
source production RO/hash. Toàn bộ runtime ở Docker, không cài công cụ Windows.

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase LimitsStart
if ($LASTEXITCODE -ne 0) { throw 'Guard/start P3 không đạt' }
try {
    foreach ($phase in @('Typecheck', 'SocketFaults', 'PrepareRegression')) {
        powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase $phase
        if ($LASTEXITCODE -ne 0) { throw "P3 phase $phase không đạt; đọc raw" }
    }
} finally {
    powershell -NoProfile -File .\scripts\test-p3.ps1 -Phase Stop
}
```

`SocketFaults` guard project/image/DB wed_snap_p3_test/Redis14/media/control/
source RO/PID mode private và server test; create server chưa chạy rồi inspect
actual trước start/arm. Server `socket-test` dùng cùng image P3, **chỉ private
network internal, không published ports/outbound**; rootfs/source RO, tmpfs8MiB,
RAM128MiB. Không mở URL nguồn mới cho người dùng hoặc nới SSRF production.

Test analyze tới selectable bình thường; prepare dùng entrypoint nạp source
production RO/hash, chỉ thay metadata/extractor và route tới HTTP server test.
HttpFD/socket, bounded read/hook, stat/FFprobe/error mapper chạy thật. Một MP4
FFmpeg nhỏ hợp lệ≤256KiB: control phải ready/full200/size/hash đúng; server gửi
partial rồi close phải CONTENT_UNAVAILABLE; partial rồi stall phải SOURCE_TIMEOUT.
Giữ socket_timeout10s/retries1; mỗi fault2 media requests/**1 invocation worker**.
Test assert preparing/staging/token/lease/owner/PID/ticks/namespace/partial có
byte trước gate, group dừng tại deletion, cleanup≤8s và2 sweep thật tiếp theo.

Chỉ override settings DB test schema-valid prepare60s/session120s/ready30s/
sweep1s/retryGrace2s; startup sweep phải vốn1s. Caps production không đổi.
Finally deepEqual restore, lifecycle dọn đúng jobs/sentinels, giữ rows/charged/
control/log/volumes; phase logs và Stop server test, `Stop` dừng riêng P3 sau
actual guards. Không dùng down-v/reset/flush/prune. Raw kết quả ngày02/10 trong
PROGRESS/TEST_REPORT/audit; command và lỗi harness trước khi chạy được giữ riêng.

PASS socket local không chứng nhận HTTPS/egress/redirect/rebinding/nền tảng/
browser/public hoặc mọi process topology. Không chạy lại R15/timeout/release/
crash70s/concurrent/active-transfer nếu không sửa runtime liên quan.

## 6.8. Policy/CONNECT egress bằng lab riêng, không outbound

Phần18 dùng source `apps/egress/src/egress.py` hiện tại bind read-only/hash, production
policy và Handler thật; resolver/connector doubles, loopback CONNECT và
socketpair relay. Lab `wed-snap-egress-lab` chỉ1 container network none/no ports/
no data volumes/PID private/rootfsRO/RAM128MiB. Không cần bật main/P3/DB/Redis;
không dùng `.env` chính (explicit env-file chỉ chứa comment, không secrets).
Image `wed-snap-p3-egress:local` phải có sẵn; script không pull/build/install,
nếu thiếu image hoặc guard không khớp sẽ dừng.

Chạy tuần tự bằng PowerShell tại thư mục gốc:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\test-egress-lab.ps1 -Phase All
```

`All` chạy Syntax→Matrix→Regression. Có thể chọn riêng `Syntax`, `Matrix`,
`Regression`. Script resolve config→create chưa chạy→inspect actual guards→
start→logs→kiểm tra exit/hash→dọn container lab trong finally. Bound90s, chỉ
loopback/socketpair; không gọi IP Internet/nội bộ canned trong resolver.
Cleanup sau FAIL/timeout được log riêng, không coi là runtime PASS.

Để giữ raw mới, dùng tên chưa tồn tại (không ghi đè evidence cũ):

```powershell
cd "D:\WED SNAP"
$egressLog = "docs/evidence/p18-$(Get-Date -Format yyyyMMdd-HHmmss)-local.log"
if (Test-Path -LiteralPath $egressLog) { throw "Log đã tồn tại" }
powershell -NoProfile -File .\scripts\test-egress-lab.ps1 -Phase All 2>&1 | Tee-Object -FilePath $egressLog
if ($LASTEXITCODE -ne 0) { throw "Egress lab FAIL; xem raw log" }
```

Matrix kiểm tra allowlist/boundary/userinfo/literal/DNS non-global/mixed,
HTTP403/0 dial, control200, numeric sockaddr443/fallback đúng thứ tự và DNS
recheck lượt CONNECT kế tiếp. Regression dùng2 helper tests và4 negative target
cũ trong lab; không chạy probe8.8.8.8. Kết quả phần18 và giới hạn xem
`docs/TEST_REPORT.md`:144 case-result PASS sau sửa helper userinfo. Không chứng
nhận Internet/TLS/redirect/DNS rebinding E2E/nền tảng/browser/public, không
build/áp dụng sửa vào egress image stack chính hoặc P3.

## 6.9. R5: React terminal polling và phân tích lại job404/410

Lab UI riêng `wed-snap-ui-lab`, dùng image có sẵn `wed-snap-p3-test:local`.
Không build/pull/install, không bật main/P3/API/worker/DB/Redis, không `.env`
chính hoặc data volumes. Source web/tests bindRO, rootfsRO/user node/PID private,
RAM384MiB/PIDs64; chỉ cổng `127.0.0.1:5175`. Script guard resolved rồi actual
ở trạng thái created trước start, imageID/env/mount/ports/network/resources.

Chạy tuần tự trong PowerShell:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Start
if ($LASTEXITCODE -ne 0) { throw 'UI lab guard/start FAIL' }
try {
    powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Typecheck
    if ($LASTEXITCODE -ne 0) { throw 'Typecheck FAIL' }
    # Mở http://localhost:5175 trong trình duyệt test.
    # Nhấn Chạy matrix R5, chờ kết quả PASS/FAIL; sau đó thử các nút Smoke.
    # Không dán link nguồn thật: HTTP analyze/cancel/poll/ticket đều là fixture.
    $uiLog = "docs/evidence/p19-$(Get-Date -Format yyyyMMdd-HHmmss)-local.log"
    if (Test-Path -LiteralPath $uiLog) { throw 'Log đã tồn tại' }
    powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Logs 2>&1 | Tee-Object -FilePath $uiLog
    if ($LASTEXITCODE -ne 0) { throw 'Logs/guard FAIL' }
} finally {
    # Đóng tab lab sau khi lưu raw/screenshot; dọn riêng lab, không volumes.
    powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Stop
}
```

`Typecheck` chạy web rồi TS tests UI. `Logs` chỉ lưu log, **exit0 của Logs
không có nghĩa matrix PASS**: phải xem record `summary` và màn hình kết quả.
`Stop` kiểm tra identity trước stop/rm container và gỡ đúng network test rỗng;
không down-v/prune/reset. Nếu Start thất bại, đọc raw/guard trước khi thao tác;
không bỏ guard hoặc đổi sang image/main port5173.

Home/hooks/api/ReactDOM production chạy trong browser thật. HTTP fetch/Beacon
được fixture kiểm soát; chỉ interval clock thay bằng đồng hồ test, React/DOM
và event listeners thực. Matrix đo requests/order/state/timer/listener sau
advance≥30s và events pageshow/visibility/pagehide. Vite test không proxy API,
mọi API HTTP không được intercept trả503; không nguồn nền tảng thật.
Frontend bridge riêng dùng để Docker Desktop phục vụ cổng loopback; không gọi
đây là network-none/no-outbound proof. CSP giới hạn trang cùng origin, fixture
chặn fetch ngoài API đã khai báo. Mạng main/P3/SSRF/egress không đổi.

Smoke404: nhấn nút Smoke để Home hiện expired từ poll404, ghi trạng thái raw,
nhấn **Phân tích link** để nhận selection job mới dù cancel cũ404; ghi raw/screenshot
trước/sau. Đây là kiểm chứng React/browser với HTTP fixture, chưa phải backend
live, BFCache/throttle/điện thoại/ad blocker hoặc tải video thật. Xem chi tiết
raw FAIL/PASS trong `docs/TEST_REPORT.md`.

## 6.10. R6: sponsor theo phiên cookie và impression đổi campaign

Chỉ dùng image đã cache; **không build/pull/install**. Lab backend mới
`wed-snap-ads-lab`: DB `wed_snap_ads_test`/Redis DB14 trong hai containers và
volumes riêng, internal network/no ports/private PID/sourceRO; không media/
worker/main/P3. Script guard resolved và actual trước start/migrate/fixtures.
DB lab dùng trust trên mạng internal riêng, signing string chỉ là test fixture,
không credentials thật và không dùng cấu hình này cho main/public.
Không đọc/ghi đè `.env` chính; env-file riêng chỉ có comment. Migrate deploy
chỉ DB lab sau guard; không reset/down-v/flush hoặc override settings/charged.

PowerShell, chạy backend rồi UI tuần tự:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\test-ads.ps1 -Phase Start
if ($LASTEXITCODE -ne 0) { throw 'Ads lab guard/start FAIL; xem raw trước thao tác' }
try {
    powershell -NoProfile -File .\scripts\test-ads.ps1 -Phase Typecheck
    if ($LASTEXITCODE -ne 0) { throw 'API/tests typecheck FAIL' }
    $r6Log = "docs/evidence/p20-backend-$(Get-Date -Format yyyyMMdd-HHmmss).log"
    if (Test-Path -LiteralPath $r6Log) { throw 'Log đã tồn tại' }
    powershell -NoProfile -File .\scripts\test-ads.ps1 -Phase Backend 2>&1 | Tee-Object -FilePath $r6Log
    if ($LASTEXITCODE -ne 0) { throw 'R6 backend FAIL; giữ raw' }
} finally {
    powershell -NoProfile -File .\scripts\test-ads.ps1 -Phase Stop
}
powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Start
if ($LASTEXITCODE -ne 0) { throw 'UI lab guard/start FAIL' }
try {
    powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Typecheck
    if ($LASTEXITCODE -ne 0) { throw 'Web/UI tests typecheck FAIL' }
    # http://localhost:5175/r6.html: Chạy matrix R6, chờ22/22.
    # Sau đó http://localhost:5175/: Chạy matrix R5, chờ39/39; không chạy cùng lúc.
    # R6 Smoke: đóng hộp bằng Enter/click, Chuẩn bị tải, nhấn link Tải xuống.
    # Ghi smoke trước/sau. Tệp native chỉ28byte text, không MP4/nguồn thật.
    $r6UiLog = "docs/evidence/p20-ui-$(Get-Date -Format yyyyMMdd-HHmmss).log"
    if (Test-Path -LiteralPath $r6UiLog) { throw 'Log đã tồn tại' }
    powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Logs 2>&1 | Tee-Object -FilePath $r6UiLog
    if ($LASTEXITCODE -ne 0) { throw 'Logs/guard FAIL' }
} finally {
    # Đóng đúng các tab lab đã mở; Stop giữ volumes backend/logs.
    powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Stop
}
```

Backend tests gọi production Nest AdsController/AdsService với HTTP thật,
session cookie fixture được DB xác thực và Redis thật; barrier chứng minh
request overlap. Chỉ tạo/dọn IDs/keys fixture đã biết, snapshot settings/charged
deepEqual. Expiry test assert TTL600s rồi PEXPIRE30ms đúng key fixture, không
đợi10phút/sửa600 production. Backend summary9PASS/0FAIL là điều kiện đạt;
không dùng exit0 của UI `Logs` thay summary22/39PASS.

UI chạy production Home/Advertising/React; HTTP/IO/hidden/clock doubles khai
báo. Native anchor smoke nhận text bytes từ Vite test, không API lease/media.
UI lab có thêm tests/p20 bindRO, vẫn không data services/volumes/secret env.
GET sponsor giữ hợp đồng Ad/null nhưng claim cooldown bảo thủ theo cookie:
response bị mất/tab đóng vẫn tiêu600s, không refund/prefetch; xem docs/API.md.
Banner/no-campaign không tiêu claim, ads null/lỗi không chặn tải. Chưa nghiệm
thu browser với backend live/nativeIO/multi-tab/mobile/ad blocker/quảng cáo
ngoài hoặc áp dụng main. Raw FAIL/PASS/attempts trong TEST_REPORT.

## 6.11. P21: sponsor job mới khi cancel job cũ còn pending

Chỉ UI lab của mục6.9; không cần chạy backend ở mục6.10. Dùng image đã cache,
sourceRO và cổng loopback5175, không build/pull/install hoặc data services.

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Start
if ($LASTEXITCODE -ne 0) { throw 'UI lab guard/start FAIL' }
try {
    powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Typecheck
    if ($LASTEXITCODE -ne 0) { throw 'Web/p19/p20 UI typecheck FAIL' }
    # http://localhost:5175/r21.html: Chạy matrix P21, chờ8/8.
    # http://localhost:5175/r6.html: Chạy matrix R6, chờ22/22.
    # http://localhost:5175/: Chạy matrix R5, chờ39/39. Chạy tuần tự.
    $p21Log = "docs/evidence/p21-local-$(Get-Date -Format yyyyMMdd-HHmmss).log"
    if (Test-Path -LiteralPath $p21Log) { throw 'Log đã tồn tại' }
    powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Logs 2>&1 | Tee-Object -FilePath $p21Log
    if ($LASTEXITCODE -ne 0) { throw 'Logs/guard FAIL' }
} finally {
    # Lưu screenshot/raw, đóng đúng tab test trước khi dọn riêng UI lab.
    powershell -NoProfile -File .\scripts\test-ui.ps1 -Phase Stop
}
```

P21 chạy production Home/useJobLifecycle/Advertising/React, chỉ HTTP và clock
doubles. Native observer/listener được instrument để đếm cleanup, không giả
entries/visibility; suite không nghiệm thu viewability. Từng ca giữ cancel200
pending, cho old poll failed/404/410 hoặc selectable, rồi mới nhận analyze
job mới và sponsor200 non-null B. Có4 biến thể old sponsorA còn pending đến
sau B;30s clock và pageshow/visibility không gọi job cũ hoặc retry sponsor.
Raw ghi pending/start-finish-order/UI/cleanup; exit0 của Logs không thay
summary8/22/39 PASS. Đây là browser HTTP fixtures, chưa backend live, native
viewability, platform hoặc multi-tab thực qua cookie/Redis. Server600s không đổi.

## 6.12. R9: metadataTTL độc lập heartbeat trong lab riêng

Source R9 đã sửa; **main chưa migrate/apply**. Metadata selectable có mốc cố
định≤120000ms từ processor chấp nhận analyze; now≥deadline trả410 JOB_EXPIRED.
Heartbeat/updatedAt/ownerUntil không gia hạn; selectable legacy thiếu mốc bị
từ chối, cần analyze mới. Prepare đã nhận trước hạn tiếp tục queued/preparing/
ready và retry idempotent; ready ticket/transfer không bị metadataTTL phá.
Title/retention lịch sử giữ nguyên. Bảng TTL/contract ở [API](docs/API.md).

Lab `wed-snap-metadata-lab` chỉ3container, internal network/no host ports/
private PID/sourceRO; cached `wed-snap-p3-test:local`, PostgreSQL16.10 và
Redis7.4.6. DB `wed_snap_metadata_test`, Redis14 trên container riêng, hai
volumes riêng; media/control/Prisma client là tmpfs riêng. Script xác minh
resolved+actual image/project/cmd/env/mount/resource/ports/network/volumes và
datastore identity trước generate/migrate/tests. Không đọc `.env` chính, không
build/pull/install. Thiếu image/client/isolation thì dừng, không fallback main.

```powershell
cd "D:\WED SNAP"
$r9Stamp = Get-Date -Format yyyyMMdd-HHmmss
$r9Dir = "docs/evidence/p22-local-$r9Stamp"
if (Test-Path -LiteralPath $r9Dir) { throw 'Evidence đã tồn tại' }
New-Item -ItemType Directory -Path $r9Dir | Out-Null
try {
    powershell -NoProfile -File .\scripts\test-metadata.ps1 -Phase Start 2>&1 | Tee-Object "$r9Dir/start.log"
    if ($LASTEXITCODE -ne 0) { throw 'Metadata guard/start/client/migration FAIL' }
    powershell -NoProfile -File .\scripts\test-metadata.ps1 -Phase Typecheck 2>&1 | Tee-Object "$r9Dir/typecheck.log"
    if ($LASTEXITCODE -ne 0) { throw 'API/shared/worker/p22 typecheck FAIL' }
    powershell -NoProfile -File .\scripts\test-metadata.ps1 -Phase Matrix 2>&1 | Tee-Object "$r9Dir/matrix.log"
    if ($LASTEXITCODE -ne 0) { throw 'R9 matrix FAIL: giữ raw trước khi sửa' }
    # Cần summary15PASS/0FAIL; exit0 của Logs không thay assertion matrix.
} finally {
    powershell -NoProfile -File .\scripts\test-metadata.ps1 -Phase Logs 2>&1 | Tee-Object "$r9Dir/containers.log"
    powershell -NoProfile -File .\scripts\test-metadata.ps1 -Phase Stop 2>&1 | Tee-Object "$r9Dir/stop.log"
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Guard/Stop FAIL: kiểm tra identity, không down-v hoặc cleanup rộng' }
}
```

Start tạo lại Prisma client6.19 trong `/app/node_modules/.prisma` tmpfs (exec
cần cho cached native engine), rootfs còn RO; không host node_modules hoặc
image/dependencies. Deploy migrations hiện có trong source vào DB lab;
R9 lịch sử dùng `202610030001_metadata_deadline` (hai cột nullable/index,
không backfill); source hiện tại còn có cleanup migration phần23 ở6.13.
Stop chỉ stop/rm container lab, giữ DB/Redis volumes/rows/charged/logs;
không reset/down-v/prune/flush. Dừng lab trước khi sửa source fingerprint để
không làm guard Stop lệch. Start thất bại guard không được bỏ guard để dọn.

Matrix dùng production Nest/API/worker/processor/lifecycle/BullMQ/Prisma và
transaction PostgreSQL thật; Date virtual, cookie DB seed, local Python
metadata/preview/8192byte và manual production sweep là doubles khai báo.
Race giữ row lock thật, đo2HTTP/2DB lock wait; không mirror TTL. Settings lab
schema-valid save/restore deepEqual trong finally, charged giữ byte finalize.
Cleanup đúng fixture bằng release/cancel/sweep, giữ rows. Test nguồn hết sớm
dùng sourceExpiresAt fixture tuyệt đối; Python production chưa trả expiry này.
Fixture không MP4/nền tảng/egress thật; không browser/UI tests trong R9.
Raw trước/sau03/10 và bounds/attempts trong [TEST_REPORT](docs/TEST_REPORT.md).

## 6.13. Phần23: cleanup cancel/retry trong lab riêng

Source cleanup đã sửa; **main chưa migrate/apply**. Yêu cầu cancel và hoàn
tất cleanup độc lập:terminal `cleanupCompletedAt=NULL` vẫn được dọn dù
cancelRequested=true/noasset/no worker. Rm thành công mới xóa cache/markdone;
rm/commit lỗi retry lượt sau. Normal cancel repeated201 không renewupdatedAt;
metadata expired cancel410 giữ R9. Live worker/transfer vẫn được bảo vệ.
Done không sweep/rm lặp, không cản purge24h. Contract ở [API](docs/API.md).

Lab mới `wed-snap-cleanup-lab`:DB/user `wed_snap_cleanup_test/p23`, Redis14
trên container riêng, hai volumes `wed-snap-cleanup-lab_cleanup_db` và
`wed-snap-cleanup-lab_cleanup_redis`; internal bridge/noports/privatePID.
Cached images như6.12,8sourceRO binds, runtime node/rootfsRO/private
media/control/client tmpfs; không đọc `.env` chính hoặc host node_modules.
Script guard resolved/actual project/image/cmd/env/mount/network/resources/
datastore/volumes trước Start/migrate/fixtures. Không chạy lab khác hoặc main
cùng lúc; RAM8GB từng phase tuần tự, thiếu cache/isolation thì dừng.

```powershell
cd "D:\WED SNAP"
$cleanupStamp = Get-Date -Format yyyyMMdd-HHmmss
$cleanupDir = "docs/evidence/p23-local-$cleanupStamp"
if (Test-Path -LiteralPath $cleanupDir) { throw 'Evidence đã tồn tại' }
New-Item -ItemType Directory -Path $cleanupDir | Out-Null
try {
    powershell -NoProfile -File .\scripts\test-cleanup.ps1 -Phase Start 2>&1 | Tee-Object "$cleanupDir/start.log"
    if ($LASTEXITCODE -ne 0) { throw 'Cleanup guard/start/client/migration FAIL' }
    powershell -NoProfile -File .\scripts\test-cleanup.ps1 -Phase Typecheck 2>&1 | Tee-Object "$cleanupDir/typecheck.log"
    if ($LASTEXITCODE -ne 0) { throw 'API/shared/worker/p23/p22 typecheck FAIL' }
    powershell -NoProfile -File .\scripts\test-cleanup.ps1 -Phase Matrix 2>&1 | Tee-Object "$cleanupDir/matrix.log"
    if ($LASTEXITCODE -ne 0) { throw 'Cleanup matrix FAIL: giữ raw, không reset data' }
    # Cần summary12PASS/0FAIL; không cộng các lượt thành coverage.
    powershell -NoProfile -File .\scripts\test-cleanup.ps1 -Phase R9 2>&1 | Tee-Object "$cleanupDir/r9.log"
    if ($LASTEXITCODE -ne 0) { throw 'R9 regression FAIL' }
    # Cần summary15PASS/0FAIL, guard P22 cho phép đúng DB cleanup lab.
} finally {
    powershell -NoProfile -File .\scripts\test-cleanup.ps1 -Phase Logs 2>&1 | Tee-Object "$cleanupDir/containers.log"
    powershell -NoProfile -File .\scripts\test-cleanup.ps1 -Phase Stop 2>&1 | Tee-Object "$cleanupDir/stop.log"
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Guard/Stop FAIL: kiểm tra identity, không cleanup rộng' }
}
```

Start create --no-build, regenerate client6.19 trong `.prisma` exec tmpfs rồi
migrate deploy chỉ DBcleanup; additive `202610030002_cleanup_completed`
thêm nullable timestamp/index, không backfilldone. Source hiện tại cần cả
R9+cleanup migration/client trước khi dùng; **chưa apply main**, không dùng
lệnh lab thay cho rollout main. Dừng lab trước khi sửa source fingerprint.
Stop chỉ stop/rm3containers, giữ volumes/network/rows/charged/logs; không
reset/down-v/prune/flush. Secret marker lab là public fixture, không dùng
cho production. Settings save/restore deepEqual, charged actual giữ.

Matrix production HTTP/DB/worker/sweep/locks thật, Date/sessionseed/local
Python metadata/preview/8192byte/manualsweep/FSfault là doubles khai báo.
EACCES đúng ownpath một lần, cancel/sweep giữ rowlock thật;501done/backlog
và1ownrow age24h±1ms để kiểm purge, không dữ liệu chính. Preparing child phải
dead trước rm; stream control8MiB là guarded file/DBsize extension tạo native
TCPbackpressure, không adaptervideo output. Final không manual cleanup;
FAIL-only cleanup guarded ghi riêng/notRuntimePass. Không gọi nguồn thật.

Bằng chứng03/10 tại [TEST_REPORT](docs/TEST_REPORT.md)/[PROGRESS](docs/PROGRESS.md).
Kiểm tra offline bộ raw cố định và snapshot, không start lab:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\validate-p23-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'Evidence/hash/parser mismatch' }
```

Validator đọc logs03/10/hash/source; `-CaptureSnapshot` chỉ đã dùng lúc bàn
giao để lưu18file sau sửa, không dùng để thay bằng chứng lịch sử sau khi source
đổi. Fixture không chứng nhận video/platform/Internet/TLS/redirect/rebinding/
browser/public hoặc cadence/load/persistentFSerror/mọi subprocess topology.

## 6.14. Phần24: generator và contract tests OpenAPI public offline

**Lịch sử đã nhận scoped19ca/typecheck.** Phần25 đã bổ sung400 framework
theo HTTP thật; p24 tests/expected/validator/raw/manifest vẫn đóng băng.
Các lệnh dưới gắn source/SHA tại bàn giao24, không dùng để nhận current
source mới. Dùng **6.16** cho generator/matrix hiện hành; không
đổi frozen p24 để ép PASS hoặc ghi đè bằng chứng cũ.

Phạm vi: health/session,8endpoint job và GET/implicit HEAD download —11paths/
12operations. Snapshot tổng19paths/23operations/12schemas; admin/ads giữ
contract cũ, còn backlog schemas/errors/constraints riêng. Không nhận toàn
R8/P2/P4. Source mới **chưa apply main**; đây không phải test HTTP/lifecycle/
platform. Audit23 scoped12cleanup+15R9/typecheck giữ bằng chứng lịch sử,
không chạy lại để sinh docs.

Lab `wed-snap-openapi-lab` chỉ một container cached
`wed-snap-p3-test:local` (image SHA guard cố định). Không build/pull/install;
thiếu/sai image phải dừng. Network none, no ports/privatePID/rootfsRO/node/
sourceRO,512MiB/.75CPU/PIDs64; không DB/Redis service/data volume. Sentinel
DB/Redis loopback port9 **không được kết nối**. Guard resolved+actual project/
image/cmd/env/mount/network/PID/resources/noports/datastore trước mỗi phase;
không đọc `.env` chính. Prisma generate chỉ vào client tmpfs riêng64MiB,
không host node_modules/migrate hoặc dữ liệu lab lịch sử.

PowerShell, chạy từng phase tuần tự, lưu log mới thay vì ghi đè raw03/10:

```powershell
cd "D:\WED SNAP"
$p24RunDirectory = Join-Path 'docs/evidence' ('p24-run-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $p24RunDirectory -ErrorAction Stop | Out-Null
try {
    foreach ($p24Phase in @('Start','Typecheck','Generate','Matrix')) {
        powershell -NoProfile -File .\scripts\test-openapi.ps1 -Phase $p24Phase 2>&1 |
            Tee-Object -FilePath (Join-Path $p24RunDirectory ($p24Phase + '.log'))
        if ($LASTEXITCODE -ne 0) { throw "P24 $p24Phase failed; giữ raw, không đổi guard để bỏ qua" }
    }
} finally {
    powershell -NoProfile -File .\scripts\test-openapi.ps1 -Phase Logs 2>&1 |
        Tee-Object -FilePath (Join-Path $p24RunDirectory 'Logs.log')
    powershell -NoProfile -File .\scripts\test-openapi.ps1 -Phase Stop 2>&1 |
        Tee-Object -FilePath (Join-Path $p24RunDirectory 'Stop.log')
    if ($LASTEXITCODE -ne 0) { throw 'Stop guard/teardown failed; kiểm raw, không kill/reset stack khác' }
}
```

**Generate ghi `docs/openapi.json`** bằng JSON sinh từ controllers/AppModule/
SwaggerModule.createDocument/describeContracts, cùng factory API; không chỉnh
snapshot bằng tay. Matrix phải19PASS/0FAIL, noDatastore/noDial/noListen/hook
restore PASS và snapshot chuẩn hóa khớp generator. Typecheck API/shared/p24
exit0. Stop chỉ stop/rm đúng container lab, không down-v/prune hoặc dùng main.
Nếu nguồn được guard đổi trong lúc lab chạy, không tiếp tục phase hoặc bỏ
guard; dừng đúng lab bằng source/identity đã xác minh trước khi sửa nguồn.

Harness chặn constructor Prisma/Redis/Queue và socket/listen **trước import
core/AppModule**; chỉ tạo Nest DI để đọc route metadata/Swagger, không init/
listen, không gọi phương thức health/session/jobs/worker. Tests dùng expected
payload/status/security viết độc lập theo source, production Zod safeParse
thuần; không mock route hay verdict schema. Không chứng nhận HTTP/stream/
runtime HEAD, toàn bộ JSON Schema hay mọi payload adapter.

Kiểm evidence bàn giao cố định03/10 mà không start lab:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\validate-p24-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'P24 raw/hash/parser/snapshot mismatch' }
```

Validator đọc raw baseline3PASS/16FAIL và final19PASS/0FAIL, cùng matrix/test/
expected, manifest13file và71protected source hashes. `-CaptureSnapshot` chỉ
đã dùng lúc bàn giao; không thay evidence lịch sử khi source đổi. Guard test
cũng giữ baseline71hashes: phiên sau có sửa logic cần nhiệm vụ/baseline mới
được đối chiếu, không tự ghi đè baseline này để ép PASS. Raw, giới hạn và các
attempt lỗi guard/type/annotation được ghi trong TEST_REPORT/PROGRESS.
Không chạy các mục main/migration/P0 phía trên/dưới để sinh OpenAPI.

## 6.15. Phần25: SafeErrors và parser HTTP loopback, lab riêng

**Lịch sử đã nghiệm thu độc lập25 scoped, không chạy lại với source26.**
Các lệnh/số liệu phía dưới ghi workflow lúc bàn giao25; validator frozen
ràng buộc builder/snapshot/API.md SHA cũ nên không dùng để ép source26
khớp lịch sử. Phần26 giữ toàn bộ artifact/hash25 và có suite riêng ở6.16.

Đã đo cached Nest11.2.7/Express5.2.1: malformed JSON400/INTERNAL_ERROR tại
12 public operations, URI encoding lỗi400 tại9 operations có parameter.
HEAD wire body rỗng. Đây là các request fixture đã thử, không bảo đảm mọi
malformed request đều400. SafeErrors giữ status/code AppError; HttpException
giữ getStatus(),404→NOT_FOUND/khác→INTERNAL_ERROR; Error khác fallback500.
Runtime parser/filter/auth/handlers không đổi; source chính chưa apply.

Project `wed-snap-parser-lab`:1cached container512MiB/.75CPU/PIDs64, node/
rootfsRO/sourceRO/network:none/privatePID/noports/no datastore/data volumes.
Guard resolved+actual image/env/cmd/mount/network/PID/resources và126hashes
logic/frozen p24 trước thao tác. Tmpfs/client riêng, Prisma generate chỉ để
typecheck, không migrate/host node_modules/build/pull/install/main `.env`.
Constructor-deny trước import core; đúng1HTTP server127.0.0.1:0 **trong
container** và client tới port của server đó; mọi listen/dial khác bị deny.
Không endpoint host để mở trình duyệt. Không valid health/session, seed
cookie/job hoặc business datastore/worker.

Chạy tuần tự PowerShell, log mới:

```powershell
cd "D:\WED SNAP"
$p25RunDirectory = Join-Path 'docs/evidence' ('p25-run-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $p25RunDirectory -ErrorAction Stop | Out-Null
try {
    foreach ($p25Phase in @('Start','Typecheck','Generate','Matrix','Regression')) {
        powershell -NoProfile -File .\scripts\test-framework.ps1 -Phase $p25Phase 2>&1 |
            Tee-Object -FilePath (Join-Path $p25RunDirectory ($p25Phase + '.log'))
        if ($LASTEXITCODE -ne 0) { throw "P25 $p25Phase failed; giữ raw và guard" }
    }
} finally {
    powershell -NoProfile -File .\scripts\test-framework.ps1 -Phase Logs 2>&1 |
        Tee-Object -FilePath (Join-Path $p25RunDirectory 'Logs.log')
    powershell -NoProfile -File .\scripts\test-framework.ps1 -Phase Stop 2>&1 |
        Tee-Object -FilePath (Join-Path $p25RunDirectory 'Stop.log')
    if ($LASTEXITCODE -ne 0) { throw 'Guard/Stop failed; không kill/reset stack khác' }
}
```

Generate ghi docs/openapi.json từ factory/controllers thật, không listen/
datastore;19paths23operations12schemas. Matrix46PASS/0FAIL, regression20/0
và typecheck exit0. HTTP matrix có32requests, không46HTTPrequests:12filter
unit,1docs,21parser,10no-cookie,1unmatched-route,1I/Odeny. Baseline sạch24/22
là contract mismatch, không22runtimebugs. HeadersSent chỉ được thử qua unit
response recorder; malformed JSON/URI và HEAD được đo HTTP wire thật.
Regression kế thừa controls p24 trong **suite p25 riêng**, chỉ cho phép delta
400 ở12operation, giữ success/security/CSRF/TTL/Range/HEAD/cancel metadata
và admin/ads. Không coi đó là lifecycle/Range/lease runtime mới.

Đối chiếu evidence cố định03/10, không start lab:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\validate-p25-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'P25 raw/hash/parser/snapshot mismatch' }
```

`-CaptureSnapshot` chỉ đã dùng lúc bàn giao, không ghi đè history. Validator
đối chiếu cùng46matrix/harness/expected,32HTTP status/body/order trước–sau,
hooks restore/server/client close và126protected/frozen hashes. Raw/logs/
manifest15file ở TEST_REPORT/PROGRESS. Stop chỉ gỡ đúnglab, giữ mọi rows/
charged/volumes/logs lịch sử. Source đổi thì cần scope/baseline mới, không
bỏ guard hoặc tự sửa historical validator. Admin/ads OpenAPI, mọi parser
fault topology, HTTP success/datastore/lifecycle/platform/browser/main/
public còn chưa nhận tại bàn giao25. Audit25 đã nhận scoped; hợp đồng
admin/ads tiếp tục ở6.16, không thay mức chứng minh HTTP business/main.

## 6.16. Phần26: hợp đồng admin/ads và generator hiện hành offline

**Lịch sử đã nghiệm thu độc lập26 scoped, F26.1 đóng về docs.**23case/
0HTTP ở26 giữ nguyên loại bằng chứng; lệnh bên dưới là workflow26 lịch sử.
Sau cập nhật prose27, frozen validator26 có SHA API.md cũ: không rerun/sửa
để ép docs27 khớp. HTTP đối chứng dùng lab/suite riêng ở6.17, không prompt26.

F26.1 xử lý đúng8paths/11operations admin/ads, chờ kiểm toán độc lập26.
Baseline3PASS/20FAIL → cùng23case23PASS/0FAIL; typecheck API/shared/p26
exit0. Snapshot tổng19paths/23operations/20schemas, thêm8schema và chỉ đổi
8targetpaths; public11paths/12operations,12schema cũ và security definitions
giữ canonical. Không đổi controller/service/auth/validator/runtime.

Lab `wed-snap-contract-admin-lab` đúng1cached image f2a71e62… không pull/
build/install:512MiB/.75CPU/PIDs64, node/rootfsRO/sourceRO/network:none/
privatePID/noports/no data services/volumes.6bindRO API/shared/prisma/p26/
tsconfig/snapshot; tmpfs /tmp32MiB,/media1MiB,private Prisma client64MiB.
Guard resolved+actual identity/image/env/cmd/mount/network/PID/resources/
volume và193protected/frozen hashes trước thao tác. Prisma generate chỉ
tmpfs private; không migrate hoặc host node_modules/.env/main.

Constructor-deny Prisma/Redis/Queue trước importcore/AppModule; nested
methods throw/count, deny mọi Socket.connect/Server.listen. Nest DI và
factory/controllers thật nhưng không main.ts/init/listen/health/session/
worker/HTTPbusiness. Pure validators Zod +3expression nguyên từ AST
production (ad-event/verified/placement), DMMF/metadata/output fixtures;
datastoreCalls/dials/listens0 và hooks restored. Không chứng nhận11HTTP
success, CSRF/auth runtime/Redis atomic/campaign CRUD/main apply.

Lệnh PowerShell tuần tự, mỗi lượt log mới, từ chối guard sai:

```powershell
cd "D:\WED SNAP"
$p26RunDirectory = Join-Path 'docs/evidence' ('p26-run-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $p26RunDirectory -ErrorAction Stop | Out-Null
try {
    foreach ($p26Phase in @('Start','Typecheck','Generate','Matrix')) {
        powershell -NoProfile -File .\scripts\test-admin-contract.ps1 -Phase $p26Phase 2>&1 |
            Tee-Object -FilePath (Join-Path $p26RunDirectory ($p26Phase + '.log'))
        if ($LASTEXITCODE -ne 0) { throw "P26 $p26Phase failed; giữ raw/guard" }
    }
} finally {
    powershell -NoProfile -File .\scripts\test-admin-contract.ps1 -Phase Logs 2>&1 |
        Tee-Object -FilePath (Join-Path $p26RunDirectory 'Logs.log')
    powershell -NoProfile -File .\scripts\test-admin-contract.ps1 -Phase Stop 2>&1 |
        Tee-Object -FilePath (Join-Path $p26RunDirectory 'Stop.log')
    if ($LASTEXITCODE -ne 0) { throw 'Guard/Stop failed; không thao tác stack khác' }
}
```

Generate xuất docs/openapi.json từ factory cùng API, không chỉnh JSON tay.
Matrix kiểm11profile success/error/security; UUID/query/17limits strict/
login/campaign/events/refinements; nullable/Date/BigInt/persisted strings;
refs/inventory/preservation/snapshot. POST default201 được kiểm bằng cached
Nest metadata/hàm status thật, không HTTP admin login/logout.
OpenAPI3 không biểu diễn hết startsAt<endsAt/HTTPS/verified constraints:
extension mô tả và fixtures gọi production validator/pure predicate.
Cookie-only CSRF fallback logout/delete vẫn bắt buộc body csrf+Origin;
strictbody login/campaign/limits/ad-event không nhận thêm csrf.

Đối chiếu evidence26 cố định03/10 offline, không start container:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\validate-p26-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'P26 raw/hash/snapshot/Stop mismatch' }
```

CaptureSnapshot chỉ dùng một lần lúc bàn giao, không ghi đè history. Lệnh
trên đọc raw/hash/manifest hiện hành, không rerun24/25. Nếu source thay đổi,
giữ log/frozen validators lịch sử và tạo scope/evidence mới; không bypass
guard. Lab cuối đã removed, logs giữ. HTTP business admin/ads/parser nhóm
này, backend live/browser/native viewability/nền tảng/Internet/main/public
chưa nghiệm thu26. Audit26 đã nhận docs scoped; phần27 bổ sung HTTP theo6.17.
Không nhận toànR8/P2/P4/P0–P6 hoặc main đã apply.

## 6.17. Phần27: HTTP admin/ads với PostgreSQL/Redis lab riêng

Thực chạy **40case/87requests PASS**:36ca/79HTTP chính +4ca/8HTTP bổ sung,
đủ11operation target có success HTTP
khớp status/schema/headers snapshot26; typecheck API/shared/tests-p27 exit0.
Không sửa snapshot/controller/service/auth/filter/parser/validation/schema/
caps/rates/runtime. AdminHTTP/tests-admin và9P20 đã có lịch sử;27 bổ sung
controls cần cho hợp đồng26, không rerun các suite cũ hoặc sponsor race/
expiry/R6UI. Chờ audit độc lập27, main chưa apply/migrate/public.

Project mới `wed-snap-admin-http-lab`,3cached services không build/pull/
install:node512MiB/.75CPU/PIDs64;PG192MiB/.5CPU/PIDs64;Redis96MiB/.25CPU/
PIDs32, tổng800MiB. Network internal/privatePID/no published ports; node
sourceRO/rootfsRO/usernode/capdropALL/no-new-privileges.6bindRO API/shared/
prisma/p27/tsconfig/snapshot; /tmp32MiB vàprivatePrisma client64MiB tmpfs.
PG/Redis dùng2namedvolumes riêng giữ lại khi Stop; không mount main/media.
Guard resolved+actual project/image pins/cmd/env/mount/resources/network
membership/volume labels và261protected/frozen hashes trước ghi/start.

DB `wed_snap_admin_http_test`,Redis database15 trong container riêng:
kiểm current_database/cluster/server address và CLIENT INFO db/run_id trước
migration/fixtures. Start từ chối foreign tables/nonempty app rows/Redis keys,
không reset/flush để chạy lại.3migration production chỉ deploy DB lab;
Prisma generate private tmpfs, không host node_modules/main `.env`.

Chạy tuần tự PowerShell, mỗi run giữ log mới:

```powershell
cd "D:\WED SNAP"
$p27RunDirectory = Join-Path 'docs/evidence' ('p27-run-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $p27RunDirectory -ErrorAction Stop | Out-Null
try {
    powershell -NoProfile -File .\scripts\test-admin-http-origin.ps1 -Phase Start 2>&1 |
        Tee-Object -FilePath (Join-Path $p27RunDirectory 'Start.log')
    if ($LASTEXITCODE -ne 0) { throw 'P27 Start failed; giữ guard/raw' }
    powershell -NoProfile -File .\scripts\test-admin-http.ps1 -Phase Matrix 2>&1 |
        Tee-Object -FilePath (Join-Path $p27RunDirectory 'Matrix36.log')
    if ($LASTEXITCODE -ne 0) { throw 'P27 Matrix36 failed' }
    powershell -NoProfile -File .\scripts\test-admin-http-origin.ps1 -Phase Matrix 2>&1 |
        Tee-Object -FilePath (Join-Path $p27RunDirectory 'Origin4.log')
    if ($LASTEXITCODE -ne 0) { throw 'P27 Origin4 failed' }
    powershell -NoProfile -File .\scripts\test-admin-http-origin.ps1 -Phase Typecheck 2>&1 |
        Tee-Object -FilePath (Join-Path $p27RunDirectory 'Typecheck.log')
    if ($LASTEXITCODE -ne 0) { throw 'P27 Typecheck failed' }
} finally {
    powershell -NoProfile -File .\scripts\test-admin-http-origin.ps1 -Phase Logs 2>&1 |
        Tee-Object -FilePath (Join-Path $p27RunDirectory 'Logs.log')
    powershell -NoProfile -File .\scripts\test-admin-http-origin.ps1 -Phase Stop 2>&1 |
        Tee-Object -FilePath (Join-Path $p27RunDirectory 'Stop.log')
    if ($LASTEXITCODE -ne 0) { throw 'P27 guard/Stop failed; không thao tác stack khác' }
}
```

Nest/AppModule/controllers/services/auth/SafeErrors/middleware theo main
thật, chỉ1HTTP server127.0.0.1:0 **trong container**, không port host hay tab
browser. Session lấy qua API; admin/passwordHash/signing tạo random trong
memory, không credential URL/cookie/CSRF/token/password/HMAC trong raw.
Client HTTP thật deadline5s/response≤64KiB/request≤100/concurrency1.
JS socket chỉ cho Redis lab hoặc exact loopback port; Prisma native TCP
được kiểm DBcluster/address, không giả vờ JS hook đếm native DB sockets.
Không main.ts/worker/jobAPI/Internet hay fake business/datastore verdict.

Matrix kiểm adminGET chỉadminCookie; writes guest+admin+Origin+CSRF;
strictbody và header/body priority; logout/DELETE bodyfallback+extra;
CRUD/audit/17limits/errors; ads projection/null/query/eventUUID/dedupe;
dashboard Date/nullability/BigInt strings. Seed DB3jobs/1asset/2leases/
1budget chỉ aggregation, không media/file/lifecycle/transfer proof.
Settings/budget restore deepEqual trong finally, fixture rows/keys xóa
theo IDs/actor/knownkeys, queue waiting/active0 giữ. Core queue/Redis/Prisma,
HTTP peers/clients đóng; hooks restore. Stop đúng3containers, giữ volumes/logs.

Lượt preflight đầu0HTTP là harness inet::text có /32; dùng host(inet) để so
numeric address và giữ raw attempt. Business baseline36/0 tự PASS, không
ép FAIL/sửa runtime. Request đã đo1.65–62.895ms/response tối đa822byte;
đây là fixture loopback, không SLA/load/public. Login đúng5lượt rate-counted,
event7 dưới60; không flood/kiểm429 mới.

Lượt4/8 bổ sung kiểm DELETE thiếu/sai Origin và logout sai Origin403 dù
token đúng, row/audit/token giữ; sau đó valid controls200/201. Không rerun
36ca lúc bổ sung, typecheck toànp27 exit0/Stop cuối11:04:29Z giữ volumes.
Runner bổ sung sửa riêng guard count tables qua stdin:PowerShell5 argv mất
quotes identifier ở Start attempt. Raw guardFAIL trước fixture/HTTP giữ,
không runtime bug/reset; Start sau13tables rỗng/no pending migrations.
Original36tests/runner/frozen evidence không đổi.

Đối chiếu evidence27 cố định03/10 offline, không start lab:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File .\scripts\validate-p27-origin-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'P27 final40/87/raw/frozen/currentdocs/Stop mismatch' }
```

CaptureSnapshot chỉ dùng lúc bàn giao, từ chối ghi đè history. Giữ frozen
24/25/26 tests/validators/raw/manifests/snapshots; suite27 kiểm source hiện
hành, không đổi historical validator khi docs prose đổi. Hai validators27
đầu cũng giữ SHA lúc36/79; validator cuối đối chiếu frozen copies và docs/
source cuối40/87, không ép oldvalidators với prose bổ sung. Chưa chứng nhận
mọi auth combination/parserfault/admin analytics/load/TLS/Secure=true/main
apply/browser/native viewability/lifecycle/platform/Internet/public/P5P6.
Không mở toànR8/P2/P4/P0–P6. Bước tiếp: audit độc lập27.

## 6.18. Phần28: Admin browser production với API fixtures, lab UI riêng

Lab chỉ1Vite service cached `wed-snap-p3-test:local`, sourceRO/rootfsRO/node/512MiB/.75CPU/privatePID/PIDs64/tmpfs32MiB, published127.0.0.1:5177 trên bridge frontend riêng. Không backend/DB/Redis/worker/.env/main/media/volume dữ liệu; CSP self và fetch fence, không coi bridge là kernel no-egress. Script pin image và kiểm resolved/actual/protected hashes, không build/pull/install/mainfallback. Phải có cached image đúng; nếu guard/cổng thất bại thì dừng, không chuyển main.

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/test-admin-ui.ps1 -Phase Start
```

Mở `http://localhost:5177`. Bấm **Chạy matrix28** (30ca) rồi **Kiểm focus sau lưu** (1ca bổ sung). `Smoke login`/`Smoke dữ liệu` mount Admin thật với session/API transport fixtures để kiểm keyboard/screenshot; mọi settings/campaign chỉ nằm trong memory test. Không cần account/password thật. Fixtures giữ method/path/header/body contract27, không thay auth/business service hoặc chứng nhận backend live. Browser viewport1280/360 là emulation; reduced motion ghi preference thật, không suy preference=true nếu công cụ chưa thử.

Sau matrix kết thúc, typecheck tuần tự, giữ log tên mới rồi dọn own root/lab:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/test-admin-ui.ps1 -Phase Typecheck
$adminUiStamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
powershell -NoProfile -File scripts/test-admin-ui.ps1 -Phase Logs 2>&1 | Tee-Object -FilePath "docs/evidence/p28-$adminUiStamp-local.log"
```

Bấm **Dọn smoke**, đóng tab test/reset viewport override, sau đó:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/test-admin-ui.ps1 -Phase Stop
powershell -NoProfile -File scripts/verify-admin-ui-evidence.ps1
```

Stop chỉ guard/remove container+network lab28, không xóa volumes. Evidence verifier đọc frozen raw28 và740protected hashes, không chạy lại browser/backend; guard phù hợp revision bàn giao, không sửa manifest cũ để ép source revision mới. Giữ `tests/p28`, snapshots/manifest/logs/screenshots riêng; không ghi đè evidence19–27. Bản bàn giao04/10:30ca baseline17PASS/13FAIL, cuối30+focus1 PASS mỗi viewport, typecheck web/p28 exit0; chưa main apply/mobile thật/reduce=true/backend+browser live/public/toànP4/P0–P6.

## 6.19. Phần29: Browser Admin nối backend thật, lab riêng

Đây là lab thực thi29 lịch sử đã được audit độc lập nhận scoped14uniquecontrols/95HTTP; không applymain hoặc toànP4. Cached API/web image `wed-snap-p3-test:local`+PG16.10+Redis7.4.6 pinned, không build/pull/install. API512/web384/PG192/Redis96MiB tổng1184MiB, sourceRO/rootfsRO/privatePID/tmpfs; Prisma clientgenerate chỉtmpfs, migrations chỉ DB mới `wed_snap_admin_browser_test`. Redis13/server riêng. Runner guard resolved+actual/mount/network/resources/datastoreidentity/empty trước seed; từ chối mainfallback/nonemptyforeign data, không reset/flush.

```powershell
cd "D:\WED SNAP"
$p29Stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
powershell -NoProfile -File scripts/test-admin-browser.ps1 -Phase Start 2>&1 | Tee-Object -FilePath "docs/evidence/p29-$p29Stamp-start-local.log"
if ($LASTEXITCODE -ne 0) { throw 'Lab29 guard/start chưa đạt; không chuyển main' }
```

Chỉ web mở127.0.0.1:5179; mở **http://p29.localhost:5179** để tách cookie khỏi localhost chính. API/PG/Redis không publish; backend mạng internal, web thêm frontendbridge riêng+CSPself (không gọi kernel no-egress). `.env` chính không dùng; envexample comment-only. Admin/password/signing random memory/hashproduction; helper relay điền credential ownlab vào form, không xuấtsecret/log/screenshotinputpassword. `__p29` diagnostics chỉharness, không đưa vào production/public. Browser fetch nghiệp vụ giữ native, session từ API thật; không dùng business fixtures hoặc account thật.

UI toolsteps: **1.Guest controls**→helper điền private→native Enter login→**2.Xác nhận login**→reload thật→**3.Cấu hình và campaign**→reload→**4.List,xóa và logout**→reload→đặt360px bằng browser viewport→**5.Sau logout**→native Enter login→**6.Màn hẹp**→native Space ở +Tạo chiến dịch/Enter Đóng→**7.Kết thúc**.13ca độc lập theo `tests/p29/expected.json`, HTTP/DB/audit thật. Supplemental responsive:8private login→nativeEnter→9→Spaceopen→10đo→Enterclose;11chỉcho control narrow lại sau harnesschange, không chạy full27/28. Đặt1280/360 qua browserAPI nếu có; nếu không phải ghi NOT RUN, không giả viewport/media. Reduced=true chỉ thử nếu capability có; không đổiOS/matchMedia.

Sau browser hoàn tất, typecheck tuần tự (không matrix/test nặng song song), giữ log tênmới:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/test-admin-browser.ps1 -Phase Typecheck 2>&1 | Tee-Object -FilePath "docs/evidence/p29-$p29Stamp-typecheck-local.log"
if ($LASTEXITCODE -ne 0) { throw 'Typecheck29 chưa PASS' }
powershell -NoProfile -File scripts/test-admin-browser.ps1 -Phase Logs 2>&1 | Tee-Object -FilePath "docs/evidence/p29-$p29Stamp-browser-local.log"
```

Đóng đúngtab lab29/reset viewport (pagehide unmount/cleanup observers), rồi restore/dọn fixtures trước Stop, giữ volumes:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/test-admin-browser.ps1 -Phase Cleanup 2>&1 | Tee-Object -FilePath "docs/evidence/p29-$p29Stamp-cleanup-local.log"
if ($LASTEXITCODE -ne 0) { throw 'Ownfixture restore chưa PASS; giữ raw, không reset' }
powershell -NoProfile -File scripts/test-admin-browser.ps1 -Phase Stop 2>&1 | Tee-Object -FilePath "docs/evidence/p29-$p29Stamp-stop-local.log"
```

Cleanup guardedfixtureIDs/actor và enumeratedknownprefixkeys; restore baseline settings[]/budget[] deepEqual, charged giữ; close server/datastore clients. Stop riêng4containers/remove, networks/volumes giữ. Không down-v/prune/flush/main. PhaseLaunch chỉ cho trường hợp Start đã guard/generate/migrate rồi bị gián đoạn **trước seed**, còn tables/keys rỗng; không dùng để restartserver đang cófixtures hoặc bỏ guard. Nếu Startup thiếucachedimages/cổng/isolation, báoblocker, không cài/build/mainfallback.

Đối chiếu bằng chứng29 **cố định của04/10**, không rerun browser/backend hoặc oldsuite:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/verify-admin-browser-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'Frozen29 evidence/protected source mismatch' }
```

Bàn giao29:13main+1responsive finalPASS,95HTTP thật;2harnessFAIL giữ riêng (focus measurement/missingCSS), production không sửa. Typecheckexit0, fixturecleanup/StopPASS. Historical27(40/87)/28(31/62/328)/29 đã audit scoped; không rerun ở30. Handoff29 copies/manifests độc lập futureliveprose, không sửa frozen19–28. Chưa mainapply/fullP4/TLS/Secure=true/public/P0nguồn thật/mobile/reduce=true/nativeviewability/R10/Internet/P5P6. R11/timefilters phần30 dưới đây đã được audit độc lập nhận scoped; không chạy lại ở31.

## 6.20. Phần30: R11 thống kê quảng cáo theo thời gian, lab riêng

GET mới `/api/v1/admin/ad-statistics` và controls trong tab Quảng cáo: ISO cótimezone→UTC, from/to cùngcó hoặc cùngbỏ, `[from,to)`, ≤90×24giờ/default7×24giờ đến servernow. Counts theo AdEvent.createdAt thật; đủcampaign0events/CTRnull→“—”, khôngclamp. Dashboard/API cũ giữ. Lịch sử30 đã được audit độc lập nhận scoped; **main chưa apply/client/migration/xác minh**, toànP4/P0–P6/public chưa hoàn tất.

Cached pinned app `wed-snap-p3-test:local`, PG16.10-bookworm, Redis7.4.6-bookworm; script từ chối nếu thiếu/saiimage/isolation/cổng, khôngbuild/pull/install/mainfallback. Project **wed-snap-ad-statistics-lab**, API512/web384/PG192/Redis96MiB=1184MiB, sourceRO/rootfsRO/node/privatePID/resources/tmpfs. Own DB **wed_snap_ad_statistics_test**/Redis13 ownserver; API/PG/Redis khôngpublish, chỉweb127.0.0.1:5181/**p30.localhost** táchcookie khỏi localhost chính. Backplaneinternal, webfrontendbridge+CSPself không là kernelno-egress. `.env` chính không dùng; labenvexample comment-only.

Lệnh tuần tự PowerShell, log tên mới tránh ghi đè evidence lịch sử:

```powershell
cd "D:\WED SNAP"
$p30Stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
powershell -NoProfile -File scripts/test-ad-statistics.ps1 -Phase Start 2>&1 | Tee-Object -FilePath "docs/evidence/p30-$p30Stamp-start-local.log"
if ($LASTEXITCODE -ne 0) { throw 'Lab30 guard/start chưa đạt; không chuyển main hoặc reset' }
powershell -NoProfile -File scripts/test-ad-statistics.ps1 -Phase Verify 2>&1 | Tee-Object -FilePath "docs/evidence/p30-$p30Stamp-verify-local.log"
if ($LASTEXITCODE -ne 0) { throw 'Giữ log FAIL; không tự rerun toàn suite' }
powershell -NoProfile -File scripts/test-ad-statistics.ps1 -Phase Supplement 2>&1 | Tee-Object -FilePath "docs/evidence/p30-$p30Stamp-supplement-local.log"
if ($LASTEXITCODE -ne 0) { throw 'Supplement chưa PASS' }
```

Start guard resolved+actual project/image/cmd/env/mount/network/privatePID/limits/volumes/datastoreidentity/empty trước ghi; clientgenerate **chỉprivate tmpfs**, migrate3migration hiện hành **chỉownDBlab**, khôngschema/migration mới/main/hostnode_modules. Seed1randomadmin productionpasswordHash/inmemorysigning,2disabledcampaign/9eventsUTC tính tay; không cần mật khẩu/tài khoản thật. Verify chạy22matrix→factorygenerate2lần/exportsnapshot→exactSHA/privateoutputcontract5→typecheck API/shared/web/tests tuần tự; Supplement7calendar/leap/offset/auth/noeffects. Không gọi nguồn/worker/media/download hoặc rerunhistory27/28/29/dedupe/lifecycle.

Browser mở **http://p30.localhost:5181/**. **Điền đăng nhập test** chỉrelay randomcredential ownlab vào productionform; nativeEnter đểlogin, không chụp/logpassword. **Chạy browser30 live**→**Kiểm active tab30**→**Kiểm narrow focus30** ở1280/360 bằng browserviewport (ghiNOT RUN nếu công cụ thiếu). Điền From/To, Tab→Tab→Enter tại Xemthốngkê đểnativekeyboardcontrol. **Chạy race30** kiểmnewwindow/logoutrồi vềlogin; điềnowncredential/Enterlogin lại→**Kiểm unmount30**. Racefixture chỉgiữ response HTTP thật tới khi window mới/logout/unmount, không thaypayload/status/auth. Chỉmộtserver/harness/clientsownlab, request bounded250/5s, khôngflood/loginratebypass.

Sauunmount, cookieadminvẫnownlab: mở **http://p30.localhost:5181/extra.html**→**Chạy error controls30** đểkiểmactual400invalidwindow/defaultbutton/realAPIlogout rồistats403 relogin. Extraunmountroot. Keyboard/focus/windowlabel/screenshots1280/360/console ghi raw; narrow khôngđiện thoại thật. Reducedmotiontrue chỉkhi browserAPI thực hỗtrợ; phiên04/10 chỉactualfalse/true chưa thử, không đổiOS/matchMedia. Diagnostic`__p30`/credentialrelay chỉlab, khôngproduction/public.

Đóng đúngtab test/resetviewport, lưu đầy đủ serverraw trước dọn rồicleanupownfixtures/stopgiữvolumes:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/test-ad-statistics.ps1 -Phase Logs 2>&1 | Tee-Object -FilePath "docs/evidence/p30-$p30Stamp-logs-local.log"
powershell -NoProfile -File scripts/test-ad-statistics.ps1 -Phase Cleanup 2>&1 | Tee-Object -FilePath "docs/evidence/p30-$p30Stamp-cleanup-local.log"
if ($LASTEXITCODE -ne 0) { throw 'Ownfixture restore chưa PASS; không reset/flush' }
powershell -NoProfile -File scripts/test-ad-statistics.ps1 -Phase Stop 2>&1 | Tee-Object -FilePath "docs/evidence/p30-$p30Stamp-stop-local.log"
```

Cleanup guardsIDs/ownactor/knownprefixkeys; settings/budget deepEqual/charged giữ, rowsfixture0, closeHTTP/corequeue/datastorehooks. Stop chỉ4owncontainers/remove, namedvols/networks/logs giữ; khôngdown-v/prune/flush/main. Launch chỉcho Start bịngắt **trước seed** nhưng guards/client/migrate đã đạt và tables/keys cònrỗng; không bỏguard/restartservercófixture. Source production đổi tronglúc labactive khiếnactualSHAguard chặn, khôngsửaenvđểépPASS.

Bằngchứng cố định30 đọc offline, khôngrerunruntime/history:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/verify-ad-statistics-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'Frozen30 evidence/protected/source mismatch' }
```

`-CaptureSnapshot` chỉdành cho bàn giao30 ban đầu, mộtlần/từchốighiđèmanifest; **không chạy lại đểép hash** sau revisionmới. Handoffcopies giữprose30, old19–29 unchanged. Raw baseline2FAIL/5HTTP, finalmatrix22PASS/supplement7PASS/contracts5PASS/11browserunique13PASSobservations/typecheckexit0; final63HTTP/tổng170across4lượt, không170cases. Active-tab/contractFAIL đãsửa đúngscope; ENODATA Windowsbind làharness0contractcases, FinalizeChecks sauđó exactSHA/contract/typecheckPASS; không gọiwholeVerifyattemptđóPASS. Details tại TEST_REPORT. Audit30 đã nhận scoped bằng chứng lịch sử; phần31 dưới đây chỉ xử lý batch retention AdEvent. Main/public/load/TLS/Secure=true/Internet/platform/mobile/nativeviewability/reduce=true/toànR10/series/P5P6 chưa nhận. Giữlayout/theme/deps vàquyền hiệnhành.

## 6.21. Phần31: kiểm chứng batch retention AdEvent trong lab riêng

Source worker giữ TTL hiện có **30×24giờ/UTC/createdAt<cutoff**, đúng cutoff giữ tại lượt đó. Mỗi sweep chỉ chọn tối đa500 IDs theo createdAt/id và xóa đúng IDs, kiểm lại cùng cutoff; phần dư sang lượt sau. Không đổi scheduler/cadence hoặc cleanup job/lease/media. Raw đã purge không tái tạo được dù query thống kê cho phép window90ngày; counts0 không chứng minh zero lượt xem thật/lifetime. Backlog expired còn chờ batch có thể vẫn được thống kê. Batch500 không chứng nhận hiệu năng hoặc thời hạn purge backlog.

Own project **wed-snap-ad-retention-lab** dùng cached pins app `wed-snap-p3-test:local`, PostgreSQL16.10-bookworm, Redis7.4.6-bookworm. Node512+PG192+Redis96=**800MiB**, không publish cổng; một network internal riêng, privatePID/rootfsRO/sourceRO/cap-drop/tmpfs bounded. DB **wed_snap_ad_retention_test**, RedisDB12 trên server lab riêng, media **/tmp/p31-media** mới/rỗng trong tmpfs. Không `.env`, datastore, network, admin hoặc media chính. Nếu thiếu cachedimage/identity/empty guard, dừng và báo blocker; không build/pull/install/reset/mainfallback.

Start kiểm resolved+actual project/image/cmd/env/mount/network/resources/volumes, TCP DB cluster/IP/name và Redis run_id/DB12 trước ghi. Client generate chỉ private tmpfs; migrate ba migration hiện hành chỉ ownDB, không schema/migration mới hoặc host node_modules. Matrix kiểm thêm empty job/lease/ticket/outbox/queue trước actual sweep. HTTP nội bộ dùng Nest/auth/AdStatistics/PG/Redis production và cookie admin fixture ngẫu nhiên ký trong memory/ownRedis; không login/password/AdminUser/guest/browser fixture, không bypass business verdict.

Chạy tuần tự; tên log mới không ghi đè bằng chứng lịch sử:

```powershell
cd "D:\WED SNAP"
$p31Stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
powershell -NoProfile -File scripts/test-ad-retention.ps1 -Phase Start 2>&1 | Tee-Object -FilePath "docs/evidence/p31-$p31Stamp-start-local.log"
if ($LASTEXITCODE -ne 0) { throw 'Lab31 guard/start chưa đạt; không reset hoặc dùng main' }
try {
    powershell -NoProfile -File scripts/test-ad-retention.ps1 -Phase Matrix 2>&1 | Tee-Object -FilePath "docs/evidence/p31-$p31Stamp-matrix-local.log"
    if ($LASTEXITCODE -ne 0) { throw 'Giữ raw FAIL; kiểm cleanup trước khi thử lại' }
    powershell -NoProfile -File scripts/test-ad-retention.ps1 -Phase Typecheck 2>&1 | Tee-Object -FilePath "docs/evidence/p31-$p31Stamp-typecheck-local.log"
    if ($LASTEXITCODE -ne 0) { throw 'Typecheck31 chưa PASS' }
} finally {
    powershell -NoProfile -File scripts/test-ad-retention.ps1 -Phase Logs 2>&1 | Tee-Object -FilePath "docs/evidence/p31-$p31Stamp-containers-local.log"
    powershell -NoProfile -File scripts/test-ad-retention.ps1 -Phase Stop 2>&1 | Tee-Object -FilePath "docs/evidence/p31-$p31Stamp-stop-local.log"
    if ($LASTEXITCODE -ne 0) { Write-Warning 'Stop guard chưa đạt; giữ lab/evidence, không reset/flush/down-v' }
}
```

Cleanup fixture nằm trong `Matrix finally`: dọn đúng own event/campaign IDs và hai key fixture, settings/budget deepEqual, đóng HTTP/datastore/hooks. Media phải đúng resolved path/không symlink/rỗng trước rmdir không recursive. `Start`/`Matrix` gọi `Stores`/`Empty` để kiểm datastore identity và trạng thái rỗng theo runner; `Matrix` kiểm rỗng trước test và sau khi test kết thúc thành công.

`Stop` kiểm cấu hình và own container identity qua `Actual`, rồi stop/remove ba own containers, giữ named volumes/network/raw log. **Stop không tự kiểm DB/Redis rỗng và không cleanup fixture.** Nếu process bị ngắt trước `Matrix finally`, fixture có thể còn trong volumes; **Stop PASS không chứng minh fixture đã sạch**. Các guard rỗng của Start/Matrix có thể chặn lần chạy sau; không bỏ guard, chuyển sang main, tự xóa dữ liệu hoặc reset/flush/down-v/prune. Không có browser/cổng host để mở. Đây là sửa hướng dẫn F31.1 ở phần32, chưa thử Stop-with-leftovers.

Bằng chứng lịch sử04/10/2026 đã được audit31 nhận chức năng scoped: baseline mã cũ **8PASS/4FAIL/exit1** trong12ca, TTL boundary đãPASS; chỉ thiếu batch nên501→0 ở cả deterministic/actual sweep. Sau sửa **12/12PASS/3HTTP**, deleted500→1→0 đúng IDs, PG row-lock recheck giữ row được cập nhật fresh; actual sweep dùng clock thật/marginseed riêng. Mỗi revision **3HTTP thật** (403 guard/200 stats trước/200 sau), tổng6HTTP; không phải12HTTP business. Typecheck là **một tsc** include worker/API/shared/tests31, noEmit/exit0. Controlled Date/helper clock chỉ cho boundary, không chứng nhận scheduler. Admin-cookie/ownRedis identity fixture và outside-model/settings/budget baseline[] không chứng nhận login/browser/live lease/charged khác0. `Baseline` là chế độ đối chứng sweep; raw FAIL được giữ từ source trước sửa, không kỳ vọng source hiện hành phải FAIL. Phần32 chỉ đối chiếu tài liệu/offline, không chạy lại những ca runtime này.

Đọc bằng chứng offline, không rerun lab hoặc các suite19–30:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/verify-ad-retention-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'Frozen31 evidence/source/protected hash mismatch' }
```

`-CaptureSnapshot` chỉ bàn giao31 lần đầu và từ chối ghi đè manifest; không dùng để ép hash sau revision. Giữ frozen19–32 và source ngoài phạm vi. **Chức năng31 đã audit nhận scoped; phần32 đã nghiệm thu tài liệu/F31.1 đóng.** Bằng chứng sửa docs/SHA/diff/line refs và verifier offline riêng tại `docs/evidence/p32-20261004-*`, không sửa raw/copies/manifest31/32. Chưa main apply, chưa chứng nhận scheduler/load/SLA, live job/lease/transfer hoặc charged khác0, nền tảng/Internet/browser/public/fullR10/fullP4/P0–P6. Sau thay đổi logging hợp lệ ở33, dùng successor verifier33 dưới đây; verifier31 lịch sử có thể báo current compose hash khác, không sửa old manifest/validator để ép PASS.

## 6.22. Phần33: Docker log rotation cấp dự án, đã nghiệm thu độc lập scoped

`compose.yaml` thêm policy chung **json-file**, options string **max-size="10m"/max-file="3"** cho api/worker/web/postgres/redis/egress. Policy kế thừa qua x-app và áp dụng rõ cho ba service còn lại. Render trước/sau chỉ dùng `infra/log-rotation-lab.env.example` placeholder, tạm clear/restore process interpolation vars; không đọc main `.env`. Canonical và diff source giữ mọi field ngoài logging/extension policy: command/env/image/resources/ports/networks/mounts/deps/healthcheck/restart.

Chỉ đổi source; phiên33 **không start/recreate/apply main**, không kiểm policy daemon/main container hiện hữu và không gọi log thực đang unlimited/diskfull. Container hiện hữu không tự nhận cấu hình mới; main10m/3 chưa được kiểm chứng. Rotation loại logs cũ theo driver policy, không phải lưu log vĩnh viễn; khi cần giữ bằng chứng phải lưu qua Docker API/logs phù hợp trước khi bị loại. Không đọc/xóa trực tiếp log files của daemon, không đổi Docker settings. Nguồn: [Docker JSON File logging driver](https://docs.docker.com/engine/logging/drivers/json-file/).

Own probe **wed-snap-log-rotation-lab** chỉ một cached pinned Node container:96MiB/CPU0.25/PIDs32/usernode/rootfsRO/privatePID/capdrop/no-new-privileges/**network:none**, không ports/data volumes/datastores/API/worker/media/Internet. Chỉ mount `tests/p33/probe.cjs` RO và tmpfs riêng8MiB. Guard resolved+actual identity/image/cmd/mount/env/network/resources/HostConfig.LogConfig **trước grant emit**. Probe dùng **64k/3**, khác10m/3 source; không build/pull/install. Writer stdout512records×1024bytes+completion marker=**524468bytes**, chờ drain và actualexit0. `logs --tail all` giữ **158records liên tục355–512 +marker**, không còn1–354; không dùng tailN tạo proof giả. Không đọc daemon files hoặc chứng nhận chính xác3physical files/hard diskcap/main10m/load/SLA/fullR10.

Raw/expected/source copies/SHA/filtered inspect/commands ở `docs/evidence/p33-20261004-*`, `tests/p33`. `test-log-rotation.ps1` có Baseline/Source/Probe/Cleanup; các lệnh đã chạy ngày04/10 là lịch sử, path evidence cố định **từ chối ghi đè**. Không chạy lại default phases để ép PASS hoặc xóa raw. Probe finally guard rồi stop/remove đúng owncontainer, giữ host raw; không có DB/media/data volumes để dọn. Cleanup-only sau attempt harness lỗi có guard riêng, không gọi đó là rotation PASS. Nếu guard/cachedimage/quyền chặn, giữ log và báo blocker, không dùng main hoặc reset/prune.

Đối chiếu bàn giao33 offline, không chạy lại probe hay lịch sử31/32:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/verify-log-rotation-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'Successor33 policy/evidence/preservation mismatch' }
```

Successor33 lịch sử chỉ exempt đúng **current compose + sáu docs cho phép**; frozen copies/raw/tests/expected/manifests19–32 và current app runtime16 không exempt. Kiểm các inventory chồng lặp riêng, không cộng thành tổngtệp: before33 có1094paths/1087giữ; old31 checked1025/1027 (chỉ currentcompose/RUNBOOK exempt), runtime16/artifacts36; old32 checked1066/1073 sau7currentexempt/artifacts20. Snapshot33 giữ, không đổi oldverifier/manifest. `-CaptureSnapshot` chỉ lần bàn giao ban đầu, không chạy lại để ép SHA. **33 đã được kiểm toán độc lập nghiệm thu scoped**, source6policies10m/3+ownprobe64k/3; main/public/toànR10/P4/P0–P6 chưa hoàn tất. Sau thay đổi schema/lifecycle được giao ở34, verifier33 lịch sử có thể báo current runtime hash khác; dùng successor34 bên dưới, không sửa validator/manifest lịch sử để ép PASS.

## 6.23. Phần34: retention chỉ worker.metrics, lịch sử đã nghiệm thu scoped

Policy mới **chỉ AuditLog actor=worker VÀ action=worker.metrics**: TTL30×24h UTC, strict createdAt<cutoff, exact cutoff được giữ trong lượt đó. Mỗi sweep chọn tối đa500id theo createdAt/id, delete đúng ids và recheck cùng actor/action/cutoff; không loop hết backlog. Tất cả nhật ký quản trị/actor/action khác giữ nguyên. AdEvent TTL/job-lease-media/cadence/concurrency/processor/main/API/UI không đổi. Schema thêm duy nhất index `[actor,action,createdAt,id]`, migration `202610040001_worker_metrics_retention_index` chỉ CREATE INDEX. **Chỉ đã apply DB lab34/main chưa apply hoặc regenerate client.** Không coi index là benchmark hoặc bảo đảm thời gian.

Lab `wed-snap-worker-metrics-retention-lab`:3cached pinned images app512MiB+PG192MiB+Redis96MiB=**800MiB limits**, privatePID/sourceRO/rootfsRO/internalnetwork/noports/noAPI/browser/Internet/worker-main/mainmounts. DB `wed_snap_worker_metrics_retention_test`, RedisDB11 trên server riêng, namedvolumes riêng; clientgenerate chỉ private tmpfs. Guard resolved+actual image/project/cmd/env/mount/resources/network và DBnumericIP/cluster/Redisrun_id/emptymodels trước generate/migrate/fixtures. Không đọc main.env hoặc cài/build/pull.

Chạy từng phase tuần tự từ PowerShell; không dùng các lệnh khởi động stack chính cho lab này:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/test-worker-metrics-retention.ps1 -Phase Start
if ($LASTEXITCODE -ne 0) { throw 'Ownlab34 guard/start failed' }
powershell -NoProfile -File scripts/test-worker-metrics-retention.ps1 -Phase Matrix
if ($LASTEXITCODE -ne 0) { throw 'Matrix34 failed; preserve raw, inspect guarded own fixtures' }
powershell -NoProfile -File scripts/test-worker-metrics-retention.ps1 -Phase Typecheck
if ($LASTEXITCODE -ne 0) { throw 'Typecheck34 failed' }
powershell -NoProfile -File scripts/test-worker-metrics-retention.ps1 -Phase Stop
if ($LASTEXITCODE -ne 0) { throw 'Ownlab34 stop guard failed' }
powershell -NoProfile -File scripts/verify-worker-metrics-retention-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'Successor34 proof/hash mismatch' }
```

`Start`/`Matrix` xác minh datastore/empty guards. Matrix finally cleanup **chỉ** rows marker34/fixture IDs/settings-budget sentinel/known queue keys; settings/charged37 được đối chiếu giữ trước cleanup; media private nonsymlink/resolved/empty trước rmdir không recursive. Matrix PASS +post-Empty là proof models/Redis sạch. **Stop chỉ guard config/owncontainer identity, stop/remove3containers; giữ volumes/network/raw; không tự kiểm DB-Redis sạch hoặc cleanup fixture.** Nếu process chết trướcfinally, StopPASS không chứng minh sạch; không reset/flush/down-v/prune/tự xóa dữ liệu hoặc chuyển main để né guard.

Baseline lịch sử34 source chưa retention/index:13controls2PASS/8FAIL/3SKIP/exit1, đúng expected-negative; không gọi main đầy hoặc TTL AdEvent mất. Final cùng expected/test **13PASS**/exit0: explicit-clock helper và manual production sweep/realclock riêng500→1→0, strict boundary/order/groups/admin preservation và3PG row-lock rechecks. **Một** tsc worker/shared/tests34/noEmit PASS;0HTTP/workerjobs. Fixture clock/manual sweep không chứng nhận startup/timer scheduler/liveleases/load/SLA/nguồn thật/public/toànR10/P4/P0–P6.

Evidence riêng `docs/evidence/p34-20261004-*`, bảo vệ frozen19–33/36artifacts31/20artifacts32/50artifacts33/supplement; expected/test trước–sau giữ. Successor34 chỉ exempt current schema/lifecycle/6docs cho phép, không frozenpath. Compose bắt buộc SHAaccepted33fe92fa79… (oldpre33hash dùng successor đãnghiệmthu, không exempt34). Không cộng inventories chồnglặp hoặc sửa oldvalidator/manifest/copies/raw. `-CaptureSnapshot` của verifier34 chỉ một lần bàn giao mới, từ chối overwrite; lệnh kiểm tra ở trên không CaptureSnapshot. **34 đã nghiệm thu scoped13PASS/F34.H1coverage đóng64artifacts;33scoped/32F31.1đóng/31scoped giữ/main chưa apply.** Đồng bộ từ kiểm toán lịch sử, không rerun34 trong35.

## 6.24. Phần35: entrypoint worker tự sweep trong ownlab, đã kiểm toán độc lập nghiệm thu scoped

Lab riêng `wed-snap-worker-scheduler-lab`, DB `wed_snap_worker_scheduler_test`, RedisDB10/server riêng; cached pinned3services/**800MiB total memory limits**, privatePID/internal/noports/source-rootfsRO, không API/browser/Internet/mainmounts. Clientgenerate chỉprivate tmpfs,4existing migrations chỉownDB; không build/pull/install/migration mới/mainapply. Fixture `SWEEP_SECONDS=2` và effective limits2 trước boot; **source default30/concurrency1 giữ**, không suy fixture2s thành maincadence/SLA.

Chạy tuần tự, chỉ khi được giao lab35; các guard resolved/actual/image/project/command/env/mount/resources/datastore/emptyqueue-models/media phải PASS trước ghi:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/test-worker-scheduler.ps1 -Phase Start
if ($LASTEXITCODE -ne 0) { throw 'Ownlab35 guard/start failed' }
powershell -NoProfile -File scripts/test-worker-scheduler.ps1 -Phase Matrix
if ($LASTEXITCODE -ne 0) { throw 'Matrix35 failed; preserve raw and guarded fixture state' }
powershell -NoProfile -File scripts/test-worker-scheduler.ps1 -Phase Typecheck
if ($LASTEXITCODE -ne 0) { throw 'Typecheck35 failed' }
powershell -NoProfile -File scripts/test-worker-scheduler.ps1 -Phase Stop
if ($LASTEXITCODE -ne 0) { throw 'Ownlab35 stop guard failed' }
powershell -NoProfile -File scripts/verify-worker-scheduler-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'Successor35 proof/hash mismatch' }
```

Matrix parent **không gọi sweep/helper**, child đúng Node argv entrypoint production. PG latches thật giữ startup trước ready và periodic sau ready để đọc1001→501→1→0/exact deleted IDs500/500/1; periodic rowlock≥2fixtureintervals để quan sát bounded sampled nonoverlap. Final **11PASS**,81samples/4273.065ms/oneDELETE; SIGTERM idle actualchildexit0/connectionsclosed. Settings/charged37/admin/freshAdEvent controls giữ. Không mock Date/timer/BullMQ/Prisma/business hoặc chứng nhận mọi instant/branch/livejob/lease/shutdown-inflight/load/default30/public/fullR10/P3/P4/P0–P6.

Lượt đầu PIDs64 bị native thread limit/SIGABRT, cgroup max2/OOM0; raw2PASS/1FAIL/8NOT_RUN+cleanup giữ. Chỉ app ownlabPIDs192, tổngmemory vẫn800MiB/source/test/expected không đổi; final max0/OOM0. Không đổi Docker host/WSL hoặc runtime policy. Evidence35/TEST_REPORT lưu quote diagnostics FAIL và final commands/exits riêng, không quy lỗi fixture thành production.

Matrix finally chỉ cleanup ownIDs/keys/settings-budget sentinel/locks/clients/child, verifiedempty rồi nonrecursive media rmdir; post-Empty guard riêng. **Stop chỉ identity/config+stop/removeown3, giữvolumes/network/raw; không tự kiểm DB-Redis sạch hoặc cleanup fixture.** Process ngắt trướcfinally có thể cònfixture dù StopPASS; không reset/flush/down-v/prune/tựxóa dữliệu hoặc chuyển main.

Successor35 chỉ exempt6currentdocs/**production exemption0**; accepted34 currentCode4/64artifacts+supplement, Composeaccepted33/frozen19–34 giữ. Before1218paths và manifest mới distinct actualfilecoverage/SHA; không cộng inventory chồnglặp hoặc sửa historicalvalidator/manifest. `-CaptureSnapshot` chỉmột lần bàn giao mới/refuseoverwrite, lệnh đọc trên không CaptureSnapshot. **35 đã audit nghiệm thu scoped; main chưastart/apply/nhận scheduler proof.**

Offline bàn giao35 PASS exit0 UTC12:52:53.252/VN19:52:53.252, **61frozen artifacts/1212protected paths ngoài6docs**; đối chiếu actual candidatefilelist/SHA độc lập exit0 UTC12:53:46.806. Source-final copies chốt trước dòng completion này; supplementary/live-docSHA/offline logs ghi riêng, không overwrite snapshot. Không chạy lại runtime lịch sử để đồng bộ nhãn.

## 6.25. Phần36: SIGTERM khi periodic sweep chờ PG lock, chờ kiểm toán độc lập

Chỉ `apps/worker/src/main.ts` sửa sau baselineproductionFAIL: dừngtimer/chặn lượt mới, awaitactiveSweep bằngshutdownPromise trước đóngresources. CùngmatrixV4 **9PASS2FAIL→11PASS/exit0**; giữstartup/default30/concurrency1/lifecycle/helpers/processor/core/schema/Compose. Main chưastart/apply. 35 đãaudit scoped11/F35.H1đóng, frozen19–35/61snapshot+65supplement35/64artifacts34 giữ; không rerun lịch sử.

Ownproject `wed-snap-worker-shutdown-lab`, DB `wed_snap_worker_shutdown_test`, RedisDB9/serverriêng; cachedpinned3services/tổngmemory800MiB/privatePID/source-rootfsRO/internal/noports/noInternet/API/browser/mainmounts. Clientgenerate chỉprivate tmpfs/4existing migrationsonlyownDB; khôngbuild/pull/install/schema mới/main.env/mainclient. FixtureSWEEP_SECONDS2/effective2 khácsource30. Cácguardsresolved+actual/image/cmd/env/mount/resources/numericDB-IP/cluster/Redisrun/emptyqueue-models/media phảiPASS trước ghi.

Chỉ chạy khi được giao lab36, tuần tự:

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/test-worker-shutdown.ps1 -Phase Start
if ($LASTEXITCODE -ne 0) { throw 'Ownlab36 guard/start failed' }
powershell -NoProfile -File scripts/test-worker-shutdown.ps1 -Phase Matrix
if ($LASTEXITCODE -ne 0) { throw 'Matrix36 failed; preserve raw and own fixture state' }
powershell -NoProfile -File scripts/test-worker-shutdown.ps1 -Phase Typecheck
if ($LASTEXITCODE -ne 0) { throw 'Typecheck36 failed' }
powershell -NoProfile -File scripts/test-worker-shutdown.ps1 -Phase Stop
if ($LASTEXITCODE -ne 0) { throw 'Ownlab36 stop/empty guard failed' }
powershell -NoProfile -File scripts/verify-worker-shutdown-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'Successor36 evidence/hash mismatch' }
```

Child chạy productionentrypoint bằngargvarray; parentkhônggọi sweep/helper/main hoặcmockclock/timer/Prisma/BullMQ/business. Startup500/còn501 làprecondition. Expired/freshSession seedsauready; periodicrow500DELETEblocked→SIGTERMownchildguard→held313.265ms/11samples→alllatchesreleased346.862ms≤1000. Currentmetricbatch500/cònID1000, tailDELETE Session/expiredgone/freshgiữ khiPID/startTicks/stateR cònlive; actualexit0/13.949ms saurelease≤5000, PG/Redis/consumers0/postexit4110.537msDBnochange. Admin/groups/settings/charged37 giữ; idlecontrol riêngexit0. Không dùngfinally/idlecleanup/exit0 riêng làmproofprimarysweep.

V1/V2/V3rawFAIL vàsourcecopies giữ: lazyobserverpool/idlepredicate/liveproof missed, không quy thành thêmproductionbug; expected/timingkhôngđổi. FinalV4sourcebefore/fixedcùngtesthash, khôngfake/mockingverdict/childdelay. Mộttsc worker/shared/tests36PASS; noAPI/UI/backlogrerun. TEST_REPORT/ledger/evidence `p36-20261004-*` cóactualUTC/VN/commandexits, ngàyVNqua05/10.

Finally chỉdọnownedIDs/knownqueuekeys/settings-budgetsentinels/locks/children/nativeclients; charged37 giữđếncleanup/modelkeysempty/ownmediaresolvednonsymlinkemptyrmdirnonrecursive. **Own36Stop cóStores+Empty trướcstop/removeown3** (kháchistorical35), giữvolumes/network/raw, khôngtựcleanupfixture. NếuMatrixchếttrướcfinally/leftovers, giữrawvàkiểmtraownidentity; khôngreset/flush/down-v/prune/bỏguard/mainfallback. FinalStopactualexit0/containers0.

Successor36 chỉexempt6currentdocs vàexactconditionalmain7d95c15b…a47ac0f backedbybaselineFAIL; before1284distinct/1277protected, mọifrozen19–35/accepted34current4/Compose33 giữ. Manifestdistinctactualcoverage/SHA/self/postSnapshotriêng, khôngsửahistoricalvalidator/manifest. Verifierởtrênchỉđọc, khôngCaptureSnapshot/reruntime/mainapply. **36chờaudit độclập**; fixture2s/emptyjobs/PGlocks/boundedwindow khôngnhậnshutdown-inflightlivejob/transfer/default30/maincadence/load/SLA/platform/watermark/public/fullR10/P3/P4/P0–P6.

## 7. Thử nguồn thật P0

`docs/p0-samples.json` chứa mẫu phim mở Blender, phải giữ thông tin tác giả/giấy phép khi sử dụng. Để kiểm chứng nền tảng khác, thêm tối thiểu 3 mẫu bạn có quyền tải cho mỗi loại nội dung cùng ca không tồn tại/đã xóa/cần đăng nhập. Không gửi cookie tài khoản. Script sau đánh giá yt-dlp trực tiếp trong container; kết quả cuối phải kiểm tra lại qua adapter bảo mật và website.

```powershell
cd "D:\WED SNAP"
docker build -f apps/media/Dockerfile -t wed-snap-media:2026.08.19 .
New-Item -ItemType Directory -Force .\docs\evidence | Out-Null
docker run --rm --memory=768m --cpus=1 --mount 'type=bind,source=D:\WED SNAP\scripts,target=/scripts,readonly' --mount 'type=bind,source=D:\WED SNAP\docs,target=/docs,readonly' --mount 'type=bind,source=D:\WED SNAP\docs\evidence,target=/evidence' wed-snap-media:2026.08.19 python3 /scripts/p0.py /docs/p0-samples.json
```

Bằng chứng thô/media không được Git theo dõi. Báo cáo phải phân biệt metadata thành công, download thành công và file đã kiểm tra phát. Không dùng bằng chứng từ lần trước để tuyên bố lần mới thành công.

Lệnh adapter bảo mật và luồng API thật ở [ADAPTERS](docs/ADAPTERS.md). CLI trực tiếp chỉ để đánh giá công cụ; không thay worker có proxy bảo vệ SSRF.

## 8. Làm tiếp và dừng

```powershell
cd "D:\WED SNAP"
docker compose up -d
```

React/Vite và API hỗ trợ hot reload source bind mount chỉ đọc. Sau sửa worker hoặc adapter:

```powershell
cd "D:\WED SNAP"
docker compose restart worker
```

Sau sửa dependencies, schema, Dockerfile hoặc mã cần image mới, build `api` rồi recreate các app; luôn migrate trước khi khởi động phiên bản cần schema mới. Khi nghỉ:

```powershell
cd "D:\WED SNAP"
docker compose stop
```

`stop` giữ volumes. Sau đó có thể Quit Docker Desktop ở khay hệ thống; `wsl --shutdown` sẽ dừng **tất cả** distro WSL đang chạy, chỉ thực hiện khi bạn muốn dừng chúng. Không dùng `docker compose down -v` để nghỉ.

## Tài liệu bàn giao

- [PROGRESS](docs/PROGRESS.md): trạng thái và bước tiếp theo.
- [ADAPTERS](docs/ADAPTERS.md): tải thật, phạm vi được bật.
- [TEST_REPORT](docs/TEST_REPORT.md): bằng chứng kiểm thử và thiếu sót.
- [API](docs/API.md), [LIFECYCLE](docs/LIFECYCLE.md): hợp đồng và TTL.
- [RUNBOOK](docs/RUNBOOK.md): sự cố, backup/restore, chi phí.
- [DEPLOYMENT](docs/DEPLOYMENT.md): chuẩn bị P5–P6, chưa deploy.
- [DEPENDENCIES](docs/DEPENDENCIES.md): phiên bản và giấy phép.
- [CODE_STRUCTURE](docs/CODE_STRUCTURE.md): trách nhiệm component, trang, controller/service và worker.
- [MAINTENANCE](docs/MAINTENANCE.md): rà soát artifact và dọn đúng phạm vi sau khi kiểm thử.


### Kiểm tra offline công cụ TikTok37.2 sau review (05/10/2026)

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File tests/p37/review_runner.ps1
powershell -NoProfile -File tests/p37/run-372.ps1 -Stage offline
```

Lệnh đầu kiểm hàm runner thật với Docker I/O doubles, không chạy container. Lệnh sau dùng cached image/pin hiện có, tạo thư mục evidence riêng tự động, guard và chạy container network none, rồi dọn đúng tài nguyên của lượt chạy. Không dùng lại thư mục evidence lịch sử. Không chạy Compose lab A/B trực tiếp: output/run-ID phải do runner cấp. Việc thiếu curl_cffi/targets chỉ là kết quả capability; chưa có A/B hoặc tải TikTok đạt. Test Python baseline/final và lệnh thực chạy xem `docs/evidence/p37-2-review-20261005/` và TEST_REPORT; không cần chạy lại backlog.
