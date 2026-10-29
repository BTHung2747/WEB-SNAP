# Chuẩn bị P5–P6 — chưa deploy

Không thuê VPS, mua domain, mở public hoặc tích hợp tài khoản quảng cáo trong phiên triển khai local.

## P5: VPS thử nghiệm ngắn hạn

1. Chủ dự án chọn ngân sách/VPS Linux/IP và quyền thử; chỉ sau đó mới triển khai. Không giả định gói frontend miễn phí cho phép media backend.
2. Dùng static Vite build qua reverse proxy; API/worker từ image đã lock. **Không dùng Vite dev/tsx watch để public.** Chuyển API sang `node dist/apps/api/src/main.js`, worker tương tự; không bind source trong production.
3. Dùng TLS thật, domain `APP_ORIGIN`, `COOKIE_SECURE=true`; firewall chỉ 80/443 và SSH cần thiết. PostgreSQL/Redis/egress chỉ nội bộ. Giữ worker internal network và proxy kiểm tra DNS/IP; không publish CONNECT proxy.
4. Khởi tạo secret khác local, migration deploy, admin không mặc định. Giới hạn upload/body tại reverse proxy, timeout truyền lớn hơn deadline app có chủ đích; no buffering toàn video. Health route không tiết lộ secrets.
5. Chạy lại P0 **từ IP VPS**: tối thiểu 3 mẫu được phép mỗi loại dự kiến bật, ca sai/đã xóa/auth, ffprobe + phát có tiếng. Ghi ngày/version/IP môi trường (IP có thể che trong bản công khai), mode/input/output/deadline. Nếu IP bị chặn, tắt nền tảng; không bypass truy cập.
6. Test workflow thật desktop và điện thoại ít nhất một trình duyệt mỗi loại; thử Range/retry, rời trang chưa tải, đóng tab khi đang tải, mất mạng, restart API/worker, disk80%, ngân sách, SSRF redirect/DNS.
7. Đo RAM/CPU/disk/input/output/workerSeconds trên tải có kiểm soát; chọn giới hạn vận hành từ số liệu. Local concurrency1; không tự tăng server concurrency trước khi đo.
8. Bổ sung structured metrics, cảnh báo disk/queue/error/egress, log retention/rotation, bản backup được mã hóa/cất riêng và thử restore. Chưa có gửi cảnh báo/email/Slack tự động trong MVP local.

## P6: Mở có kiểm soát

- Chỉ bật adapter/loại nội dung đạt P5, ghi phạm vi công khai trung thực. Bổ sung CONTACT_EMAIL thật, điều khoản/quyền riêng tư và quy trình báo cáo.
- Có người chịu trách nhiệm xử lý sự cố; xác nhận restore admin/campaign/settings thành công trên target riêng.
- Chuẩn bị tắt `acceptJobs` và adapter; thử rollout/rollback không mất quyền phiên đang truyền.
- Đặt ngân sách tháng và bộ chặn; đối soát phí nhà cung cấp; chống abuse và đo lượng tải. Không tuyên bố doanh thu hoặc lượt xem từ click nội bộ.
- Nếu dùng mạng quảng cáo/affiliate, chủ web cung cấp chương trình/tài khoản/điều kiện đã duyệt; kiểm tra link và nội dung theo chương trình. Không nhập script HTML tùy ý vào admin.
- Mở giới hạn ít người trước; kiểm tra sweep/crash/restore trong nhiều chu kỳ; tăng tải dựa trên số liệu, không cam kết mọi URL/nền tảng.

Điều kiện còn chặn public được theo dõi trong docs/PROGRESS.md và TEST_REPORT.md. Việc có cấu hình deploy/runbook không có nghĩa P5–P6 đã thực hiện.

## Gói một máy Linux amd64 — chuẩn bị offline29/10/2026

Các lệnh dưới là **runbook cho operator sau khi được giao target**, chưa thực thi. Không dùng chúng trên stack local đang chạy. Không tạo EC2/DNS/AWS credentials hoặc nâng tài khoản khi chỉ chuẩn bị gói. Sizing ban đầu4GiB, concurrency1 là cấu hình giới hạn, chưa phải benchmark target; không cần RDS/ALB/NAT Gateway ở kiến trúc một máy này.

### Recipe và phiên bản

