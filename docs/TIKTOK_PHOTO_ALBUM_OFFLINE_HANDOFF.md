# Bàn giao album TikTok lab offline — 13/10/2026

**ALBUM_LAB_OFFLINE_PENDING_INDEPENDENT_REVIEW**, sourceGate=false. Code mới ở
`labs/tiktok/photo-album-offline/`; evidence mới ở
`docs/evidence/tiktok-photo-album-offline-20261013/`. Chưa album nguồn/gallery/main/
API E2E/deploy. Xác nhận human review “Hình đúng, không thấy watermark TikTok” của
ảnh index1 đã được nghiệm thu trong successor cũ; visual-assessment cũ nguyên byte.
Ảnh thật2–5 chưa tải/xem. Video2/3/mẫu3pending giữ nguyên phạm vi hồ sơ hiện hành.

## Mã và thư viện

Giữ Cobalt commit a636575b09de1fc55d9b8cd98cac88f5f2f16b42/API11.7.1/AGPL-3.0,
imputnet, LICENSE/NOTICE/PROVENANCE/package-lock tại labs/tiktok/photo nguyên byte.
Gọi picker/resolver hiện có read-only; high-level yt-dlp lấy webpage/challenge,
Requests/urllib3 xử lý HTTP/TLS/cookie/decompression; FFmpeg/ffprobe và JPEG contract
hiện có kiểm tệp. Không chép private helpers/solver/parser/downloader ứng dụng khác.
Python3.11.2/yt-dlp2026.8.19/Requests2.34.2/urllib3-2.8.0/HE2.7.1/Brotli1.2.0,
imagecache31742091…417e; khôngdependency/build/pull/install. Xem references.json và
derivations.json (hash ban đầu từng module proxy/DNS/ownership/order được derive).

Tự viết đúng glue còn thiếu: album_contract (strict metadata/selection/ledger),
AlbumBudget subclass, album_worker nối vòng selected GET, album_parent (own names/
native exit/reap), fixture synthesis, runner và finalizer. accounting chỉ nhận
selected_count đã kiểm để mở quota N; toàn bộ RID/observer-order/type/missing-byte
checks giữ. Module proxy/connector/DNSv4/trace/batch/registry lấy từ lab đã nghiệmthu;
source-only lab và apps giữ nguyên. Fixture/runner không đưa vào apps runtime.

Public structural item/snapshot keys chỉ hash post/type/index/dimensions/vector,
khôngsigned URL/cookie/token; **content identity UNKNOWN**. Metadata1..50 JPEG
descriptors đều được kiểm; khôngfilter/reindex/truncate tail. Chọnsingle/subset≤5,
indices integer ascending unique; all chỉ khi count≤5. URL/cookie/HTML chỉ RAM/pipe
riêng trong workflow active; không DB/tệp/account cookie/selectable background.

## Quyền tệp, ngân sách và deadline

Parent đăng ký100candidate jpg/part và snapshot sentinel/filehash/link trước
metadata spawn; tựvalidate metadata/selection và exactselectednames trước command
prepare/GET/filewrite. Không lấy quyền cleanup từ packet worker. Tên giữ index
nguồn image-000X.jpg; xb.part/collision/symlink deny, rollback toàn finiteownedset
minuspreexisting. Failitem2: verifieditem1 discarded, item2failed, item3skipped;
khôngGET3/deliverpartial. PASS chỉ provisional cho tới exit0/reap vàfinalizer.

≤2metadata GET+NselectedimageGET; redirect/retry/HEAD0. Metadata8MiB/response và
16MiB tổngdecompressed,30s. Mỗiimage20MiBinput/16MiBoutput, aggregate16+20N/16N
≤116/80MiB; counters khôngreset qua ảnh. Prepare180absolute/item≤60clampremaining−
10reserve; ffprobe10+10/fullDecode30 clampitemdeadline. GET qua own-egress/TLSverify,
anonymousRAMcookies; metadata gate trướcprepare. Bộcaps scaled chỉ trong probe
được ghi rõ, wholefixture dùngprofile thật. budget.json các lượt đầu có nhãn
imageGET dùngdescriptor count; freeze6 sửa nhãn, runtime luôn dùng selectedN.

