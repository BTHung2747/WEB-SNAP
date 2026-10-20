# Core ảnh TikTok bước1 — bàn giao15/10/2026

**PASS_OFFLINE_PHOTO_CORE_NOT_WIRED_PENDING_REVIEW**. Đã tạo bốn module runtime mới và kiểm49ca offline trên đúng source cuối. Chưa nối CLI/entrypoint/API/worker/web hoặc bật photo/TikTok main. Không GET TikTok/CDN, tạo claim/cold, install/build/pull, sửa egress/DB/Compose/settings hoặc deploy.

Mẫu album5ảnh trước đã technical+human visual accepted theo [successor riêng](evidence/tiktok-photo-album-mount-all5-human-visual-20261015/ASSESSMENT.md). Lần này chỉ dùng media tổng hợp và HTTP adapter giả; không phải nguồn/app/API E2E và không có kết luận watermark mới.

## Mã và API bàn giao

- `D:\WED SNAP\apps\media\src\tiktok\photo_contract.py`: public summary strict, count1–50/index/dimensions/itemKey/snapshotKey, single format ID72ký tự và public format rows. Port phần thuần từ album_contract đã kiểm. Fingerprint chỉ ràng buộc cấu trúc, không chứng minh pixel identity khi thay ảnh cùng dimensions.
- `D:\WED SNAP\apps\media\src\tiktok\photo_picker.mjs`: stdin đọc có cap8MiB; pinned Cobalt parse body RAM, fetch bridge không mạng đúng một lời gọi; bodyID/resolvedPostID/imagePost/private/count/dimensions/HTTPS. Private picker≤128KiB chỉ qua pipe cho Python, không public logs/audio/stream proxy.
- `D:\WED SNAP\apps\media\src\tiktok\photo_file.py`: MIME+JPEG magic, ffprobe mjpeg/một stream/dimensions/pixels/một frame, full FFmpeg decode rồi SHA; Operations/native hiện có. Không crop/blur/transcode, không Pillow.
- `D:\WED SNAP\apps\media\src\tiktok\photo_core.py`: `analyze_album(url,folder,**options)`, `prepare_photo(url,folder,selected,**options)`; `PhotoLimits` nhận giới hạn thấp hơn. Không CLI hoặc side effect mạng khi import. Dùng `owned_folder` UUID hiện có, extractor mức cao, GuardedYDL/Requests/cookiejar/Operations. `diagnostics` là dict nội bộ chỉ chứa bộ đếm/row đã che URL; `session_factory` phục vụ adapter fixture, không được lấy từ dữ liệu client.

Các lời gọi cần **hai child độc lập được parent giám sát**, như contract app hiện có; không giữ session qua selectable. Prepare lấy metadata mới, so bodyID/count/snapshot/index/itemKey/dimensions trước một GET ảnh. Body cũ bị xóa trước mỗi request; lỗi transport/cap/deadline không được dùng lại body challenge. Cookie/body được xóa cả khi close lỗi.

`PhotoYDL` thêm owner mỏng quanh public Session/Adapter APIs để giữ response trả về từ send cho tới physical close. Lý do: cancel/deadline có thể xảy ra sau send nhưng trước lúc GuardedYDL bọc body; owner đóng cả response đó mà không đổi request, TLS, proxy, exception hoặc cookie preparation. Lỗi close một response/session không chặn cleanup còn lại. Không sửa `core.py` video hoặc viết transport mới.

Fixed output `image.jpg` và exclusive `.part`, không thay file có sẵn/symlink. Sau full contract/SHA, `os.link`+unlink cùng filesystem publish tệp hoàn chỉnh theo chế độ không thay thế: POSIX `rename` mặc định có thể ghi đè nên không dùng nó. Cleanup kiểm inode/dev do lượt đó tạo, giữ collision/preexisting/sentinel. **SIGKILL không chạy finally**: parent phải reap ProcessGroup rồi dọn job/output đã sở hữu. Fixture parent kiểm điều này; chưa thay hay kiểm app ProcessGroup integration trong bước1.

