# Phương án khép lỗi video TikTok trước release

## Lệnh triển khai hiện hành — 02/11/2026

Chủ đã giao **triển khai** để link sao chép từ web TikTok và link chia sẻ trong ứng dụng đều tải được, cung cấp hai link của cùng video. Mục này thay trạng thái chỉ-lập-phương-án bên dưới; các lượt/giới hạn cũ là lịch sử, không reset hoặc dùng lại.

- Web input thực: `https://www.tiktok.com/@yusuri.noy/video/7702474511697956103?is_from_webapp=1&sender_device=pc&web_id=7691323503794177543`.
- App input thực: `https://vt.tiktok.com/ZSgKDSorH/`.
- Video đích theo chủ: `7702474511697956103`. Phải xác minh ID sau resolve và metadata/body; không tự hardcode shortlink này thành canonical hoặc nhận một video khác.
- Thực hiện sửa trong worker/media/egress/shared URL theo nguyên nhân thật; dùng dependencies hiện có. Tái dùng recipe đã chạy, log mandatory đã review, caps1728MiB và TTL/cleanup; không dựng lại stack/harness, không đổi framework hoặc thêm logger optional rộng.
- Một đầu mối nguồn là **root qua trình duyệt UI** sau khi nhận binding mới; coder không đồng thời tạo job hoặc gọi TikTok. Thử web rồi app tuần tự, mỗi link một analyze/prepare/native download khi đạt. Nếu baseline cả hai đạt, dùng chính hai hành trình đó làm bằng chứng, không chạy lại sau đó. Nếu thất bại, lưu predicate trước cleanup, sửa hẹp/review/hồi quy sát lỗi rồi chỉ chạy lại dạng link bị ảnh hưởng; kế hoạch tối đa hai lượt ban đầu và hai lượt nghiệm thu sau sửa. Không tự retry vô hạn hoặc quay lại mẫu cũ, không có nguồn ảnh trong đợt này.
- Chỉ mở browser kiểm thử sau khi có source/binding/flags/guard/expiry rõ. Dùng locator theo tên thật và trạng thái mới; không dùng AX index sau screenshot hoặc thao tác song song hai tab nguồn. Native GET/download chỉ một lần; timeout phải đối chiếu transfer/file trước mọi quyết định.
- Đạt khi cả hai input đi tới đúng videoID, lựa chọn nguồn ≤1080p giữ luồng, prepare/proxy proof hợp lệ, MP4 về host có hình/tiếng và được kiểm media. SHA của hai tệp không bắt buộc bằng nhau vì CDN/format nguồn có thể khác; cần cùng ID và đúng format đã chọn. Chưa gọi đầy đủ watermark/visual PASS nếu chưa xem tệp thực.
- Deploy vẫn chỉ sau nghiệm thu/source candidate/image mới và target SSH/backup/rollback như kế hoạch. Lệnh này cho phép triển khai bản sửa và kiểm hai input, không apply production trước khi đạt. CURRENT/task docs do root quản lý.

### Điều chỉnh cách kiểm khi Browser bị tắt — 02/11, 00:15VN

Root đã hoàn tất WEB baseline qua CUA: một analyze/prepare/native GET, host `C:\Users\LENOVO\Downloads\wed-snap-video.mp4`, 2433084B/SHA256 `28f4a6def10d70980e2ecf594968165b6d6d8ee9580c1e15470f3e53de787505`. Chưa kết luận media/watermark trước đối chiếu. Khi tiếp sang APP, CUA báo “Local browser use is disabled in Work settings” trước thao tác nào; root đã báo chủ và đề nghị bật lại, không chuyển sang công cụ điều khiển browser khác.

Để tiếp tục công việc độc lập, root chuyển **actor nguồn duy nhất của APP baseline sang coder qua API lab thật**, không thao tác đồng thời: một analyze đúng URL app mới, đạt mới prepare và một GET tới tệp lab. Giữ budget/workflow/caps trước đó, fresh session/CSRF cùng source/IDbinding. Đây là phép kiểm API/media, không được gọi là CUA/native browserSave. Nếu lỗi thì lưu predicate rồi dừng nguồn; sửa hẹp/hồi quy/review theo phạm vi trước, chưa tự thử sau sửa. Khi Browser được bật lại, tái dùng job/file còn sống nếu có thay vì analyze lại; nếu hết hạn, báo khoảng trống UI và không lặp nguồn tự động. Bản web native đã đạt không chạy lại.