225s là containment của worker active(metadata30+prepare180+end15), khônghostE2E.
Parent activeEpoch ghi riêng; Dockerworker watchdog bắt đầu container startup.
Readiness≤35/validator15/stop15/nativeCLI20 (waitworker230) riêng; khôngclaim toàn
orchestration225 hoặc chứng minh mọi kernel/host failure. Kill/reap/pipe/socket
closure độc lập tracewrite; incomplete/native lỗi FAILclosed. Runtime512MiB/.75CPU+
proxy96/.25=608MiB, validator96 sau rolesstop; privateIPC/rootfsRO/UID1000-65534/
capdropALL/NNP/defaultseccomp/noports/mountRO/oneworkflow/cache. DNSraw256 được kiểm
mọirow trướcdedup/unique64ordered/IPC/helperdeadline/policyC/SSRF/TLS giữ. Trace256/
owner32/map64, Operations32/event sink mỗiảnh (≤160cho5), khôngresetglobaltrace.
Original Operations0600 giữ; projection numeric-only≤16KiB0644 cho separatefinalizer.
Disk preflight≥112MiB; worker peak RAM UNKNOWN, guard hardlimit/nativeOOM state và
proxy peak measured lưu. Không suyfixture nhỏ thành benchmarksource20MiB×5.

## Lệnh và bằng chứng

Freeze cuối: freeze-6.json; mỗi wholelượt source-before/runtimeactual khớp inventory,
source-after khôngdrift. Probe4 và suite47 là final-code; các namespace cũ FAIL/PASS
và code-attempt1..5/freeze1..5 giữ. actual-commands.json/native.jsonl/state/guard/
completion/operationpublic/accounting/proxytrace/registryDNS/measurements ghi actual
exit/signals/UTC-VN. Sandbox defaultDockerpipe denied được lưu; elevated chỉownlab.

Lệnh đã chạy (PS7 bundled path đầy đủ trong actual-commands):

```powershell
pwsh -NoProfile -File docs/evidence/tiktok-photo-album-offline-20261013/run-probes.ps1 -Attempt 4 -FreezePath docs/evidence/tiktok-photo-album-offline-20261013/freeze-6.json
pwsh -NoProfile -File docs/evidence/tiktok-photo-album-offline-20261013/run-suite.ps1 -StartAttempt 47 -FreezePath docs/evidence/tiktok-photo-album-offline-20261013/freeze-6.json
pwsh -NoProfile -File docs/evidence/tiktok-photo-album-offline-20261013/gate-probes.ps1 -FreezePath docs/evidence/tiktok-photo-album-offline-20261013/freeze-6.json -OutputName gate-final6
pwsh -NoProfile -File docs/evidence/tiktok-photo-album-offline-20261013/run-measure.ps1
pwsh -NoProfile -File docs/evidence/tiktok-photo-album-offline-20261013/verify.ps1 -Seal
pwsh -NoProfile -File docs/evidence/tiktok-photo-album-offline-20261013/verify.ps1
```

Final kết quả thực ở RESULT.md/assessment.json/measurements.json; unit/whole/gate
khác source. Expectednegative wrapper0 không có nghĩa filePASS: giữ validator20,
worker20 hoặc−9/signal9, rollback vàzero nextGET. Golden/manifests/raw lịch sử không
sửa; protected-before và doc-successor kiểm byte, own IDs/remove exits+Dockerafter.
Seal/readonly phải PASS mới đủ bàn giao review; khôngrungolden lịch sử để ép PASS.

## Bước tiếp

NEXT_PROMPT.md: kiểm độc lập implementation/evidence, đối chiếu guards/typedledger/
ownership/deadlines/GET-counters/serialization/DNSobserver và lịch sử. Nếu finding,
successor offline riêng. Chỉ sau reviewPASS mới lập sourcealbumtrial riêng với
newauthority/quota cụ thể vàhumanreview từngảnh; tasks consumed khôngreuse/reset.
App hai child/CSRF/session-job-transfer/gallery/UI/schema/API/E2E cần nhiệm vụ riêng;
YouTube CLI/media.mp4/production behavior giữ. Khôngsource từ prompt review này.
