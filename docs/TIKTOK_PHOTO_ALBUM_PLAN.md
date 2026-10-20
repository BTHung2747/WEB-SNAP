# Kế hoạch album TikTok trong lab offline

Ngày13/10/2026. **ALBUM_PLAN_PENDING_INDEPENDENT_REVIEW.** Đây là thiết kế và
đề xuất quota để review, chưa triển khai runtime, tải ảnh2–5, mở gallery hoặc deploy.
Quyền nguồn cũ chỉ một ảnh số1, task/allocation đã CONSUMED và không được dùng cho album.

## Cơ sở đã kiểm

Ảnh số1 bài7678209751167110421 đã được kiểm độc lập và human-review: JPEG2132×2132,
518342bytes/1frame/fullDecode/SHA7fc4899a…dde1f0d2, hình đúng/không thấy watermark
TikTok. Metadata an toàn ghi5ảnh, nhưng chỉ tệp số1 được tải/xem. Source86/human10/
audit33 artifacts là hồ sơ của lượt đã hoàn tất, không là album PASS. Đã kiểm
manifest/audit seal+readonly; phiên kế hoạch này không chạy lại tải/FFmpeg/tests.

Mã hiện có đã được đọc:

| Thành phần hiện tại | API/hành vi đúng pin được xác minh | Phần thiếu cho album |
|---|---|---|
| Cobalt a636575b09de1fc55d9b8cd98cac88f5f2f16b42/API11.7.1/AGPL-3.0 | `tiktok.js` map `imagePost.images` theo thứ tự, chọn URL chứa `.jpeg?`, trả `picker`; annotation lab thêm id/resolvedPostId/private/dimensions từ detail đã parse | Validate toàn bộ descriptor; không đổi parser hoặc thứ tự, không tự sửa suffix/query |
| `labs/tiktok/photo/picker.mjs` | Đọc body tối đa8MiB, gọi resolver pin `alwaysProxy:false`, id/bodyID khớp, picker1..50, map index1-based/URLHTTPS/dimensions; output private pipe cho Python | Public descriptor fingerprint, strict numeric/dimension/index toàn bộ; URL vẫn chỉ RAM |
| `labs/tiktok/photo/worker.py` | `GuardedYDL.extract_info(... download=False, ie_key='TikTok',process=False)` lấy body bằng extractor pin; Cobalt parse; shared anonymous RAM cookiejar | Lệnh prepare chỉ `images[0]`, tên image.jpg; cần selected indices và bộ điều phối nhiều file |
| `apps/media/src/tiktok/core.py` | Budget bounded decoded read, Requests public Session/Adapter.send, TLSverify/proxy/redirectdeny/HTTPtimeout10–20; `Budget.prepare()` cố định1request | Không thể gọi prepare N lần để reset quota/total; cần budget album wrapper/profile trong lab |
| Photo `contract()`/Operations/parent | imghdr JPEG +2ffprobe+fullffmpegdecode, SHA/xb, parent chờ worker exit0 rồi reap/cleanup; packetcap8192/Operations32events | Validate từng file, ledger toànalbum, scope log perimage; cleanup hardcoded2names cần owned set |
| Source lab `photo-source-trial-v4-live` | Strict authority scalar/DNSv4 outer-nested/missingbyte/SSRF/policyC/native/trace/claim/cancel/cleanup; finalizer index1/input2+1/outputimage.jpg | Kế thừa nguyên các guard, thêm album contract/accounting/finalizer riêng; nguồn tiếp tục off |
| Core app adapter/worker/API | Hai child analyze/prepare riêng, selectable không giữ child; `media.mp4` và video selection hiện tại, ownership/session-job-transfer lease/CSRF | Tích hợp ảnh là nhiệm vụ/schema/API riêng sau lab và source; không đưa photo lab runner vào runtime |

