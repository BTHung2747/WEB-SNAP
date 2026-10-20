# F-STAGE-ORIGIN và candidate challenge — 08/10/2026

**F-STAGE-ORIGIN đã sửa và kiểm offline. Candidate yt-dlp mức cao đã triển khai, native challenge chỉ chạy trên fixture. Lượt này có 0 request TikTok thật và 0 lượt tải tệp.** Không nghiệm thu metadata nguồn, file, watermark, ba mẫu hoặc no-button API E2E; không bật main/deploy.

## 1. Observer đúng request/origin/socket

Trước sửa đọc AGENTS, PLAN/STRUCTURE, nghiệm thu độc lập mới nhất, PROGRESS và STAGES_HANDOFF. Finding chỉ ra cờ TLS/CONNECT/failure cũ bị dùng cho request chuyển origin; kết quả một GET lịch sử vẫn hợp lệ, không bị xóa hoặc hồi tố.

src/stages.mjs chuyển sang schema lab2, với requestId, originId và connectionId mờ. Mỗi hop có trạng thái đọc/gửi/lỗi riêng; origin giữ thông tin socket sẵn có, socket giữ lifecycle và số lần dùng. Không reset mọi cờ tùy ý. TLS sẵn trong pool được ghi là availability, chưa phải TLS của request hiện tại; khi Undici gửi header bằng đúng socket, observer xác nhận connectionId/reuse. Socket đã được CONNECT giao cho tunnel không coi là còn rảnh để mở CONNECT mới. Callback muộn của request cũ cập nhật đúng hop cũ, không đổi lỗi của hop mới.