### Kết quả hai baseline và bước phân biệt lỗi — 02/11

[Lab848ce606/HANDOFF](../../lab-runs/tiktok-video-recovery-20261102-848ce6066a784de585fdd63e5f5dcc7f/HANDOFF.md) startup một lượt/sáu role1728MiB/TTL00:34:05VN. WEB jobe6768fd8…7541: UI nhận đúng tiêu đề/duration21s, một prepare/GET đưa tệp host nêu trên. [Đối chiếu transfer](../../lab-runs/tiktok-video-recovery-20261102-848ce6066a784de585fdd63e5f5dcc7f/web-transfer-diagnostic.json): server_finished/2433084B=reserved=sizehost. [Media thật](../../lab-runs/tiktok-video-recovery-20261102-848ce6066a784de585fdd63e5f5dcc7f/web-host-media-check.json): ffprobe0/H264576×1024/AAC44100stereo/21.177s, full decode video+audio0/stderr0 trong cachedimage networknone256MiB/RO; không sửa tệp. [Identity](../../lab-runs/tiktok-video-recovery-20261102-848ce6066a784de585fdd63e5f5dcc7f/web-identity-summary.json): retained snapshot bodyIDmatchesExpectedtrue, sourceDefault/highesttrue; sourceUrl DB đã cleared theo lifecycle nên canonicalMatchesExpectednull vẫn UNKNOWN. Hình/tiếng cảm nhận và watermark chưa có review người xem mới.

APP baseline job6da183cb…996a: đúng một APIanalyze, failedCONTENT_UNAVAILABLE, chưa prepare/GET. [Worker](../../lab-runs/tiktok-video-recovery-20261102-848ce6066a784de585fdd63e5f5dcc7f/app-worker-diagnostic.json) actualchild0/group0 nhưng parent brokerREJECTED/connections2/stoppedfalse/deadlineExceededfalse. [Broker](../../lab-runs/tiktok-video-recovery-20261102-848ce6066a784de585fdd63e5f5dcc7f/app-egress-diagnostic.json): ctxFailedtrue/validationAcceptedfalse, owner/DNS/registry/worker-client-loop closure đạt. Đây là kết nối có lỗi trong phase short, không chứng minh leak/timeout/mismatch hoặc nguồn video không tồn tại. Bản trích chưa có thao tác/exception hoặc reasonCodes, không tự quy RST/redirect là nguyên nhân. Một runner preflight lỗi DateTime-coercion đã dừng trước session/source và được sửa DateKindString; không tính thành một source analyze khác.

Chủ báo Browser đã bật sau đổiaccount; root thử lại và reset kết nối chuẩn vẫn báo Worksettingsdisabled nên không tạo APPjob bằng CUA. Coder tiếp tục actor nguồn duy nhất theo bàn giao, không có root/coder đồng thời tạo job.

Root đã review [mandatory observation](../../lab-runs/tiktok-mandatory-failure-observation-20261102/observation.patch): đúng3source egess/Request/Broker, log failure-stage/direction/fixedexceptioncode/tunneled và whitelist reasonCodes sẵn có max8; giữ verdict/exceptionpropagation/guards. Coder3focusedpuregroupsPASS (0socket/native/source), hostPython3.14 giới hạn riêng; root đọc test/diff và4pinsmatch, không rerun. Không optional protocol hoặc trace framework mới. Cho restart riêng egress thuộc lab/owner kiểm lại tối thiểu, rồi workflow3 APP một analyze với log này; đạt mới prepare/GET cùngjob, lỗi thì giữ predicate trước cleanup và dừng. Chưa có kết quả workflow3 ở thời điểm ghi mục này; còn tối đa workflow4 cho nghiệm thu sau functionalfix nếu cần.

### Workflow3 xác định CLIENT RESET; bản sửa lifecycle đang thực hiện

