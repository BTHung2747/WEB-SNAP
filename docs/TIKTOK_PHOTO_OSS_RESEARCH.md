# Nghiên cứu mã nguồn mở tải ảnh TikTok và phương án WED SNAP

Ngày12/10/2026. **RESEARCH_COMPLETE_PLAN_ONLY_NO_RUNTIME_CHANGE.** Đã đọc mã nguồn,
dependencies, giấy phép, commit và mẫu kiểm thử của các dự án chính thức. Không
cài thư viện, chạy downloader bên ngoài, gọi TikTok/CDN, sửa code chức năng hay
cấp lượt nguồn mới. Ảnh thật của WED SNAP vẫn chưa tải được.

**Đề xuất:** tiếp tục dùng bộ phân tích ảnh Cobalt đã ghim, lấy gallery-dl làm
nguồn đối chiếu và phương án adapter thay thế có điều kiện. Sửa lớp tích hợp DNS/
biên nhận của WED SNAP trước khi đổi bộ lấy ảnh. Không tự viết lại parser hay
downloader album, không chuyển toàn bộ dự án sang một stack mới.

## Các dự án thực sự có mã xử lý ảnh

| Dự án/phiên bản đã đọc | Bằng chứng chức năng | Phù hợp với WED SNAP |
|---|---|---|
| Cobalt API11.7.1, commit a636575b09de1fc55d9b8cd98cac88f5f2f16b42 | tiktok.js lấy webpage dạng /video/ kể cả photo, đọc hydration itemStruct.imagePost.images, trả picker ảnh từ imageURL.urlList | Lựa chọn chính: parser này đã có trong lab ảnh, cùng commit upstream vừa đọc; Node hiện có, không thêm dependency |
| gallery-dl1.32.16 trong snapshot GitHub ef30ea97c68d0d03ec49bd810ffe3fb4965559b7 | TiktokPostExtractor nhận photo/video; items duyệt imagePost.images, phát từng URL ảnh; HttpDownloader dùng Requests tải tệp; test/results/tiktok.py có single/many/few photos và shortlinks | Đối chiếu tốt nhất và dự phòng cho extractor ảnh; Python≥3.8/Requests phù hợp tĩnh với lab3.11.2, chưa cài hay benchmark |
| TikTokDownloader, nay DouK-Downloader5.8, commit473c90ff70c663cfb69310fff2b8d5192f200661 | extractor nhận imagePost.images, tạo downloads từ imageURL.urlList; src/downloader/download.py chuyển album tới download_image/request_file | Có triển khai ảnh đầy đủ ở code, nhưng Python≥3.12/curl_cffi và stack riêng không khớp lab3.11.2; dùng tham khảo, chưa chọn tích hợp |
| F2 main7dab3e… và default devf6be8c… | TikTok dl.handler_download hai bản đã đọc xử lý video/music/cover; chưa thấy vòng tải imagePost album. Không coi ignore_fields.images hay tính năng ảnh Douyin là bằng chứng ảnh TikTok | Không chọn làm backend ảnh dựa README. Dev chưa đồng nghĩa bản PyPI; thêm HTTPX/curl_cffi/DB và nhiều dependency |

Các nguồn chính thức:

- [Cobalt TikTok exact commit](https://github.com/imputnet/cobalt/blob/a636575b09de1fc55d9b8cd98cac88f5f2f16b42/api/src/processing/services/tiktok.js),
  [package API](https://github.com/imputnet/cobalt/blob/a636575b09de1fc55d9b8cd98cac88f5f2f16b42/api/package.json).
- [gallery-dl extractor](https://github.com/mikf/gallery-dl/blob/ef30ea97c68d0d03ec49bd810ffe3fb4965559b7/gallery_dl/extractor/tiktok.py),
  [photo test definitions](https://github.com/mikf/gallery-dl/blob/ef30ea97c68d0d03ec49bd810ffe3fb4965559b7/test/results/tiktok.py),
  [HTTP downloader](https://github.com/mikf/gallery-dl/blob/ef30ea97c68d0d03ec49bd810ffe3fb4965559b7/gallery_dl/downloader/http.py),
  [CLI options](https://github.com/mikf/gallery-dl/blob/ef30ea97c68d0d03ec49bd810ffe3fb4965559b7/gallery_dl/option.py),
  [package requirements](https://github.com/mikf/gallery-dl/blob/ef30ea97c68d0d03ec49bd810ffe3fb4965559b7/setup.py).
- [DouK image extraction](https://github.com/JoeanAmier/TikTokDownloader/blob/473c90ff70c663cfb69310fff2b8d5192f200661/src/extract/extractor.py),
  [image download](https://github.com/JoeanAmier/TikTokDownloader/blob/473c90ff70c663cfb69310fff2b8d5192f200661/src/downloader/download.py),
  [requirements](https://github.com/JoeanAmier/TikTokDownloader/blob/473c90ff70c663cfb69310fff2b8d5192f200661/pyproject.toml).
- [F2 main TikTok downloader](https://github.com/Johnserf-Seed/f2/blob/7dab3e2ffffaa2535834d28fca99dbc2e89fa9d3/f2/apps/tiktok/dl.py),
  [F2 dev TikTok downloader](https://github.com/Johnserf-Seed/f2/blob/f6be8c0ffba9a127075bbeafe4838716650b6325/f2/apps/tiktok/dl.py),
  [dev requirements](https://github.com/Johnserf-Seed/f2/blob/f6be8c0ffba9a127075bbeafe4838716650b6325/pyproject.toml).

Đây là xác minh **có implementation và test definitions**, không phải chạy các
project trên link/mạng của người dùng. Không dự án nào được ghi là bảo đảm tải
mọi bài hoặc đã giải quyết DNS/SSRF/source contract riêng của WED SNAP.

## Duy trì, giấy phép và tài nguyên

Cobalt API có AGPL-3.0/Node≥18.17; commit upstream quan sát đúng bản WED SNAP đã
ghim, tiktok.js upstream mới tải SHA58d30356…39275 trùng frozen upstream. Bản lab
đã đổi local imports/no-stream và thêm observations theo PROVENANCE; không gọi
vendor đã sửa là byte-identical upstream. Chưa có căn cứ cần nâng Cobalt lúc này.

Gallery-dl có GPL-2.0, Python≥3.8 và required Requests≥2.11.0. Maintainer đã
[chuyển phát triển sang Codeberg](https://github.com/mikf/gallery-dl/issues/9374).
Snapshot GitHub1.32.16 không chứng minh code mới nhất ở Codeberg: branch API
Codeberg trả503 trong phiên. Phải kiểm release chính thức/commit Codeberg và
license trước một nhiệm vụ cài/tích hợp; không copy GPL code vào AGPL vendor rồi
coi đã kiểm tương thích. Public CLI có -j/--dump-json, --no-download, --range và
--config-ignore; chưa xác minh tích hợp runtime hoặc coi các flags đó một mình
đã đáp ứng analyze→userselect→prepare của WED SNAP.

DouK GPL-3.0/Python≥3.12/dependencies gồm curl_cffi/aiofiles/FastAPI; README nói
không còn duy trì thuật toán tham số ký. downloader có WRITE_BUFFER_SIZE100MiB
và tập hợp nhiều tasks; đây là cấu hình code, không số RAM thực đo. Cần đổi môi
trường/giới hạn nếu tích hợp, nên không phù hợp để thay ngay trên máy8GB.

F2 Apache-2.0; main Python≥3.10 nhưng pin websockets<13 xung đột lock17.1 hiện tại
nếu cài chung. Dev Python≥3.11 có curl_cffi, nhiều dependency và branch chưa chắc
đã phát hành. Không cài trọn bộ vì thấy cùng từ khóa TikTok/ảnh. Sửa lời nhận
định thăm dò ban đầu: đã đọc F2 để khảo sát, chưa chứng minh nó tải album ảnh
TikTok ở hai nhánh kiểm tra; không xếp cùng nhóm đã xác minh như Cobalt/gallery.

Đánh giá tài nguyên là inference từ stack/dependency/cấu hình, chưa benchmark
CPU/RAM. Không chọn theo sao GitHub; các copyright/license đã lưu cùng reference.

## Cách các dự án giải quyết ảnh và phần có thể tham khảo

Cobalt/gallery/DouK cùng dùng dữ liệu bài đăng imagePost.images rồi lấy các URL
ảnh trong imageURL.urlList; downloader tải bytes từ CDN. Cobalt và gallery đổi
dạng URL photo sang video để đọc dữ liệu webpage. WED SNAP đã làm cùng luồng:
labs/tiktok/photo/worker.py dùng high-level yt-dlp lấy body, picker.mjs gọi
vendored Cobalt để phân tích body trong RAM, rồi tải1 ảnh được chọn bằng Requests/
yt-dlp networking đã có. Đây đã là tái sử dụng mã nguồn mở, không parser tự nghĩ.

Khác biệt cần theo dõi: Cobalt chọn candidate chứa .jpeg?; gallery dùng candidate
đầu và không buộc suffix đó. Nếu sau khi thông DNS có metadata imagePost nhưng
không có candidate JPEG mà Cobalt hỗ trợ, đây mới là căn cứ so sánh extractor.
Không tự sửa suffix/query của URL ký, không đoán endpoint, không âm thầm nhận
WebP/PNG vào hợp đồng JPEG. Lưu fingerprint/index/dimensions, URL chỉ RAM; kiểm
MIME/magic/full decode với FFmpeg đang có, rồi review ảnh thật.

Gallery extractor có hành vi thử JS challenge thêm ngay cả khi retries0. Vì
vậy thay toàn bộ CLI không tự giữ quota HTTP/deadline/redirect/CSRF/session của
WED SNAP. Chỉ xem là adapter dự phòng cần chứng minh ở lab, không chạy vô hạn
retry, solver, scan profile hoặc tải sẵn toàn album. Tải theo URL ảnh cũng chưa
chứng minh không có watermark TikTok; phải xem ảnh nguồn thật, giữ logo tác giả.

## Vì sao đổi downloader chưa giải quyết được lần FAIL của ta

Lượt TikTok thật cuối: DNS inspector ghi129 raw/40 endpoint/89 duplicates nhưng
source connector còn RAW64-v3 nên ANSWER_CAP trước origin TCP/HTTP/metadata;
imageGET0/JPEG0. Raw rows không lưu; không thể suy40IP/nguyên nhân89duplicates.
Đây là evidence ở lớp kết nối, chưa có body bài ảnh để quy lỗi cho Cobalt.

PoC v4 offline đã tải JPEG giả lập khi validate raw≤256 rồi dedup fullkey≤64.
Nó chưa nối vào nguồn và còn F-V4-OUTER-ADMISSION-TYPED-LINK P2: outer admission
sai bool/float vẫn qua finalizer. Project ngoài không có schema biên nhận riêng
của WED SNAP để thay trực tiếp phần này. Dùng stats_valid sẵn có để sửa integration
là phạm vi nhỏ có căn cứ; chưa sửa trong phiên nghiên cứu này.

## Kế hoạch đề nghị, theo thứ tự

1. **Harden integration offline:** successor riêng, reuse stats_valid cho outer
   dnsAdmission trước equality; giữ classifier/stdlib/HE2.7.1/Cobalt/Requests và
   contracts. Chỉ regress counterexamples đã có +typed control/missing bytes/
   owned-output cleanup, không mở một matrix rộng không cần thiết.
2. **Review độc lập rồi wiring offline:** nối DNS v4 đã nghiệm thu vào successor
   photo source candidate, default source off. Chứng minh private/invalid suffix,
   code/runtime hash, late deadline/cleanup và whole fixture. Không sửa accepted
   source/claims, không đổi parser, TLS hay main. Lưu nhiệm vụ wiring riêng.
3. **Một thử nguồn thực có phạm vi riêng:** sau review và khi người dùng giao
   riêng, tạo quyền mới đúng quy trình;1 metadata workflow +conditional ảnh index1
   của bài mẫu hiện có, giữ2metadata GET/1image GET và toàn bộ byte/deadline/SSRF.
   Hai allocations cũ đã consumed, không reset hoặc tự retry. Ghi native exit,
   metadata ID/photo/count, tệp MIME/full decode/SHA và review ảnh thật/watermark.
4. **Chỉ đổi extractor khi có lỗi metadata được chứng minh:** nếu DNS/TCP/TLS đã
   thông nhưng body không được Cobalt phân tích, dùng snapshot/body được phép
   giữ an toàn để đối chiếu gallery-dl official pinned release trong lab riêng.
   Nếu thư viện thực sự giải quyết được trường hợp đó và qua license/resource/
   request-budget checks, viết adapter tối thiểu qua public CLI/API; không copy
   private helpers hay tự viết lại parser. Nếu không, báo đúng HTTP/status/schema
   evidence, không đoán blocker hoặc mua API ngoài.
5. **Mở sản phẩm sau source evidence:** tải từng ảnh được chọn, giữ index/order/
   dimensions, session–job–lease/CSRF/native download; gallery/UI/API E2E cần nhiệm
   vụ tích hợp riêng. Không coi source1JPEG là đã hỗ trợ mọi ảnh/album/nền tảng.

Phương án1–3 là đường ngắn nhất theo evidence hiện có; đó là nhận định thiết kế,
không cam kết Cobalt chắc chắn tải link này sau khi sửa DNS. gallery-dl là đối
chiếu/dự phòng có điều kiện, DouK/F2 không được cài hoặc chuyển stack hiện tại.

Evidence research: docs/evidence/tiktok-photo-oss-research-20261012/, heads/
official references/39 captures200/failed captures/cobalt-parity/runtime-protected,
docs successor và manifest. Không chạy functional tests/benchmark/source trong
research. P2 vẫn OPEN, source ảnh FAIL/JPEG0/visualNOT_REVIEWED, video2/3/mẫu3pending/
galleryOFF/API E2E/deploy giữ. Prompt kế tiếp chỉ giao bước1 offline, không quyền nguồn.

Ghi nhận công cụ bảo toàn evidence: verifier nghiên cứu lần1 có giả định số file >2000 sai (scope thực1097), đã lưu FAIL nguyên bản. Verifier successor kiểm đúng tập đường dẫn1097 và toàn bộ hashes, output tên mới; không thay code, nguồn hoặc kết luận chức năng. Đây không phải một lần tải/test TikTok.

Lần verifier2 đổi tên output quá rộng khiến tham chiếu receipt parent sai đường dẫn; FAIL2 cũng giữ nguyên. Verifier3 chỉ đổi đường dẫn output/exclusions riêng, bảo toàn tham chiếu parent và đưa cả hai FAIL vào coverage. Không chạy test chức năng hay nguồn trong các lần kiểm hash này.

