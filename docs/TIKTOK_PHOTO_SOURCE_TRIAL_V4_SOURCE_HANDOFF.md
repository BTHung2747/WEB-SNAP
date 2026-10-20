# Một workflow ảnh TikTok thật — 13/10/2026

**SOURCE_TECHNICAL_PASS_NEEDS_VISUAL_REVIEW.** Đã thực chạy đúng một workflow
nguồn thật sau independent binding và fresh preclaim. Metadata đúng ID/photo,
ảnh số1 tải đạt MIME/magic/ffprobe/1frame/fullDecode/SHA. Chưa human visual review,
không tự kết luận watermark PASS hoặc cả album/gallery/app/API E2E/deploy.

Target đã giao https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421,
expectedID7678209751167110421/photo/index1. Task cố định
`cf3808fc328743369a848f3bb5a5495e`, allocation
`b8f3a0d86c51490383c87fc925c876da` hiện **CONSUMED**, không reset/reuse/retry.
Source runner chỉ gọi1lần; analyze/workflow1; actual GETmetadata2 và conditional
image1, redirect0/retry0/HEAD0. Không tải ảnh2–5 hoặc resolve/endpoint/mạng khác.

## Binding và kết quả thực

Code giữ nguyên `labs/tiktok/photo-source-trial-v4-live/`109source/runtime107;
sourceHash619a12e8…964f59/runtimeHash024ca568…797013, gateSHA
2e181a719d4513f6165a055927a1d51a6cb4ba0e92ca6a0addd2509a0a08d91a.
Independent-review exact SHAe9ec0074…da4a08 từ reviewer, không viết lại gate/review.
Audit final verification-seal-2/verification-2 PASS, Additive112evidenceSHA còn
nguyên; snapshot314/root gate/preparation/cold/fixture scripts cũ không sửa.
Giữ classifier/Requests2.34.2/urllib3-2.8.0/HE2.7.1/yt-dlp2026.8.19/Cobalt/FFmpeg/
API/schema/pins/LICENSE/NOTICE/lock. Chỉ scripts bàn giao mới, không đổi runtime.

Fresh preclaim actualnetworknone96MiB/CPU.25/UID65534/RO/privateIPC/dropALL/NNP/
noports/native0/101coldchecks/sourceimports nofixture/originalCA/runtime107 đúng,
DNS-TCP hooks0. Authority trong preclaim/authority có FIXTURE_LABEL là mô phỏng,
không cấp quyền tải. Human authorization và allocation thật materialize đúng
schema từ lời giao và dispatch đã lưu, expiryUTC10min **chốt saupreclaim**, exact
gate/review/code-runtime/CA/quota/target/IDs/preclaimSHA. AssertSourceAuthorization/
AssertSourceAllocation trướcconsume đạt; actual runner CreateNew latch→claim
trước network-private timestamp, native/files exclusive không overwrite.

Nguồn thật:

- Native wrapper/runner/workercontainer/proxy/validator/parent/child **đều0**;
  finalizer PASS_SOURCE_TECHNICAL_NEEDS_REVIEW, mọilabel/DNSv4/trace/operation/
  batch/accounting/file gate true. Source stage thực/no fixture imports/CA/env/
  ExtraHosts; originaltrust9cc2a774…d730f worker/proxy/child giữ. UID1000 không
  đọc privateproxytrace và noBypass guard đạt. Cookie ngoại/account/browser/solver0.
- Metadata2GET đều200, body1462 rồi413648bytes, tổng415110≤16MiB. ID7678209751167110421/
  typephoto/imageCount5/index1/dimensions2132×2132 valid, metadata4.7224s≤30s.
  Body đầu1462chưa tựPASS; existing extractor xử lý trong giới hạn2GET để có
  metadata hợp lệ, không thêmretry/fallback ngoài thư viện đãghim.
- ConditionalimageGET1/HTTP200/518342bytes. Prepare3.2479s≤60s;
  giữ imageinput20MiB/output16MiB/workflow36MiB đãchốt, actualinput518342bytes.