[APP3 log](../../lab-runs/tiktok-video-recovery-20261102-848ce6066a784de585fdd63e5f5dcc7f/app3-egress-diagnostic.json): `egress_request_failed/RELAY_READ/CLIENT/RESET/tunneled=true`, member validationReasonCodes `CONTEXT_LIFECYCLE`, `REGISTRY_COMPLETION_UNKNOWN`, ctxFailedtrue. DNS/closure/registry sạch, childactual0; parentREJECTED/connections2/stoppedfalse/deadlineExceededfalse. Job2966467d…60aa failed, metadata chưa accepted, không item/asset/prepare/GET. Một analyze đã dùng; còn workflow4 theo phạm vi đợt02/11. Đây là lỗi đọc ở phía client sauCONNECT, không phải bằng chứng TikTok/CDN reset; member là short redirect hay canonical chưa được log định danh. Không hồi tố nguyên nhân tuyệt đối cho video1 cũ.

Root cho sửa hẹp lifecycle response của resolver: dùng `BoundedBody`/API Requests/urllib3 đang ghim để đọc bỏ redirect body đến EOF trướcclose, chunks nhỏ/caps/deadline cũ; không dùng `.content` hoặc `drain_conn` vô hạn. Carry decoded bytes sang metadata canonical để tổng≤16MiB/inputcap, perresponse≤8MiB; video/photo cùngresolver không được reset accounting. Canonical khôngshort mặc định giữ hành vi. Kiểm tối đa3nhóm sát validEOFbeforeclose, oversize/aggregate, deadline/errorcleanup/cookies; root review trước workflow4. Không đổi egress để chấp nhận RST hoặc nới proof, không nâng dependency/build stack. NếuTTL hết trong lúc sửa offline thì dọn cũ đúng hạn, không gia hạn; chỉ một lab thay thế saucleanup cho lượt nghiệm thu còn lại khi root nhận bản sửa.

**Root nhận candidate, 00:35VN:** [functional.patch](../../lab-runs/tiktok-short-response-lifecycle-20261102/functional.patch) chỉ4mediafiles: `core.py` thêm carry_metadata_bytes chỉ freshmetadata/int/nonbool/nonnegative/bounded/no-reset; `shortlink.py` đọc bỏ16KiB chunks quaBoundedBody đếnEOF, chuyểnaggregatecount và giữabsolute deadline; `adapter.py`/`photo_core.py` seedcounter, mặcđịnhcanonical0. [Kết quả3nhóm](../../lab-runs/tiktok-short-response-lifecycle-20261102/result.json) dùng actualRequests.Response/urllib3.HTTPResponse trên gzip/BytesIOseam, chứng minh oldclosebeforeEOF/newEOFbeforeclose, video+photo carry12B,8MiBperresponse/16MiBaggregate/nextbyterefused, invalidcarry/deadline/readtimeout/cookiecleanup. [Native receipt](../../lab-runs/tiktok-short-response-lifecycle-20261102/native-final-result.json) cachedimage/networknone256MiB/0.75CPU/exit0; source/socket0. Firstimportfail thiếuoverlay giữ riêng, không là chức năngFAIL. Root đọcdiff/testsource/5pinsmatch, khôngrerun; nhận cho integrationcheck, chưachứngminhnguồnđãsửa.

FixtureTLSloopback trước đó [redirect-probe-result](../../lab-runs/tiktok-mandatory-failure-observation-20261102/redirect-probe-result.json) dừng ở3sbarrier trướccompare; giữFAIL và chưa dùng chứng minh nguyên nhân. Khi đã có candidate/seamchecks mới, root không mở thêm vòng sửafixture đó; tập trung workflow4 thật. Không suyCLIENTRESET tuyệtđối thuộc memberredirect hoặc hồi tố historicalvideo1.

Cho coder tiếp tục actorAPIduynhất workflow4APP sau khi oldlabcleanup0 và một replacementlab cùngrecipe/guard/cache/TTL30phút; khôngdịchvụsonghành/extendTTL/build/pull. Mộtanalyze đúngappURL, verifyresolved/bodyID, đạt mớiprepare/nativeGET mộtfile vàffprobe/fullDecode; lưusnapshottrướccleanup. KhônglặpWEBPASS, khôngsource5 hoặcdeploy trong lệnh nghiệmthu này. BrowserrootvẫnbịWorksettingsdisabled sauaccountchange; APIfilekhôngđượcgọiCUAbrowserSave.

