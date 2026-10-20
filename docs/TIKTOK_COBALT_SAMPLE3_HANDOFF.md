# TikTok Cobalt candidate — mẫu3 URL dài, 08/10/2026

**Offline đúng wiring mới PASS0. Nguồn thật FAIL ở prepare; chưa có MP4.** Mẫu1+2 giữ nghiệm thu2/3. Đã dừng sau một analyze và conditional một client GET MP4 attempt; không retry/fallback/resolve phụ, không shortlinkAPI E2E/TikTokmain/deploy.

## Đầu vào, provenance và phần sửa

Đọc AGENTS/PLAN1.1/STRUCTURE/AUDIT/PROGRESS, hai human-review/successor đã nghiệm thu và sample3-target.json tại docs/evidence/tiktok-cobalt-candidate-sample2-audit-20261008/. Hai review có accepted/fullVideo/perceptualAudio/watermark=true và SHA review/manifest/video khớp, không sửa raw visual-assessment lịch sử.

User giao URL dài https://www.tiktok.com/@nguye003/video/7692288554839313682, expectedID7692288554839313682. Mapping05/10 của shorttokenZSbxd2AVY là lịch sử (HTTP301, historicalMetadataFAIL), không truy cập shortlink trong lượt này. Target hash4cd5d7d6c2a731bd533933bca97380d0e9dc321d3d203ec0ef9de32e4978af5d được kiểm với audit successor; metadata mới vẫn kiểm bodyID bằng Cobalt. Không dùng parser tự viết hoặc suy URL ID là bodyID.

Chỉ sửa run.ps1 (Sample3-only, URL/ID, evidence mới, gate hai human-review và mapping hash), fixture_pipeline_worker.py/test_pipeline.py (ID synthetic và assertion) cùng NOTICE. Compose giữ expected-ID parameter đã kiểm. Tự nối authorization/config/evidence vì yt-dlp/Cobalt không quản lý hợp đồng WED SNAP; không viết lại resolver/transport/solver/downloader. Hành vi/API đã xác minh được tái sử dụng: [yt-dlp2026.08.19 YoutubeDL](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/YoutubeDL.py), [TikTok extractor](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/extractor/tiktok.py), [HttpFD](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/downloader/http.py); api-decision.json của origin-challenge ghi lý do dùng high-level API/public Requests Adapter.send. Không thêm API/dependency trong lượt này.

Cached Cobalt image sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6; own-egress sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10. Cobalt commit a636575b09de1fc55d9b8cd98cac88f5f2f16b42/AGPL-3.0/LICENSE/upstream/attribution giữ. yt-dlp2026.08.19/Requests2.34.2/urllib3-2.8.0/Brotli1.2.0/Undici6.24.1/FFmpeg5.1.9 không đổi; actual1364dependency-binary files bằng mẫu2. Không install/build/browser/host/sandbox thay đổi.

## Offline thực chạy

Một offline mới network-none256MiB, outer/runner/container0. Fixture fake adapter nhưng extractor/native challenge/Cobalt body check/downloader/parent/file contract thật: bodyID7692288554839313682,2metadataGETfake→1MP4GETfake,H264AAC2s/26531byte, worker/parent0, SHA input/output4f0e867b32f6843471cf089151e0799fa7c8b4cdd16c0d0584de6062ff1dc7b3. Các ca related caps8/16MiB, stalehash/URLtoken redaction, request/redirect, worker PASS→exit20/kill, MP4/container/duration đều qua. OS watchdog30s busyNode child−9, elapsed30,026230s gồm kill/reap overhead; không dùng JS timer làm gate.

UTC09:29:10.648–09:29:57.000/VN16:29:10.648–16:29:57.000, own1container/network0 dọn0left UTC09:29:58.195.40host/32source/runtimeSHA498882465a110c5452efec576c8c058fc65eba8b833584716b9b8c0705ac337a đúng offline/live. Host gate kiểm code/config/lock/image/native receipt, integration bodyID/worker0; entry đối chiếu installed runtime trước source và reservation exclusive. Không dùng receipt cũ hoặc ghi đè evidence.

## Kết quả nguồn thật

