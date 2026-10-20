# Điều tra hẹp Cobalt TikTok — 08/10/2026

**Chưa xác định được vì sao response cũ HTTP200/1.462 byte không có rehydration.** Kiểm toán chỉ đọc không tìm thấy lỗi đổi URL/parser/header cụ thể trong lớp tích hợp. Đã sửa khoảng trống chẩn đoán bằng helper yt-dlp hiện có và kiểm offline; một lượt nguồn mới hết hạn trước header/body, nên chưa xác nhận hoặc loại trừ giả thuyết challenge. Metadata FAIL, download0, file/ffprobe/giải mã/hình/tiếng/watermark NOT_RUN. Dừng đúng phạm vi, không mẫu2/3, retry, browser/chroot/solver hoặc main/deploy.

## Kiểm toán chỉ đọc và mức độ bằng chứng

Đầu phiên chạy `verify_recheck.ps1` **không Capture**, actual exit0,73/73 artifact trước khớp; source/docs/evidence trước sửa được snapshot1.996+34=**2.030 file**. Sau đó chỉ đọc code/raw/official sources, không chạy lại 37.3 hoặc request TikTok để kiểm toán. `read-only-audit.json` và `comparison.json` lưu phân loại, không sao chép URL/token/cookie/HTML thật.

| Giả thuyết | Bằng chứng và kết luận |
|---|---|
| Cobalt parser không nhận video vì thiếu JSON nó yêu cầu | **Đã quan sát** trong lượt recheck: marker toàn body=false, Cobaltfetch.fail. Chưa biết nguyên nhân nguồn không cấp JSON. HTTP200 chỉ là transport status. |
| Lớp nối thay nhầm URL tác giả thành@i | **Không phù hợp code**: resolver upstream đúng commit tự tạo@i/video/{postId}; lab giữ dòng đó. InputID7692808825228807442 được chuyển qua extractor URL gốc; không dùng@i làm chứng cứ tác giả thực. |
| @i là nguyên nhân duy nhất | **Bị giảm mức tin cậy**: 37.3B đã GET URL tác giả, cũng metadataFAIL/solver_blocked, tổng giải nén1.462byte. Không phải đối chứng cùng cấu hình: curl_cffi GET thực chrome-146:macos-26 khác HEAD yêu cầu chrome-136:macos-15; header/transport/giờ khác Cobalt. Không có bodyhash lịch sử, cùng size không chứng minh cùng HTML hoặc loại trừ mọi ảnh hưởng URL. |
| Parser chỉ sai thứ tự thuộc tính script | **Ít phù hợp**: marker substring trong toàn body cũ đãfalse, không chỉ exact-tag parseFAIL. Không sửa parser để đoán schema. |
| Brotli/cap/reader làm mất body | **Không thấy dấu hiệu**: cũ1.462byte thấp hơn cap, EOF/khôngtimeout. Fixture mới qua Undici6.24.1 br decode trả HTML đầy đủ và SHA đúng; đây là fixture, không hồi tố body cũ. |
| HTML là JS challenge mà marker captcha cũ bỏ sót | **Giả thuyết cụ thể, chưa chứng minh**: yt-dlp ghim đọc cs/wci, marker cũ chỉcaptcha/verify-center. Fixture mới chứng minh classifier nhận dạng đúng mẫu giả; nguồn mới chưa trả body. |
| TLS/session/egress/header/nguồn biến đổi | **Chưa đủ bằng chứng**. Cobalt core/api khởi động randomizeCiphers; lab dùng default TLS, không nhập bước thaycipher. Khác biệt này có thật nhưng chưa chứng minh lỗi tích hợp gây response1462, không áp dụng ngẫu nhiên để thử. |

Lưu ý raw37.3B: per-request decoded_bytes0/read_errorCLOSED và markerfalse là callback có thể chạy trước sniff/count. Đọc **executed-source/probe_373.py**, không gán sửa diagnostics sau đó vào lượt đã chạy. Tổngbudget1462 và native metadataFAIL/solver_blocked vẫn có; không dùng rowmarker0 để kết luận captcha hoặc challenge không tồn tại. Lượt Cobalt recheck marker toàn body riêng đáng tin hơn; không có payload lịch sử để phân loại thêm.