- JPEG MIMEimage/jpeg/magicjpeg/2132×2132/pixels4545424/1frame.2FFPROBE native0,
  fullDECODE native0/.140359s; filebytes518342/SHA
  `7fc4899a9e249f93789724dd036852110f360eb570b4b85539fb38ebdde1f0d2`.
- DNSactual metadata144raw/validated144/30endpoint/114duplicates và image63raw/
  validated63/21endpoint/42duplicates, ALL_ALLOWED/admitted≤64/nativehelper0/
  reaped/pipesclosed/groups0. Rawrows/IP không lưu; không suy30IP hay nguyên nhân
  duplicate. Proxyowners accepted2/closed2/workersReturned2/socketthreadsleft0/
  trace48rows vàoperation20complete. Origin/perSocket causalcorrelation UNKNOWN.

MộtPASS khôngchứngminh v4dedup lànguyênnhân duy nhất sửa mọiFAILlịch sử; noA/Bnguồn
tronglượt này. Không suy metadata/file này tải đượcmọilink hayallalbum.

## Tệp thật và visual

Tệp giữ nguyên ở sourceRoot/source-task/task-cf3808fc328743369a848f3bb5a5495e/
b8f3a0d86c51490383c87fc925c876da/worker/image.jpg. Đãvieworiginal2132×2132 vàmở
trongapp cho người dùng; ảnhcollage4ô minh họa cócaption “You the main attraction”.
Assistant chưa thấy rõ wordmark/iconTikTok trongfile, nhưng **humanReviewPENDING/
NEEDS_VISUAL_REVIEW**, watermarkNOT_FINALIZED. Giữ chữ/logo/nội dung nguồn; không
crop/blur/transcode đểchelogo. Không sửa visualassessment cũ khi nhận review;
humanreview/successor sau đó cần gắn SHA này. Nếu người dùng chưaxemđủ, giữpending.

## Guards, cleanup, bằng chứng

Giữ metadata30/prepare60/HTTPconnect10read20/requestbudget2+conditional1/
redirectretryHEAD0/8MiBresponse16total/20input16output/workflow36MiB/dimension8192/
pixels16M/raw256-unique64/validateall/stablefullkey/order/SSRF-publicIP/TLS/IPC/
heap/trace/policyC/cancel/native/ownership. Cachedimage31742091…dfa417e/no build-
pull-install/RAM8GB sequential/worker512CPU.75+proxy96CPU.25=608/validator96after
rolesstop/UIDRO/privateIPC/dropALL/NNP/ROcode/noports/source-onlyimports/trust.
Own4containers/2nets absent;13images25oldcontainers35volumes/mainrendererđúngID
giữ;globaldriftUNKNOWNnếucó/nohostfix. History/code/protectedhash và exactreviewgate
khôngđổi. SourceRoot chỉthêm preclaim/humanauth/source-task, additive ledger mới;
manifest gốc khôngđổi hoặc mở exclusions. Claims real/task consumed giữ evidence.

Prepare toolAttempt1 chưa đọc đủ dispatchreceiptchain lúc dispatchghi; Attempt2
inventory property null, đều trướcpreclaim/authority/capability/source. Rawscript/
failure giữ, collectorfixedkhôngruntimechange. Chỉ1sourceattempt0, no sourceretry.
Lệnh actual bundledpwsh -NoProfile -File:prepare1FAIL/prepare2FAIL/preparecorrect;
run-preclaim;run-source-once;collect;insert-docs;verifySeal/readonly. Nativeexits,
timestampsUTC-VN/codehash/caps/cause/file/cleanup/evidencefullcoverage tại
`docs/evidence/tiktok-photo-source-trial-v4-source-result-20261013/`.

Tiếp theo chỉkiểmđộc lập kếtquả vàhumanvisual review theo
[NEXT_PROMPT](evidence/tiktok-photo-source-trial-v4-source-result-20261013/NEXT_PROMPT.md).
Không source2/retry/reset/gallery/main/UI/DB/settings/host/deploy; video human2/3/
mẫu3pending/appAPI E2E vẫn giữ. Source ảnh thật technicalPASS1 chưanghiệmthu album.
