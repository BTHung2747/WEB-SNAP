# Candidate wired lab, mẫu1 — 08/10/2026

**Đã nối candidate vào runner/Compose, kiểm toàn luồng offline và tải được một MP4 nguồn thật. Metadata và file contract PASS với parent/worker exit0. Trạng thái cuối vẫn NEEDS_VISUAL_REVIEW.** Chưa hoàn tất nghe bằng cảm nhận/xem liên tục toàn clip và kiểm watermark đầy đủ; không thử mẫu2/3, không nghiệm thu ba mẫu/no-button API E2E/TikTokmain/deploy.

## Nối và kiểm đúng bản mã

Đọc AGENTS/PLAN/STRUCTURE, nghiệm thu candidate exit/file mới nhất, PROGRESS/handoff trước sửa. Giữ image cache5fcc01bb…0fb3f3a6 và own-egress8bc0a567…7f10; không build/install/dependency/production thay đổi.

run.ps1 và compose.yaml chỉ lab: command chuyển sang candidate_entry.py, expectedID cố định mẫu1, reject sample khác. Live chỉ mở bằng receipt offline của đúng hash source/config/lock/image và native0, cộng integration-result đã đi qua parent/worker0, metadataAccepted và file contract. Entry kiểm lại inventory thực bên trong container trước source, reservation exclusive, không re-use directory. Scope guard giữ user1000/65534, rootfs/sourceRO/outputownRW/privateIPC/PID/defaultseccomp/capdropALL/no-new-privileges/noports, memoryswap/CPU/PIDs và exact mounts/command/entrypoint/labels/networks. Source runtime512+96=608MiB, không rộng hơn.

Fixture mới cung cấp challenge/metadata và bytes MP4 lavfi bằng fake Requests adapter trong network-none. Nó không mock extractor, solver native, downloader, parent hoặc file inspector: high extract_info → bodyID Cobalt RAM → process_ie_result/nativeHTTPFD → parent wait/exit → MP4/duration/decode/SHA đều chạy thật. Đối chiếu [API yt-dlp2026.08.19](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/YoutubeDL.py), [HttpFD](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/downloader/http.py).

Hai offline đầu exit1 giữ raw: metadata fixturePASS, prepare AttributeError trướcGETMP4. Stack đã lọc xác định outtmpl bị thay thành string sau khi constructor yt-dlp chuẩn hóa nó thành mapping. Progress_hooks cũng không nên chỉ sửa params sau init. Sửa tối thiểu: static format/outtmpl/external_downloader/overwrites vào constructor; đăng ký guard qua public add_progress_hook. Không sửa parser/solver hoặc nới limit. Fixture debug chỉ xuất tên thuộc tính/file/function/line, không message/header/body/URL; không bật trên nguồn.

Offline3 cuối exit0: metadata2GET giả/challenge-cookie RAM → prepare1GET giả, MP4/isom/H264+AAC2s,26531byte; source-input SHA và output SHA bằng nhau4f0e867b…c7b3, không transcode tệp. Worker/parent0, FILE_NEEDS_VISUAL_REVIEW là state thật nhưng đây vẫn là fixture. Các case exit/file/origin/caps/deadline liên quan cùng đạt; busyNodeOS30s quan sát30,035818s/child−9 có overhead. UTC06:02:48.767–06:03:32.750/VN13:02:48.767–13:03:32.750 ngày08/10. Ba container offline dọn0left, nativeexits1/1/0 đều giữ.

Fingerprint cuối **40hostfiles/32sourcefiles/1364dependency-binary files**, runtimeSHAf97eecb405cd2706a8c35e98880f580f2fd2da610e8ea38b72b9ecb6063c73f8, khớp offline/live thực. All deps/image/production giữ.

## Một analyze nguồn và một tệp

Input long author URL đã giao, ID7692808825228807442, không truy cập shortlink. Backend là candidate high-level yt-dlp/Requests.HTTPAdapter default verifiedTLS/no impersonation; không fallback sang Cobalt live/browser/backend khác.