Nguồn chính thức đúng pin đã đọc:

- [Cobalt resolver](https://github.com/imputnet/cobalt/blob/a636575b09de1fc55d9b8cd98cac88f5f2f16b42/api/src/processing/services/tiktok.js), [API boot](https://github.com/imputnet/cobalt/blob/a636575b09de1fc55d9b8cd98cac88f5f2f16b42/api/src/core/api.js), [cipher helper](https://github.com/imputnet/cobalt/blob/a636575b09de1fc55d9b8cd98cac88f5f2f16b42/api/src/misc/randomize-ciphers.js). Code resolver/helper/upstream/license/commit giữ nguyên.
- [yt-dlp2026.08.19 TikTokBaseIE](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/extractor/tiktok.py), HTML helpers `find_element`/`extract_attributes`/`traverse_obj` đang cài. SHA tiktok.py vẫn `3257fdea…c9e`. Đối chiếu pipeline đọccs/wci, **không gọi** `_solve_challenge_and_set_cookies`.
- [Node22.22.3 execFileSync](https://nodejs.org/download/release/v22.22.3/docs/api/child_process.html#child_processexecfilesyncfile-args-options). Undici6.24.1 vẫn thực hiện HTTP/proxy/decompression; Brotli fixture dùng node:zlib. Không thêm dependencies hoặc parser HTML tự viết.

Một lệnh tìm file ban đầu dùng glob thư mục trong PowerShell bịrg báo pathsyntax; một đường dẫn current-1 đoán từ hồ sơ cũ không tồn tại. Đã chuyển sang rg --files và đọc đúng ab/executed-source. Hai URL GitHub dispatcher đoán không lấy được, không dùng làm bằng chứng; core/api.js và helper theo imports chính thức đọc được. Không coi lỗi tìm kiếm/tool là lỗi nguồn.

## Sửa tối thiểu và kiểm offline

Thay đổi chỉ lab: `classify.py` nối API HTML/JSON helpers yt-dlp để trả boolean về cs/wci/rci/rs, JSONchallenge và trườngdigest, Pleasewait/rehydration. Không trả class/payload/cookie/token; không tìm đáp án, tạo challenge cookie hoặc request. Giữ version+SHA TikTokIE đã ghim. `classify.mjs` gửi HTML đã bounded qua pipe RAM, execFileSync khôngshell, SIGKILL timeout2s/maxstdout-stderr4KiB. Không log lỗi kèm payload. ClassifierFAIL chặn metadata; không fallback ngầm.

`transport.mjs` chỉ thêm bodySHA256 và gọi classifier cho text/html sau đọc dưới8MiBresponse16MiBaggregate; không thay URL/header/TLS/redirect/cookie/source selection. `test.mjs` thêm br roundtrip/challenge giả và negative/malformed/rehydration tests; `run.ps1` chỉ đổi evidence namespace mới. NOTICE ghi thay đổi AGPL-3.0. Gate/hash/guards/redaction/metadataOS30s/prepare180s và downloader250MiBinput200MiBoutput giữ nguyên.

Offline mới network-none: **9 Node cases PASS**, host hash/redaction suite và Python installed-runtime hash/redaction/watchdog PASS; runner/container0. Nodebusyloop bị SIGKILL/child−9 sau30,056496s theo timeout30s, thời gianquan sát có overhead. Fake challenge br nhậncs/wci/JSON/digest true, marker captcha cũfalse, fixture metadata không được coi là nguồnPASS. SHA HTMLfake khớp dữ liệu gốc; output chỉ booleans/digest, token giả không ra report. Không chạy solver.

## Một lượt nguồn mới và dừng

Trước gọi có `live-hypothesis.json`: kiểm cụ thể cấu trúc challenge bị marker cũ bỏ sót. Offline receipt khớp **25 host file/17 runtime source**,1.271 installed dependency/binary file không đổi so với recheck. Runtimeinventory SHA `221ecc3800b7664cb9ffb39c7954d7cdeaeaac6ba23d2aea21287cd78f162d03` giống offline/live. Image `5fcc01bb…0fb3f3a6`/own-egress `8bc0a567…7f10` giữ; không build/install/TLSshuffle.

Một GET attempt cho canonical@i với mẫu1: fetch chờ tới AbortSignal28s, `Error: METADATA_DEADLINE`, worker **exit20/28,368956s**, externalwatchdog timed_out=false vì Node đã kết thúc trước30s. **Không quan sát HTTPstatus/header/body**, tổng giải nén ghi nhận0; không claimHTTP200 mới hoặc DNS/TLS/IPfault. Classifier **NOT_RUN** trên nguồn thật, giả thuyết challenge chưa xác nhận và cũng chưa bị bác bỏ. Không có đoạn HTML/token/signedURL/cookie được lưu.

Native docker attach/runner/outer shell đều20, stderr rỗng. Attach UTC07/10 **19:13:08.529–19:13:38.596**, VN08/10 **02:13:08.529–02:13:38.596** (~30,067s gồm container fingerprint/start/exit); deadline metadata áp dụng worker28,369s, không ghi attach là cùng thước đo worker. Offline attach UTC19:06:34.808–19:07:13.378, VN02:06:34.808–02:07:13.378, exit0.

Đã dừng ngay sau metadataFAIL. Download0/CDN/fileSHA/ffprobe/decode/visual/audio/watermark NOT_RUN; không được tuyên bố tải khôngwatermark hoặc bỏ logo tác giả. Hai mẫu còn lại không gọi.

## Lệnh đã chạy và preservation

```powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_recheck.ps1
# Sau audit và thêm diagnostics; Docker có quyền pipe thực thi:
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage live -Sample 1 -FixtureAttempt 1
# Chốt và kiểm read-only successor:
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_investigation.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_investigation.ps1
```

Các lệnh trên là hồ sơ, không yêu cầu chạy lại evidence đã có. Lệnh runtime dùng image cache, tuần tự: offline256MiB, live512+96=608MiB≤1GiB. UID/rootfs/sourceRO/privateIPC/PID/capdropALL/no-new-privileges/defaultseccomp/mount/noports/own-egress SSRF/TLS và labels vẫn được Guard kiểm trước start. Docker cần quyền thực thi kỹ thuật cho pipe, không nới sandbox container. Cleanup ownIDs/labels:1offlinecontainer;2livecontainers/2networks,0left; khôngprune/down-v.

Evidence riêng `docs/evidence/tiktok-cobalt-investigation-20261008/`: read-only audit/comparison/hypothesis, offline/newsource native UTC-VN/receipt/guards, sanitized result, baseline/outcome/successor/manifest. Giữ raw, manifests, golden/verifiers và hai handoff trước; successor mới chấp nhận đúng4filelab và4statusdocs cũ thay đổi. Production/apps/media/egress/YouTube/API/UI/DB/lifecycle và archive/history19–37.4-R giữ hash. Không sửa verifier cũ để nhận code mới hoặc sửa AUDITgolden.

**Khác biệt predecessor phát hiện khi chốt:** verifier đầu phiên báo73/73/exit0; tại snapshotbefore-all, riêng PROGRESS khác gói recheck: golden SHA `18da0f606977fc2bf54525c2e69e0bba6097500314c3cef60f4c456c266b8c71`/205.792byte → baseline SHA `673067e6f608bc14b7842552e224510d6efa25070f6f37eace4252404d69518a`/207.313byte. 72artifact còn lại khớp baseline. Chưa biết người/lệnh/thời điểm tạo khác biệt, không quy cho sửa trong phiên; giữ raw của phép Capture ban đầu exit1 và chưa tạo manifest trong `progress-predecessor-observation.json`. Successor mới kiểm đúng hash/size này rồi hash hiện tại, không thay golden hay nói mọi baselinepath đều bằng predecessor. Các thay đổi8file trong phiên được đối chiếu với baseline đã chụp, không với golden cũ đã khác PROGRESS.

**Phần còn chưa biết:** loại body1462 của lượt cũ, lý do thiếu rehydration, nơi fetch mới bị chờ, ảnh hưởng độc lập của URL/header/TLS/IP/session và khả năng tảifile. Bước tiếp phải là nhiệm vụ riêng dựa trên điều kiện/bằng chứng mới; không có quyền retry tự động hoặc bật TikTokmain từ các fixtures này.