Dùng Cobalt/yt-dlp2026.8.19/Requests2.34.2/urllib3-2.8.0/HE2.7.1/FFmpeg/stdlib
đang ghim. `Budget`, `Operations`, ProcessGroup/Trace và validator có sẵn là nền;
chỉ viết glue selection/aggregate-budget/file-ledger còn thiếu. Thư viện không
có hợp đồng job/album/claim/owned-cleanup riêng của WED SNAP. Không copy private
helper, toànứngdụng Cobalt, parser/gallery-dl/F2/DouK, cài dependency hoặc build.
Giữ LICENSE/NOTICE/AGPL attribution imputnet, locks/SRI/hash/classifier hiện tại.

Nguồn chính thức đúng pin đã lưu nội dung/hash trong nghiên cứu OSS và đọc cùng
vendored implementation:
[Cobalt tiktok.js](https://github.com/imputnet/cobalt/blob/a636575b09de1fc55d9b8cd98cac88f5f2f16b42/api/src/processing/services/tiktok.js),
[API package](https://github.com/imputnet/cobalt/blob/a636575b09de1fc55d9b8cd98cac88f5f2f16b42/api/package.json).
Frozen upstream tiktok.js SHA58d30356…39275 khớp nghiên cứu; lab vendor khác vì
imports/no-stream/annotations đã có provenance. Xem `TIKTOK_PHOTO_OSS_RESEARCH.md`
và official-references/cobalt-parity. Gallery-dl là reference/dự phòng có điều kiện;
chưa căn cứ cần đổi extractor. Không web tra mới vì không dùng API mới/chưa xác
minh; phiên này chỉ đọc snapshots/code pin, không xác nhận upstream latest.

## Phạm vi lựa chọn và identity

Đề nghị đợt lab đầu **JPEG-only, tối đa5ảnh được chọn**, mode `single`, `subset`,
`all`. `all` chỉ cho bài có1..5ảnh; với count6..50 phải báo ALBUM_SELECTION_LIMIT
trước imageGET, không truncate5 rồi gọi là toànalbum. `subset` có thể chọn1..5
ảnh từ metadata1..50; cả bài vẫn chưa được nghiệmthu nếu chưa tải đủ. Đây là
bounded album support có tiêu chí rõ, không cam kết mọi bài TikTok/50ảnh/fullformat.
Mục tiêu source kế tiếp nếu được giao sẽ đủ5ảnh bài mẫu, với quota/authority mới.

Metadata contract đề xuất version riêng `tt-photo-album-v1`: id/typephoto/
imageCount1..50/images đúnglength/index1..N liên tục duy nhất, không bool/float/
NaN/Inf/null dimensions, width-height1..8192/pixels≤16M, mỗi URLHTTPSpolicy checked
trongRAM bằng library; không rawURL trong packet/evidence/DB. Bất kỳ descriptor
malformed/thiếu JPEGURL ởgiữa/cuối từ chối toànmetadata; khôngfilter/reindex/drop
badimage. Cobalt hiện map khôngfilter nên thiếu candidate URL đã gây pickerFAIL,
giữ nguyên hành vi failclosed. Private/wrongbodyID/type khôngđượcprepare.

Public descriptor: `index,width,height,itemKey`; `itemKey` hash public tuple
postID/type/index/dimensions, `snapshotKey` hash vector descriptor cóthứtự+count.
Có thể reuse cách canonical public fingerprint của core video adapter qua helper
glue riêng. Dùng stdlibJSON/SHA, không hash cookie/token/signedURL hay HTML đểpersist.
Metadata public packet max8192 nhưparent; phải đo serialization với50descriptor
maxwidth/key trongoffline fixture, vượtcap thìFAIL, không nângcap ngầm.

**Giới hạn identity:** hiện Cobalt lab chỉ expose index/dimensions, chưa xác minh
stable public per-image assetID. Structural keys phát hiện body/count/index/
dimension-vector thay đổi, **không chứng minh bytes của ảnh không đổi** nếu cùng
kích thước. Không bịa assetID hoặc gọi hash publictuple là contenthash; SHAfile
chỉ có sau tải. Trước appselectable cần chốt semantics “prepare lấy phiên metadata
mới có cấu trúc tương ứng”, hoặc xác minh official publicimageID và thêm annotation
nhỏ từ detail đãparse trong nhiệm vụ riêng. Nếu sản phẩm cần chính xác ảnh đã
preview mà identity vẫnUNKNOWN, dừng integration phần đó, khôngpersist signedURL.

Selection packet strict object/version/mode/snapshotKey/indices. `indices` list
int thật1..N, unique, tăngdần,1..5; modeall phảiđúng `[1..N]`; subset/single đúng
count, mode/snapshot/bodyID match. Input `[3,1]` reject SELECTION_ORDER_POLICY;
không cast text/bool/float/dedup hoặc tự sort dữ liệu sai. Trả kết quả theo thứtự
nguồn vàindex gốc; chọn `[2,4]` luôn filenames0002/0004, khôngđổi thành0001/0002.
Hai ảnh giốngbytes nhưng indexkhác vẫn là2item, không dedup nội dung làm mất thứtự.

## Kiến trúc lab và file contract

Lab mới đề xuất `labs/tiktok/photo-album-offline/` với sourceGatefalse/default-
source deny trướccapability. Derive source-safe egress/authority/caps đã review;
không sửa live source lab hoặc files/pins đã seal. Parser/downloader gọi qua public
APIs hiện có, fixture được mount/import chỉoffline và labels rõ.

Luồng một workflow lab: parent spawn metadata child → Cobalt picker all-safe-
descriptors → packet selectable → nhận selection ngay trong bounded fixtureflow →
chuẩn bị tuần tự Nảnh bằng RAM URLs/cookiejar cùng child → từngfile xb/streamread/
JPEGcontract/fullDecode/SHA → worker provisional album packet → worker exit0 và
reap → finalizer độc lập nhận source-safe trace/accounting/ownership/file ledger →
ALBUM_TECHNICAL_PASS_NEEDS_VISUAL_REVIEW. Không background child qua userselectable.
Fixture tests nên kiểm cả metadata-only exit0 path. Apphai-child là bước sau.

Owned workdir duy nhất mỗi run/job, output fixed `image-0001.jpg` …`image-0050.jpg`
theo sourceindex; stage `.part` dùngexclusive xb. Tên từ validatedinteger, không
title/username/path nguồn. Chỉ generate name từ selectedindices; refuse symlink/
junction/traversal/nonregularfile/collision/preexisting trước GET. SHA+size+
dimensions+frame/nativeexit/itemKey giữ trong public fileledger. In-process ledger
gồm tấtcả filenames cóthể tạo, parent nhận cùng owned set trước spawn; không glob
xóa `*.jpg` hoặc dùng cleanup theo packet chưatin. Native bytes tải giữ nguyên,
không cropblurtranscode/copythumbnail/re-encode; decode dùng ffmpeg `-f null`.

Album thànhcông chỉkhi **mọi selected item** cócontract/SHA vàexact coverage,
worker exit0/cleanup proof/finalizer0. Item-provisionalPASS khôngready/deliverable
trướcalbumcommit; fileledger index/key/order khớpselection+metadata. NativeSHA
validation file thực vàno extra owned/unownedfile; sentinel hash giữ. Manifest
receipt cuối là điểmpublication, không cầnZIP hoặc archive trong đợt này.

Chọn **fail-fast với rollback owned set**: ảnh thứk lỗi/timeout/CDN/SSRF/invalid
format thìkhông GETảnhk+1, đóngresponse/session/nativechild/socket/helper vàreap,
remove tấtcả file/part do workflow tạo kểcảảnh1..k−1 đãverified; sentinel giữ.
Peritemreceipt cófailedIndex/cause/verifiedThenDiscarded/skipped, khôngraise
ALBUM_PASS/partial file ready. Logdiagnostics/bằngchứng cócấu trúc vẫn giữ riêng.
Khôngresume/download retry trong cùngclaim; partialfailure hoànthànhkhôngđược
nghiệmthu. Evidence/cleanup thiếu, nativekilled/nonzero dùpacketPASS: FAILclosed.

Cancellation/expired dùng parent ProcessGroup hiện có, absolute deadlines độc lập
eventloop, kill-reap đóngpipes; cleanup physical không phụ thuộc tracewrite. Trace
incomplete fail nhưng vẫn phảiclose; repeatedcleanup idempotent; khôngdọn ngoài
runIDs. Exit0≠metadata/filePASS vàpacketPASS≠childexit0 vẫn giữ ởmọiphase.

## Đề xuất quota album cần review/chốt riêng

Các số dưới **chưa áp dụng runtime hoặc quyền nguồn**, chỉ đưa vào profile lab
mới khi bước triển khai đượcgiao/chốt. Profile mộtảnh đãnghiệmthu giữ nguyên.

| Giới hạn đề xuất lab album | Giá trị | Cơ sở/điểm dừng |
|---|---:|---|
| Metadata descriptors / selected images |≤50 /≤5|50 làcap parserhiệncó,5 đủbàimẫu vàgiữbounded file/trace/disk; không nói50 làplatformmax |
| Metadata GET / image GET |≤2 /≤N selected|Quota cảworkflow, eachitem≤1 GET; không gọi `Budget.prepare()` đểreset allow repeatedGET; lỗi đầu tiên dừng |
| Metadata response/phase decoded |8/16MiB|Giữ current caps đọcdecompressed trongstream, noHTML logs |
| Image response decoded input/output |20/16MiB mỗiảnh|Giữ current perimage, reject ContentLength hoặc readboundary vượtcap; fullDecode/subprocess guards |
| Aggregate workflow input/output |116/80MiB choNmax5|16+5×20;5×16. Actualbudget tính N:16+20N/16N, vẫn max116/80; không cấp dư GET khi selectionnhỏ |
| Metadata deadline |30s|Mộtphase, khôngreset vìchallenge/headers/body |
| Album prepare active deadline |180s absolute|Đề xuất mới phùhợp parentpolicy≤180;5×60=300 bịclamp180, khôngcamkết5ảnh sẽxong nếuchậm |
| Item subdeadline / native contracts |≤60s, clampremaining|Itemexpiry≤albumdeadline−10sreserve; ffprobe10/10/decode30 clampitem/albumremaining, không giảmfullDecode |
| Final hash/exit/cleanup reserve |10s nằmtrong180|Không đủngânsách trướcspawn thìFAIL; time trả vềsauabsolute vẫnFAIL |
| Outer watchdog / proxy containment |225s / existing setup10s|Đề xuất225=30+180+15boundedrolesstop/collection, không allowance thêmGET sauactivephase; watchdogactualexit/nocontainerleft |
| RAM/concurrency |worker512+egress96=608MiB,1task/1ảnh|Reusecached image/CPU.75+.25/validator96 saurolesstop, memorykhôngscale theoN; không giữimagebuffers toànalbum |
| DNS/egress protections |raw256/unique64/allraw/SSRF/TLS/setup10/helper1|Không tăng đểphục vụalbum, stablefullkey/order/IPv6extrasguard/capdrop/UIDRO/NNP/privateIPC |
| Trace/diagnostic |networktrace256/owner32/map64;perimageOperations32|Mỗiimage riêngboundedoperations file cùngoriginalAPI+itemindex; ledger tổng≤5×32+32=192events dựphòng; no reset networkTrace đểche cap |

Networking tracecap256 giữ toànworkflow. Bound selected5 giúp giảm sốconn, nhưng
không bảo đảm mọi DNS/connection failure pattern nằm256. Adapter phải kiểm/reserve
trace capacity trướcrequest/group nhưexisting; tracecap thiếu thìFAIL trướccapability
vàrollback, khôngdrop evidence/tăngcap tựđộng. 1fileOperations objectgộpNảnh có
32eventcap, cần instantiation theoimage/sink cố định+boundedaggregatedreceipt;
không global monkeypatch `Operations.events`. Bytebudget tổng khôngreset giữaảnh,
HTTPphase remaining/accountingrequestID liên kết selectedindex choactualcalls.

Disk: max80MiB ảnh+16MiB activepart (nếu mọiảnh lưutrướccommit), boundedreceipt;
đề xuất workspace riêng kiểm≥112MiB free trướcprepare, quản lý actualownedbytes
trongloop, không quota tổngfilesystem thật/main. Testdiskfull/oversize dọnownedset,
no extra scratchcopy (renamepart khôngcopy). Kiểmstat free không bảo đảm disk sẽ
khôngcạn tronglúc chạy; errors thực vẫnFAIL/cleanup. Không gán caps từ sốbytes
518342 của mộtảnh thành bound mọiảnh. Metadata dims unknown/malformed reject,
formatJPEG missing reject; WebP/PNG/animated/bài>50 cần nhiệm vụ/quota khác.

App tươnglai: analyze vàprepare child riêng mỗiphase; workflow dài ≤2GETanalyze+
2GETmetadataPrepare+NimageGET, bytesbudgettổngbao cả2metadata (≤32+20NMiB) cần chốt
riêng, khôngcopy116MiB profilelab1metadata sang app. Prepare freshextraction validate
bodyID/count/order/selection snapshot; noRAMsession giữ quaselectable/DB/tệp.
Native transferlease/jobownership/sessionexpiry/CSRF giữ; no slot/claim reset.

## Tệp triển khai đề xuất, chỉ trong successor lab

| Tệp trong photo-album-offline | Thay đổi có căn cứ |
|---|---|
| `album_contract.py`, `album_budget.py` (glue mới) | Strict metadata/selection/ledger/version/errors+globalbytes/deadline/GET profile; delegate Budget/GuardedYDL/public Session |
| `worker.py` dẫnxuất photo worker | Cobalt RAM parse → validatedselection → sequentialstream each selectedindex → existingJPEGcontract+Operations+SHA; no parserrewrite |
| `picker.mjs` và NOTICE/PROVENANCE | Chỉbridgesafedescriptors/keys/dimension contract; Cobaltvendorpin nguyênbyte trừannotation cầnreview riêng |
| `parent.py`, `worker_entry.py` | Bounded selection IPC/8192bytes, nativeexit/reap/watchdog/owned ledger, prepareabsolute180profile, retaincancelguards |
| `finalize.py`,`accounting.py`,`receipt_labels.py` | ExpectedN/exactselection/fileSHA/contract/native/requestID linkage/peritemandaggregate acceptance; FAILcleanup toàn ownedset |
| `run.ps1`,`lab_contract.ps1`,`common.py` | Offline-only hashgate/runtimeinventory/mount/photooverride+deadline225/twofixtureimages, nguồndefaultdeny |
| `source_contract.ps1`,`source_policy.py`,`source_admission.py` | Chỉoffline profileproposal/fixturetest nếu cần; khôngauthority thật. Source albumschema/gate/quota/selectedindices/newtask cần reviewnhiệm vụkhác |
| EgressDNS/ownership/policyC/networktrace | Byte-identical reuse, khôngtransportchanges. Chỉnewfixturehost/body/image routing cần test isolation/hash |
| Fixture/harness/docsevidence | Newmetadata≥2orderedimages, faultcaps/cancel/cleanup/hashcoverage/cachedpins; no historicalverifier edits |

Không sửa `apps/`, existing `labs/tiktok/photo/` hoặc live namespace đã seal trong
offline implementation. Mount successor photo worker/picker thay lab base qua
runnerhashinventory rõràng; cached core/libs giữ. Khôngcopyrunnerfixtures vào app.

## Bước và cổng nghiệm thu

1. **Review kế hoạch độc lập.** Chốt boundedJPEG5, all/subset semantics, identity
   limitation, quota116/80/180/225 vàOperations/Trace coverage. Nếu cần50fullalbum
   hoặcformatkhác, chỉnh thiết kế/profile bằng nhiệm vụriêng trướccode. PlanPASS
   chỉýnghĩareviewthiết kế, khôngsource/runtimePASS.
2. **Triển khai lab offline khi đượcgiao.** Newnamespace/sourceGatefalse/freeze/
   LICENSEpin/provenance/diff. Tái dùng APIs đãđọc, no dependencies/buildpull/main.
   Đạt ít nhấtmetadata2ảnh/order/ID/all+single+subset/partialfailure/cleanup; narrow
   vàwholefixture quaextractor/downloader/nativeparent/finalizer thật/hashfinal.
3. **Kiểm độc lập implementation offline.** Newauditnamespace/nativeguards/receipt
   contradictions/scalar/DNSmissingbyte subset, fullcoverage; mọiFAIL/rawattempt giữ.
   Không tựbỏgate/tăngcap vìcaseFAIL. SourceGate tiếpfalse sauofflinePASS.
4. **Album source trial riêng khi chủ giao.** Newquota/task/allocation/selection
   binding/freshpreclaim/sourcegate/review/runtimehash. Khôngreuse cácclaims của
   ảnhindex1. Mộtworkflow đầyđủselectedimages hoặcFAILfast; requestcaps/bytes/
   no accounts/retry0/owncleanup. Bodymetadata đúng →từngfileMIMEdecodeSHA →visual
   review tấtcảảnh đượcchọn. Không xem ảnh1 đãđạt là nghiệmthu ảnh2–5.
5. **App integration/E2E/UI nhiệm vụriêng.** GiữvideoCLI/schema/media.mp4+YouTube
   nghiệmthu; thêm photo-specificasset selection/outputcontract rõriêng. Phân
   tích2child/session–job–transferlease/ownership/CSRF/cancel/expired/sweep/Range,
   thay đổischemaDB/API cầnreviewmigrations/quota/cache vàfixturesoffline trước
   realAPI E2E. ChưadesignUI; khi làmUI phải đọcTasteSkill, không đổi lifecycle.
   Mộtjobalbum publishmultiassets cần versioned contract/API: eachasset native
   lease độc lập vàjobready saumọiselectedverified; no ZIP/bundledtransfer tựđộng.
   TảiALL là lựa chọn chủđộng, khôngprefetch album khi userdánURL.

Fixture cầnthiết, khôngfullhistoryrerun: metadata2và5ảnh/allindex order; single/
subset2,4; duplicate/gap/bool/float/outofrange/wrongID/private/type/dims/selection
keymismatch; ảnhthứ2HTTPfail/html/MIME/decode/dimensionfail; partialverifiedthen
rollback/nothirdGET; perresponse+aggregatebytes trênN; remainingdeadline/exhausted
trướcspawn/readstall/cancel/PASS→exit20/hang/killed/helperlate; sentinel/symlink/
preexisting/path collision/idempotentcleanup/tracewritefail; receiptindex/count/
SHA/native contradictDNSouter scalar+missingbytes/orderlink failclosed; SSRF/
redirect noGETextra, fullDecode/hashreadycoverage. Groupcase bằngcoupled proof,
không mirrorimplementationassertions hoặcmatrix302historyđểtăngcount.

## Những điểm chưa biết, phải giữ đúng trạng thái

Không biết size/codec/bytes/watermark ảnh2–5, cácURLJPEG còn sống hoặc nguồn5ảnh
cóxong dưới180s; không mớiGETđểđo trongkế hoạch. Không biết stablepublicimageID,
contentidentity across phases, nonJPEGfullalbum/largealbums; no parserhypothesis
thaythế khi chưa lỗi. NetworkrawIP/duplicatecause/sourcecorrelation vẫnUNKNOWN.
Memory/disk/timing profile là design estimates, khôngbenchmeasure. All5cached
fixturePASS chưasourceall5PASS; JPEGsource1humanreview khôngalbumreview.

Evidence kếhoạch tại docs/evidence/tiktok-photo-album-plan-20261013/, read-only
code/pin/official refs hashes, auditmanifest33/protected/sourceJPEG+humanSHA intact,
commands/document successor/fullmanifest. ChỉPowerShelldocument/integrity tools,
Docker/testfunctional/source0/runtimechanges0. Promptnext offlineimplementation
chỉcóhiệulực sau independentreview vànhiệm vụ đượcgiao theo WORK_COORDINATION.