| Chặng | Quan sát mới |
|---|---|
| Metadata packet |PASS; bodyID7692288554839313682/video/duration486s≤600 được parser Cobalt kiểm từ RAM|
| Metadata HTTP |2GET200, decoded1462+428682=430144byte;1,768655982s<30;8MiB/response16MiBtotal|
| Format |play-bitrateh264_540p_1544395/MP4/H264AAC1024×576, filesize metadata93936477byte; không downloadAddrwatermarked|
| Prepare |Một Adapter.send GET attempt; chưa có status/header/body trong evidence, decoded0;10,041466928s<180|
| Error packet |FAIL/YTDLP_OR_FILE_FAILURE/UnavailableVideoError|
| Native result |worker−9/signal9, parent/container/runner/outer20, OOMfalse, runtimeHashGatePASS|
| Pipeline acceptance |FAIL/metadataAcceptedfalse/fileFAIL_DISCARDED; packetPASS không thắng worker nonzero|
| Tệp thật |Không video.mp4/.part/.ytdl; ffprobe/duration/decode/SHA/visual/audio/watermark NOT_RUN|

Metadata body/format phù hợp đã mở conditional prepare, nhưng không là thành công cuối. Worker gửi FAIL rồi parent finally kill own process còn chạy và wait/reap;−9 không phải metadata30s/prepare180s deadline hay OOM. Parent cleanup chỉ output mới do lượt tạo; ownedOutputRemoved=[], preexisting=[] và không có tệp để trình bày. Các MP4 trong offline directory là media tổng hợp, không mẫu3.

Không có HTTP status: không chứng minh CDN403/404, video bị xóa, URL hết hạn hoặc một nguyên nhân mạng cụ thể. Code Requests unchanged có Adapter.send timeout=(10,10), elapsed10,041s phù hợp guard timeout ngắn nhưng lower exception chain không được ghi nên đây chỉ là suy luận; không phân biệt proxyTCP/CONNECT, originTLS và chờheader. Không thay timeout/TLS/proxy/guards theo phỏng đoán. cause.json chỉ lưu mã lỗi, lớp exception, thời gian và các giới hạn quan sát; không URL thật/token/cookie/HTML.

Guards actual trước start giữ resolver512MiB/egress96MiB=608MiB, memoryswap=memory, CPU0,75/0,25/PIDs96/64, rootfs/sourceRO/outownRW, users1000/65534, capdropALL/no-new-privileges/defaultseccomp/privateIPC/PID/noports, privateinternal+ownoutbound egress/SSRF/verifiedTLS. ActualImpersonationfalse/cookie ẩn danh RAM. Redirect0/retry0/fallback0, input250MiB/output200MiB caps giữ. NativeUTC09:30:39.825–09:30:53.112/VN16:30:39.825–16:30:53.112; exact own2containers/2networks dọn0left UTC09:30:56.639/VN16:30:56.639.

## Lệnh thực và bảo toàn

~~~powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -Sample 3 -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage live -Sample 3 -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_sample3.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_sample3.ps1
~~~

Lệnh được chạy với quyền Docker cần thiết ngoài filesystem sandbox, không nới container guards. Đây là hồ sơ, không hướng dẫn rerun nguồn. Offline exit0 khác live exit20 được lưu riêng. Evidence docs/evidence/tiktok-cobalt-candidate-sample3-20261008/ giữ baseline2390file/before snapshots/provenance review+target/caps/receipts/nativeUTC-VN/guards/runtime/reservation/result/cause và manifest successor mới. Chỉ4lab+AUDIT/PROGRESS cũ thay; production/history/raw/video/human-review/visual-assessment/golden/manifests/verifier cũ giữ. Verifier mới kiểm đúng kết quả FAIL, không sửa verifier/golden lịch sử để ép PASS.

Đã dùng hết một lượt nguồn của nhiệm vụ. Mẫu1+2 đạt2/3, mẫu3 chưa đạt. Đề xuất bước sau: nhiệm vụ điều tra hẹp chỉ đọc cause chain Requests/urllib3/yt-dlp và khả năng chẩn đoán chặng trước header bằng API hiện có; nếu triển khai logging cần whitelist mã/lớp và offline delayed failures trước bất kỳ nguồn mới được giao. Không tự retry/fallback/resolve thêm. URL dài không là kiểm shortlinkAPI E2E; đủ3mẫu về sau cũng không tự bậtTikTokmain/deploy hoặc cam kết mọi URL.