Dùng [Agent.factory](https://github.com/nodejs/undici/blob/v6.24.1/docs/docs/api/Agent.md), [Connector callback](https://github.com/nodejs/undici/blob/v6.24.1/docs/docs/api/Connector.md), [DiagnosticsChannel](https://github.com/nodejs/undici/blob/v6.24.1/docs/docs/api/DiagnosticsChannel.md) của Undici6.24.1; các wrapper chỉ gọi connector/Pool gốc với options/kết quả nguyên bản. Không patch internals hoặc thay proxy/TLS. Request/origin/socket cap16/16/32, event128, chỉ ID/role/time/status/code/boolean; URL/header/cookie/socket thô không xuất log. Kết nối không gán chắc được thì không đoán theo hostname.

Fixture network-none dùng HTTPS/proxy loopback:

- Redirect khác origin: r1/o1/c2 và r2/o2/c4, không nhận reuse hoặc TLS của origin cũ.
- Request cùng origin: r2 dùng chính c2, connectionReused=true và TLS đã đo được giữ đúng.
- Request2 ở origin khác nhận CONNECT200 nhưng TLS chưa xong: originTLSReady=false, failureStage=WAITING_ORIGIN_TLS.
- Request3 trở lại origin đầu dùng c2, không kế thừa failureStage của request2.

Tất cả qua kiểm mới. Không gọi nguồn để kiểm finding. EgressDNS so với TCP nguồn, remote receipt và first wire byte vẫn không quan sát riêng được như bàn giao trước.

## 2. API challenge và phần tự nối

Đối chiếu [yt-dlp2026.08.19 embedding](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/README.md#embedding-yt-dlp), [YoutubeDL API](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/YoutubeDL.py), [TikTok extractor](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/extractor/tiktok.py). Luồng web của version này đọc rehydration; khi thiếu, extractor thực hiện challenge native, tạo cookie ngắn hạn trong CookieJar, lấy lại webpage một lần rồi xóa cookie challenge. Vòng tìm digest nằm trong thư viện đã ghim, tối đa1.000.001 bước, thêm giới hạn OS30s ở lab. Không chép helper private hoặc tự viết solver.

Candidate mới ở yt_candidate.py gọi **YoutubeDL.extract_info(download=False, ie_key='TikTok', process=False)**; parser/challenge/normalizer chạy trong thư viện. Không chạy Cobalt rồi fallback thêm một analyze yt-dlp. Cobalt parser được tái dùng trên body cuối trong RAM để xác minh itemStruct.id, duration, private/photo: API TikTok của yt-dlp trả id lấy từ URL, nên so id của info một mình chưa đủ. validate_cobalt_body.mjs dùng resolver đã ghim với fetch chỉ trả body RAM, không HTTP; chỉ ID/duration/boolean được trả qua pipe, tối đa2s. Không viết parser khác, không lưu HTML/URL nguồn.

Chỉ phần HTTP guard còn thiếu được nối bằng [Requests2.34.2 HTTPAdapter.send](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py), prepare_request và [urllib3-2.8.0 decoded read](https://github.com/urllib3/urllib3/blob/2.8.0/src/urllib3/response.py). Lý do cụ thể:

- Backend yt-dlp mặc định có thể tự theo redirect bên trong một urlopen, nên đếm urlopen chưa đủ đếm từng request.
- Session.request(allow_redirects=False) vẫn chuẩn bị response.next qua resolve_redirects và có thể tiêu thụ body redirect trước khi trả. Candidate dùng Adapter.send công khai, stream/preloadfalse và redirectfalse của backend, chặn3xx trước đọc body/theo hop.
- Bounded reader đọc giải nén mỗi lần≤16KiB/remaining+1, clamp trước concat/parse; kiểm8MiBresponse16MiBtotal khi đọc. urllib3/Brotli1.2.0 có cơ chế output_buffer_limit đã đối chiếu và kiểm fixture thật8MiB.

Bridge không triển khai HTTP/TLS/cookie parser: thư viện Requests/urllib3 làm transport và CookieJar; proxy cố định own-egress, verifyTrue, trust_envFalse, retry0. CookieJar cùng instance yt-dlp/Session, không cookiefile/cookiesfrombrowser/netrc/account, chỉ cookie nguồn/challenge RAM và domain scope. Cookie tạo/xóa bởi extractor được fixture xác nhận; close xóa jar.

**Profile candidate được khai báo:** Requests mặc định, TLS xác minh, không browser impersonation. Extractor có thể yêu cầu impersonate; bridge ghi actualImpersonation=false, không giả là curl_cffi/Chrome. Đây là candidate mới có guard, khác transport/header của Cobalt Undici; chưa chứng minh đủ trên nguồn thật, không đổi cipher/proxy tùy đoán. Không dependency/image mới.

## 3. Lựa chọn play và lifecycle candidate

Input là long author URL mẫu1 đã giao, expectedID7692808825228807442; chỉ TikTokIE, không app_info/device/account/API fallback. Bridge chỉ cho GET đúng URL metadata; reject nguồn khác/method khác trước gửi. Metadata native được body-parser Cobalt xác nhận ID/loại nội dung/duration, rồi chọn format đã normalizer xử lý: play hoặc h264 bitrate ID, MP4/H264/audio, HTTPS443, không DRM/manifest/fragments/download/watermarked source. Không tạo chất lượng hoặc fallback downloadAddr.

Candidate giữ info/selected URL/CookieJar trong **cùng worker RAM**. Khi parent gửi prepare, worker gọi process_ie_result trên info chỉ còn một format, cùng ydl/session, không re-extract. Parent yt_candidate_driver.py quản lý hai deadline OS độc lập với CPU solver/child I/O, protocol công khai≤8KiB; metadataFAIL thì dừng. Prepare có budget HTTP riêng, ffprobe10s/decode30s/SHA nằm trong deadline180s; không crop/blur/transcode/logo removal. Kết quả file vẫn NEEDS_VISUAL_REVIEW. Cleanup chỉ tên tệp fixed mới trong owned/out; không xóa tệp tồn tại trước.

**Phần chưa kiểm thực:** prepare/code tải có sẵn, nhưng lượt này không có MP4 nên chưa kiểm native download/CDN, ffprobe, decode, SHAfile, hình/tiếng/watermark. Output/input/download guards cần được đối chiếu trên lần tải thực được giao sau; metadata fixture không chứng nhận file. Parser Cobalt xác minh body khá chặt về tag/schema, nếu không parse được thì fail closed, không tự viết parser để đoán.

## 4. Kiểm offline và actual exits

Image giữ sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6; yt-dlp2026.08.19/moduleSHA3257fdea…c9e, Requests2.34.2, urllib3-2.8.0, Brotli1.2.0. Runtime fingerprint mở rộng thêm libraries đã cài, không install/upgrade: **35hostfiles/27sourcefiles/1.364dependency-binary files**. FinalinventorySHA021aa6fc60408a1506992fc6ff748dae6a233c1ae032013042e53874b23e80d3.

Bốn lượt offline tuần tự network-none/256MiB cùng guard, mỗi lượt native/container/runner0 và dọn đúng1container/0network. Raw không ghi đè; snapshots phần mã đổi sau các lượt đầu được giữ.

| Lượt | Kết quả thực |
|---|---|
| Offline1 | F-STAGE-ORIGIN redirect/reuse/pre-TLS-failure/third-reset PASS;9Nodecases+stage cases/caps/hash/redaction/watchdog PASS. |
| Offline2 | Candidate highAPI/nativechallenge và guard fixtures PASS; sau đó tinh chỉnh deadline test/cleanup. |
| Offline3 | Parent deadlinemetadata/prepare fake150ms cắt childCPU bằngSIGKILL; source-disabled guard/byte caps PASS. |
| Offline4 final | Tất cả trên đúng bản mã cuối PASS; thêm body ID sai bị Cobalt parser chặn. Native busyNodeOS30s quan sát30,086839s/child−9, không ghi thành chính xác30,000s. |

Candidate14cases: nativechallenge/refetch, unsupported/repeatedchallenge, redirect, download-only, wrong-body-id, chặnrequest3 trướcsend, deadline sauadapterblocking, Brotli8MiB+aggregate16MiB thực, source-disabled, parentmetadata-only và hai deadline parent. Fake challenge cookie được **extractor native thật** tạo, kiểm chỉ trong RAM rồi xóa; metadataFIXTURE_PASS/2requests/playselected, cookiefilefalse, fileNOT_RUN. Không gọi helper solver private trực tiếp.

Offline4 native attach UTC08/10 **05:00:58.109–05:01:37.751**, VN **12:00:58.109–12:01:37.751**, exit0; cleanupUTC05:01:38.904/VN12:01:38.904. Parent deadline fixture150ms không thay production constants30/180s. Tổng4offlinecontainers dọn0left; không egress/network lab nào được start.

## 5. Phương án thử nguồn cụ thể — chưa thực thi

Lượt mới phải được giao riêng. Runner hiện từ chối Stage live trước Docker/source; driver mặc định SOURCE_DISABLED. Không bỏ gate/hash hoặc dùng PASS của snapshot cũ. Khi được giao, tạo đúng own lab resolver512MiB+egress96MiB=608MiB≤1GiB, user1000/65534, source/rootfsRO/outputownedRW/privateIPC/capdropALL/no-new-privileges/defaultseccomp/noports/SSRF/TLS như cũ, kiểm actual image/mount/command/labels/limits. Chốt backend candidate trực tiếp và kiểm offline lại đúng code khi wiring runner/Compose.

Ngân sách **một analyze**, source HTTP tối đa:

1. GET longURL mẫu1 một lần.
2. Chỉ nếu extractor nhận challenge native hỗ trợ: một GET lại cùng URL bằng cookie RAM. Tổngmetadata≤2GET, redirect0/HEAD0/thumbnail-subtitle0/retry0,8MiBresponse16MiBaggregate,30s OS.
3. Chỉ sau metadata đủ ID/body/duration/format: một GET MP4 selected, redirect0/retry0/fallback0, prepare180s/input250MiB/output200MiB. TổngsourceHTTP≤3; CONNECT proxy là tunnel traffic riêng, không là analyze bổ sung.

Lệnh worker/driver đã có, chỉ chạy **trong container đã Guard** khi nhiệm vụ nguồn mới cho phép:

~~~text
python3 /lab/src/yt_candidate_driver.py https://www.tiktok.com/@nxheitd.vln/video/7692808825228807442 7692808825228807442 --allow-network --prepare
~~~

Đây là lệnh đề xuất tương lai, **chưa chạy trong phiên này**, không phải lệnh run.ps1 live đang hoạt động. Không dựng lượt Cobalt trước rồi tựfallback để vượt2GET. Nếu muốn metadata-only thì bỏ prepare, vẫn tính cùng analyze và không gọi lại sau đó để “thử vận may”.

Đạt metadata: bodyID thật khớp, không private/photo, duration≤600, sourceplay đượcpolicychấp nhận. Dừng ngay nếu timeout/redirect/HTTP/byte/request/ID/schema/challenge vẫn thiếu JSON hoặc không có play; không request3 metadata, không mẫu2/3. Nếu prepare thất bạiCDN/codec/audio/duration/size/decode thì dừng và cleanupownpartial. File đạt mới xem tệp thật/toàn clip, kiểm tiếng và watermark TikTok, giữ logo tác giả. Một file chưa nghiệmthu3mẫu/no-buttonAPI E2E/TikTokmain hoặc mọiURL.

## 6. Lệnh đã chạy và preservation

~~~powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 2
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 3
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 4
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_origin_challenge.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_origin_challenge.ps1
~~~

Chứng chỉ mới chỉ cho localhost/alt.localhost fixture được tạo bằng .NET, dùng keyfixture cũ; không trustWindows hoặc liveCA. Không rebuild/install. Evidence riêng docs/evidence/tiktok-cobalt-origin-challenge-20261008/ có nativeUTC-VN/actualexits/guards/pins/origin-candidate-fixtures/APIdecision/plan/snapshots/baseline/successor/manifest. Baseline2.120file, chỉ7lab+AUDIT/PROGRESS cũ đổi; các file mới thuộclab/handoff/evidence. Predecessor96artifact qua doc-onlyAUDIT/PROGRESS successor của audit độc lập,94artifact còn lại khớpbaseline. Raw/golden/verifier/manifests/handoff/history/archive cũ giữ; không sửa golden épPASS hoặc chạy lại history.

Production/YouTube/API/UI/DB/lifecycle không sửa. Source0/download0/realmetadata-file-watermarkNOT_RUN; TikTokP0 vẫn0/3, khôngmainapply/deploy.
