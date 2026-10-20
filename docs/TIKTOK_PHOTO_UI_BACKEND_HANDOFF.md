# Backend ảnh TikTok → UI hướng A — 15/10/2026

**Đã đạt một ảnh canonical qua backend ứng dụng trong lab riêng; chưa browsercombined/main.** [Nghiệm thu độc lập](evidence/tiktok-photo-source-fixed-live-review-20261015/ASSESSMENT.md): một workflow/2child/5responses200, JPEGảnh2 2132×2132/322655B/SHA62308e…5a8b, probe/decode/nativeHEAD/fullGET/Range/closure/cleanup đạt. Reviewer mở **tệp mới**, không thấy watermarkTikTok và kiểmbyteidentity với ảnh2 đãhumanaccepted; không giả một humanreply mới. [Tệp mới](evidence/tiktok-photo-source-fixed-runtime-20261015/source-once/cases/source/native-image.jpg). Evidence tác giảvisualpending giữ nguyên; kết luậnreviewer bổ sung riêng. Không suy thành mọiTikToklink, shortlinkAPI, toànalbumUI hoặc UIA đã chạy backend thật.

## Bản đồ code thật

| Phần | File / trách nhiệm |
|---|---|
| Màn tải đang có | `apps/web/src/pages/Home.tsx`: đọc capability, chọn một format, prepare/newjob/cancel và nativeJPEG link |
| Public UI types và client | `apps/web/src/types.ts`, `apps/web/src/lib/api.ts`: same-origin cookie, x-csrf-token cho POST, ApiError |
| Phiên / job / tải | `apps/web/src/hooks/useSession.ts`, `useJobLifecycle.ts`, `useDownloadLink.ts`: giữ vòng đời và ticket riêng |
| API phiên / job | `apps/api/src/controllers/{session,jobs}.controller.ts`, `services/{session,jobs}.service.ts` |
| Ownership/CSRF | `apps/api/src/auth/session.ts`; validation trong `apps/api/src/validation.ts` |
| Public photo descriptors | `packages/shared/src/tiktok-photo.ts`: checkedPhotoFormats/selectedPhoto/checkedPhotoFile/assetDescriptor |
| Worker và phaseproof | `apps/worker/src/{processor,adapter}.ts`: hai CLI child riêng, ProcessGroup/proxyphasegate trước ready |
| Media / egress | `apps/media/src/tiktok/{photo_adapter,photo_core,photo_contract,photo_proxy}.py`; `apps/egress/src/tiktok_policy/` |
| Native transfer | `apps/api/src/services/downloads.service.ts`, `controllers/downloads.controller.ts`: JPEG/MP4 MIME/name/Range/lease |

## API và dữ liệu UI dùng

Tất cả đường dưới có prefix `/api/v1`; dùng client/hook sẵn, không tạo downloader/extractor trong browser.

| Thao tác | Contract từ code |
|---|---|
| `GET /session` | Cookie phiên HttpOnly `ws_session`; JSON `csrf`, `supported`, `verified`, `contact`, `productName`, `heartbeatSeconds`, `capabilities.tiktokPhoto` |
| `POST /jobs/analyze` | `{url}` →202 `{jobId}`; UI chờ job, không chuẩn bị/tải ảnh trước chọn |
| `GET /jobs/:id` | `id,state,errorCode,title,duration,metadataAcceptedAt,metadataExpiresAt,items,previewUrl,mode,serverMeaning` |
| `POST /jobs/:id/prepare` | `{itemId,formatId,idempotencyKey}` →202 `{jobId,state}`; idempotencyKey UUID mới cho job mới, giữ khi cùng prepare đang chờ |
| `POST /jobs/:id/heartbeat` | Gia hạn owner job, không biến thành transferlease; response `{ok:true}` |
| `POST /jobs/:id/release` | Đặt releaseGrace; hookpagehide gửi beaconbody `{csrf}`, không đồng nghĩa cancel đangtransfer |
| `POST /jobs/:id/cancel` | Đánh cancelled/cancelRequested; lỗi/expired xử lý qua errorcode, không épUIready |
| `POST /jobs/:id/download-ticket` | Chỉ ready/assetavailable/ownership hợp lệ; `{url,expiresIn}`. URLticket chỉ dùng trong phiên, không log/chia sẻ/lưu lâu |
| `GET /downloads/:ticket` | Nativeattachment `image/jpeg`, `wed-snap-image.jpg`; HEAD và Range được server xử lý. Nút dùng `<a>` theo useDownloadLink, không fetchJPEGtoBlob để thay luồng native |

Jobphoto có **một `items[]` phần tử** `kind:'photo'`; `item.id` là UUID ứng dụng, không số thứ tự ảnh. `item.formats[]` là lựa chọn ảnh: `id,label,size:null,kind:'photo',contentId,imageCount,index,width,height,itemKey,mime:'image/jpeg',snapshotKey`. UI hiển thị label/index/dimensions nếu có, gửi nguyên `item.id`/`format.id`; không tự tạo ID, itemKey, snapshot hoặc phụ thuộc cấu trúc formatId. UI types hiện chỉ khai báo subset cần hiển thị; sharedvalidator mới là hợp đồng đầy đủ.

