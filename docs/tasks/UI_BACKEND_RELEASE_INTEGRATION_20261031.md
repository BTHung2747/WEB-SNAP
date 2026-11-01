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

## Git và CI thực — 01/11, 16:24 VN

Đã commit và push đúng 86 đường dẫn: [c0f71e5](https://github.com/BTHung2747/WEB-SNAP/commit/c0f71e5d5616b19d40125b262dd711808f431740). Index sau commit trống; 77 blob runtime/QA khớp bản đã review, ngoại lệ duy nhất là bỏ một dòng trống cuối `scripts/test-support-projection.ps1` để `git diff --cached --check` đạt. Không thay executable content hoặc chạy lại test; manifest gốc giữ nguyên, delta có [receipt riêng](../../lab-runs/ui-backend-release-final-20261101/root-whitespace-successor.json).

Đã dispatch đúng một lượt [release CI 41293014266](https://github.com/BTHung2747/WEB-SNAP/actions/runs/41293014266), API HTTP200, ref main/head c0f71e5. Snapshot đầu: checkout/bind đạt, Build app đang chạy; chưa kết luận build/Caddy/publish. [Git receipt](../../lab-runs/ui-backend-release-final-20261101/root-git-receipt.json), [dispatch receipt](../../lab-runs/ui-backend-release-final-20261101/root-dispatch-receipt.json), [CI snapshot](../../lab-runs/ui-backend-release-final-20261101/root-ci-status.json). Lần duyệt thao tác trước bị usage-limit nên không thực thi; sau mốc thử lại, thao tác được duyệt qua cơ chế chuẩn, không bỏ qua approval. Không apply Lightsail hoặc chạy nguồn mới.

## CI build/publish đạt — 01/11, 16:29 VN

[Run41293014266](https://github.com/BTHung2747/WEB-SNAP/actions/runs/41293014266), job124808004441, source `c0f71e5d5616b19d40125b262dd711808f431740`: completed/success. Build app, static web từ cùng app, egress, compiled/native pins/static identity, Caddy2.11.7 version/adapt/validate bằng binary thật, publish và cleanup đều success theo API jobs/steps. Log thực có `v2.11.7` và `Valid configuration`; mandatory Caddy syntax/config gate đã khép ở CI. Không đồng nghĩa đã kiểm request upload chậm, TLS/startup hoặc nguồn thật trên target.

Ba immutable registry refs được bind theo đúng tag source/run/attempt từ output docker push; [receipt và refs](../../lab-runs/ui-backend-release-final-20261101/root-release-images.json), [log job](../../lab-runs/ui-backend-release-final-20261101/ci-release-job.log). Workflow kiểm remote config digest bằng local image ID trước báo thành công. API log theo từng step trả404; dùng endpoint job-log chính thức với credential Git hiện có, chỉ trong bộ nhớ và không forward Authorization sang URL tải log. Không dispatch lại, tải image về máy8GB hoặc chạy test/source mới.

Chưa đổi production. Bước kế tiếp: nhận cách truy cập SSH (terminal AWS hoặc đường dẫn khóa có sẵn), đọc current source/3image refs/health/tài nguyên trước; chốt drain/backup/rollback rồi mới apply. Không đọc/in full env hoặc gửi khóa/mật khẩu vào chat. Giữ Settings support/main, saved/pending QR và dữ liệu/volumes; không seed hoặc reset. Preview mặc định0 vẫn giữ đến khi luồng nguồn có evidence riêng.

## Chủ chọn SSH AWS và bỏ liên kết quản trị công khai — 01/11

Chủ chọn phương án1: dùng lại terminal SSH trên AWS, root gửi từng lệnh ngắn; không yêu cầu cung cấp khóa/mật khẩu. Trước rollout, chủ yêu cầu bỏ đường dẫn tới trang quản trị khỏi giao diện công khai. Root tìm đúng một anchor ở `apps/web/src/components/Footer.tsx`, đã giao code tay to xóa anchor này; giữ route `/admin`, đăng nhập, API và bố cục đã duyệt. Không đổi thành một cơ chế cấp quyền mới.

CI41293014266/sourcec0f71e5 vẫn là release lịch sử đã đạt, chưa có delta bỏ link. Sau handoff hẹp, root review diff, commit/push exact footer + hai tài liệu tiến độ đang mở rồi dùng workflow hiện có để tạo image successor cùng source. Không sửa manifest57 hoặc gắn image cũ thành đã chứa thay đổi mới. Chưa apply production; lệnh SSH đầu chỉ đọc current checkout/container images, tránh in full env và chưa drain hoặc dừng dịch vụ.

Root đã nhận handoff và kiểm trực tiếp: Footer chỉ0added/1removed, SHA54a4554d…9f8c3ed; tìm anchor `/admin` trong components/pages không còn, App vẫn điều kiện `page === 'admin'` render Admin. `git diff --check` cho Footer và hai tài liệu đạt. Không thêm test hay chạy lại suite cho xóa liên kết; không thay CSS/deps/route/auth/API. Chuyển commit exact3path và rebuild bằng release workflow bắt buộc để image mới thật sự chứa delta.

## Xem trước API thật trước triển khai — 01/11

Footer và hai tài liệu đã commit/push `6fd6d08c463d470a593a1354342fc3d12b861426`, đúng3paths. Chủ ngắt trước/đang gọi dispatch rồi yêu cầu kiểm API/chức năng, chạy web xem trước. [Snapshot sau ngắt](../../lab-runs/admin-link-release-20261101/interruption-check.json) lúc16:40VN: không receipt dispatch local và không run gần nhất khớp6fd6d08; không tự dispatch lại. Release/deploy tạm giữ theo chỉ đạo mới, CI c0f71e5 cũ vẫn là bằng chứng build riêng.

Root giao code tay to tái dùng `scripts/support-ui.ps1`/`tests/support-live.ts`: AppModule/auth/CSRF/PG/Redis thật trong dữ liệu lab mới, loopback, giới hạn/watchdog cũ, source6fd6d08 và UI hiện tại có Footer mới. Build UI nhẹ một lần nếu artifact stale; không build/pull image, không sửa runtime/deps/framework hoặc main/settings/DBproduction. Trước mắt chỉ smoke health/session/publicsupport; tái dùng các nhóm upload/PG đã đạt, không rerun suite. Root sẽ mở CUA cho chủ và kiểm một luồng UI cần thiết, nêu rõ lab nguồn-disabled chưa chứng minh tải.

Để khép chức năng tải mới, yêu cầu chuẩn bị phương án tái dùng API/worker/own-egress thật cho tối đa hai job tuần tự qua UI: shortvideo `https://vt.tiktok.com/ZSgnv8Lae/` và photo7698239729019456789/ảnh1 đã do chủ cung cấp; không thêm canonical khi short lỗi, không retry/crawl hoặc YouTube mới nếu phần đó không đổi. Chưa tự khởi chạy job; root phải nhận binding/source/guards trước thao tác web, giữ30/180s và caps/preview6s8MiB≤50 hiện có. Không dùng fixture job/download hoặc quyền/grant cũ để tuyên bố livePASS.

### Bản xem trước thật và luồng Ủng hộ đã kiểm

[Lab511370d6/HANDOFF](../../lab-runs/support-ui-real-20261101-511370d65a114d16afac722a3d5a465d/HANDOFF.md): `http://127.0.0.1:5210/`, API/PG/Redis thật, Viteproxy, dữ liệu riêng và source-disabled. Correctivebuild đúng cwd đạt; tổng2buildinvocations (attempt1 cảnh báo Tailwind được giữ). Root thấy assetsDjUQu5Te/Bz6TDUvt đúng artifact và không có publicanchoradmin. Đã mở home và admin cho chủ bằng CUA; phiên admin demo do coder đăng nhập trước, root không nhận hoặc in mật khẩu.

Root chạy đúng một hành trình mới trên UI: chọn ảnh tổng hợp702B cũ, nhập tiêu đề/lời nhắn rõ **không chuyển khoản**, uploadpending giữ text/publicoff; bật+Lưu rồi reload public hiện đúng text/ảnh; nativePNG đã lưu trên host và SHA0560773f…8db khớp đầu vào/ID nội dung; tắt+Lưu/publicreload off. Không nhập ngân hàng/QR nhận tiền, không logout hay thay settings vận hành. [Receipt](../../lab-runs/admin-link-release-20261101/browser/real-api-journey.json), [ảnh public đã lưu](../../lab-runs/admin-link-release-20261101/browser/support-saved.jpg). Một locator exactlabel không khớp được sửa bằng AX hiện hành, không lặp mutation. Chọn tệp qua CUA bị chờ683s; không coi đó là latencyAPI. Không rerun8suite hoặc PGprojectiongroup.

Chủ cũng giao trực tiếp chat code sửa chữ/phông admin. [Handoff2file](../../lab-runs/admin-typography-20261101/HANDOFF.md) chỉ nhãn/copy và CSS, typecheck/build0; sau rootkhépSupport, chuyển riêngweb sang BX-fhY1a/DKtUQYhV, giữ3CID/API/PG/Redis/session và deadline cũ. Rootreload thấy đúng hai asset, fontSegoeUI/Arial, ảnhdesktop chữ rõ; coder giữ kiểm mobile riêng. [Admin thực](../../lab-runs/admin-link-release-20261101/browser/admin-live.jpg), [home thực](../../lab-runs/admin-link-release-20261101/browser/home-live.jpg). Lab này runtime30phút, watchdogcleanup17:16:11VN, chưa là web production/TLS/Caddy hoặc tải nền tảng.

Root đã nhận proposal chuẩn bị source-lab riêng tổng1728MiB caps (API384/PG256/Redis96/web128/worker768/egress96), giữ các guard và worker+egress864MiB, không tăng tài nguyên để épPASS. Cho startup/health/import cần thiết từ cachedroles+sourceoverlay, không pull/buildimage hoặc nguồn trước binding/browserREADY. Root testbudget đúng2job, không gọi nó hardquota runtime. Chưa có nguồn/downloadTikTok/YouTube từ việc mở labỦnghộ.

### Giới hạn startup nguồn quan sát được

Lượt source-lab [1d9c98d7/receipt](../../lab-runs/tiktok-source-preview-20261101-1d9c98d7979e4bbf9df46601c279da02/receipt.json) dừng khi tạo network thứ3: Docker báo `all predefined address pools have been fully subnetted`. Chưa tạo container hoặc chạy importer/worker/API, nguồn0; coder đã dọn đúng2network của lượt lỗi, không prune/đổi daemon hoặc dùng bridge khác. Đây là lỗi tài nguyên môi trường trước khởi động, không phải kết quả tải TikTok hay lỗi API được tái hiện.

Lab5210 kết thúc đúng cửa sổ đã chốt: [cleanup](../../lab-runs/support-ui-real-20261101-511370d65a114d16afac722a3d5a465d/cleanup.json) lúc17:16:15VN ghi ownResourcesLeft0 và operatorAccessRemovedtrue. Sau khi trạng thái tài nguyên đổi vì hai ownnetwork được giải phóng, coder được tiếp tục đúng1startup cùng source mới; chưa cấp retry nguồn và không sửa guards. URL5210 không còn được giới thiệu là đang sống; chờ URL/binding mới rồi root mới thử2job đã chốt.

### Video1 thật thất bại, đọc chẩn đoán sau khi tiếp tục lúc22:53

Source-lab [0bd9fc0a/HANDOFF](../../lab-runs/tiktok-source-preview-20261101-0bd9fc0affda4f348a93431a28b90542/HANDOFF.md) đã đạt startup sáu role1728MiB sau các lỗi labwiring được sửa (entry source-live và bindvendorreadonly đúngDockerfile/10pins). Root review runtimeGitdiff0 so6fd6d08, nhập credentialdemo quaCUA khônginsecret, bật nhậnjob chỉ DBLAB rồi đúng1analyze shortvideo. Khôngprepare/nativeMP4/canonicalfallback/retry hoặc jobphoto.

[VIDEO1_DIAGNOSTIC.md](../../lab-runs/tiktok-source-preview-20261101-0bd9fc0affda4f348a93431a28b90542/VIDEO1_DIAGNOSTIC.md) và JSON là nguồn chuẩn: job52de0ae6…bcc7 failedCONTENT_UNAVAILABLE, childactualExit0 nhưng parentproxy_phase_gate acceptedfalse/REJECTED, toànjob≈22.183s. Các điều kiện state/connections/stopped/deadline được gộp ởfinish; replyfailure không giữ nên underlyingbrokerstate và request/HTTP/DNS/TLS đềuUNKNOWN. Không suy metadata nguồn đãđạt từ child0, không quy lỗi TikTok/CDN hoặc cache khi chưa có evidence. [Ảnh lỗi trên web](../../lab-runs/admin-link-release-20261101/browser/video-analysis-failed.jpg). Nguồn0 trong startupreceipt chỉ là snapshot trướcjob, cleanupcounter đãsửa null/NOT_MEASURED.

Chatcode bị usage-limit trước khi gửi diagnostic; sau chủ tiếp tục, đã gửi lại bản trích từ observationworker/PG trướcTTL, không query lại DB đãdọn. Root đối chiếu codefinish với diagnostic và [cleanup0](../../lab-runs/tiktok-source-preview-20261101-0bd9fc0affda4f348a93431a28b90542/cleanup.json) thực17:53:31VN. Hiện cả5210/5212 đều khônglive; không giả bộ server cònchạy và không tựretryvideo.

Bước hẹp đang giao: log sanitized brokerstate/connections/stopped/deadline từ reply hiện có ở đúng failurefinish, giữ wire/acceptance/transport/caps; vài nhánh offline bằng helper sẵn có, khôngsuite/framework/nguồn. Saurootreview, dùng lại startuprecipe đãsửa để mở một previewlab mới cùng1728MiB/TTL30phút/loopback/ownDB/secret/acceptJobsfalse. Root chỉ chạy **photoảnh1 còn lại** của budget2job sau binding/browserREADY; không cấp thêm video hoặc source probe. Khôngdeploy/push/CI hoặc sửaproduction trong bước này.

### Kết quả photo qua UI thật — 01/11, 23:36

Đã nhận [binding mới](../../lab-runs/tiktok-photo-finish-observation-20261101-96a2221104564a43b41b13de86ac7ae1/HANDOFF.md): sáu role1728MiB, cached images/source overlay và ba mạng riêng; không build/pull/dependency mới. Root nhận delta quan sát3runtimefile, tái dùng7worker+2broker pure cases/typecheck0 theo [handoff](../../lab-runs/proxy-finish-observation-20261101/HANDOFF.md), không chạy lại. CUA thấy đúng assets BX-fhY1a/DKtUQYhV, đăng nhập test thật rồi lưu acceptJobs=true và giảm input36MiB/output16MiB cho lượt ảnh; 30/180s giữ nguyên. Không đụng production.

Job `9a131dd4-8f5f-41bc-ba23-be959e852e13` của bài @fergs_28/photo/7698239729019456789: đúng một analyze chủ động lúc16:20:39UTC, selectable3ảnh; ảnh1 1080×1100, ảnh2/3 1080×1080. Một prepare ảnh1 tạo asset63678B; worker analyze/prepare hoàn tất10925/7354ms, proxy proof ACCEPTED connections1/2. Optional preview lượt này không đạt nên UI hiện “Chưa có xem trước”. Có ticket1, không có transfer lease được chấp nhận trong snapshot. Đây là backend prepare đạt, chưa phải tải tệp end-to-end hoặc chứng nhận hình/chất lượng.

Root bấm nút tải một lần bằng AX sau khi chụp, nhưng CUA giữ lời gọi540s rồi báo chờ download10s hết hạn; không có đường dẫn trả về. Kiểm Downloads host read-only trong25phút gần nhất không thấy tệp khớp. Không kết luận HTTP GET chưa xảy ra vì API không có access log tương ứng; số byte trình duyệt nhận vẫn UNKNOWN. Ảnh asset sau đó đã hết hạn và được dọn. Không bấm tải/prepare lại.

**Sai lệch phạm vi cần giữ rõ**: PG/log thực ghi thêm job `58942ca2-d1ad-4678-80d9-631b913127f0` created16:32:17.459UTC, ngay sau job trước bị cancelled16:32:17.430UTC. Root không chủ động yêu cầu analyze thứ2; actor/trigger chưa xác định, không quy cho người dùng, TikTok hoặc lỗi runtime khi chưa có bằng chứng. Actual lab là **2analyze/1prepare**, vượt kế hoạch1analyze còn lại; không gọi là vẫn trong quota. Job thứ2 main proof1/preview proof3 ACCEPTED; CUA thấy ảnh thực sau đó, nhưng đây là quan sát của lượt ngoài kế hoạch. [Ảnh màn hình thực](../../lab-runs/tiktok-photo-finish-observation-20261101-96a2221104564a43b41b13de86ac7ae1/photo-visible-preview.jpg), [PG snapshot](../../lab-runs/tiktok-photo-finish-observation-20261101-96a2221104564a43b41b13de86ac7ae1/photo-db-diagnostic.json), [worker snapshot](../../lab-runs/tiktok-photo-finish-observation-20261101-96a2221104564a43b41b13de86ac7ae1/worker-photo-diagnostic.json). Các screenshot dùng tab.screenshot trước đó bị lệch với AX, không dùng làm bằng chứng trạng thái READY; ảnh native getScreenshot sau đối chiếu mới dùng minh họa preview.

Root đã tắt nhận tác vụ và lưu thành công trong lab, giữ deadline tự dọn23:40:23VN; không gia hạn hoặc nguồn mới. Kết luận: API/admin/Ủng hộ đã nối thật và đạt hành trình trước; photo analyze/prepare đạt, native download chưa đạt nghiệm thu; video short còn FAIL proxy proof cũ. Chưa đủ điều kiện deploy. Giao code tay to đọc đúng source hiện có để lập kế hoạch fix hẹp cho video finish refusal/preview không ổn định; không test/framework/lab/nguồn thêm và chưa sửa guards hoặc code trước kết luận cụ thể.

**Chốt review và cleanup, 23:44VN:** root đọc [PHOTO_DIAGNOSTIC](../../lab-runs/tiktok-photo-finish-observation-20261101-96a2221104564a43b41b13de86ac7ae1/PHOTO_DIAGNOSTIC.md), [SOURCE_REVIEW_PLAN](../../lab-runs/tiktok-photo-finish-observation-20261101-96a2221104564a43b41b13de86ac7ae1/SOURCE_REVIEW_PLAN.md) và [cleanup](../../lab-runs/tiktok-photo-finish-observation-20261101-96a2221104564a43b41b13de86ac7ae1/cleanup.json). Cleanup thực16:40:31.8066160UTC/23:40:31VN: ownResourcesLeft0, operatorAccessRemovedtrue; sourceRequestsnull/NOT_MEASURED, không dùng startup0 thay actual. Không còn URL local sống.

Review source chỉ ra các nhánh grant/proof/publication optional đang gộp lý do; chưa chứng minh đây là nguyên nhân preview1 hoặc video mandatory proof thất bại. Không có căn cứ đổi redirect-body handling, deadline hoặc closure predicate. Root nhận kết luận có giới hạn và **chưa duyệt** đề xuất thêm enum/packet optional cùng nhóm test mới: đây là bổ sung quan sát, chưa phải bản sửa blocker hiện tại và chưa cần mở rộng protocol. Giữ diagnostic4fields/broker predicates đã review, không tạo thêm vòng lab/test/nguồn để báo tiến độ. Code tay to được yêu cầu dừng, không tạo tài liệu lặp. Việc xác định predicate thất bại thực của video vẫn là khoảng trống cần giải quyết trước nghiệm thu shortlink/release; không coi prepare READY, optional preview hay CI cũ là bằng chứng tải native hoặc watermark đạt.
