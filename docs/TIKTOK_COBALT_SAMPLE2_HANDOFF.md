# TikTok Cobalt candidate — bàn giao mẫu2, 08/10/2026

**Mẫu2 metadata/file contract PASS, parent/worker/container/runner/outer exit0. Chưa hoàn tất review toàn clip và tiếng/watermark: NEEDS_VISUAL_REVIEW.** Mẫu1 đã được chủ nghiệm thu qua human-review riêng, tổng nghiệm thu vẫn1/3; mẫu3 chưa chạy. Không bật TikTok trên main hoặc deploy.

## Wiring, thư viện và phạm vi

Đã đọc AGENTS, PLAN1.1, STRUCTURE, PROGRESS, kết luận audit mới và human-review/successor mẫu1. Mẫu2 dùng đúng URL đã giao, expectedID7611475556395191573; entry/guard Compose nhận COBALT_EXPECTED_ID thay hardcode mẫu1. Runner chỉ cho Sample2, namespace evidence mới và từ chối directory đã có. Gate mẫu1 kiểm human-review SHA, predecessor manifest SHA, các cờ chấp nhận toàn clip/tiếng/watermark và SHA video gốc. Visual-assessment lịch sử không sửa.

Chỉ tự nối cấu hình/expectedID/receipt vì thư viện không quản lý authorization và evidence WED SNAP. Fixture đổi bodyID sang mẫu2 và kiểm ID trả về; không viết lại extractor/parser/transport/solver. Candidate implementation và thư viện không đổi. Tái sử dụng API mức cao đã xác minh theo source chính thức đúng phiên bản: [yt-dlp2026.08.19 YoutubeDL](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/YoutubeDL.py), [TikTok extractor](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/extractor/tiktok.py), [HttpFD](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/downloader/http.py). Lý do/API bridge được giữ trong docs/evidence/tiktok-cobalt-origin-challenge-20261008/api-decision.json; lượt này không thêm API thư viện. Cobalt commit a636575b09de1fc55d9b8cd98cac88f5f2f16b42/AGPL-3.0/LICENSE/upstream/attribution và parser cũ giữ.

Cached image sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6; own-egress sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10. yt-dlp2026.08.19/Requests2.34.2/urllib3-2.8.0/Brotli1.2.0/Undici6.24.1/FFmpeg5.1.9 không đổi, không install/build. Actual mounted32sources/40host hash gate;1364installed dependencies/binaries bằng lượt mẫu1. RuntimeSHA6abf18049f5b32da026d356ad0d6311226913e35fb340f0e573f350d708aabcf offline/live cùng nhau. Giữ verifiedTLS/no impersonation/no account; cookie ẩn danh chỉ RAM.

Guards thực tế kiểm trước start: resolver512MiB/egress96MiB, memoryswap bằng memory, CPU0,75/0,25/PIDs96/64; RO/user1000/65534/capdropALL/NNP/defaultseccomp/privateIPC/PID/no ports, chỉ sourceRO/outRW, private internal network và own outbound egress. Không sửa host/sandbox/SSRF/production hoặc fallback browser. Chạy tuần tự trên RAM8GB.

## Offline thực chạy

Offline1 outer1 vì sandbox Docker pipe denied trước create. Native raw preexisting và cleanup-query đều denied, không có end/receipt, không ghi cleanup PASS giả. Không có container/source tạo bởi lượt này; offline2 sau đó xác nhận không có lab preexisting. Giữ nguyên directory và chuyển attempt2 với quyền Docker, không ghi đè.

Offline2 network-none256MiB dùng đúng source/config sau sửa, outer/runner/container0. Full fake adapter → native challenge/TikTok extractor → Cobalt validate bodyID mẫu2 từ RAM → native yt-dlp downloader → parent wait worker0 → ffprobe/decode/SHA contract. Metadata2GETfake225+451byte; MP4 tổng hợp26531byte/H264AAC2s, SHA input/output4f0e867b32f6843471cf089151e0799fa7c8b4cdd16c0d0584de6062ff1dc7b3. Fixture không là TikTok thật.

Hash gate nguồn/dependencies stale bị reject, fake URL pathname/query/cookie redacted, actual8MiB/16MiB decoded caps, request/redirect guards, worker PASS→exit20/kill, MP4/Matroska/QuickTime/duration mismatch đều qua. OS watchdog30s independent event loop giết busyNode child−9, elapsed30,202s gồm scheduling/kill/reap; deadline không phụ thuộc timer JS. Offline nativeUTC08:50:33.616–08:51:22.805/VN15:50:33.616–15:51:22.805; own1container/network0 dọn0left UTC08:51:24.446.

Live gate kiểm host source/config/lock/image đúng receipt offline2, native/runtime SHA và integration worker/parent0, metadataAccepted/file contract cùng ID7611475556395191573. Entry còn đối chiếu inventory thực trước source và reservation exclusive; không chỉ dựa fixturepacketPASS.