- Metadata:2GET, mỗi status200, giải nén lần đầu1462byte rồi426255byte, tổng427717≤16MiB và từng response≤8MiB. Native extractor xử lý challenge/cookie RAM, body cuối được parser Cobalt xác minh ID/loại/duration, không thêmHTTP. Metadata27s, selected h264_540p_708653/play-bitrate, MP4/H264/AAC576×1024, không downloadAddrwatermarked. Parent metadata1,758990s<30.
- Prepare:1GETMP4/status200, redirect0/retry0/fallback0, input2398348byte≤250MiB, output2398348≤200MiB. Prepare3,147257s<180 gồm tải/probe/decode/hash; cùng worker giữ CookieJar RAM theo domain, không file/account cookies.
- Parent/worker/container/runner/outer **exit0**, metadataAcceptedtrue và runtimeHashGatePASS; không suy success từ packetPASS riêng. Native attach UTC08/10 **06:06:52.404–06:06:59.004**, VN **13:06:52.404–13:06:59.004**. Dọn own2containers/2networks,0left lúcUTC06:07:02.779/VN13:07:02.779.

Tệp nguồn sample-1/video.mp4:

| Kiểm thật | Kết quả |
|---|---|
| Container |MP4 ISO-BMFF, majorbrandisom|
| Hình/tiếng |H264576×1024, AAC; cả hai qua decode|
| Duration |format27,075s/video27,066667s/audio27,073991s; metadata27, tol0,75s|
| Bytes |2398348|
| SHA256 |14a8ed07de9bdfa201f819cd88d1d2468ee98f011d938f22504512f7616af434|
| Contract |PASS; không crop/blur/remux/transcode/xóa logo|
| Acceptance |NEEDS_VISUAL_REVIEW, không phải no-watermark PASS|

## Trình bày và review còn thiếu

Original MP4 và audio-review.wav đã yêu cầu mở bằng open_in_codex (tool trả queued), video gốc trình bày inline và có link trong final. Không coi queued là user đã xem/nghe. Review offline network-none dùng cached image256MiB, guard riêng; tạo contact sheet1fps, fullframe0/10/20/26,8s và PCM mono16k chỉ để nghe. SHA video gốc trước/sau vẫn14a8…f434; không thay tệp nguồn.

Assistant đã xem contact sheet và fullframes10/26,8s: nội dung/logo HONKAI STAR RAIL và text gốc còn nguyên, chưa thấy dấu TikTok rõ trong các frame lấy mẫu. **Không đủ để tuyên bố không watermark trên toàn video**. Chưa nghe bằng cảm nhận hoặc xem liên tục toàn clip; fullVideoReviewed/perceptualAudioReviewed/watermarkReviewed=false, accepted=false trong visual-assessment.json. Giữ NEEDS_VISUAL_REVIEW. Người xem cần phát tệp gốc đủ27s, nghe tiếng, kiểm mọi phần/các góc/đoạn kết, phân biệt logo nội dung có sẵn với watermark TikTok; không sửa logo.

Review helper đầu lỗi biến automatic PowerShell args trước tạo container; raw review/ và review-preflight-fail.json giữ. Sửa thành commandArgs, tạo review-2 riêng rồi guard/create/start/remove đều0. Lệnh Dockerps chỉ đọc bị sandboxpipe denied lần đầu, chạy lại với quyền thực thi và rỗng; không là lỗi nguồn. Review container own dọn0left, sourceRequests0.

## Lệnh và bàn giao

~~~powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 2
# Sửa đúng cause chuẩn hóa outtmpl và public hook:
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 3
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage live -Sample 1 -FixtureAttempt 3
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/review.ps1
# Review lần đầu lỗi biến; chạy lại với review-2 riêng sau sửa:
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/review.ps1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_candidate_live.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_candidate_live.ps1
~~~

Các lệnh là hồ sơ, không chạy lại để ghi đè evidence. Evidence mới docs/evidence/tiktok-cobalt-candidate-live-20261008/ giữ FAIL→PASS snapshots/nativeUTC-VN/pins/guards/integration/candidate-result/sourcevideo/review/manifest. Baseline2228file, chỉ6lab+AUDIT/PROGRESS cũ đổi; file/test/entry/review/verifier/handoff mới đúngphạmvi. Predecessor89artifacts nối hai doc-only revisions của audit độc lập,87artifact còn lại khớpbaseline. Raw/manifests/verifiers/golden/oldhandoffs/history/archive và production giữ SHA; không main/UI/API/DB/lifecycle/deploy hoặc build.

Đã hết budget analyze nguồn của lượt này. Không mẫu2/3 hoặc request thêm. Trước nghiệmthu mẫu1 cần hoàn tất review toàn tệp/hình/tiếng/watermark. Dù mẫu1 được review đạt sau này vẫn chưa ba mẫu/no-buttonAPI E2E/mọiURL/TikTokmain. Bước tiếp cần nhiệm vụ riêng, không tự mở thêm nguồn từ file-contract PASS.
