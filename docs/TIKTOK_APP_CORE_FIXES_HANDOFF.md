# Bàn giao hai finding core TikTok — 09/10/2026

F-APP-DURATION-CAP và F-APP-BODY-TIMEOUT-CODE đã đóng **trong kiểm offline**. Nguồn thật0; TikTok main OFF; source/API E2E NOT_RUN; production build/deploy0. Nguồn đã nghiệm thu vẫn2/3, mẫu3 NEEDS_VISUAL_REVIEW. Không đổi visual-assessment lịch sử.

## Mã sửa và API tái sử dụng

- apps/media/src/tiktok/adapter.py truyền effective ADAPTER_MAX_DURATION vào inspect_file.
- candidate_file.py kiểm duration thực của container và từng H.264 stream không vượt effective ceiling, trước phép so metadata/file. Tolerance5%, bounded0.15–0.75s chỉ dành cho metadata/mux granularity; không nới ceiling. DURATION_POLICY đã được mapper hiện có đổi LIMIT_EXCEEDED. FFprobe và full FFmpeg decode giữ nguyên.
- core.py dùng classifier Requests/urllib3 hiện có tại BoundedBody.read, ghi SOURCE_TIMEOUT chỉ cho timeout đã nhận diện khi chưa có failure. Giữ bare raise/exception identity, byte/request counters, deadlines và failure đã có; không dò message/tên lớp hoặc thêm retry.
- PROVENANCE.json cập nhật SHA source copy đã đổi; NOTICE.md ghi thay đổi AGPL. SHA của cả ba executable và toàn core đang chạy có trong runtime-1/runtime-pins.json và successor mới. Vendor/LICENSE/lock/pins không đổi; không thêm dependency.

Tài liệu chính thức đã đối chiếu: [Requests2.34.2](https://requests.readthedocs.io/en/latest/api/), [urllib3 2.8.0 exceptions](https://urllib3.readthedocs.io/en/stable/reference/urllib3.exceptions.html), [FFprobe](https://ffmpeg.org/ffprobe.html). runtime-1/library-api-check.json còn kiểm mã thư viện chính thức **thực sự cài trong image** và hash requests.models/urllib3.response/exceptions: public HTTPResponse.read(decode_content), ReadTimeoutError/TimeoutError, Requests.iter_content bọc ReadTimeoutError thành ConnectionError. FFmpeg/FFprobe version5.1.9 đã kiểm từ executable cache. Không thêm parser/HTTP/TLS/solver.

## Lệnh thực chạy và kết quả

Chạy bằng bundled pwsh.exe -NoProfile -File, tại D:\WED SNAP:

1. labs/tiktok/app-core-fixes/build.ps1 (lần1): runner exit1 do literal PowerShell false khi ghi receipt sau export; log build giữ trong build-1. Không suy log export thành native build exit đã lưu. run.ps1 -Mode fixes lần1 exit1 vì thiếu receipt, chưa tạo container. early-runner-failures.json lưu rõ hai lỗi, không ghi đè.
2. build.ps1 -Attempt2: exit0, COPY-only --pull=false --network=none; không install. Parent cache d4558b29...18e4e giữ nguyên. Image lab mới **sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e**.
3. run.ps1 -Mode fixes -Attempt2: native test/state exit0, **29 case** PASS.
4. run.ps1 -Mode regression: exit0, **19 case** CLI fixture PASS.
5. run.ps1 -Mode runtime: exit0, pins/API/source hash PASS.
6. labs/tiktok/app-core-fixes/verify.ps1 -Capture, sau đó không -Capture: kiểm hash/coverage/lineage, không gọi nguồn hoặc chạy lại test chức năng.

Namespace mới: docs/evidence/tiktok-app-core-fixes-20261009/. Mọi test tuần tự network-none512MiB, memory-swap512MiB, CPU0.75, user1000, rootfsRO, cap-dropALL, no-new-privileges, privateIPC, pids96, tmpfs32MiB. Không sửa seccomp/host/Docker/WSL. Không dựng egress vì không có network; fixture kiểm TLSverify/proxy forwarding, **không** nghiệm thu mạng/SSRF mới. Own containers đã rm đúng ID/run label; namespace không còn container/network.

fixes kết thúc UTC06:24:40 / VN13:24:40; regression UTC06:25:13 / VN13:25:13; runtime UTC06:25:47 / VN13:25:47. Native logs lưu start/end và actual exit, guard/state/completion có ở từng lượt.

## Bằng chứng chức năng

MP4 thật do FFmpeg tạo: container1.92/2.00/2.12s, metadata2, max2. Dưới/bằng trần prepare0, full decode0 và SHA khớp input. Trên trần prepare1 LIMIT_EXCEEDED và cleanup media/.part/.ytdl mới. Container/H264 bound độc lập; stream H2642.01 khi container2 bị reject. Tệp thực601.028s bị LIMIT trước decode; metadata mismatch vẫn FORMAT_UNAVAILABLE.

Direct/wrapped body timeouts qua **CLI extractor/downloader thật với transport fixture**, metadata và MP4 sau status200, đều exit1 SOURCE_TIMEOUT; protocol lỗi vẫn CONTENT_UNAVAILABLE. Unit boundary bổ sung Requests.ReadTimeout/MaxRetry wrapper/fake class trùng tên/prior BYTE_LIMIT, kiểm exact exception identity, counters3byte không reset, deadline/request budget không đổi. BYTE_LIMIT/DEADLINE vẫn giữ failure; không retry. Sidecar mới cleanup; cả media.mp4/.part/.ytdl preexisting giữ bytes và MP4GET0.

Regression xác nhận hai child riêng, metadata2+2 GET và1 MP4 GET, media.mp4/schema giữ, fresh bodyID/format kiểm trước tải, default-off, lower caps/deadline, symlink và ownership. YouTube là **fixture legacy branch**, không nguồn thật. API/worker không chạy lại: hai finding nằm trong child core; CLI trả đúng error, worker hiện có chuyển data.error thành AppError sau native exit/group-stop. Worker/API/ProcessGroup/processor/CSRF/native lease và toàn YouTube source giữ hash baseline; audit lịch sử API-worker vẫn là kết quả cũ.

## Điều kiện tiếp theo

Đọc NEXT_PROMPT.md trong namespace mới. Review mẫu3 toàn clip/hình/tiếng/watermark là điều kiện riêng trước đề nghị nguồn/API E2E. Chưa bật TikTok main. Hai finding đã đóng offline không chứng minh mọi link/no-button/shortlink hoặc nguồn thật hoạt động.
