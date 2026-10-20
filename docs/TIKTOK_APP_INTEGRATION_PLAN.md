# Kế hoạch tích hợp candidate TikTok vào ứng dụng WED SNAP

Ngày09/10/2026. Core đã được triển khai vào apps/media và kiểm CLI/API-worker bằng fixture trong lab riêng theo nhiệm vụ mới; TikTok vẫn tắt trên stack chính, chưa nguồn/API E2E/deploy. Workflow URL dài đã chốt≤2GETanalyze+2GETmetadataPrepare+1GETMP4. Các mục dưới giữ kế hoạch gốc; kết quả triển khai ở TIKTOK_APP_INTEGRATION_HANDOFF.md và AUDIT/PROGRESS. Kỹ thuật mẫu3 PASS vẫn không thay review toàn clip.

## Cổng trước khi bật tính năng

- Ba mẫu nguồn phải có technical PASS và human-review đầy đủ, gắn đúng SHA tệp. Evidence lab, raw pending và các FAIL trước giữ nguyên.
- Cần kiểm adapter ứng dụng và API E2E riêng. Ba mẫu tải trong lab không chứng nhận luồng shortlink/no-button qua API, mọi URL hoặc môi trường triển khai.

## Hợp đồng đang có và quyết định tích hợp

Worker tại apps/worker/src/adapter.ts gọi python3 /app/infra/media_adapter.py theo phase analyze hoặc prepare, stdin ignore; mỗi lần có ProcessGroup và deadline/workerToken riêng. Source thật của script ở apps/media/src/media_adapter.py. Candidate lab giữ metadata/cookie/URL nguồn trong cùng child chờ lệnh prepare, nên không thể dùng nguyên runner/driver lab cho hai job phase của ứng dụng.

Đề xuất giữ hai phase hiện tại:

1. Analyze dùng instance extractor mới và cookie chỉ RAM; trả title/duration/formats công khai, ID và dữ liệu cần đối chiếu. Chỉ liệt kê định dạng thật qua chính sách play/H264/audio/không-watermarked, không bịa chất lượng.
2. Prepare dùng instance mới, trích xuất lại metadata và xác minh bodyID/content/duration/format đã chọn; cookie và signed URL chỉ tồn tại trong child này. Format cũ không còn thì trả FORMAT_UNAVAILABLE, không tự đổi format hoặc downloadAddr.
3. Không giữ child analyze sống qua selectable/queued hoặc lưu cookie/signed URL vào DB/tệp. Điều đó giữ vòng đời phiên, job, worker lease và transfer lease đã nghiệm thu.

Ngân sách cần chốt tường minh khi triển khai: với URL dài, analyze tối đa2GETmetadata; prepare tối đa2GETmetadata mới+1GETMP4. Tổng workflow có thể5GET, khác một pipeline lab2+1GET. Metadata30s nằm trong prepare180s khi tái trích xuất; giới hạn ứng dụng thấp hơn phải được tôn trọng. Shortlink resolve có ngân sách riêng và kiểm SSRF/redirect riêng; không suy longURL đã kiểm là shortlink API E2E.

## Phần được tái sử dụng và phần phải nối

- Đưa phần core tối thiểu vào apps/media/src/tiktok/ theo STRUCTURE; labs/ tiếp tục là harness/evidence, không đưa runner/fixture/verifier/benchmark vào runtime sản phẩm.
- Giữ API mức cao yt-dlp, Requests/urllib3 guards, cookie RAM, bodyID Cobalt, file contract FFprobe/full FFmpeg decode, budget remaining/reserve và diagnostics đã kiểm. Không viết lại parser/solver/HTTP/decoder.
- Docker media hiện đã có Node22/Python/FFmpeg và requirements.lock cùng phiên bản Python libs. Kiểm npm dependencies tối thiểu cho Cobalt body validator theo lock, SRI và LICENSE/NOTICE/attribution; không tự nâng framework hoặc thư viện.
- Bỏ hardcoded ID mẫu và /out trong phần nối sản phẩm: ID từ URL đã xác minh, folder thuộc job do worker cấp, output media.mp4 theo hợp đồng cũ. Kiểm path ownership/symlink/preexisting và cleanup đúng job, không thay bằng phép replace đường dẫn toàn cục.
- Analyze trả dữ liệu công khai đúng schema hiện có; prepare trả file/size/inputBytes đúng schema. Giữ error-code whitelist, không expose exception hoặc URL/cookie/headers nhạy cảm.
- Giữ ProcessGroup, cancellation/expired/workerToken/poll/disk cap/confirmed group exit và CSRF/native ticket/Range/transfer lease. Không đổi lifecycle để tiện giữ phiên mạng.

## Trình tự triển khai và nghiệm thu

1. Tích hợp code với TikTok vẫn tắt ở stack chính; kiểm môi trường và seams trước sửa. Không đổi settings/main DB/Redis/.env thật.
2. Kiểm offline qua hai phase và API/worker trong lab riêng: fake nguồn nhưng extractor/downloader/file contract thật; phân biệt fixture với nguồn thật. Kiểm format selection, bodyID sai, auth/private/photo/live/deleted, watermark-only, request/redirect/byte caps, child failure/cancel/expired/cleanup và đồng thời lease.
3. Nếu cần image runtime mới, nhiệm vụ triển khai phải cho phép build; dùng pin/lock và build tuần tự trên RAM8GB. Không đọc bản kế hoạch này như quyền build/install/deploy.
4. Sau code/guards/fixture đúng hash đạt, giao một smoke API E2E nguồn có ngân sách riêng. Kiểm link dài no-button đã cho phép; shortlink cần thêm scope resolve. Đối chiếu tệp thực, native exits/SHA và review hình/tiếng/watermark; không dùng browser fixture thay backend live.
5. Chỉ khi adapter+API E2E và policy cần thiết được nghiệm thu mới xét VERIFIED_PLATFORMS/enabledPlatforms trên môi trường được giao. Tài liệu hỗ trợ nêu phạm vi, hạn chế và ngày kiểm; không cam kết mọi link.

## Bàn giao bắt buộc

Cập nhật AUDIT/PROGRESS/ADAPTERS/STRUCTURE theo phạm vi triển khai; evidence mới có before/after hashes, lệnh thực/native exits, resource measurements, fixture versus source và cleanup. Không sửa manifest/verifier lịch sử để ép PASS. Kế hoạch này không tự khởi động UI redesign hoặc deploy.