Analyze≤2GET metadata/30s/8MiB mỗi response/16MiB tổng decoded. Prepare metadata mới≤2GET/30s, JPEG conditional≤1GET/redirect0/retry0/HEAD0; prepare≤180s/input≤36MiB/output≤16MiB hoặc app thấp hơn; JPEG response/input≤20MiB; item≤60s và≤prepareEnd−10s. HTTPconnect≤10/read≤20 clamp remaining. `network_total` không reset khi chuyển ảnh; metadata8MiB không áp nhầm JPEG. Core kiểm deadline tại các ranh giới đọc/thao tác; **parent OS deadline độc lập vẫn bắt buộc**, không quảng cáo hai hàm Python đơn lẻ có thể tự ngắt mọi backend blocking.

## Delta/licensing và dependency thực

Cobalt giữ commit **a636575b09de1fc55d9b8cd98cac88f5f2f16b42**, imput/Cobalt contributors, AGPL-3.0 và LICENSE nguyênbyte. Chỉ ba file cũ thay đổi có chủ đích:

1. vendor/tiktok.js: thêm đúng một dòng annotation photo từ `detail` đã upstream parse. Gỡ dòng mới trong bộ nhớ khôi phục SHA before chính xác; video/picker algorithm nguyênbyte.
2. NOTICE.md: ghi nguồn/phạm vi/glue/owner/publish và giới hạn.
3. PROVENANCE.json: cập nhật SHA/modified của resolver delta và mapping/SHA bốn module mới. Giữ fromSHA/original sources/history.

[Before bytes, diff và source-final](evidence/tiktok-photo-core-step1-20261015/), [source gate27file](evidence/tiktok-photo-core-step1-20261015/offline-4/expected-source.json). Baseline223file trong kế hoạch là snapshot **trước** delta được phép, không còn là runtime fingerprint mới; không sửa baseline/verifier/golden cũ để ép PASS. Baseline mới197file có đúng3delta; module mới được đối chiếu bằng gate riêng. Phạm vi bảo toàn đọc/hash không phải chạy lại toàn13.768 lịch sử.

Image cache cố định `sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e`. Quan sát thực: Python3.11.2, Node22.22.3, FFmpeg5.1.9-0+deb12u1, yt-dlp2026.8.19 (extractor SHA guard), Requests2.34.2/urllib3-2.8.0/brotli1.2.0. Npm installed/pins/license đối chiếu read-only riêng: undici6.24.1, set-cookie-parser2.7.2, @imput/psl2.0.4, url-pattern1.0.3, punycode2.3.1. Không đổi dependency/lock/image. `requirements.lock` hiện là version pin, không tự gọi là hash lock. [API và nguồn chính thức](evidence/tiktok-photo-core-step1-20261015/API_REFERENCES.md).

## Kiểm thực chạy và giới hạn bằng chứng

Lệnh thực: `& 'D:\WED SNAP\labs\tiktok\photo-core-step1\run.ps1' -Attempt 1`, rồi2,3,4 theo lỗi/kiểm bổ sung dưới. Không ghi đè attempt. Runner gate27file trước/sau, container networknone/privateIPC/user1000/rootfsRO/capdropALL/NNP/512MiB(no swap extra)/CPU0,75/PIDs96; tmpfs/media lab riêng. Không build/start main. TLS/proxy trong fixture là kiểm forwarding `verify=True`/own-egress options; **không phải bắt tay TLS/SSRF live**. Proxy app chưa parity lab DNS/HE và vẫn là bước sau. Không đo peakRSS; có enforce cap và state noOOM.