### Nghiệm thu APP4 và candidate phát hành — 02/11

[Handoff chuẩn](../../lab-runs/tiktok-video-recovery-20261102-4f99fbf9e76441cdb935098c6467abad/HANDOFF.md). Oldlabcleanup00:34:13VN/0, replacementstartup cùngcache/6roles1728MiB/3net/sourcepins4functional+3diagnostic kiểm thực. APP4 job909b4ff3…564b: [resolve binding](../../lab-runs/tiktok-video-recovery-20261102-4f99fbf9e76441cdb935098c6467abad/app4-resolve-binding.json) canonicalMatchestrue/queryAbsenttrue; [DB snapshot](../../lab-runs/tiktok-video-recovery-20261102-4f99fbf9e76441cdb935098c6467abad/app4-db-diagnostic.json) selectioncontentId7702474511697956103, sourceDefault/highesttrue/H264AAC576×1024/21s, cùngformat WEB. [Worker](../../lab-runs/tiktok-video-recovery-20261102-4f99fbf9e76441cdb935098c6467abad/app4-worker-diagnostic.json) analyze/preparechild0/group0/mainproofACCEPTED2/2; optionalpreviewfalse không được nâng thànhđạt.

Mộtprepare vàmộtGET trongAPP4 tạo [app4-video.mp4](../../lab-runs/tiktok-video-recovery-20261102-4f99fbf9e76441cdb935098c6467abad/app4-video.mp4) 2433084B/SHA28f4a6def10d70980e2ecf594968165b6d6d8ee9580c1e15470f3e53de787505 **bằngtệpWEBnativebrowser**; lease server_finished/bytes=reserved2433084. [Media check](../../lab-runs/tiktok-video-recovery-20261102-4f99fbf9e76441cdb935098c6467abad/app4-host-media-check.json) networknone/RO/256MiB: ffprobe0,H264576×1024/AAC44100stereo/21.177s; full video+audio decode0/stderr0. Khôngupscale/transcode/crop/blur/xóa logo. Highest chỉ trong tập nguồn hợp lệ nhận được, không chứng minh mẫu này có1080p. APIGET lưu file trongnamespace không đượcgọi APP CUA/browserSave.

Đợtmới thực4analyze/2prepare/2nativeGET; khôngsource5. APP2/3FAILED giữ bằngchứng, APP4saucandidate đạt cùngWEB; đây là bằngchứngsửaluồng hiện hành cho cặplinkchủgiao, chưachứngminhcauseduynhấtmọiTikTok/video1cũ. Rawredirects0 củaAPIrunner chỉauto-redirectHTTPclientđãtắt, khôngphépđếmmanualshortredirect. [Cleanupreplacement](../../lab-runs/tiktok-video-recovery-20261102-4f99fbf9e76441cdb935098c6467abad/cleanup.json) thực00:39:12VN/0/accessremoved; mediahost/evidencegiữ, URL5212đãdừng. Root đãgửi clipvàxinreviewhình/tiếng/watermark; chủtrả lời chưa thấyclip, nên chưaghihumanPASS. Đãgửi lạifileworkspace/Downloads vàopen_in_codex trảqueued; khôngcoi queued làđãhiểnthị.

Root đọc [release-delta.json](../../lab-runs/tiktok-video-recovery-20261102-4f99fbf9e76441cdb935098c6467abad/release-delta.json)/patch:11runtime (4media+3egress+2worker+2adminfont),4manualfocusedQA,2devlabhelpers; đọc/táidùngreviewđúngpins trước, khôngrerunsuite. Hai devhelpers chỉport/UIartifact/privateACL của lab, khôngproductionbehavior. Chọnexact17codepaths+CURRENT+hai taskdocsroot; khôngcompose.yaml/oldlabs/permissions/logs/raw/credentials/media hoặcunknownpaths. Chuyển một commit/push/CI theo workflowhiệncó, Caddygatebắtbuộc; chưaapplyLightsailvàpreviewproductionflaggiữtắt. Visual/watermark cònchờreviewclip; rolloutchỉsauartifact vàtarget/drain/backup/rollback đãrõ.