`snapshotKey` ràng buộc cấu trúc/count/thứ tự/dimensions, **không hashpixels**. Preparefreshmetadata/bodyID/selection được backend kiểm lại; khác thì FORMAT_UNAVAILABLE/failed, không chọn ảnh khác ngầm. Albumtitle public `'Album TikTok'`, durationnull, previewUrlnull cho ảnh; không thumbnail/CDNURLpublic để UI tự tải. Canonical HTTPS `@author/photo/id` được kiểm chặt; nguồn ngắn và galleryall/ZIP/audio chưa là contract đã nghiệm thu. Một ảnh/job: muốn ảnh khác sauprepare cần phân tích lại job mới, không đổi format của job đã chuẩn bị.

`session.capabilities?.tiktokPhoto === true` mới mở chọn ảnh; thiếu/false giữ khóa. Đây là capability cấu hình, không quyềnnguồn mới hoặc bằng chứng mọi link tải được. Các flags/verifiedplatform/settings/egresscontrol bên server vẫn cần đồng bộ; UI không tự bật hoặc sửa chúng. Không chép cookie/signedCDNURL/privatephaseproof vào state lưu lâu, localStorage, DB hoặc log.

## Vòng đời và trải nghiệm giữ nguyên

Giữ idle/analyzing/selectable/queued/preparing/ready/failed/cancelled/expired. Job thuộc phiêncookie; mọi write cần Origin hợp lệ và CSRF (header qua api(), bodycsrf riêng cho beacon). useJobLifecycle poll2s/heartbeat15s, chống callbackjobcũ, releasepagehide và khôi phục heartbeat khi trở lại; đừng viết lại để phục vụ bố cục. useDownloadLink chỉ mintticket khi ready, chặn ticketjobcũ; “tạo lại liên kết tải” là ticketAPI, không tự gọi prepare/analyze nguồn lại. Mỗi liên kết GET tạo transferlease độc lập; HEAD không tạo lease. Click/native server_finished **không chứng minh thiết bị đã lưu tệp**.

SESSION_REQUIRED/CSRF_INVALID (403 theo authcode) xử lý qua clientcode; `isMissingJob()` chỉ 404JOB_NOT_FOUND/410JOB_EXPIRED mới an toàn bỏ job cũ. FORMAT_UNAVAILABLE, SOURCE_TIMEOUT, CONTENT_UNAVAILABLE, LIMIT_EXCEEDED, RATE_LIMITED, QUEUE_FULL và failed/cancelled/expired hiển thị errorCode có mapping; không auto-retry nguồn/fallback hoặc giữ CTA tải của job trước. Giữ text/logo vốn có trong ảnh; không crop/blur/transcode để xóa watermark. Không dùng lời hứa “mọi link/không watermark” trênUI từ mộtmẫu đạt.

## Code ứng dụng và phần còn ở lab

PublicphotoAPI/validator/media/worker/nativeJPEG và Homehooks đã có trong `apps/`/shared; mainflags/settings vẫn tắt. Lượt nguồn đạt dùng **labconsumer/orchestrator** gọi productionprocessor/core và pinnedmounts, không fullmainstack đãdeploy. DNSchildenvsource/vendor, diagnosticsP2 và entrywiring nằm ở `labs/tiktok/photo-dns-child-offline/common/`, `photo-dns-diagnostics-fix/`, `photo-source-fixed/`; **chưa main-apply**. Runtime800MiB/SSRF/TLS/DNS256raw→64unique/twochildphaseproof/ownership được kiểm trong lab, không tự biếnmain thành cấu hìnhđãđạt.

Trước browsercombined: giao phạm vi tích hợp UIA vào apps/web riêng, reuse đúng hook/contract; kiểm offline bằng fixture/currentUI đã có cho chọnảnh/state/cancel/expired/nativeJPEG, không dựng harness mới hoặc gọi nguồn. Nếu cần backend thật trong labcombined, phải chọn rõ cache/sourceoverlay đãreview và giữ defaultoff/guards; việc chuyển DNSenv/diagnostics/wiring ra recipe vận hành là delta riêng cần review, không giải quyết bằng cách bậtflagmain. Mainactivation/deploy hoặc nguồn mới cần nhiệm vụ riêng; lượt5requests vừa dùng đã kết thúc.

## Đề bài tiếp theo ngắn cho chat UI, chưa thực hiện ở lượt này

> Tích hợp hướng A Studio sáng đãchủchọn từ `design/ui-redesign-v1/` vào apps/web trong nhiệm vụ UI riêng. Đọc TasteSkill/AGENTS và handoff này; reuse Home/useSession/useJobLifecycle/useDownloadLink/api/types hiện có, giữ CSRF/session/job/lease và toàn bộstate. Mànphoto chọn mộtformat từresponse, không thumbnailURL/ZIP/allalbum; nativeJPEGlink đúng MIME/name, capabilityfalse khóa. Dùng fixtures/browserchecks hiện có để kiểm offline trạng thái/keyboard/mobile/cancel-expired/latecallback và cả videoYouTube cũ; chỉ kiểm delta cần thiết, không dựngharness/schema/backend mới. Khôngnguồn/Dockerbackendcombined/mainflags/settings/API/schema/deps/deploy trong nhiệm vụ UI nếu chưa được giao riêng. Bàn giao diff+ảnh+scope/giới hạn và review trước mainapply.

Hướng A thuộc chat **Giao diện WED SNAP**; lượt này chỉ viết tài liệu, **không gửi chat khác**, sửaUI/code/test hoặc tạo tác vụ mới. [Prompt bàn giao](evidence/tiktok-photo-ui-backend-handoff-20261015/NEXT_PROMPT.md). Các mốc09/10 trong ADAPTERS/STRUCTURE là lịch sử, không kết luận hiện tại ảnh chưa cósource nữa.
