# Candidate exit/file fixes — 08/10/2026

**F-CANDIDATE-EXIT và F-CANDIDATE-FILE đã sửa, kiểm offline PASS. Không gọi TikTok và không tải video nguồn.** Có năm tệp media tổng hợp từ FFmpeg để kiểm container/duration; chúng không phải mẫu TikTok, không có kết luận watermark hoặc P0.

## Sửa F-CANDIDATE-EXIT

Parent không return0 ngay khi nhận packetPASS. Packet chỉ là dữ liệu tạm; parent dùng Popen.wait(), reap worker và kiểm actual exit0 rồi mới đặt METADATA_ONLY hoặc FILE_NEEDS_VISUAL_REVIEW. Trường metadataAccepted phân biệt quyết định của parent với metadataPacket/preparePacket đã nhận.

Grace thoát vẫn tối đa1s như trước, nhưng lấy min(1s, thời gian còn lại của deadline metadata/prepare), không thêm thời gian ngoài30/180s. Worker nonzero hoặc hết grace/deadline rồi bịSIGKILL khiến parent20/statusFAIL, metadataAcceptedfalse. Chờ thất bại vẫn ghi workerActualExit và workerSignal. Broken pipe lúc stop/close không che quyết định exit; không gửi raw stderr có thể chứa URL/token.

Cleanup lỗi áp dụng cả metadata-only và prepare: chỉ ba tên fixed mới trong owned/out, không xóa tệp đã có lúc bắt đầu. Không xóa artifact/manifests khác. Output mới từ workerPASS→lỗi/kill bị dọn; sentinel preexisting trong fixture giữ nguyên.