## Nguồn mẫu2 và tệp thật

Đúng một analyze long author URL đã giao; không dùng shortlink hoặc thêm nguồn. Body ID7611475556395191573/loại video/duration23s được xác minh bằng parser Cobalt có sẵn. Chọn play-bitrate h264_540p_2382069, không downloadAddrwatermarked.

| Kiểm | Kết quả thực |
|---|---|
| Metadata |2GET200, redirect0,1462+429507=430969byte decoded;1,438703502s<30s;8MiB/response16MiBtotal|
| Prepare |conditional1GETMP4200, redirect0;3,878240976s<180s;input/output6967552byte≤250/200MiB|
| Native outcome |worker0/parent0/container0/runner0/outer0, runtimeHashGatePASS; không packet-only success|
| Container |ffprobe MP4 ISO-BMFF, major brand isom; H264576×1024 và AAC|
| Duration |format/video23,400000s, audio23,357007s; meta23s, delta0,4s≤tol0,75s|
| Decode |FFmpeg giải mã toàn tệp PASS; lỗi ffprobe/decode nonzero sẽ bị contract reject|
| Bytes/SHA256 |6967552;d379130bcda4e3a7033e01faa6b82e05b8e7708c0117cb1a8595852b6433899a|
| Visual/audio/watermark |NEEDS_VISUAL_REVIEW, chưa xác nhận toàn clip/nghe bằng cảm nhận/watermark|

Dung sai min(0,75,max(0,15,0,05×metadata duration)) giây, có cap để chịu lệch frame/AAC/mux, không nới theo file. Tệp nguồn giữ nguyên, không crop/blur/remux/transcode hoặc xóa logo. Native sourceUTC08:52:55.900–08:53:02.665/VN15:52:55.900–15:53:02.665; dọn exact own2containers/2networks,0left UTC08:53:06.258/VN15:53:06.258. Không retry/fallback/sample3 hoặc thêm request review.

## Video gốc để review

[Tệp MP4 gốc](evidence/tiktok-cobalt-candidate-sample2-20261008/sample-2/video.mp4) được trình bày inline và gọi open_in_codex; tool trả queued không chứng minh đã xem/nghe. Cần phát liên tục toàn23,4s có tiếng, kiểm hình/tiếng và watermark TikTok mọi phần/các góc/đoạn kết; giữ logo/chữ tác giả vốn có. Chưa có xác nhận nên accepted/fullVideoReviewed/perceptualAudioReviewed/watermarkReviewed=false ở visual-assessment mới. Không suy no-watermark từ playAddr/probe/decode. Review xác nhận về sau dùng human-review/successor mới gắn SHA này, không hồi tố raw.

## Lệnh thực chạy và evidence

~~~powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -Sample 2 -FixtureAttempt 1
# Sandbox Docker pipe denied/outer1, raw giữ; chạy attempt mới với quyền Docker:
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -Sample 2 -FixtureAttempt 2
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage live -Sample 2 -FixtureAttempt 2
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_sample2.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_sample2.ps1
~~~

Đây là hồ sơ lệnh, không hướng dẫn gọi lại nguồn. Source budget của nhiệm vụ đã dùng hết. Evidence riêng docs/evidence/tiktok-cobalt-candidate-sample2-20261008/ giữ before snapshots,baseline2337file, provenance acceptance mẫu1, offlineFAIL→PASS/nativeexitsUTC-VN/guards/receipts/inventory/reservation/source-result/video/visual assessment và manifest đầy đủ. Successor mới chỉ5lab+AUDIT/PROGRESS cũ đổi; verifier/golden/raw/manifests/video/human-review/sample1/history19–37.4-R/archives/production đều giữ hash. Verifier mới không sửa verifier lịch sử để nhận wiring mới.

Lệnh verifier mới -Capture đầu exit1 trước tạo manifest: assertion đã đòi URL proxy nguyên văn trong guard JSON vốn được che toàn URL. Sửa đúng verifier mới để kiểm MEDIA_PROXY=[url-redacted]; runner đã kiểm proxy thực trước start và source/runner hash không đổi. Raw verifier-preflight.json giữ nguyên cause, không sửa raw, không chạy lại nguồn hoặc fixture. Capture tiếp và kiểm chỉ đọc cuối được ghi bằng kết quả thực.

Tiếp theo chỉ review tệp đã có. Nếu chủ xác nhận toàn clip/hình/tiếng/noTikTokwatermark, có thể nghiệm thu mẫu2 thành2/3 bằng successor. Mẫu3 cần nhiệm vụ riêng và canonicalID/budget phù hợp; không tự mở từ filePASS. TikTokmain/no-buttonAPI E2E/UI/API/DB/lifecycle/deploy chưa được làm.
