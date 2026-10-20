# Bàn giao bước2 tải từng JPEG — 15/10/2026

**PASS_OFFLINE_PHOTO_APP_STEP2_PENDING_REVIEW_DEFAULT_OFF**. Đã nối CLI→runAdapter→worker→API bằng core ảnh bước1 đã nghiệm thu. Một ảnh/job, hai child độc lập, prepare lấy metadata mới; chưa bật main, sửa UI/egress hoặc gọi TikTok/CDN. Mẫu5ảnh nguồn/human trước giữ trạng thái accepted, không phải bằng chứng nguồn mới của bước2.

## Mã thay đổi và thư viện

Năm file cũ được sửa: `apps/media/src/media_adapter.py`, `apps/worker/src/adapter.ts`, `processor.ts`, `apps/api/src/services/jobs.service.ts`, `downloads.service.ts`. Hai file mới: `apps/media/src/tiktok/photo_adapter.py`, `packages/shared/src/tiktok-photo.ts`. [Before/diff/source cuối](evidence/tiktok-photo-app-step2-20261015/). Không sửa bốn module core ảnh, vendor/NOTICE/LICENSE/PROVENANCE, engine video, YouTube, schema/migrations, locks, web, egress, main Compose/env/settings. Lab mới ở `labs/tiktok/photo-app-step2`; fixture không nằm trong runtime.

CLI photo yêu cầu `TIKTOK_PHOTO_ENABLED=1`, `TIKTOK_ADAPTER_ENABLED=1` và `VERIFIED_PLATFORMS` có tiktok. Thiếu/sai/0 bị từ chối trước core/network; flag mới mặc định tắt. API/worker còn yêu cầu platform trong limits đã lọc verified. Worker và runAdapter kiểm lại trước spawn; queued work không tự vượt cờ đã tắt. Chỉ canonical `/@author/photo/{id}`, không shortlink/fallback. Nhánh video/YouTube giữ bộ trích xuất cũ.

Dùng core Cobalt/yt-dlp/Requests/Operations/FFmpeg hiện có. Zod3.25.76 `.strict()`/`safeParse`/integer.safe và Node crypto chỉ kiểm/public-project descriptor WED SNAP, không parser/solver/transport mới. Express5.2.1/setHeader/pipeline cho native file transfer; Prisma6.19.0/transaction và BullMQ5.81.5 đã có. [Đối chiếu API/pins](evidence/tiktok-photo-app-step2-20261015/API_REFERENCES.md), [package và API capability thực](evidence/tiktok-photo-app-step2-20261015/api-3/node-capability.json). Không install/build/pull dependency hoặc image. Prisma generate từ dependency cache và migrate deploy **chỉ vào DB fixture mới** bằng migrations cũ; không thay schema hoặc dữ liệu main.

Shared validator kiểm strict summary/formats/kind/title/duration-null/public keys, tái tính itemKey/snapshot bằng canonical JSON giống Python, count/index/dimensions/format72ký tự và label. Không spread private packet vào DB; MediaItem.kind=photo và formats chỉ allowlist. Snapshot chỉ ràng buộc cấu trúc, không chứng minh pixel identity. Prepare chỉ nhận formatId qua shape cũ; server descriptor không do client thay. Worker so selection lưu trước/sau, public contract/index/itemKey/dimensions/input/size/SHA; mở fixed image.jpg bằng O_NOFOLLOW và đọc lại SHA trước ready. Staging path do server chọn; không thay available asset/tệp ticket cũ. Chọn ảnh khác cần job mới.

Analyze/prepare hai child/session riêng, cookies/body/signed URL chỉ RAM và dọn khi đóng. Parent chờ native exit0 và group đóng; log thêm actualExit/actualSignal số/tên quan sát được. Packet PASS rồi exit20 hoặc SIGKILL không được ready. OS watchdog/cancel/process guards/live registry/quarantine giữ; không xác minh đóng group được thì giữ token/lease/file, không dọn liều. Tài liệu test phân biệt fault injection observer với lỗi OS thật.

API giữ ownership/CSRF/admission/quota/metadataTTL/idempotency/heartbeat và native ticket/lease/month accounting. Không preview URL giả cho photo. MIME/filename từ server kind + strict formats + fixed path: image.jpg→image/jpeg/attachment wed-snap-image.jpg; video media.mp4→video/mp4/wed-snap-video.mp4. Unknown/mismatch fail-closed. HEAD ảnh kiểm owned local file/size, không gọi nguồn hoặc tạo transfer lease; GET/Range dùng lock order job→asset→budget và transfer lease cũ. Không đổi tệp dưới lease đang tải.

## Ngân sách và môi trường thực

Photo clamp theo app nếu chặt hơn: metadata≤30s/2GET/8MiB response/16MiB decoded tổng; prepare≤180s, fresh≤2GET metadata rồi conditional≤1JPEGGET, redirect/retry/HEAD nguồn0; input≤36MiB/output≤16MiB, JPEG response≤20MiB, item≤60s và prepareEnd−10s; HTTPconnect≤10/read≤20. Core budget/file validator nguyênhash, không thay timeout. Workflow dài≤2+2+1GET, không giữ child qua selectable. Giới hạn đọc/HTTP/cookie do core đã kiểm; parent OS deadline độc lập vẫn enforce qua runAdapter.

Image cache cố định **sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e**. Thực đo Python3.11.2, Node22.22.3, yt-dlp2026.8.19, Requests2.34.2, urllib3-2.8.0, brotli1.2.0, FFmpeg5.1.9-0+deb12u1. Mounted source69file hash trước/sau; thư viện Cobalt/node_modules lấy nguyên từ cache. Không gọi source hoặc DNS ngoài; adapter fake kiểm proxy/TLS forwarding, không là real handshake/SSRF test.

