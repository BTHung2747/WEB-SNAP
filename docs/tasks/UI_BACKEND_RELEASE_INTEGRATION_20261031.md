# Kiểm nối UI được duyệt với backend và chuẩn bị phát hành — 31/10/2026

Chủ giao: “kiểm tra nó đã nối với backend chưa nếu rồi có thể deloy”. Được kiểm tích hợp và deploy savlivo.online khi bản mới thật sự sẵn sàng; không cần xin lại cùng quyền này. Điều kiện chưa đạt thì không coi bản fixture là kết quả backend hoặc bật flag production để thử. Mẫu01/thẩm mỹ đã duyệt, không sửa lại.

## Kết quả root thực kiểm

- API client của `apps/web/src/lib/api.ts` gọi `/api/v1/` cùng origin, credentials same-origin và CSRF như cũ. Caddy production chuyển `/api/*` tới api:3000; UI không hardcode backend giả. `MediaPreview.tsx` chỉ nhận URL API cùng job/origin, có fallback khi thiếu ảnh. Luồng mã có contract backend; chưa là bằng chứng bản mới end-to-end nguồn thật.
- HTTP GET thực: local5197 `/api/v1/session`200, header `x-wed-preview: fixture-only`, CSRF giả (không in giá trị vào báo cáo); `preview-fixture.cjs` trả jobs/preview giả, downloads410. Local5196 đã connection refused. Bản mới nhất chat UI bàn giao5197 là bản minh họa, không backend thật.
- `https://savlivo.online/api/v1/health`200 và `/api/v1/session`200, không header fixture, supported youtube,tiktok, capabilities.tiktokPhoto=true. Không tạo job/prepare/download hoặc ghi settings trong lượt root này; không suy GETsession chứng minh tải thật của UI mới.
- Backend preview local có routes/API cache/worker/media/egress, nhưng `TIKTOK_PREVIEW_ENABLED` mặc định tắt. `compose.production.yaml` và env mẫu chưa forward flag này tới worker/egress. Release production được ghi nhận trước vẫn2ec8034; mã UI/backend preview mới còn modified/untracked, chưa là image đã publish.
- Đọc gate `lab-runs/tiktok-quality-preview-offline-20261030-bceec901a8294e95bd87f2b9f21423cd/final-coverage.json`: PASS_OFFLINE11Python+11parent/API/typecheck0, HTTP/DB/proof doubles, sourceRequests0. Root kiểm readonly25source SHA khớp, không rerun22nhóm. Cleanup receipt ownResourcesLeft0. Đây chưa là nghiệm thu TLS/source hoặc full UI→backend thật.
- UI mới: [handoff menu cuối](../evidence/ui-preview-admin-redesign-20261030/quality-match-width-20261031/HANDOFF.md), tsc/build và CUA menu desktop/320px đã đạt bởi chatUI. Root đọc bàn giao, không chạy lại chỉ để tăng số kiểm. [Contract/backend handoff](UI_PREVIEW_ADMIN_REDESIGN_20261030.md#bàn-giao-backend-preview3010--offline-chờ-review).

## Giao code tay to — delta tích hợp cần thiết

1. Giữ UI được duyệt và luồng tải/quality≤1080/shortlink hiện hành; không sửa apps/web hoặc redesign. Rà đúng diff/wiring preview, bổ sung flag mặc định0 vào Compose runtime và egress/env mẫu, cập nhật đúng checker cấu hình để chứng minh0/1 truyền đúng vai trò. Không sửa `.env` thật/settings/main hoặc bật production trong lượt chuẩn bị. Giữ caps preview6s/8MiB/512KiB/50GET tối đa, deadline30/180s và proof/ownership/cleanup; không tăng budget để ép đạt.
2. Chuẩn bị đường tích hợp UI hiện hành với **API/worker/egress thật** và bản candidate có đủ mã mới. Tái dùng các bằng chứng offline đã khớp; chỉ kiểm thêm wiring/config mới và đúng khoảng trống contract/runtime cần thiết. Không thêm lab/framework/observer/suite lịch sử. Nêu cách kiểm nhỏ nhất cho một video và một ảnh đã có mẫu, tải preview/cache đúng nội dung và download native đúng lựa chọn; không dùng fixture HTTP làm chứng minh nguồn thật. Chưa chạy nguồn, thêm quyền album hoặc cấp retry tự động trong lượt chuẩn bị này. Nếu cần source execution, ghi rõ exact mẫu/quota/candidate/lệnh để root review trong phạm vi chủ đã giao, không tạo vòng xin lại quyền máy móc.
3. Chuẩn bị release scope chính xác từ dirty tree: file cần có, dependency của preview với patch quality/shortlink trước, build/publish workflow hiện có, immutable refs/rollout/rollback dự kiến. Không `git add .`, không kéo lab/evidence/env/secret hoặc mọi thay đổi ngoài scope vào image. Tránh build image nặng local8GB; ưu tiên GitHub workflow hiện có khi candidate được chốt. Không publish/commit/push/dispatch hoặc apply VPS trước root review candidate và điều kiện backend thật; quyền deploy của chủ vẫn có hiệu lực cho bước sau khi đạt.

Handoff gọn: delta/config check thực, phần tái dùng, khoảng trống còn lại, candidate/release path và đúng bước kế tiếp có thể thực hiện. Không đổi dữ liệu/thẩm mỹ/deps/framework hoặc tự chạy lại các mẫu đã khép. Root quản CURRENT và review/release; code tay to sở hữu backend/infra/checker, chatUI giữ apps/web. Giao xong root dừng nếu không còn việc độc lập; không polling lặp.

## Kết luận tại mốc kiểm

**Chưa đủ điều kiện deploy toàn bộ trải nghiệm mới có preview thật.** UI đã dùng contract/API thật ở mã nguồn, bản duyệt local vẫn fixture; backend preview chưa activation/nguồn thật và production wiring còn thiếu. Không xác nhận đã deploy hoặc đã tải từ bản mới. Không bắt chạy lại toàn bộ suite để đóng các khoảng trống cụ thể trên.

## Backend bàn giao preparation31/10 — config đạt, chưa nguồn/release

### Delta thực hiện và kiểm đúng khoảng trống

- `compose.production.yaml`: `TIKTOK_PREVIEW_ENABLED: ${TIKTOK_PREVIEW_ENABLED:-0}` chỉ ở worker (merge runtime cũ) và egress. Không đưa vào shared runtime/API/maintenance/proxy/PG/Redis. `infra/production/production.env.example` ghi0 và nói rõ preview không tự mở platform/gallery/retry. Không đọc/sửa env thật, settings hoặc service đang chạy.
- `scripts/check-production-config.ps1 -PreviewOnly`: ba lần Compose render bằng fake env đã xóa, chứng minh unset→0/explicit0/explicit1 đúng hai role, gates adapter/photo/video/policy vẫn0; role khác không có cờ. Không cần engine hoặc suite config lịch sử. Bốn nhóm checker đạt, ba native render exit0; outer PowerShell exit0. Source inspection thêm default mẫu và build-context exclusions. Compose CLI thực5.5.1; dùng public [interpolation/default](https://docs.docker.com/reference/compose-file/interpolation/) và [config --format json](https://docs.docker.com/reference/cli/docker/compose/config/). Không library/dependency mới.
- `.dockerignore`: loại `lab-runs`, `labs`, `design`, `apps/web/dev`; `docs/evidence`/env/.git đã bị loại. Đây ngăn cả build context và `COPY apps` mang UI fixture server vào image. Không thay source UI/thẩm mỹ đã duyệt.
- `.github/workflows/release.yml`: thêm kiểm artifact `preview-cache.js`, `tiktok-short.js`, file Pythonpreview/short và không có `/app/apps/web/dev`. Cùng check image networknone có sẵn, fail closed khi Python không3.11, FFmpeg/ffprobe không5.1.9 hoặc extractor/dependency pins không khớp `versions()`. Không thay base/dependency hoặc tự nâng version để build PASS. Python check không in stdout làm bẩn staticfile manifest app↔web. **Lượt này chỉ kiểm shell tokenization + Python AST của đoạn mới, exit0; chưa chạy Bash/CI/image build.** Mismatch ở CI phải dừng, không bỏ gate để publish.
- Rà diff preview giữ optionalproof riêng/nativeexit0/groupreap/không publish pending khi lỗi; analyze30/prepare180 và preview6s/512KiBresponse/8MiBtotal/≤50candidate giữ. Photo digest là normalizedRGB trước JPEGencode, so freshoriginal khi có cache; không gọi structural snapshot là contentidentity. Không chỉnh runtime sau gate25pins. GETpreview chỉ cache/owner/snapshot/state, không fetch nguồn; cleanup job/lease cũ giữ.

**Evidence mới duy nhất:** [thư mục preparation](../../lab-runs/ui-backend-release-preparation-20261031/), [checker successor](../../lab-runs/ui-backend-release-preparation-20261031/preview-config-check-successor.json), [nativeouter](../../lab-runs/ui-backend-release-preparation-20261031/execution-successor.json), [CI static](../../lab-runs/ui-backend-release-preparation-20261031/ci-snippet-static.json), [candidate41file](../../lab-runs/ui-backend-release-preparation-20261031/candidate-files.json). Checker đầu fail vì `environment` absent ở Redis bị indexnull; raw `preview-config-check.json`/`execution.json` giữ, sửa đúng helpernull và tạo successor, không sửa Compose để ép test. Checker thành công lúc10:38:23UTC/17:38:23VN31/10. Temporaryfakeenv đã xóa; không container/network/nguồn được tạo, không DockerDesktop/build/pull/CI/actions mới.

**Tái dùng:** previewgate `bceec901…23cd`11Python+11parent/API/typecheck0; readonly25pins trong [receipt](../../lab-runs/ui-backend-release-preparation-20261031/reused-preview-gate.json) vẫn khớp, **không rerun22nhóm**. UIbuild/menu/CUA theo handoff `quality-match-width-20261031` của UI; không dựng lại screenshot hoặc kiểm UI. Quality/pair/shortlink theo `TIKTOK_SOURCE_QUALITY_20261030.md`, không chạy lại lịch sử. Không coi checkerfakeenv/CIstatic là sourcePASS.

### Candidate chính xác, chưa commit hoặc image mới

Baseline Git hiện hành **`f5288fa24c3019f638f887f37f75eccfa3bb76dc`**. Candidate là baseline cộng đúng **41file có SHA/length** trong `candidate-files.json`:24backendruntime/12approvedUI/5releasewiring. Đây là đề xuất immutable source-delta bằng SHA, **chưa có fullcommit mới hoặc ba registrydigests**; các trường này để null. Imagecache5b994d…a7ba3 dùng kiểm offline trước đây không chứa bản mới nguyên khối và không được gắn nhãn releasepreview.

Các nhóm cần đi cùng nhau, không chỉ lấy hai file UI hoặc riêng cache route:

- Backend24: APIcontroller/jobsservice+`preview-cache.ts`; egresscontrol; `apps/media/Dockerfile`, media_adapter/video_policy, TikTokNOTICE/adapter/candidate_file/core/photo_core/photo_proxy/prepare_operations/validate_cobalt_body +newpreview_cache/shortlink/video_selection; workeradapter/processor/proxy-phase; sharedcore/tiktok-video/newtiktok-short. Native formats đã là `tt2` và có companion/sourceDefault/FullHD, nên cần mọi selection/validator/default/audio-copy dependency trong nhóm; short binding cũng đã đi qua processor/API.
- UI12: App/api/Admin/Home/style +admin/home/layout/responsive CSS/types, `MediaPreview.tsx`, `source-quality.ts`; chỉ pin bản UI hiện có, không sửa. `apps/web/dev` không commit/image. Other baseline UIcomponents/worker lifecycle/APIauth/sourcevendor từ baseline giữ.
- Release5: productionCompose/envmẫu/checker/.dockerignore/workflow. `compose.yaml` devdirty và các localoverride27/10 không thuộc release; không dùng chúng làm productionconfig.
- Unchanged build/lock/license pins11 ghi riêng trong manifest (rootDockerfile, package/lock, mediarequirements, TikToklock/LICENSE, egressDockerfile, webDockerfile/Caddyfile, tsconfig, Prisma schema). Không migration/DBchange. Source/NOTICE/AGPL/LICENSE phải đi cùng release; source chính thức corresponding commit là baseline+delta được commit sau review.

Không `git add .`; không commit lab/evidence/env/keys/claims hay chỉnh ledger lịch sử để gom release. Sau root review mới stage **exactpathlist**, kiểm staged diff khácbaseline khớp41file/SHA (lưu ý Git LFnormalization, workingtreehash không đồng nhất blobhash; xác minh lại sourcecheck ở cleancheckout), chốt fullcommit và không đẩy các dirty không liên quan. Kiểm candidateSHA drift trước staging/build, nếu UIchat sửa tiếp thì manifest này stale, không tự cập nhật pin để che. Tài liệu task này là handoff, root có thể commit riêng phần tài liệu phù hợp, không trộn filelịch sử ngoài scope.

### Build/publish rồi bind đúng candidate — lệnh đề xuất, CHƯA CHẠY

Sau reviewsource, dùng workflow sẵn có trên cleanmain của đúng fullcommit mới; không build image nặng tại máy8GB. Ví dụ operator chạy sau khi commit/push có chủ đích:

```sh
# REVIEWED_COMMIT phải là fullSHA vừa review, không lấy HEAD dirty ở máy này.
test "$(git rev-parse HEAD)" = "$REVIEWED_COMMIT"
test -z "$(git status --porcelain)"
test "$(gh api repos/BTHung2747/WEB-SNAP/git/ref/heads/main --jq .object.sha)" = "$REVIEWED_COMMIT"
gh workflow run release.yml --ref main
```

Workflow chỉ cho repository `BTHung2747/WEB-SNAP` và `github.ref=refs/heads/main`; do đó **dispatch bằng main khi main đã đúng REVIEWED_COMMIT**, kiểm run headSha bằng REVIEWED_COMMIT trước dùng kết quả. Không dispatch nhánh khác để lách gate. Giữ ba package `ghcr.io/bthung2747/web-snap-{app,web,egress}`, tagfullcommit+run+attempt, revisionlabels/architecturelinuxamd64; app-static/web-static byte/SHA identity và Caddyversion/config checks cũ phải PASS. Lấy **cả ba** `repo@sha256` từ Actions summary, registryconfigdigest=imageID; partialpublish/failedworkflow không là candidate. Nếu runtimepin mới reject apt/base drift, giữ FAIL và báo, không nângdependency hoặc rerun đến PASS trong quyền hiện tại.

Trên target/staging root đã chọn, chỉ nạp reviewedimmutable refs, không `latest`/cachetag. Nguồn phải dùng app/API+worker mới **và egress mới** (profilev2preview), webimage được build từ cùng apprelease. Không chạy API mới với egressproduction2ec… cũ hoặc staticfixture. Lưu candidate sourcecommit/run/full3digests trước request1.

### Phép thử nguồn tối thiểu đề xuất root review — CHƯA CẤP/CHƯA CHẠY

**Targetbinding còn thiếu:** chưa có image mới/full3digests và stagingorigin/project/envpath được chốt cho candidate. Không mặc định5197 (fixture) hay dùng mainenv/localDB. Root chốt một namespace dữ liệu/network/volumes riêng với API/worker/own-egress và web tĩnh **thật**, cùng sourcecommit; hoặc quy trìnhmaintenance/rollback trên target được giao sau review. Không cần hỏi lại chủ cùng quyền deploy có điều kiện; đây là việc kỹ thuật chưa hoàn tất. Production đường `/etc/wed-snap/production.env` chỉ cho rollout thật sau gate; env staging riêng bên ngoàirepo, secrets mới, CIDRkhôngoverlap, không in configfull/inspectEnv.

Candidate topology dùng `compose.production.yaml` riêng, image immutable; nếu targetcóproduction đang chạy thì không bind lại80/443 hoặc dùng volume/project của main. Root phải bind stagingorigin/cert/ports hợp lệ trước start, không tắt TLSverify hoặc sửahost để ép chạy. Lệnh sau chỉ là phần deploy chuẩn, **không chạy đến khi biến project/path/refs đã bind và rootreview**:

```sh
set -euo pipefail
dc() { docker compose --project-directory "$RELEASE_DIR" \
  --project-name "$REVIEWED_PROJECT" --env-file "$REVIEWED_ENV" \
  -f "$RELEASE_DIR/compose.production.yaml" "$@"; }
dc config --quiet                  # không dump secrets
# Images đã nạp đúng3digests; DB mới theo bootstrap DEPLOYMENT, không reset main.
dc up --wait --wait-timeout 120 --no-build --pull never postgres redis
# Chỉ migration/bootstrap DB MỚI nếu project mới; DB main không bootstrap lại.
dc --profile tools run --rm --no-deps maintenance
dc up -d --no-build --pull never egress api worker proxy
dc ps
```

`REVIEWED_ENV` candidate giữ guards/caps hiện có và concurrency1; flagpreview1 chỉ worker+egress, platform/video/photo/policy1 khi vào lượt nguồn được review, settings acceptJobs/enabledPlatforms trong namespace mới đúng phạmvi được rootchốt. Không dùng việc checkerforward1 làm quyền bậtmain. PG256+Redis128+API384+worker768+egress96+proxy128=1760MiBcap cũ; sourceworker+egress864MiB≤1GiB. Không chạy tools384MiB song song source hoặc build/test khác; không tăngmemory/CPU/timeout để ép PASS. Có health/session thật khôngfixture và UIassets identity trước source; nếu không thì dừng0source.

Hai mẫu **canonical**, chạy tuần tự qua UI mới thật để giữ heartbeat/nativelease/CSRF và kiểm chính contract đã giao; không chạy thêmCLIanalyze lặp cùng bài:

| Thứ tự | Link công khai/expectedID | Một lần chọn/prepare/tải |
|---|---|---|
|1video|`https://www.tiktok.com/@arunal_loyria/video/7611475556395191573`, bodyID7611475556395191573|Một analyze, thumbnail video thật; chọn progressiveH264/AAC≤1080 từ metadata có sẵn (sourceDefault nếu phù hợp, nếu không thì người kiểm chọn rendition phù hợp trước prepare), đúng mộtprepare và mộtnativeGETMP4. Không companionGET trong phép thử tối thiểu này; không formatphùhợp thì dừng.|
|2photo (chỉ sau1đạt)|`https://www.tiktok.com/@fergs_28/photo/7698239729019456789`, bodyID7698239729019456789|Một analyze; lịch sửalbum3, previewtheoindexsnapshot; chọn ảnh1/đúngttp1_ID, mộtprepare và mộtnativeGETJPEG. Không ảnh2/3 download, ZIP hoặc galleryactivation.|

Đây là **đề xuất lượt mới** để kiểm code mới, không gọi dữ liệu nguồn cũ PASS là bản này PASS. Chưa chạy link nào. Requestpolicy canonicalanalyze≤2GETmetadata/noHEAD/no retry/redirect0/30s/8MiBresponse16MiBtotal; optionalpreviewvideo≤1GET/512KiB, photo≤NGET với N=actualvalidatedalbumcount≤50/tổng8MiB/512KiBresponse/6ssoft. Bài ảnh lịch sử3 không bảo đảm hiện tại3; implementation không có capsource3 riêng, vì vậy root phải review **worstcase50previewGET**, không ghi quota3 giả hoặc âm thầm phát quyền54GET cho toànanalyze. CONNECTpreviewcap=N riêng; metadatacanonical2, preparesingle3 giữ. Nếu root chỉ cho≤3previewGET thì chưa có runtimeclamp tương ứng, phải chốt delta hẹp riêng trước nguồn, không tự nới/giả vờ enforce.

Prepare fresh≤2GETmetadata +conditional1GETmedia/redirect0/180s; video≤600s/input250MiB/output200MiB, photoinput36MiB/output16MiB (image response≤20MiB và aggregateinput còn lại), full contract/decode/hash cũ giữ. Workflowvideo≤2+1+2+1=6sourceGET; ảnh≤2+N+2+1=5+N (N≤50) trong hai child; requestcap là trần, không cam kết requestthực. TLSCONNECT count không thay actualGET; logchỉfixedcodes/phase/opaqueIDs/numericcounts, không URL/cookie/header/token. NativeGETpreviewAPI (khôngnguồn)≤1video/≤Nảnh và nativeasset1/mẫu; không force reloadpreview/retrydownload khi lỗi.

Thao tác UI tương ứng endpoint chính xác: `GET /api/v1/session` (cookie/CSRF riêng RAM), `POST /api/v1/jobs/analyze {url}` đúng1; `GET /jobs/:id` poll/heartbeat theoUIhiệncó; sauselectable đọc `status.previewUrl` hoặc `items[0].formats[i].previewUrl` đúngsameorigin/owner. `POST /jobs/:id/prepare {itemId,formatId,idempotencyKey}` đúng1; readystate → `POST /jobs/:id/download-ticket` → một nativeGETrelativeURL. Không nhập kýURLCDN vàocurl/img hoặc ghi ticket vào log. Không thêmcurlanalyze bên cạnh UI để có hai lượt. DevTools/browserfixturekhôngđược dùng làm chứng minh backendnguồn.

Tiêu chí đạt/dừng: ID/kind/freshselectedformat đúng, preview200JPEG/private-no-store/nosniff đúngjobvànội dung; photoảnh1tronglưới đúngảnh1JPEGđượcchuẩn bị, normalizeddigestpreparekhớp; nativeexit0/group0/main+optionalproofACCEPTED thật, sourcecaps/deadline khôngvượt; nativefilebytes/SHA trùng asset, MP4container/H264/AAC/duration/fullDecode và JPEGcontract/fullDecode thật. Trình MP4/JPEGgốc cho chủ xem hình/tiếng/watermark, giữ logo tác giả; chưa humanreview thì giữ NEEDS_VISUAL_REVIEW, không biến preview/metadata thành nghiệmthu file. Review normalizeddigest chỉ là ảnh320×320, không là cryptographicidentity toàn file/nguồn. Byte/request không quan sát được phải UNKNOWN+policyceiling, không suy từCONNECT. Một lỗi ởmetadata/preview/proof/file/UI/ownership/cancel/cleanup thì dừng đúngstage, khôngretry/fallback/mẫu2. OptionalpreviewFAIL có thể vẫnmetadataPASS theo runtime, nhưng **không đạt releasepreviewgate** trong phép thử này.

### Rollout/rollback sau khi mọi điều kiện đạt

Giữ deployauthorization của chủ, root quản lý thực thi sau reviewcandidate+nguồn: sourcecommit/3digests/manifest đúng; lưu fullrefs và cờpreview cũ ngoàirepo, settingsacceptJobs=false rồi drain job/queue/transferlease (khôngclear/reset), backupDB cóexit/SHA/list như DEPLOYMENT, media/lifecycle nguyên. Không migrationmới từ delta này. Sau drained, cập nhật đúng3images/productionCompose và riêngflagpreview đã nghiệmthu, `dc up -d --no-build --pull never egress api worker proxy`; khôngPG/Redis recreate/volumedelete. Kiểm configquiet,health/sessioncapability/staticidentity/UI+API thật; nếu lỗi giữmaintenance/khôngnguồnretry.

Rollback phải khôi phục **bộ APP+WEB+EGRESS cùng release cũ và cờpreview0**, vì brokerprofile/schema cùng đổi; không chỉ rollbackUI/API rồi giữ egress bất kỳ. Đợi/drain jobtt2 của candidate trước thaybinarytt1 cũ; selectablett2 không được tựmap sangtt1, chỉ hết hạn/analyze mới theo nhiệm vụ sau. Không resetDB/migration/queue hoặc xóa volumes; khônggiết transferđangactive để rolloutnhanh. Fullrefproduction trước phải lấy exactdigest từ receipt/targetread-only, nhãn2ec8034 lịch sử không là immutableimagepin. Nếu bất kỳ binding/backup/drain chưa đủ, dừng trướcapply và báo phầnthiếu.

**Kết thúc preparation:** code/config/checker và proposedfilelist đã sẵn sàng để root review. Sourcepreview thực/wholeUIbackend/source/immutablebuild/rollout vẫn **NOT_RUN**, chưa deploy. Root quản CURRENT; coder đã báo phần làm được/chưa làm và dừng, không polling hoặc mởsuite khác.

## Successor release01/11 — bản nháp, chờ bố cụcQR mới

Theo nhiệm vụ mới, đã lập đúng một namespace [ui-backend-release-preparation-20261101](../../lab-runs/ui-backend-release-preparation-20261101/). **Chưa freeze candidate cuối**: trong lúc chuẩn bị, chủ giao root/UI sửa bố cụcQR; manifest có `DRAFT_UI_QR_LAYOUT_PENDING_NOT_RELEASE_FROZEN`, `freezeAllowed=false`. SHA hiện chỉ là snapshot trước deltaUI mới, không được dùngstage/release. SauhandoffUI/rootreview mới chốt bản cuối, giữ draft và manifest41file31/10 làm lịch sử.

- [candidate-files.json](../../lab-runs/ui-backend-release-preparation-20261101/candidate-files.json):57provisionalreleasepaths,31backend/20UI/6releasewiring; mỗi file có nhóm/lýdo/length/worktreeSHA256/Gitblobđãchuẩn hóa, baselinef5288fa24c3019f638f887f37f75eccfa3bb76dc. So41file:38giữnguyênbyte,3UIcũ đổi doỦnghộ (`App.tsx`, `lib/api.ts`, `pages/Admin.tsx`),16Ủnghộmớivàoscope. Sourcecommit/image3digests vẫnnull.17unchangedbuild/dependency/licensecontrols được liệt kê; Caddyfile đã đổi nên chuyển khỏi nhómunchanged cũ sangreleasewiring.
- [release-paths.txt](../../lab-runs/ui-backend-release-preparation-20261101/release-paths.txt), [diff-summary.json](../../lab-runs/ui-backend-release-preparation-20261101/diff-summary.json), tracked-diff-summary.txt: exactpathlist/diff đểreview, **chưa stage**; tracked39/untracked18 được nói rõ, không bỏ sót file mới chỉ vìgitdiffkhôngliệt kê. Không gomdirtyCompose local/labhistorical/env/QRtest/builddata/claims.
- [supporting-code-and-docs.json](../../lab-runs/ui-backend-release-preparation-20261101/supporting-code-and-docs.json):18QA/devsourcepaths riêng, không tựchọn vào commit hoặc runtimeimage. Root-managed CURRENT/PLAN/tasks được liệt kêriêng, không pin docsđangđổi như runtime. Không códữliệuQR/bank/credentials trongcandidate.
- [BUILD_RELEASE_NOTES.md](../../lab-runs/ui-backend-release-preparation-20261101/BUILD_RELEASE_NOTES.md):đối chiếuDockerfiles→API/worker/media/support/AppModule/tsc/UIbuild→websameapp→egress+license; existingworkflow compiled/nativepins/staticidentity/**Caddybinary+adapt+validate trướcpublish** vẫngiữ. Sourceinspectionkhông làimagebuildPASS. Supportrowvắng→false, giữDBmain/rowSettings/QRhiệnhữu; khôngseedtest/reset/migrationmới. Có lệnh stageexactlist saufreeze/maincommitworkflow/update/drain/backup/rollbackcả3images, không đoánSSHtarget hoặc dùngcacheimagecũ nhưcandidate.

Cácgatecònmở được tách trong notes: UIQRhandoff cuối; realTikTokpreview/own-egress/proof→nativefile; shortlinkbodyIDbindingnguồnthật; FullHD/tt2/HEVCpairnguồn/playerclaims; image3digests/SSH/drain/backup/targetrelease. Support1journey UI→API/PG/Redis đãrootnhận, khôngrerun. Rootcóthểchọn tốithiểu1canonicalvideo+1ảnh1 theo taskcũ, hoặc chọnthayvideoentrybằngshortđãgiao đểkhépvừa linkbinding, nhưng đây chỉphươngánreview, khôngsourceauthority mới. Albumtừng3ảnhkhôngenforceN≤3: budgetpreviewN≤50 phảiđược rootchốt, không ghiquota3giả hoặc thêmrequestmù.

Lượt này chỉđọc source/metadata Git và lập artifact: old41manifestSHA7405268b…e8c0nguyên, currentindex0staged,0functionaltests/0engine/0source/0commit/push/CI/build/publish/deploy. [draft-status.json](../../lab-runs/ui-backend-release-preparation-20261101/draft-status.json) ghi trạngtháichờUI; khôngsửa apps/web/productionruntime/CURRENT. Không có findingbuildpath mới qua lượtđọc; binaryCaddylocalNOT_RUN cònđúng vàgateCIbắtbuộc trướcpháthành. Bàn giao bảnnháp và dừng, khôngpollUI hoặc mởbộkiểm mới; rootbáohandoffUI mới rồi mới chốt candidate một lần.

## Root review phần độc lập của bản nháp 01/11

Đã đối chiếu 37 file backend/release và 17 build/dependency/license pins: khớp, manifest 41 file cũ nguyên, index chưa stage. Kết quả đọc-only ở [root-independent-review.json](../../lab-runs/ui-backend-release-preparation-20261101/root-independent-review.json); không chạy test/engine/nguồn hoặc release. Đã đọc build-path/runbook, không thấy finding mới. Hoãn đối chiếu 20 file UI vì chủ đang yêu cầu sửa bố cục QR; freezeAllowed=false vẫn đúng. Chưa dùng danh sách nháp để commit/push/CI/deploy. Sau handoff UI mới mới chốt candidate cuối.

## Candidate FINAL source01/11 — bàn giao rootreview

Sau chủduyệtUIQR và [rootnhận3fixAPI](API_SECURITY_FIXES_20261101.md#root-nghiệm-thu-successor), đã chốt đúngmột successor [ui-backend-release-final-20261101/HANDOFF.md](../../lab-runs/ui-backend-release-final-20261101/HANDOFF.md). **57runtimepaths** exactdraftset/31backend+20UI+6releasewiring; đúng6delta đãreview (3UIQR+3API/Caddy),51cònbyteexact;17build/dependency/licensecontrols nguyên. Mỗi file có SHA/normalizedGitblob/length/nhóm/lýdo; exactlist sẵn để rootđối chiếu trướcstage. Tách20supportingQA/dev (18cũ+2projectiontest/runner),9rootdocpaths riêng khôngpin nhưruntime. Không nhập raw/build/QRtest/credentials/mainenv/data/claims.

Readonlypreparation exit0/101Gitcalls0;94source/control/supportpins khớp, HEADbaselinef5288fa24c3019f638f887f37f75eccfa3bb76dc/index0, draft57/old41manifests nguyên.0test/engine/source/stage/commit/push/CI/build/publish/deploy mới; khôngrerunPG/upload/UIjourney. FINAL là **sourcecandidate chờ rootmanifestreview**, không image/productionPASS; commitmới+3digestsnull. Caddy nativeversion/adapt/validate phảiPASS ởCI trướcpublish; slowrequest/sourcepreview+short/quality/targetSSH/drain/backup/TLS/nativechecks vẫnOPEN/NOT_RUN theohandoff. CURRENT/PLAN do rootcậpnhật; coder đãbàn giao vàdừng, không tự mởlượt nguồn hoặc deploy.

## Root chốt candidate source — 01/11

Đã nhận bản FINAL ở lab-runs/ui-backend-release-final-20261101/HANDOFF.md. Root đối chiếu 57 runtime + 20 QA/dev source + 17 build/dependency/license controls: SHA/length khớp, baseline main/f5288fa24c3019f638f887f37f75eccfa3bb76dc và index trống. Giữ nguyên draft57/old41, không chạy lại test/nguồn. Root chọn exact57runtime+20QA/dev+9tài liệu trong root-selected-paths.txt (86path) cho Git; không raw evidence/build/QR/ngân hàng/env/secrets. Filelist review là source-only, không chứng nhận images hoặc production.

Đã đọc diff PLAN chỉ thêm phạm viủnghộ do chủ giao; các task/report/CURRENT giữ kết quả và giới hạn hiện hành. Chuyển commit/push exactpathlist rồi existing release workflow từ đúng SHA. Caddy native version/adapt/validate phải PASS trước publish; không nâng claim sourcepreview/short/HEVC từ artifact offline hoặc tự bật preview. SSH/target/drain/backup và phạm vi nguồn thực còn phải chốt trước apply. Ghi kết quả Git/CI thực vào receipt riêng, không đổi metadata lịch sử thành đã chạy.
