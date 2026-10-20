# Bàn giao lab ảnh TikTok — 09/10/2026

**Kết quả nguồn: metadata PASS, tải ảnh FAIL; chưa nghiệm thu tải ảnh.** Bài7678209751167110421 đúng type photo, có5 ảnh theo thứ tự Cobalt. GET ảnh đầu gặp SOURCE_TIMEOUT tại CONNECTION_SETUP trước header/body. Không có JPEG nguồn để kiểm magic/dimensions/decode/SHA/visual/watermark. Dừng sau lượt được giao; không retry/ảnh2/album/audio/HEAD. Main OFF, deploy0; video vẫn accepted2/3, mẫu3 NEEDS_VISUAL_REVIEW.

## Phạm vi và thư viện

Chỉ thêm labs/tiktok/photo và namespace docs/evidence/tiktok-photo-lab-20261009; apps/media/worker/API/UI/schema/lifecycle/egress cùng hai bản sửa duration/body-timeout giữ hash. Dùng cache image **sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e**, egress8bc0a567...d48d7f10; build/install0.

Đối chiếu chính thức [Cobalt commit a636575b09de1fc55d9b8cd98cac88f5f2f16b42](https://github.com/imputnet/cobalt/blob/a636575b09de1fc55d9b8cd98cac88f5f2f16b42/api/src/processing/services/tiktok.js): imagePost.images→picker giữ thứ tự, chọn URL chứa .jpeg?, alwaysProxy=false tránh whole-app stream; không tải audio. Lab giữ8helper/vendor có sẵn, LICENSE/NOTICE/lock/SRI và PROVENANCE ghi from/toSHA. Chỉ thêm lab annotation ID/type/private/dimensions trên detail Cobalt đã parse; không parser mới.

[yt-dlp2026.08.19](https://raw.githubusercontent.com/yt-dlp/yt-dlp/2026.08.19/yt_dlp/extractor/tiktok.py) không có gallery extractor; API YoutubeDL.extract_info(download=False,process=False,ie_key=TikTok) lấy canonical /video trang tác giả và xử lý challenge thư viện có sẵn. Không chép private helpers hoặc tự solver. Cobalt parse body cuối trong RAM, kiểm fresh bodyID/type trước chọn ảnh. Nếu extractor lỗi mà không có budget failure và đã có body, chỉ chuyển body đó cho Cobalt, không thêm request/fallback. Metadata target thực dùng /@adne_la.veil/video/7678209751167110421 theo đường thư viện; đầu vào chủ là /photo/. Picker Cobalt vẫn gọi @i/video giả lập trong RAM; **không gửi GET @i**. Đây chưa phải app/API E2E URL photo.

Requests2.34.2/urllib3-2.8.0/Brotli1.2.0/yt-dlp2026.8.19, extractor sourceSHA, FFmpeg5.1.9 được assert trong fixture; runtime-inventory.json kiểm23corefile image khớp host. Tái dùng GuardedYDL/Budget/classifier/observer/Operations trong core đã sửa. [imghdr.what Python3.11](https://docs.python.org/3.11/library/imghdr.html) sniff JPEG magic; API này deprecated và chỉ phù hợp cache Python3.11, không đề nghị upgrade/runtime mới. [FFprobe](https://ffmpeg.org/ffprobe.html) xác nhận mjpeg/dimensions/1frame; FFmpeg full decode -xerror/-err_detect explode, max_alloc64MiB, threads1, output null không sửa tệp. JPEG tĩnh là phạm vi hiện tại, định dạng khác phải fail/report trước mở rộng.

## Budget, ownership và guard

budget.json chốt trước nguồn: một analyze, metadata≤2GET/30s, decoded8MiB mỗi response/16MiB tổng. Conditional1GET ảnh đầu, prepare≤60s, input≤20MiB/output≤16MiB; tổng input metadata+ảnh≤36MiB. Redirect0/retry0/HEAD0. Image cạnh≤8192px, tổng≤16.000.000pixel, ≤50entry metadata. Cookie/signedURL chỉ RAM/pipe giữa Python-Node, không log/DB/tệp; evidence chỉ ID/index/dimensions/counters và URL request [url-redacted]. Public canonical target không bí mật được ghi riêng.

Parent OS watchdog metadata30/prepare60, packet PASS chưa thành công cho đến worker exit0. Failure/kill dọn đúng image.jpg/partial do lượt tạo, giữ preexisting. Runtime tuần tự photo512MiB+egress96MiB=608MiB; CPU0.75/0.25, swap bằngRAM, user1000/65534, rootfsRO/privateIPC/cap-dropALL/NNP/pids96/64, output riêng/tmpfs32MiB. Offline network-none; live worker chỉ network internal tới own-egress, proxy HTTPS CONNECT/public-DNS/SSRF và TLSverify giữ. Không đổi seccomp/host/Docker/WSL.

## Lệnh và fixture thực chạy

Bundled pwsh.exe -NoProfile -File tại D:\WED SNAP:

- labs/tiktok/photo/run.ps1 -Stage offline:17case PASS/runner-container0; bản đầu chưa có runtime inventory và tổng pixel case, giữ offline-1 làm lịch sử lượt này.
- run.ps1 -Stage offline -Attempt2: **18case PASS/runner-container0**, đúng source/lock hash cuối; runtime23core khớp host. Đây là gate của lượt live, không fixture thành nguồnPASS.
- run.ps1 -Stage live -Attempt2: **runner/container/parent20**, worker **−9/SIGKILL** sau packetFAIL; parent FAIL path kill/reap worker theo supervisor đã tái dùng, không khẳng định worker tự exit20. Docker wait tool exit0 trả container20. Native remove/network-remove0, own resources0. Gate so source hashes/image/offline native/result/runtime hashes trước mở nguồn; source-hashes.json bản live trùng receipt.
- Docker ps/network ls theo label tiktok-photo không còn ID; image main e7f93577...0184b giữ. Không DB/settings access.

18case: ordered picker2entry/freshID, wrong-body/private/age, redirect, metadata oversize/timeout, image body timeout, HTML giả JPEG, header oversize và stream oversize, preexisting, width cap/tổng pixel cap, worker PASS→exit20 và hang/OS deadline cleanup, decoded response/aggregate caps. JPEG tổng hợp64×64 được MIME/magic/ffprobe/1frame/full-decode0/SHA; metadata2GET+image1GET trong successfixture, anonymous cookie đúng domain. Body timeout giữ SOURCE_TIMEOUT từ bản sửa core. Full HTML/cookie/URL fake token không đi vào packet evidence.

Offline-1 cleanup UTC06:58:08.549 / VN13:58:08.549; offline-2 UTC06:59:50 / VN13:59:50. Lượt nguồn cleanup UTC07:00:56.071Z / VN14:00:56.071+07. Native.jsonl/guard/state/completion ghi thời gian/actual exits; verifier chỉ kiểm coverage/lineage, không chạy lại nguồn hay fixture.

## Nguồn thật: giới hạn kết luận

Input https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421.

Metadata **PASS**: actual target /@adne_la.veil/video/7678209751167110421,1GET/status200,413.992decodedbyte,1.520498s. Cobalt xác minh bodyID/type photo và5 ảnh: [2132×2132,2132×2132,2132×2132,2248×2132,2132×2132], thứ tự1..5; không URL ảnh bí mật được lưu. Chỉ descriptor metadata, chưa đo dimensions thực của file.

Conditional ảnh1GET **FAIL**: phase prepare10.073427s; HTTPAdapter.send10.066345s READ_TIMEOUT (Requests.ReadTimeout/urllib3.ReadTimeoutError/builtins.TimeoutError); CONNECTION_SETUP ERROR10.010758s với timeout số10. Không có REQUEST_SEND/RESPONSE_HEADERS terminal, status UNKNOWN/body0. Setup nhóm DNS/proxyTCP/CONNECT/TLS chưa tách; proxyConnect/originTLS/headerWait UNKNOWN. Không quy chắc lỗi cho TikTok/CDN/TLS hay tăng read20 vì mã ReadTimeout có thể xuất hiện lúc setup. Tổng input chỉ metadata413.992byte, output0.

metadataPacket PASS khác tổng pipeline metadataAccepted=false: supervisor fail closed vì prepareFAIL/worker bịkill, statusFAIL/fileFAIL_DISCARDED. Không downgrade quan sát bodyID/metadataPASS, cũng không nâng thành filePASS/no-watermark. Magic/MIME/ffprobe/decode/hash/visual nguồn NOT_RUN. Không có tệp thật để trình bày; fixture JPEG không thay ảnh nguồn.

## Hướng tiếp

NEXT_PROMPT riêng trong namespace mới bàn giao điều tra hẹp setup từ evidence/API thư viện, chưa cho phép retry nguồn. Chỉ sau file nguồn hợp lệ và review gốc mới xét lab gallery ứng dụng: analyze descriptors công khai theo thứ tự, prepare child riêng fresh postID/type/index và dimensions, download từng ảnh có ownership/lease riêng, cookie/signedURL RAM; review schema/API/UI/worker là nhiệm vụ riêng. Không nhập lab fixture/runner hoặc bật main từ kết quả metadata.