Đối chiếu API [Python3.11 subprocess](https://docs.python.org/3.11/library/subprocess.html). Không thay thư viện/process model hoặc giới hạn tài nguyên. Không sửa verifier/audit reproduction trước để biến parent0 cũ thành PASS mới.

## Sửa F-CANDIDATE-FILE

candidate_file.py dùng FFprobe/FFmpeg5.1.9 hiện có; Candidate.prepare gọi cùng hàm với duration metadata đã được parser Cobalt xác minh. Không dùng suffix.mp4 hoặc format_id làm chứng cứ tệp.

- Probe format_name, major_brand/compatible_brands, codec_type/name và duration stream/format. Demuxer MOV/MP4 trả cùng nhóm tên, nên cần brand MP4 ISO-BMFF được nhận diện; QuickTime qt bị loại.
- Bắt buộc H264video và audio, duration hữu hạn dương≤600. Cả duration container và video stream phải khớp metadata; stream duration không đủ để xác minh thì fail closed.
- Dung sai tuyệt đối theo giây: **min(0,75; max(0,15; 5%×expected))**. Sàn0,15s nhận granularity frame/AAC/mux ở clip ngắn; trần0,75s không cho clip dài dùng sai lệch nhiều giây. Đây là policy lab có thể từ chối metadata ngắn không chắc, không bảo đảm nhận mọi tệp hợp lệ. So delta gốc, không làm tròn để ép đạt. Với mẫu27s, bound0,75s; fixture2s dùng0,15s.
- Tệp hợp lệ được FFmpeg giải mã đầy đủ như trước, rồi SHA256. Không crop, blur, remux/transcode để sửa tệp nguồn hoặc logo; fixture tạo mới từ lavfi theo nhiệm vụ.

CLI đúng version được kiểm thực bằng ffprobe/ffmpeg -version và -show_entries trong container. [Mã MOV/MP4 n5.1.9](https://github.com/FFmpeg/FFmpeg/blob/n5.1.9/libavformat/mov.c) giải thích group demuxer/brand; không viết parser media mới. Probe10s/decode30s vẫn nằm trong prepareOS180s, input250MiB/output200MiB không đổi.

## Kiểm mới thực sự chạy

Một lượt offline network-none, imagecache sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6, user1000/RO/privateIPC/defaultseccomp/capdrop/no-new-privileges,256MiB/CPU0,5/PIDs96. Không start egress hoặc mạng nguồn. Các kiểm mới chạy tuần tự cùng guards/hash/caps/candidate fixtures cần thiết; không chạy lại test lịch sử không liên quan.

| Fake worker | Metadata-only | Prepare |
|---|---|---|
| PASS→exit0 |parent0/worker0, accepted|parent0/worker0, needs visual review|
| PASS→exit20 |parent20/worker20/FAIL|parent20/worker20/FAIL|
| PASS→không thoát |parent20/worker−9/SIGKILL/FAIL|parent20/worker−9/SIGKILL/FAIL|

Hai nhánh lỗi/kill đều dọn output mới, giữ preexisting. Deadline fixture0,6s là giá trị hạ trong API test, không đổi defaults30/180s. Fake prepare packetPASS không chứng nhận media: worker fixture chỉ ghi payload thử, kiểm file thực là nhóm riêng dưới đây.

| Media do FFmpeg tạo | Probe thực | Quyết định |
|---|---|---|
| correct.mp4, metadata2s |MP4group/isom/H264+AAC/2,000s|PASS, decodePASS|
| near-duration.mp4, metadata2s |MP4group/isom/2,120s|PASS, delta0,120≤0,150s, decodePASS|
| matroska-named.mp4 |matroska,webm/2,023s, cùng codec|FAIL MP4_CONTAINER_REQUIRED|
| quicktime-named.mp4 |MOV/MP4group nhưng brandqt/2,000s|FAIL MP4_CONTAINER_REQUIRED|
| truncated.mp4, metadata2s |MP4/isom/0,520s|FAIL FILE_METADATA_DURATION_MISMATCH|

Media nhỏ64×64, tone tổng hợp440Hz; giữ bytes/SHA/ffprobe và actual command exits trong finding-fixtures.json, media-native.json, media-fixtures/. Không xem các media này là no-button video hoặc tải không watermark.

Offline runner/container/shell **exit0**, UTC08/10 **05:37:47.881–05:38:33.232**, VN **12:37:47.881–12:38:33.232**. BusyNodeOS30s guard còn PASS, child−9 sau30,054159s có overhead quan sát. Cleanupown1container/0network,0left. Raw có worker20/−9 được giữ bên trong suiteexit0; không nhầm suitePASS với success của fake worker lỗi.

Runtime hash final37host/29source/1.364dependency-binary files; inventorySHAfdd7456ef3958e1b2abae1919edee9a8576928f4ca6dd13b04acbc161a3e798a. Deps/image/sourceHTTPguards không đổi; không build/install hoặc mainapply.

## Lệnh, evidence và điều kiện mở nguồn

~~~powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_candidate_fixes.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_candidate_fixes.ps1
~~~

Lệnh đã chạy, không yêu cầu chạy lại evidence directory. ffmpeg/ffprobe commands/actualexit từng fixture lưu media-native.json. Evidence riêng docs/evidence/tiktok-cobalt-candidate-fixes-20261008/; baseline2.195file, chỉ5lab+AUDIT/PROGRESS cũ đổi, file/test/verifier/handoff mới đúngphạmvi. Predecessor123artifacts nối hai doc-only revisions của audit độc lập,121artifact còn lại khớpbaseline. Raw/golden/verifiers/manifests/handoff/history/archive cũ giữ nguyên. Production/YouTube/API/UI/DB/lifecycle không sửa.

Hai finding đóng **trong offline**. Runnerlive và defaultdriver vẫn source-disabled; chưa mở nhiệm vụ nguồn. Để mở lượt riêng: kiểm phiên bản/hashes final, wiring command/Compose dưới actual guards, offline đúng code nếu wiring thay đổi, rồi chỉ mẫu1 một analyze≤2metadataGET/redirect0/30s/8–16MiB. Metadata đủ mới conditional1MP4GET/redirect0/180s/250–200MiB, cachedimage/own-egress/TLS/SSRF/608MiB total như cũ. PacketPASS chưa đủ; worker phải exit0 và file phải qua contract mới. Lỗi/deadline/nonzero/container/duration/CDN thì dừng và dọn ownoutput, không retry/mẫu2/3.

Nếu có tệp TikTok thật hợp lệ sau này, còn phải xem hình và nghe tiếng, kiểm watermark TikTok trên toàn tệp, giữ logo tác giả. Một tệp hoặc fixturePASS vẫn chưa nghiệmthu ba mẫu/no-buttonAPI E2E/TikTokmain/mọilink. Lượt này TikToksource0/download0, actualTikTokfile/visual/audio/watermarkNOT_RUN.