### Git/CI đã đạt, chưa rollout — 02/11, 00:49VN

Root đã commit/push đúng20paths được review ở `add52bc1723f58aade8abbb42bc831f2a2071c0d`, không stage phần khác. [Git receipt](../../lab-runs/tiktok-release-final-20261102/root-git-receipt.json); đúng một dispatch được nhận, [CI41333031820](https://github.com/BTHung2747/WEB-SNAP/actions/runs/41333031820) attempt1 completed/success. Build app/web/egress, compiled/static identity, pinned Caddy2.11.7 native adapt/validate, publish ba registry digests và cleanup đều success. [Immutable image refs](../../lab-runs/tiktok-release-final-20261102/root-release-images.json) lấy từ log đúng job124926951854/tag/source; đây là image mới có bản sửa, chưa apply Lightsail và không phải kết quả chạy nguồn thêm trong CI.

Chủ chưa nhìn thấy video đính kèm. Kiểm lại hiện tại: file `C:\Users\LENOVO\Downloads\wed-snap-video.mp4` không còn; [MP4 kiểm thử còn trong workspace](../../lab-runs/tiktok-video-recovery-20261102-4f99fbf9e76441cdb935098c6467abad/app4-video.mp4) đủ2433084B. Đã đính chính đường dẫn và gửi cách mở file trực tiếp; open_in_codex vẫn chỉ queued. Không ghi human visual/watermark PASS. Tiếp theo: chủ xem clip; trước rollout qua SSH AWS phải đọc target/source/image refs hiện hành, drain/backup và chuẩn bị rollback, giữ env/settings/volumes; chưa chạy bước đó.

### Xác nhận người xem — 02/11

Chủ trả lời trực tiếp câu hỏi nghiệm thu clip21giây: **“Đã xem/nghe đủ, hình tiếng đạt và không có watermark TikTok”** (reply cho `call_39dcb4c024c8417a9cd54c12e0f6c5f1`). Khép kiểm hình/tiếng cảm nhận và watermark cho MP4 mẫu7702474511697956103 đã đối chiếu cùngSHA giữa WEB và APP4; không cần tải hoặc test lại mẫu này. Các giới hạn APP qua API thay vì CUA/browserSave, optionalpreviewfalse và highest trong tập nguồn nhận được vẫn giữ nguyên.

Chủ đã gửi ảnh kết quả hai lệnh SSH trên `wed-snap-beta`: checkout `/opt/wed-snap` tại `2ec80343a94135b3e169b6164804b93f3707debf`; project `wed-snap-production` có worker/API/egress/proxy/Redis/Postgres Up, API/proxy/Redis/Postgres hiện healthy. `docker ps` chỉ hiện image ngắn app`89dee3aba025`, egress`1477bc7d5488`, web`cff11e84300e`; đây chưa đủ làm immutable rollback refs. Bằng chứng này là output trong ảnh chủ cung cấp, không phải lệnh root chạy trực tiếp trên VPS. Tiếp theo lấy full Config.Image/actualImage của bốn container ứng dụng, checkout dirty state và dung lượng đĩa; chưa drain/backup/apply hoặc thay production. Candidate mới vẫn đúng ba image của CI41333031820, không build tại VPS hoặc cập nhật PG/Redis.

**Target preflight bổ sung, 02/11:** ảnh tiếp theo cho thấy `git status --short` trống; API/worker cùng full appref, egress/web fullrefs và actualImage bằng digest trong Config.Image. Bộref cũ và source đã lưu tại [root-target-preflight.json](../../lab-runs/tiktok-release-final-20261102/root-target-preflight.json), đủ chốt rollback images; không phải backup dữ liệu. `/dev/root`77G/used6.3G/avail71G/9%. Gửi chủ [bốn lệnh preload](../../lab-runs/tiktok-release-final-20261102/lightsail-preload-commands.txt): fetch đúng candidate SHA và pull đúng3digests từ CI, chưa checkout/env/up/stop. Website tiếp tục bản cũ; chỉ chuyển maintenance/drain/backup sau khi các bước preload thực thành công. Chưa nhận kết quả các lệnh mới.

## Phương án đã lập ngày01/11 — cơ sở để thực thi

Ngày01/11 chủ yêu cầu **đưa ra phương án sửa** sau khi được báo mẫu video shortlink của bản mới thất bại. Phần dưới ghi kế hoạch và trạng thái tại thời điểm đó; lệnh triển khai02/11 ở trên là hiện hành.

## Kết luận để chọn phạm vi

- Lượt video `https://vt.tiktok.com/ZSgnv8Lae/` có child exit0 nhưng parent từ chối tại mandatory proxy finish. Chưa xác định predicate thất bại; không kết luận mọi video lỗi hoặc TikTok chặn. [Bằng chứng](../../lab-runs/tiktok-source-preview-20261101-0bd9fc0affda4f348a93431a28b90542/VIDEO1_DIAGNOSTIC.md).
- Photo mới đã qua cùng main proof và prepare; lỗi native download quan sát được còn thiếu bằng chứng request/lease/tệp host, không được trộn với lỗi video. [Chẩn đoán ảnh](../../lab-runs/tiktok-photo-finish-observation-20261101-96a2221104564a43b41b13de86ac7ae1/PHOTO_DIAGNOSTIC.md).
- Giữ yt-dlp2026.8.19, Requests2.34.2/urllib3 2.8.0, FFmpeg và framework hiện tại; không có căn cứ thay extractor hoặc cài dịch vụ tải bên thứ ba. Lockfile: `apps/media/requirements.lock`. Đây là lỗi cần đối chiếu ở phần tích hợp/phê duyệt kết nối do dự án sở hữu.
- Log worker bốn trường và broker closure predicates đã có, đã review. Đề xuất enum/packet optional preview trước đó không nằm trong bước ưu tiên này.

## Trình tự sửa có điểm dừng

### 1. Chốt đúng nguyên nhân của video, không mở rộng logger preview

Tái dùng recipe source-lab đã chạy được, cached images/source overlay, tổng caps1728MiB/loopback/ownDB/TTL30phút; không tạo harness/image/dependency mới. Đây là lượt mới cần được ghi riêng khi chuyển sang thực thi, không reset lịch sử.

Một đầu mối duy nhất gửi **một analyze** cho đúng shortlink đã lỗi. Khớp jobID xuyên suốt; root không đồng thời điều khiển UI nguồn. Lưu ngay sau kết quả, trước cleanup: worker `brokerState/connections/stopped/deadlineExceeded`, broker `proxy_finish_refused` và `proxy_member_refused`, job state. Không ghi URLCDN/cookie/token hoặc gọi thêm control/source probe. Log hiện có là điểm bắt đầu; chỉ nếu thiếu đúng `validation.reasonCodes` thì cho nối danh sách mã cố định có sẵn từ validator vào cùng event mandatory, có giới hạn/whitelist, không packet/protocol mới.

Nếu lỗi tái hiện, chọn bản sửa theo trường thật. Nếu không tái hiện, có thể hoàn tất prepare/native download của **cùng job** để đánh giá hoạt động, nhưng nguyên nhân cũ vẫn UNKNOWN; không tuyên bố đã sửa một lỗi chưa tái hiện. Không tự lặp analyze, đổi mẫu hoặc mở thêm bộ test.

### 2. Sửa hẹp theo bằng chứng, giữ điều kiện bảo vệ

| Bằng chứng phân biệt | Điểm sửa dự kiến | Điều kiện để nhận |
|---|---|---|
| Redirect/response/session hoặc tunnel chưa đóng đúng; chứng minh từ refusal và hồi quy cục bộ | `apps/media/src/tiktok/shortlink.py`, `session_owner.py` hoặc đúng nhánh relay ở `apps/egress/src/egress.py` | Dùng API public của thư viện; đóng/join/reap đúng chủ sở hữu trước finish. Không đổi mọi RST/BrokenPipe thành thành công, không bỏ proof. |
| Reply state/phase/profile/selection hoặc connection binding sai | `apps/worker/src/proxy-phase.ts` và đúng điểm tạo phase ở `adapter.ts`/broker | Sửa giá trị/binding hoặc thứ tự dùng handle; giữ chống replay, SSRF, TLS và giới hạn số kết nối. |
| Deadline/stop thật sự tới trước finish | Đúng chỗ dùng chung absolute deadline và phân bổ công việc trong worker/media | Sửa thứ tự đóng tài nguyên/khởi công việc optional khi còn ngân sách; không tăng30/180s hoặc nhận metadata sau hạn. |
| Lỗi nguồn/kết nối thật, không có bug tích hợp được chứng minh | Giữ fail-closed; phân loại lỗi đúng bằng enum hiện có khi có căn cứ | Không nới bảo vệ hoặc đổi thư viện để che sự cố môi trường. Chỉ có thể bàn giao giới hạn đã chứng minh, chưa gọi là functional fix. |

Giả thuyết cần xem trước nếu closure flags chỉ tới redirect: shortlink dùng `stream=True`, không đọc body redirect rồi `Response.close()`; proxy relay hiện gộp exception vào `policy.failed`. Đây **chưa phải nguyên nhân đã chứng minh**. Requests2.34.2 cho phép đọc hết body **hoặc** gọi `Response.close()`; vì vậy không tự coi việc không đọc body là bug. Không gọi `drain_conn()` vô hạn: urllib3 mô tả hàm này đọc bỏ toàn bộ dữ liệu còn lại, có thể làm thay đổi caps/deadline. Nguồn chính thức: [Requests body workflow](https://requests.readthedocs.io/en/latest/user/advanced/#body-content-workflow), [urllib3 response](https://urllib3.readthedocs.io/en/stable/reference/urllib3.response.html#urllib3.response.HTTPResponse.drain_conn).

### 3. Kiểm nhỏ nhất đủ nghiệm thu

Sau khi có delta functional cụ thể, chọn tối đa ba nhóm hồi quy sát lỗi: nhánh đã thất bại nay đạt, luồng hợp lệ đối chứng, và nhánh nguy hiểm/hết hạn vẫn bị từ chối. Dùng seam/helper đang có; không chạy cả labP18, suite lịch sử hoặc dựng framework mới. `tests/p18_egress_lab.py` chỉ là ví dụ cơ chế loopback/socketpair có sẵn, không được xem kết quả lịch sử của nó là proof mới cho policy hiện tại.

Sau review bản sửa, một hành trình video thật: shortlink → metadata/selectable → prepare → native MP4 → tệp host. Kiểm ffprobe/decode phù hợp để xác nhận hình/tiếng, kích thước không vượt FullHD1080p và giữ luồng nguồn; không tự upscale/re-encode để gắn nhãn HD. Nếu lượt nguyên nhân ở bước1 đã hoàn tất cả luồng trên cùng source không sửa, tái dùng kết quả và ghi chưa tìm được root cause, không lặp chỉ để có thêm PASS.

Ảnh còn thiếu native proof cần đúng một hành trình ảnh1 riêng trong cùng đợt nghiệm thu cuối nếu còn cần release. Tái dùng kết quả UI/admin/Ủng hộ và offline quality/URL mapping không đổi. CUA dùng locator theo tên thật, đọc trạng thái mới trước bấm; không tái dùng AX index sau screenshot hoặc khi UI đổi. Một actor, một lần nhấn tải, kiểm cả event tải và file host; timeout không tự bấm lại. Mỗi analyze/prepare/source count phải ghi thực tế.

### 4. Release sau khi đạt chức năng

Root review exact diff và evidence, cập nhật CURRENT. Build/publish một candidate gồm UI/Ủng hộ/Footer/adminfont và bản sửa đã nhận; source cùng commit với image digests. Tái dùng CI hiện có và gate Caddy bắt buộc. Sau đó mới rollout qua terminal SSH AWS: đọc target, drain/backup, apply immutable images, giữ env/settings/volumes, có refs rollback. Không đẩy ảnh cũ thành đã chứa mã mới hoặc đổi production trong lúc chẩn đoán.

## Trạng thái sau khi lập phương án

Đã đọc code/handoff/lockfile và tài liệu thư viện chính thức; chưa chạy test/runtime/nguồn hoặc sửa code. Lab5212 cũ đã cleanup0. Phương án không cam kết một bản sửa giả định sẽ chữa lỗi trước khi có predicate thực; bước tiếp theo tập trung duy nhất vào video mandatory proof, không mở thêm thiết kế giao diện/preview protocol.