CLI/typecheck networknone. API fixture mạng internal riêng, không publish cổng: app+API+worker+media **chung container512MiB/CPU0,75**, Postgres128MiB/CPU0,25 + Redis64MiB/CPU0,25; tổng memory704MiB. Không nói từng tiến trình đều có cgroup riêng512MiB. Nonroot/rootfsRO/privateIPC/capdropALL/NNP/no extra swap; tmpfs/data/media riêng, không volume main. Typecheck heap riêng256MiB vẫn trong container512MiB; runtime Node heap128MiB/process. Máy8GB chạy tuần tự. Không đo peakRSS; state cuối noOOM. Own IDs/nonces/guard/cleanup lưu từng lượt, không prune hay đổi tài nguyên cũ.

## Lệnh thực và kết quả

Lệnh PowerShell chung: `& 'D:\WED SNAP\labs\tiktok\photo-app-step2\run.ps1' -Mode <mode> -Attempt <n>`. Các lượt giữ riêng, không ghi đè:

| Lượt | Kết quả thực |
|---|---|
| typecheck-1 | Docker pipe bị sandbox từ chối trước create; chưa test chức năng; raw giữ |
| typecheck-2 | Container exit250: Node tsc heap128MiB hết heap (native abort), không phải cgroup OOM; raw và cleanup giữ |
| typecheck-3 | Exit2, TS báo match có thể null; sửa guard rõ ràng, không đổi policy |
| typecheck-4 | Exit0/noOOM, source cuối69file; tsc bằng heap256MiB trong cùng cap512MiB |
| cli-1 | Exit0,8ca; media source cuối nhưng trước delta log adapter.ts; không dùng nó thay gate cuối |
| api-1 | Lỗi tham số tên network trong runner, Docker chưa tạo resource; sửa runner, giữ raw |
| api-2 | Exit0/24nhóm ca trung gian. Ca prepare PASS→exit20/hang **chưa đủ bằng chứng**: core hết reserve trước PASS. Không công nhận hai ca đó từ lượt này |
| api-3 | Exit0/noOOM, **26nhóm ca** trên runtime cuối, assertions xác nhận core đã PASS trước fault; metadata/prepare exit20 thực, hang SIGKILL thực; cleanup/quarantine đạt |
| api-extra-1 | Exit0/noOOM; hai job riêng chọn ảnh1 rồi2 qua CLI/worker/API, đổi ảnh trên job cũ409; giữ hai JPEG thực đọc qua HTTP và operation logs |
| cli-2 | Gate CLI cuối8ca, source runtime cùng69hash với typecheck-4/api-3/api-extra-1 |

Api-3 test UTC04:23:07–04:25:04 (VN11:23:07–11:25:04) ngày15/10. Các lượt khác lấy UTC/VN và actual exits từ native/completion, không suy thời gian từ fixture. [26ca](evidence/tiktok-photo-app-step2-20261015/api-3/api-result.json), [cờ API tắt trước queue](evidence/tiktok-photo-app-step2-20261015/api-3/flags-api-result.json), [hai job](evidence/tiktok-photo-app-step2-20261015/api-extra-1/new-job-result.json).

Bao phủ: hai child thật khác PID/PGID, native0/0, fresh2+2metadata+1JPEGGET, session/cookie/response đóng; chọn ảnh2, body/count/snapshot/index/stored descriptor/client extra key sai; unknown packet path/size/contract/kind/private key; app cap nhỏ hơn; HEAD/GET/Range bytes và MIME/SHA, HEAD không lease; session khác/CSRF/idempotency/TTL-heartbeat; active lease bảo toàn qua sweep; packet PASS→20/hang/cancel/expired/deadline và group cleanup; observer-fault quarantine giữ token/file rồi dọn sau physical closure được kiểm. Video TikTok qua HTTP fixture cũ; YouTube extractor/download fixture cũ, cùng production CLI/probe/API/Range: đây là hồi quy glue hẹp, không nguồn thật.

Quarantine là **tiêm lỗi method public ProcessGroup.members trong test**, không tuyên bố host đã có lỗi identity. Hai job source giả có ảnh giống pixel chủ ý; index/format/job khác và mỗi prepare fresh đúng budget. [JPEG1](evidence/tiktok-photo-app-step2-20261015/api-extra-1/prepared-image-1.jpg), [JPEG2](evidence/tiktok-photo-app-step2-20261015/api-extra-1/prepared-image-2.jpg) đều248byte/SHA **45cea83ba1889b4f948c9fca05932a47ff2bb92723dd8fa798fcf14149c51e00**, JPEG64²/2ffprobe0/full decode0/hash thật. Đây là ảnh tổng hợp, không watermark/visual PASS mới và không cần chủ review lại.

## Bước tiếp và giới hạn

[Prompt kiểm độc lập](evidence/tiktok-photo-app-step2-20261015/NEXT_PROMPT.md). Xem before/diff, actual native/state, per-job redacted events và source gate, không chỉ đọc packet PASS. Các manifest/golden/source/human/claims cũ giữ; docs prepend theo receipt nối dispatch2→audit1→implementation1 và toàn chain tới source golden. Không chạy verifier lịch sử trên live source đã được giao đổi rồi sửa golden.

Chưa egress parity DNSv4/HE/registry bước3, UI bước4, shortlink/nguồn/API E2E thật bước5 hoặc mọi URL. TIKTOK_PHOTO_ENABLED vẫn không được bật trên main. Dừng ở bàn giao bước2 để review, không tự làm bước3/4/5, nguồn/cold/claim/reset/renew/retry hoặc deploy.