- `compose.production.yaml` là file **độc lập**, project `wed-snap-production`; không ghép với `compose.yaml` hay ba override local. Không có build/source bind/watch/Vite dev; API/worker dùng `node dist/.../main.js` trong app image hiện có. Không đổi chức năng tải hoặc lockfile.
- `infra/production/Dockerfile.web` lấy `/app/apps/web/dist` từ **cùng app release**, chạy static SPA và reverse proxy bằng **official `caddy:2.11.7-alpine`**. Pin exact version, Apache-2.0; [official-images](https://github.com/docker-library/official-images/blob/master/library/caddy) chỉ tới Docker recipe commit **9234f5785658cae8129bfae366e196d0670468ac**, [Dockerfile tại commit đó](https://github.com/caddyserver/caddy-docker/blob/9234f5785658cae8129bfae366e196d0670468ac/2.11/alpine/Dockerfile). Không tải image trong lượt chuẩn bị; **OCI digest chưa resolve**. Trước build phát hành, resolve/lưu digest thực của base và output images vào release record; tag version không được gọi là pin content bất biến. Không dùng `latest`, không thay base/deps app chỉ để build proxy.
- Caddyfile dựa trên [SPA/API pattern](https://caddyserver.com/docs/caddyfile/patterns#single-page-apps-spas), [reverse proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy) và [global options](https://caddyserver.com/docs/caddyfile/options); đối chiếu parser [tag2.11.7](https://github.com/caddyserver/caddy/blob/v2.11.7/modules/caddyhttp/reverseproxy/caddyfile.go). Chỉ dùng tính năng built-in, không plugin/framework mới. [Automatic HTTPS](https://caddyserver.com/docs/automatic-https) cần DNS trỏ đúng origin, inbound80/443 và outbound ACME; chưa chứng minh certificate/renewal trên target.
- Proxy user1000/capdropALL, listen nội bộ8080/8443 và map host80/443; Caddy `http_port`/`https_port` dùng đúng chức năng chuyển tiếp cổng, vẫn redirect khách tới HTTPS443. HTTP/1.1+HTTP/2, chưa bật UDP/HTTP3. Data/config Caddy riêng giữ certificate; health8090 chỉ loopback container, admin API tắt.
- API/worker/postgres/redis chỉ mạng internal. Egress là tiến trình nguồn duy nhất có outbound, giữ CONNECT DNS/IP/SSRF/TLS và phase proof. Proxy có frontend để nhận HTTPS/ACME, mạng `proxy_api` internal chỉ tới API; API không có outbound. API tin đúng DNS host `proxy`; Caddy ghi đè XFF bằng một TCP peer, bỏ Forwarded/X-Real-IP. Phương án này giả định **DNS only/direct client→Caddy**; không đặt CDN/Tunnel/ALB phía trước rồi tự tin CF-Connecting-IP/XFF do khách gửi. Nếu đổi proxy chain cần review riêng.

### Chuẩn bị release, chưa bật máy để build thử

Trên máy build/CI amd64 đã được giao, làm tuần tự, không dùng dữ liệu production:

```sh
set -euo pipefail
# Ví dụ tên release công khai, thay bằng release đã review; không secret trong args.
APP_RELEASE=wed-snap-app:beta-RELEASE
EGRESS_RELEASE=wed-snap-egress:beta-RELEASE
WEB_RELEASE=wed-snap-web:beta-RELEASE
docker build --platform linux/amd64 -f Dockerfile -t "$APP_RELEASE" .
docker build --platform linux/amd64 -f infra/production/Dockerfile.web \
  --build-arg APP_IMAGE="$APP_RELEASE" -t "$WEB_RELEASE" .
docker build --platform linux/amd64 -f apps/egress/Dockerfile -t "$EGRESS_RELEASE" .
```

App build hiện có thực hiện Prisma generate, tsc và Vite build; web recipe chỉ COPY static từ app, không chạy Vite server. Kiểm artifact/entrypoint trong image: `dist/apps/api/src/main.js`, `dist/apps/worker/src/main.js`, `dist/scripts/create-admin.js`, `/app/infra/media_adapter.py`, TikTok package/LICENSE/NOTICE và static `index.html/assets`. Validate **bằng Caddy binary đúng pin** trước cấp TLS: `caddy adapt --config /etc/caddy/Caddyfile --adapter caddyfile --validate` với hostname/email giả trong container riêng `--network none`. Đây là cổng target/release chưa chạy trong lượt offline này; không coi kiểm đường COPY là đã có static bundle mới.

Giữ sizing4GiB để chuẩn bị; chủ chưa chọn cấu hình máy cuối. Sáu role runtime có tổng cap1760MiB; máy2GiB chỉ còn288MiB so với tổng cap đó **trước** OS/Docker/page cache và các peak khác, nên chưa có căn cứ nói đủ. Nếu tools384MiB chạy cùng toàn bộ runtime thì tổng cap2144MiB đã vượt2GiB; bootstrap đúng thứ tự chỉ PG+Redis+tools là768MiB, không cần mở toàn stack. Các con số này là tổng trần khai báo, không RAM thực đo hoặc cam kết dùng hết. Không tự hạ worker768MiB hoặc caps media để ép vừa máy nhỏ. Build tuần tự trên máy build/CI được giao, ưu tiên máy có headroom (máy local8GB vẫn không build/test nặng song song), rồi chuyển image; chưa đo peak build và không khuyên build trên máy2GiB đang phục vụ. Không thêm profile/benchmark trong gói chuẩn bị này.

Ghi commit/source delta, lockfile, full image IDs/digests, build logs và Caddy base digest; chuyển bằng registry private hoặc `docker save`/`load` theo quyền được giao. Target chỉ nạp đúng image đã review, không build lúc khởi động (`pull_policy: never`, không `build:` trong Compose). Giữ image trước để rollback. Cung cấp corresponding source/giữ LICENSE và NOTICE của Cobalt/AGPL code khi phát hành, không đưa env/secrets vào source bundle.

### Release qua GitHub Actions → GHCR — chuẩn bị29/10, chưa chạy

Luồng ưu tiên hiện tại là [workflow release](../.github/workflows/release.yml) trên GitHub; không cần mở Docker hoặc giải phóng RAM máy local để chuẩn bị bước này. Workflow chỉ có `workflow_dispatch`, chỉ nhận repo `BTHung2747/WEB-SNAP`/nhánh `main`, một job Ubuntu24.04 x86_64/45phút, không chạy khi push/PR và không deploy. Mỗi lần build tuần tự **app → web lấy static từ chính app đó → egress**, Linux/amd64; giữ Dockerfiles app/egress, dependencies/lockfile và runtime. Web recipe chỉ thêm ARG CADDY_IMAGE để CI dùng chính official digest vừa resolve; mặc định build thủ công vẫn caddy:2.11.7-alpine. Không migration/settings/DB/nguồn trong CI. Dùng Docker CLI có sẵn trên runner và duy nhất Action [checkout v7.0.1 ghim commit3d3c42e5aac5ba805825da76410c181273ba90b1](https://github.com/actions/checkout/commit/3d3c42e5aac5ba805825da76410c181273ba90b1), Node24 theo [action.yml đúng tag](https://github.com/actions/checkout/blob/v7.0.1/action.yml); không lưu checkout credential.

Trước publish, container kiểm riêng `network none`/nonroot/rootfsRO/capdrop/no-new-privileges/privateIPC/pids64, tối đa một container, caps512MiB hoặc Caddy128MiB. Kiểm compiled API/worker/admin bằng `node --check`, tệp media/license, static app và web trùng toàn bộ fileSHA, egress Python syntax bằng `compile` không execute/start server. Caddy **binary của web image** phải báo2.11.7, `adapt` rồi `validate` Caddyfile thật với hostname/email `.invalid`, tmpfs data/config và timeout hữu hạn; không bật server/ACME. Đây là artifact/config gate, chưa là kiểm startup/TLS/DB/native transfer hoặc P5/P6. Build được phép lấy base/dependencies từ registry; các container kiểm artifact không có mạng.

Chỉ sau mọi gate trên thành công, step publish mới nhận `GITHUB_TOKEN` qua environment/`--password-stdin`; quyền chỉ `contents:read, packages:write`, không PAT/SSH/AWS/id-token. Push đúng ba package `ghcr.io/bthung2747/web-snap-{app,web,egress}`, mỗi package một tag `sha-<fullcommit>-run-<runID>-<attempt>`, không `latest`. Ghi OCI source/revision labels. Tắt provenance attestation cho build này để xuất manifest một platform; [API CLI build](https://docs.docker.com/reference/cli/docker/buildx/build/) đã đối chiếu. Đọc [registry manifest/digest qua buildx imagetools](https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/), kiểm config digest từ registry bằng imageID đã kiểm ở runner. Chỉ ghi bảng release hoàn chỉnh vào **Actions job summary** khi cả ba thành công: sourcecommit/run/tag, ba immutable `name@sha256:...`, imageIDs, Caddy base RepoDigest và binary version. Không thêm artifact/cache upload. Các push không là transaction: nếu push/verify giữa chừng lỗi có thể còn package đã đẩy; run FAIL, không dùng bộ chưa đủ ba digest hoặc tự retry/xóa package. Cleanup chỉ các container có tên runID/attempt và credential directory riêng; không prune chung. Hủy runner cưỡng bức vẫn có giới hạn cleanup của hosted runner.

**Trước commit/push/dispatch (owner/reviewer thực hiện sau review):**

1. Xem diff và scope code đã nghiệm thu. Snapshot29/10: local HEAD và local tracking `origin/main` cùng `5b3d0e9c376f338da7ed296cd6de3e1c354bd27c` (Initial import20/10); chưa fetch để xác nhận remote mới nhất. Các thay đổi27/10 và gói production còn modified/untracked. Actions chỉ build commit đã có trên GitHub, không thấy working tree local; không dispatch Initial import rồi coi là bản mới. Không `git add .` hoặc stage tất cả lịch sử lab/evidence/grants.
2. Đối chiếu đúng remote `https://github.com/BTHung2747/WEB-SNAP.git`, quyền owner/Actions, default branch main và quota/budget trong tài khoản. Workflow phải có trên default branch mới [chạy thủ công](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow) được. Review package namespace/access hiện hữu trước lần publish đầu: package mới mặc định private theo [GHCR](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry); package có sẵn có thể có visibility/quyền khác hoặc không cho GITHUB_TOKEN push. Workflow không đổi visibility/quyền, không mở public repo/package. Nếu bị từ chối quyền thì dừng, không tự thêm PAT hoặc quyền rộng.
3. Sau khi owner cho phép đồng bộ đúng mã và đã xác minh commit trên GitHub, chọn **Actions → Build and publish reviewed release → Run workflow → main**. Lưu actual sourcecommit/run URL/conclusion và bảng digest từ job summary, không suy `workflow prepared` thành đã có image. Không tự dispatch hoặc publish trong bước chuẩn bị này.

**Quota/phí đối chiếu tài liệu chính thức29/10:** [GHCR container storage và bandwidth hiện miễn phí](https://docs.github.com/en/billing/concepts/product-billing/github-packages#free-use-of-github-packages), là ngoại lệ riêng so với quota Packages thông thường500MB của GitHubFree; không dùng500MB để kết luận app image không chứa được. [Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions) tính compute runner private/internal theo khoản bao gồm của plan và phí vượt mức; public standard runners có chính sách riêng. Không hứa private runner miễn phí vô hạn hoặc đổi repo sang public để né phí. Quota đã dùng/quyền thanh toán của tài khoản **chưa đọc**; owner kiểm trước dispatch. Chỉ viết workflow chưa tiêu thụ runner compute.

**Từ registry tới VPS (chỉ khi được giao target/deploy riêng):** lấy ba immutable refs của cùng run/sourcecommit PASS, đối chiếu SHA với source/config trên target. Với package private, operator phải xác thực GHCR trước bằng credential được duyệt có `read:packages`, dùng `docker login ghcr.io --username <operator> --password-stdin` (đầu vào stdin bảo vệ, không token trong args/log); không chuyển GITHUB_TOKEN của CI thành secret lâu dài trên VPS. Bước này chưa tạo/yêu cầu credential. Điền đúng ba refs vào env ngoài repo; ví dụ dưới là placeholder, không chạy nguyên:

```sh
set -euo pipefail
export APP_IMAGE='ghcr.io/bthung2747/web-snap-app@sha256:REPLACE_APP_DIGEST'
export WEB_IMAGE='ghcr.io/bthung2747/web-snap-web@sha256:REPLACE_WEB_DIGEST'
export EGRESS_IMAGE='ghcr.io/bthung2747/web-snap-egress@sha256:REPLACE_EGRESS_DIGEST'
for ref in "$APP_IMAGE" "$WEB_IMAGE" "$EGRESS_IMAGE"; do
  [[ "$ref" =~ ^ghcr\.io/bthung2747/web-snap-(app|web|egress)@sha256:[0-9a-f]{64}$ ]]
  docker pull --platform linux/amd64 "$ref"
done
# Chỉ tiếp tục bootstrap/up bên dưới sau cả ba pull thành công.
# Ghi các refs này vào /etc/wed-snap/production.env trước khi kết thúc shell.
```

Compose giữ `pull_policy:never`: **phải pull đủ ba digest trước**, rồi mới dùng `up --no-build --pull never` theo thứ tự healthy→migration→settings/admin→services bên dưới. PostgreSQL/Redis official version pins cũng phải nạp sẵn theo release/target đã review; chúng không thuộc ba image CI publish. Không thay bằng `compose pull` ngầm dưới policy never hoặc dùng tag nổi. Rollback cũng phải preload đúng app/web digest cũ trước `up`; giữ ba refs/sourcecommit trong release record, không deploy chỉ từ tag hoặc imageID local.

**Kiểm thực đã chạy29/10:** parser YAML của Compose standalone (workflow được đặt dưới extension `x-workflow` trong wrapper tạm, `config --no-interpolate --format json`, env trống/Environment.Clear) và assertions trigger/job/permissions/pin/build-order/publish-order đạt; `bash --noprofile --norc -n` trên8run blocks đạt, final tool exit0. Đây không phải GitHub workflow server validation hay chạy các lệnh trong block. Không có YAML parser riêng trên host nên tái dùng [Compose extensions](https://docs.docker.com/reference/compose-file/extension/), không cài dependency hoặc tự viết YAML parser. Lượt đầu harness lỗi PowerShell quoting trước thực thi; lượt sau YAML/wiring đạt nhưng Git Bash không tạo được MSYS object (0xC0000022) trong môi trường hạn chế; static check được executor cho phép lại và đạt, không phải lỗi build. Tệp tạm riêng đã dọn; không rerun checker/suite cũ. **GitHub dispatch/build/artifact-run/Caddy binary/push/digests/deploy NOT_RUN.**

**Sửa hẹp Caddy exec30/10:** run [40918727686](https://github.com/BTHung2747/WEB-SNAP/actions/runs/40918727686), commit `db771d2b12022d56e26a8526ccc6de94f7a875a7`, đã được coordinator báo build app/web/egress và compiled/static/egress syntax SUCCESS; Caddy step dừng ngay tại `caddy version` với `exec /usr/bin/caddy: operation not permitted`/exit255 lúc29/10 **17:11:32.8658640Z** (VN30/10 **00:11:32**). Publish SKIPPED, cleanup SUCCESS. Đây là kết quả CI do coordinator bàn giao, không phải lệnh build chạy trong phiên sửa; Caddyfile chưa được parse/validate. Giữ run lỗi làm bằng chứng.

Đối chiếu [official-images pin2.11.7-alpine](https://github.com/docker-library/official-images/blob/master/library/caddy) trỏ [recipe commit9234f5785658cae8129bfae366e196d0670468ac](https://github.com/caddyserver/caddy-docker/blob/9234f5785658cae8129bfae366e196d0670468ac/2.11/alpine/Dockerfile): base đã có `libcap` và đặt `setcap cap_net_bind_service=+ep /usr/bin/caddy`. Theo [Linux capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html), file effective capability có thể làm exec trả EPERM nếu bounding set không cho nhận đủ file permitted capabilities; NET_BIND_SERVICE chỉ cần cho cổng dưới1024. [Kernel no_new_privs](https://docs.kernel.org/userspace-api/no_new_privs.html) ngăn file capability tăng permitted set, không được quy riêng flag này là nguyên nhân duy nhất. Cơ chế file-capability/bounding phù hợp lỗi quan sát; chưa đọc trực tiếp xattr hoặc tracing kernel trên image CI lỗi để chứng minh toàn bộ nhánh thực thi.

Web recipe nay dùng [setcap -r](https://man7.org/linux/man-pages/man8/setcap.8.html) gỡ file capability tại build, rồi lấy output [getcap](https://man7.org/linux/man-pages/man8/getcap.8.html) và bắt buộc rỗng; lệnh tool lỗi cũng làm build FAIL. Container kiểm web hiện có kiểm lại getcap rỗng dưới UID1000/capdropALL/no-new-privileges trước static checks; sau đó cổng Caddy version/adapt/validate vẫn nguyên. Không cài tool/dependency: dùng libcap sẵn trong official base. Giữ image version/digest forwarding, UID1000, port8080/8443 (host80/443), rootfsRO/privateIPC/caps/timeouts; không thêm capability, runtime root hoặc tắt bảo vệ. Không sửa app/egress Dockerfile, lockfile, downloader hay warning ARG APP_IMAGE (CI đã truyền app image đúng).

Kiểm tĩnh30/10 đã chạy: Compose standalone `config --no-interpolate --format json` trên wrapper `x-workflow`/env trống/Environment.Clear (không daemon) parse YAML exit0; `bash --noprofile --norc -n` đúng artifact-check block vừa đổi và RUN của web recipe, cả hai exit0. Không thực thi `setcap/getcap` hay các lệnh Docker trong block; không chạy lại8blocks hoặc checker/suite cũ. Thư mục tạm own namespace đã dọn. Phạm vi phiên sửa chỉ ba file recipe/workflow/runbook; không Docker engine local/build/dispatch/commit/push/nguồn hoặc deploy. Bản sửa **chưa có build/Caddy binary PASS mới**; coordinator review diff rồi giao chạy CI trên commit mới. CURRENT/task/actual-run record do coordinator cập nhật riêng.

### Env, mạng và đóng nhận job trước public

1. Copy `infra/production/production.env.example` tới **`/etc/wed-snap/production.env` bên ngoài repository**, `chmod600`; không đọc/sao chép local `.env`. Tạo ba giá trị ngẫu nhiên **riêng nhau** bằng `openssl rand -hex 32`: POSTGRES_PASSWORD, ADMIN_SESSION_SECRET, TIKTOK_EGRESS_CONTROL_SECRET. Không ghi secrets vào commandline/log/chat. PG password hex tránh lỗi escaping DATABASE_URL. Nhập contact thật, hostname đã duyệt và immutable images APP_IMAGE/EGRESS_IMAGE/WEB_IMAGE. Không gửi dump `docker compose config`/inspect Env vào bằng chứng.
2. `APP_ORIGIN` được Compose tính **`https://PUBLIC_HOST`**, COOKIE_SECURE=true cố định. `PUBLIC_HOST` chỉ DNS hostname, không scheme/path/query/port; cùng hostname được Caddy cấp TLS. Trước đổi DNS, xử lý route Worker/preview hiện có của chủ theo quyền riêng; không tự ghi đè `savlivo.online`.
3. Operator xem routes host/VPC/VPN/Docker rồi điền **PRODUCTION_PRIVATE_SUBNET chưa dùng** thuộc RFC1918. Biến này cấp đúng cả IPAM private và control CIDR; không lấy172.19/16 của local làm mặc định. `proxy_api` là internal network khác. Kiểm subnet thực Docker trùng env sau tạo mạng; nếu overlap/mismatch thì dừng, không nới allowlist. Không publish DB5432/Redis6379/API3000/egress8888/Caddy2019/health8090.
4. VERIFIED_PLATFORMS cố định youtube,tiktok; bốn cờ TikTok mặc định0. **Settings là cổng thứ hai:** khởi tạo `acceptJobs=false, enabledPlatforms=[]` trước API/worker/proxy. Không lấy defaults acceptJobs=true làm trạng thái maintenance. Sau P5 mới bật đúng nền tảng/loại đã đạt trong settings và gate; không tự thêm X/Facebook/shortlink/gallery. Cấu hình verified không chứng minh tải nguồn target.

### Khởi tạo target: migration → settings/admin → services

Chỉ chạy sau khi owner giao target, image đã nạp, domain/firewall và ngân sách được duyệt. Dùng Bash Linux với `set -euo pipefail`, ghép các khối bootstrap bên dưới trong cùng script/shell giữ hàm `dc`; không chạy lệnh tiếp theo sau exit lỗi. Luôn một Compose file/env/project rõ ràng:

```sh
set -euo pipefail
cd /opt/wed-snap
dc() { docker compose --project-directory /opt/wed-snap \
  --env-file /etc/wed-snap/production.env \
  -f /opt/wed-snap/compose.production.yaml "$@"; }
dc config --quiet
dc up --wait --wait-timeout 120 --no-build --pull never postgres redis
# maintenance thuộc profile tools; run service này không khởi động worker/proxy.
dc --profile tools run --rm --no-deps maintenance
```

Theo [Docker Compose up](https://docs.docker.com/reference/cli/docker/compose/up/), `--wait` đợi running/healthy và ngầm detached; postgres/redis đều có healthcheck nên được đợi **healthy**, `--wait-timeout 120` đặt trần120s. Timeout/lỗi làm script dừng trước maintenance, không retry/reset hoặc tăng hạn tự động. Migration dùng `node node_modules/prisma/build/index.js migrate deploy` đã có trong image, không `db push`/reset; exit0 và `_prisma_migrations` phải đạt trước settings/admin/API/worker. Service maintenance riêng internal/nonroot/RO, không media volume. Settings bootstrap dưới chỉ dành **DB mới**, từ chối ghi đè main có sẵn; DB cũ phải xem/sửa qua admin và review riêng:

```sh
set -euo pipefail
dc --profile tools run --rm --no-deps -T maintenance node <<'JS'
const {db,defaults,queue,redis}=require('./dist/packages/shared/src/core');
(async()=>{
  if(await db.settings.findUnique({where:{id:'main'}})) throw new Error('SETTINGS_ALREADY_EXIST');
  await db.settings.create({data:{id:'main',value:{...defaults,acceptJobs:false,enabledPlatforms:[]}}});
  console.log('SETTINGS_MAINTENANCE_CREATED');
})().catch(()=>{console.error('SETTINGS_BOOTSTRAP_FAILED');process.exitCode=1;})
 .finally(async()=>{await queue.close();redis.disconnect();await db.$disconnect();});
JS
# Admin JSON do operator chuẩn bị ở file0600 ngoài repo; không echo mật khẩu/history.
dc --profile tools run --rm --no-deps -T maintenance \
  node dist/scripts/create-admin.js < /etc/wed-snap/admin-bootstrap.json
# Sau exit0, operator xóa an toàn file bootstrap theo chính sách lưu secret.
dc up -d --no-build --pull never egress api worker proxy
dc ps
```

Không chạy lại bootstrap để ép PASS; script admin hiện có từ chối tài khoản trùng. `NODE_ENV=production`, `TRUSTED_PROXY_HOSTS=proxy`, cookie Secure/SameSite/CSRF cùng origin. Health proxy loopback chỉ chứng minh server đang nghe, không certificate thật; kiểm TLS/domain/cookie/Range từ client target ở P5. `worker_ready/concurrency1` và worker metrics hiện có là bằng chứng consumer; không gán healthcheck PID thành consumer readiness. Resource caps runtime6roles **1760MiB**, tools thêm384MiB trong một tác vụ riêng; không phải RAM đo. Worker768MiB/CPU1 giữ profile hiện tại, không tự tăng concurrency để rút ngắn prepare.

### HTTPS, log, transfer và giới hạn vận hành

- Mở duy nhất80/443 cho proxy (SSH giới hạn IP quản trị); chứng minh luật firewall thực tế với Docker published ports, không chỉ tin UFW. Không dùng host network/privileged/Docker socket mount.
- Không cấu hình cache/buffer toàn tệp hoặc proxy_retry. API/download path giữ nguyên URI/method/Range/If-Range/Content-Length/Disposition/status206/416; không gzip ở nhánh API (`compression off` transport), encode chỉ static. Positive `flush_interval100ms` giữ cancellation khi client ngắt; **không dùng flush_interval -1**, vì Caddy low-latency mode không hủy backend khi client disconnect. App vẫn sở hữu transfer deadline≤1800s/lease/byte budgets, proxy không tăng hạn mức ứng dụng.
- Caddy body cap64KB cho API; transport dial3s/header10s chỉ cho API phản hồi nhanh, không giới hạn toàn stream về10s. Stop grace API/proxy1860s và worker190s là trần dừng, **không bảo đảm API đã graceful drain**; phải chờ không còn transfer/job trước update. Không thêm timeout thấp hơn full download bằng đoán.
- Không bật access logs/debug/log_credentials: ticket nằm trong pathname native URL. Caddy loại `http.log.access`/`http.log.error` khỏi runtime logger để tránh request object chứa URI/cookie. Chỉ giữ runtime/TLS errors không request và app fixed-code/metrics sẵn có. Cần kiểm logging thực trên target trước public; đừng bỏ `exclude` chỉ để thấy URL lỗi. Docker json-file10MiB×3/service, kiểm dung lượng volume/disk80%, queue20, monthly egress10GiB mặc định (operator đặt thấp hơn nếu ngân sách yêu cầu).
- Caddy certificate `/data` và config volume riêng, media API mountRO/workerRW; không public file_server lên media volume. Cookie nguồn/signedURL vẫn RAM trong child, không cấp control secret cho proxy/static. Không claim đối soát ngân sách app thay hóa đơn nhà cung cấp.

### Backup, restore và rollback

**Trước migration/update:** admin đặt acceptJobs=false (không giết lượt đang truyền), đợi không analyzing/queued/preparing và không transfer started chưa hết hạn; xem queue counters wait/active/delayed/prioritized/paused không còn công việc, chỉ count, không clear/reset. Chặn/tắt adapter không thay thế việc drain transfer. Giữ proxy/API phục vụ các lease cũ cho tới xong; sau đó dừng worker/API/proxy để có mốc nhất quán. Native leases và media tạm không được coi là dữ liệu lưu dài hạn.

```sh
set -euo pipefail
set -o noclobber
# Xác nhận đúng project trên target trước mọi stop/backup.
dc ps
dc stop worker api proxy
umask 077
mkdir -p /var/backups/wed-snap
dump="/var/backups/wed-snap/pre-update-$(date -u +%Y%m%dT%H%M%SZ).dump"
# Dùng socket nội bộ; không password/DBURL trong lệnh hoặc log.
dc exec -T postgres pg_dump -U wed_snap -d wed_snap --format=custom \
  > "$dump"
dc exec -T postgres pg_restore --list < "$dump"
sha256sum "$dump"
```

`pg_dump` hoặc `pg_restore --list` lỗi làm dừng ngay trước checksum/bước sau; file có thể đã tồn tại nhưng **chưa là backup hợp lệ**, giữ trạng thái FAIL, không chuyển/restore hoặc tự chạy lại. Tên có UTC và noclobber tránh ghi đè backup trước. Giữ exit/SHA/restore-list, release images/digests, migrations và bản env/certificate được bảo vệ. Dump chứa dữ liệu quản trị/phiên: mã hóa bằng công cụ operator đã duyệt và lưu bản ngoài máy; không đưa lên Git/chat/public bucket. Không xem `pg_restore --list` là restore thành công. Giữ Redis AOF volume hiện có cho rollback bình thường; không xóa volume production. Chỉ media tạm không cần backup dài hạn, lifecycle xử lý theo epoch/thời hạn; không bỏ kiểm job/lease vì đã backup DB.

**Restore drill bắt buộc trước P6:** tạo project riêng `wed-snap-restorecheck`, env riêng/CIDR không overlap, volumes PostgreSQL/Redis **mới trống**, không proxy/public port. Chạy trong Bash fail-fast như trên; khởi động chỉ postgres/redis với `up --wait --wait-timeout 120 --no-build --pull never postgres redis`, verify full project/volume ownership rồi `exec -T postgres pg_restore --exit-on-error --no-owner -U wed_snap -d wed_snap < dump`; lỗi ở bước nào dừng ở đó, không chạy migration/validation sau restore lỗi hoặc tự reset/retry. Migrate kiểm tương thích nếu cần, query aggregate admin/campaign/settings và schema/migrations. Không in password/session records. Redis trống trong drill không là phép thử phục hồi queue đang chạy: nguồn trước backup phải đã drain. Kiểm cleanup/expired assets trên namespace drill trước mở ứng dụng, không đưa job/media cũ tới người dùng. Ghi actual exits/counts và xóa **chỉ** tài nguyên drill theo exact ownership; không chạy `down -v` trên project production. Hướng dẫn này chưa thực thi restore.

**Rollback:** sau drain/backup, thay APP_IMAGE và WEB_IMAGE trong env ngoài repo sang **cặp release trước đã review**, giữ EGRESS_IMAGE nếu không đổi; `dc up -d --no-build --pull never api worker proxy`. Không đổi project/volume/control secret/CIDR, không reset DB/Redis/queue. Schema phải tương thích với binary cũ; nếu không, giữ maintenance và lập kế hoạch phục hồi DB từ backup được owner duyệt, không tự downgrade migrations hoặc restore đè dữ liệu hiện hành. Health/config không đồng nghĩa source PASS. Chỉ mở acceptJobs/phạm vi adapter sau cổng nghiệm thu trên target.

### Kiểm offline đã chuẩn bị và giới hạn

Trên máy Windows của phiên code, chạy **chỉ** `scripts/check-production-config.ps1`: Compose standalone render với process environment tách biệt, env giả tạm riêng rồi dọn, không đọc `.env` thật/không daemon. Kiểm default-off, topology/ports/user/rootfs/resources/secret forwarding/origin, gate forwarding khi được bật rõ và missing secret bị reject; entrypoint/tsconfig/COPY static được kiểm bằng source inspection. Không có project node_modules, Caddy hoặc Go binary trên host trong lượt chuẩn bị: **chưa fresh npm/TypeScript/Vite build, chưa Caddy adapt/validate**. Không cài dependency/toàn Windows, không lấy chúng từ Docker engine để vượt phạm vi.

Trước dùng target: build/validate Caddy đúng release, kiểm init volume ownership dưới nonroot, compiled startup/migrate/backup+restore/rollback, real HTTPS/cookie/trusted-hop spoofing, source/Range/native disconnect/desktop/mobile theo P5/P6. Đây là phần còn thiếu cụ thể, không yêu cầu chạy lại mọi suite/lab đã khép. Không coi offline Compose PASS là productionPASS hoặc tự bắt đầu AWS/DNS/deploy.