| Lượt | Native exit | Kết quả thực |
|---|---|---|
| offline-1 | 1 | Gate đi qua happy pipeline và ca từ chối; FAIL fixture JPEG lớn vì chèn padding trước magic. Giữ raw; sửa fixture, không nới JPEG contract |
| offline-2 | 0 | 46ca đạt trên bản core khi đó; chưa có kiểm đóng response đầy đủ |
| offline-3 | 1 | Thêm closure assertions/video regression. Dừng ca cancel, child1/packetnull, stderr570byte chỉ được đếm ở wrapper cũ, không lưu nội dung. Không suy class/message cụ thể từ stderr đã mất; đọc mã xác định khoảng trống ownership sau send. Sửa owner ở core ảnh; wrapper sau lưu lỗi fixture bằng class/file/line đã whitelist |
| offline-4 | 0/noOOM | **49ca đạt trên source cuối**, gồm owner/cookie/response closure, không phải lặp nguồn |

Gate cuối: UTC02:13:33–02:14:08 ngày15/10 (VN09:13:33–09:14:08); timestamp đầy đủ ở [native.jsonl](evidence/tiktok-photo-core-step1-20261015/offline-4/native.jsonl), [completion](evidence/tiktok-photo-core-step1-20261015/offline-4/completion.json). Npm capability đọc riêng native0, own container dọn. Capability đầu dùng `docker run --rm`/exit0 nhưng không capture containerID, ghi đúng giới hạn đó; bốn lượt gate và npm read sau có ownID/ownership/remove/absence receipts.

49ca gồm: real extractor/challenge→Cobalt bridge→Requests adapter fake→JPEG thật→ffprobe/full decode/SHA; hai child exit0/0 và hai RAM session tách; chọn ảnh2; bad ID/private/nonphoto/count51/URL/dimensions; snapshot/count/index/format thay đổi chặn trước ảnhGET; TLS/body timeout sau challenge không dùng body cũ; gzip decoded>8MiB bị chặn; exact16MiB metadata; JPEG hợp lệ>8MiB với cap20; input/output nhỏ hơn; prepare10s hết reserve trước ảnhGET; MIME/magic/truncated/dimensions; cancel sau headers và sau tạo part; decode native20/-9; preexisting/symlink/collision giữ nguyên; metadata-only/prepare packet PASS→exit20/PASS→hang không được parent chấp nhận; OS parent kill backend blocking, ProcessGroup không còn.

Decoder fault injection gọi native child exit20 hoặc SIGKILL tại boundary sau real ffprobe; không giả là FFmpeg nguồn thật đã lỗi. Full FFmpeg decode happy và JPEG lớn thực chạy0. Parent deadline kiểm dạng thu nhỏ0,8s, adapter cố ý ngủ10s, marker xác nhận đã vào adapter; parentkill/reap actual−9. Không đo lại deadline30/180 trên nguồn. Sau core lỗi, kiểm filesAfterCall trước parent cleanup; riêng fake PASS rồi child chết, parent dọn output đã được core tạo hợp lệ. App parent chưa được nối/test ở đây.

Tệp mẫu fixture64×64: SHA256 **45cea83ba1889b4f948c9fca05932a47ff2bb92723dd8fa798fcf14149c51e00**, [fixture-output.jpg](evidence/tiktok-photo-core-step1-20261015/offline-4/fixture-output.jpg). JPEG/mjpeg/one frame/fullDecode PASS, metadata/prepare2+2+1 và inputBytes giữ cả metadata. Đây là ảnh màu tổng hợp, không trình nó như ảnh TikTok hoặc đánh giá watermark.

Bốn gate own containers và npm capability container được dọn theo đúng label/runID, không network/volume mới; không prune/đụng tài nguyên cũ. Historical raw/golden/human/claims, entrypoint/API/worker/web/shared/DB/YouTube/egress và locks giữ. [Verifier bảo toàn](evidence/tiktok-photo-core-step1-20261015/verify.ps1) chỉ đọc/hash/kiểm receipts, nhận output riêng, không chạy runtime/nguồn.

## Bước kế tiếp

[Prompt kiểm độc lập bước1](evidence/tiktok-photo-core-step1-20261015/NEXT_PROMPT.md). Chưa tự nối bước2. Sau review core đạt mới giao CLI/worker/API default-off theo kế hoạch; proxy parity và web là các bước riêng trước app/source E2E. Không dùng offline PASS hoặc human visual cũ làm source grant/activation/deploy.
