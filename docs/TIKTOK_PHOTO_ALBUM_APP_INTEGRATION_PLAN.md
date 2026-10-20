# Kế hoạch tích hợp tải từng ảnh TikTok vào ứng dụng

Ngày15/10/2026. Trạng thái: **READ_ONLY_PLAN_COMPLETE — chưa triển khai tích hợp**. Phạm vi lần này là đọc mã/lockfile, đối chiếu API chính thức và viết tài liệu. Không test chức năng, gọi TikTok/CDN, tạo claim, chạy Docker, cài dependency hoặc sửa runtime.

## 1. Cơ sở nghiệm thu và quyết định sản phẩm tối thiểu

Mẫu album7678209751167110421 đã đạt kỹ thuật và human visual cho đúng5JPEG: chủ xác nhận xem đủ5ảnh, đúng/đầy đủ nội dung và không thấy watermark TikTok thêm vào. Xem [successor human](evidence/tiktok-photo-album-mount-all5-human-visual-20261015/ASSESSMENT.md), [human review gắn SHA](evidence/tiktok-photo-album-mount-all5-human-visual-20261015/human-review.json), [source audit](evidence/tiktok-photo-album-mount-all5-source-audit-20261015/ASSESSMENT.md). Không còn chờ review5ảnh này. Các nhãn NEEDS_VISUAL_REVIEW/contentIdentityUNKNOWN trong raw cũ giữ nguyên vì là snapshot trước phản hồi chủ. Một album không chứng minh mọi URL, shortlink, app/gallery/API E2E hoặc cho phép lượt nguồn mới.

Chọn MVP **mỗi job chuẩn bị và tải một JPEG được chọn trong album**, không ZIP, tải cả album, nhạc nền hoặc chuyển ảnh thành video. Album metadata có thể chứa1–50ảnh; chọn một index bất kỳ hợp lệ. Muốn ảnh khác sau prepare phải tạo job analyze mới. Không tái sử dụng job đã có asset để thay file: ticket hiện gắn job, asset chỉ có một trên mỗi job, transfer lease có thể vẫn đang giữ tệp cũ.

Quyết định này giữ CLI hai child analyze/prepare và mô hình DB/API hiện có; không cần migration cho MVP. Hỗ trợ nhiều ảnh dưới cùng job cần thiết kế asset/ticket/ownership khác, nằm ngoài kế hoạch tối thiểu này. Giữ ảnh nguyên bản và chữ/logo tác giả; không crop/blur/transcode.

## 2. Bản đồ mã thực có và phần cần nối

Đường dẫn trong bảng là source trên Windows; đường dẫn `/app/...` là vị trí trong container, không phải thư mục app mới.

| Mã đang có | Hành vi quan sát từ đọc mã | Thay đổi dự kiến tối thiểu |
|---|---|---|
| `D:\WED SNAP\apps\media\src\media_adapter.py` | Dispatch TikTok qua `TIKTOK_ADAPTER_ENABLED=1`; YouTube dùng nhánh hiện có | Sau core offline mới dispatch ảnh có cờ riêng, giữ nhánh video/YouTube |
| `D:\WED SNAP\apps\media\src\tiktok\adapter.py`: `input_id`, `owned_folder`, `execute`, `main` | Chỉ URL `/@author/video/id`, video≤600s; fresh metadata mỗi child; output `media.mp4`; cleanup theo UUID | Core ảnh riêng, đầu vào `/photo/id`, output cố định `image.jpg`, không sửa contract MP4 |
| `D:\WED SNAP\apps\media\src\tiktok\core.py`: `Budget`, `BoundedBody`, `GuardedYDL` | yt-dlp API mức cao, Requests Session RAM, fixed own-egress, verify TLS, retry/redirect0, decoded caps trong lúc đọc | Dùng lại HTTP/cookie/observer; thêm policy JPEG có cap riêng, không viết transport khác |
| `D:\WED SNAP\apps\media\src\tiktok\validate_cobalt_body.mjs` và `vendor\tiktok.js` | Resolver pinned đã có photo picker nhưng validator hiện từ chối picker/imagePost; photo return chưa có annotation `.lab` như lab | Bridge ảnh riêng gọi cùng resolver; delta annotation id/count/dimensions tối thiểu, giữ logic picker upstream |
| `D:\WED SNAP\apps\media\src\tiktok\candidate_file.py`, `prepare_operations.py` | Validator MP4; Operations/native/deadline và logging đã có | Tái dùng Operations; tách JPEG contract, không gọi validator MP4 cho JPEG |
| `D:\WED SNAP\labs\tiktok\photo-album-authority-mount-fix\photo-runtime\picker.mjs`, `worker.py:contract` | Cobalt từ body RAM; JPEG magic,2ffprobe,1frame/mjpeg/dimensions, full decode | Port đúng các hàm hợp đồng và bridge, không port worker/runner |
| `D:\WED SNAP\labs\tiktok\photo-album-authority-mount-fix\runtime\album_contract.py`: `summary`, `validate_summary`, `selection` | Public count/index/dimensions/itemKey/snapshotKey, không cần giữ signed URL | Tách phần thuần phục vụ single selection; không mang Ledger all5/authority vào app |
| `D:\WED SNAP\labs\tiktok\photo-album-authority-mount-fix\runtime\album_worker.py`, `album_budget.py` | Lab giữ child/session qua stdin giữa metadata→prepare; sample/author hardcoded; có all5 policy | Chỉ tham khảo thứ tự/library calls. App phải hai child độc lập và fresh metadata, không copy worker |
| `D:\WED SNAP\apps\worker\src\adapter.ts`: `runAdapter` | ProcessGroup, timeout, cancellation, stdout cap, chờ native exit0/group đóng trước nhận JSON | Giữ; thêm nhận diện contract ảnh ở processor, không coi packet PASS là child exit0 |
| `D:\WED SNAP\apps\worker\src\processor.ts`: `processJob` | Analyze tạo một MediaItem kind video; staging/output/validation hardcode `media.mp4` | Phân nhánh kind đã allowlist, lưu public photo formats, chọn fixed output theo stored kind; cùng lifecycle |
| `D:\WED SNAP\apps\worker\src\lifecycle.ts`, `main.ts` | Worker concurrency1; cancel/expired, lease/worker/group kiểm trước xóa UUID folder | Giữ nguyên quy tắc; kiểm hồi quy liên quan tới ảnh |
| `D:\WED SNAP\apps\api\src\services\jobs.service.ts` | Ownership/CSRF/admission/metadataTTL; prepare item+format; format khác sau prepareKey → IDEMPOTENCY_CONFLICT | Dùng một item album và N format ảnh; không cho đổi ảnh trên job đã prepare; không tạo preview URL khi chưa có preview file |
| `D:\WED SNAP\apps\api\src\validation.ts`: `prepareSchema` | `formatId`≤80 ký tự, regex chữ/số/gạch dưới/gạch nối và dấu cộng có giới hạn | Giữ request shape; format ảnh mới phải nằm trong80 và so với format lưu server |
| `D:\WED SNAP\apps\api\src\services\downloads.service.ts`: `download` | Ticket/job→asset; Range, HEAD local, lease và quota; MIME `video/mp4`, filename video hardcode | Allowlist mapping cố định `media.mp4→video/mp4`, `image.jpg→image/jpeg` cho cả HEAD/GET; không lấy MIME/path/filename từ client |
| `D:\WED SNAP\apps\api\src\auth\session.ts`, `services\session.service.ts` | Cookie session hash, CSRF, supported theo platform; chưa tách loại nội dung | Dùng capability photo từ flag server cùng verified platform; platform TikTok video không tự quảng cáo photo |
| `D:\WED SNAP\packages\shared\src\core.ts` | Limits, canonical URL/platform, metadataTTL, lockJob/lockAsset, path containment, queue attempts1 | Kiểu photo public strict; deadline không heartbeat-renew; guard đường dẫn/locks không thay |
| `D:\WED SNAP\prisma\schema.prisma` | MediaItem kind String/formats JSON; TemporaryAsset.jobId unique; ticket job-bound | Một album item/Nformats, một JPEG/job: không migration. Không biến thành multiasset ngầm |
| `D:\WED SNAP\apps\web\src\pages\Home.tsx`, `types.ts`, hooks vòng đời/tải | Chọn formats của item đầu; states/native link đã có; label/duration thiên video | Bước UI sau: chọn index ảnh, duration null, giữ native link/cancel/states; phải đọc Taste Skill trước sửa UI |
| `D:\WED SNAP\apps\egress\src\egress.py`: `public_addresses`, CONNECT/connect | Kiểm mọi IP global, allowlist, chỉ CONNECT443; getaddrinfo và connect tuần tự | Chưa tương đương DNSv4/connector đã kiểm lab; cần port có giới hạn trước nguồn/API E2E, xem mục6 |

**Không có thư mục source `D:\WED SNAP\apps\media\src\tiktok\source_photo`.** Trong lab, `/app/apps/media/src/tiktok/source_photo` là mount của `photo-runtime` nêu trên. Không được ghi nhận mount đó là core ảnh đã tích hợp sản phẩm.

## 3. API thư viện, pins và lý do chỉ viết glue

Không cần dependency mới cho bước core ảnh đầu tiên. Dùng các module/thư viện hiện tại:

- Cobalt commit **a636575b09de1fc55d9b8cd98cac88f5f2f16b42**, AGPL-3.0, [resolver chính thức](https://github.com/imputnet/cobalt/blob/a636575b09de1fc55d9b8cd98cac88f5f2f16b42/api/src/processing/services/tiktok.js) đã xử lý imagePost/picker. Giữ LICENSE/NOTICE/PROVENANCE, ghi delta projection, không viết parser HTML/TikTok extractor mới hoặc nhập cả Cobalt app. Picker chọn JPEG, không tự fallback định dạng khác/audio.
- yt-dlp **2026.08.19**: [YoutubeDL chính thức](https://raw.githubusercontent.com/yt-dlp/yt-dlp/2026.08.19/yt_dlp/YoutubeDL.py) hỗ trợ `extract_info(...,download=False,ie_key='TikTok',process=False)`; [TikTokIE đúng tag](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/extractor/tiktok.py) matcher video. Vì vậy photo URL đầu vào được đổi rõ ràng sang `/@author/video/{id}` chỉ để lấy metadata theo đúng cách lab đã đo; không thử cả hai URL hoặc resolve phụ. Cobalt kiểm bodyID/imagePost. Khi TikTokIE không trả video cho imagePost, chỉ dùng body cuối đã đọc an toàn nếu không có lỗi budget/transport; không nuốt lỗi mạng/cap/deadline.
- Requests **2.34.2**: [HTTPAdapter.send chính thức](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py), [Session/cookie API](https://github.com/psf/requests/blob/v2.34.2/src/requests/sessions.py). Dùng lại Session/adapter/Requests cookiejar/stream read của GuardedYDL; không viết HTTP/TLS/cookie engine. Signed URL/cookie ở RAM từng child, xóa khi close, không log pathname/query/header/body HTML.
- urllib3 **2.8.0**: [Timeout API đúng phiên bản](https://urllib3.readthedocs.io/en/2.8.0/reference/urllib3.util.html). `total/connect/read` chỉ giới hạn hoạt động thư viện; vẫn cần deadline tuyệt đối bằng parent/Operations, cap khi đọc và clamp thời gian còn lại.
- JPEG: dùng FFmpeg/ffprobe CLI đang có và `hashlib`/Operations hiện có. Lab dùng `imghdr` Python3.11 để xác nhận JPEG; stdlib này đã deprecated và bị loại ở3.13, nên không nâng Python tùy ý. Không thêm Pillow chỉ để kiểm ảnh nếu contract hiện tại đủ. Không coi đuôi `.jpg` là bằng chứng container/codec. Không có phép đo phiên bản binary FFmpeg mới trong nhiệm vụ đọc mã này; Dockerfile cài apt chưa khóa số phiên bản package. Bước chạy lab tiếp phải capture version/image thực, không bịa pin hash FFmpeg.

Lock hiện tại: `D:\WED SNAP\apps\media\requirements.lock` khóa số phiên bản nhưng **không phải hash lock**: requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/brotli1.2.0 cùng dependencies hiện có. `tiktok/package-lock.json` có integrity cho undici6.24.1/set-cookie-parser2.7.2/@imput/psl2.0.4/url-pattern1.0.3/punycode2.3.1. Không đổi lock trong kế hoạch này. Root lock giữ React19.1.1/Vite7.3.6/Zod3.25.76/Prisma6.19.0/BullMQ5.81.5/Nest11.2.7; không cần framework mới.

Glue cần tự viết vì thư viện không cung cấp hợp đồng WED SNAP: public fingerprint không bí mật, chọn đúng một index, fresh prepare so snapshot, UUID ownership/output allowlist, policy byte/deadline, mapping MediaItem/asset/native MIME. Đây không phải lý do viết parser/solver/transport mới. Không dùng browser, account cookie, solver hoặc dịch vụ tải ngoài.

## 4. Hợp đồng đề xuất — chưa phải API/code hiện hành

**Đầu vào MVP:** canonical HTTPS `https://www.tiktok.com/@author/photo/{id}` với ID15–22 chữ số; không credentials/port tùy ý/query/fragment. Chỉ normalize metadata path một lần như mục3. Shortlink chưa hỗ trợ trong core ảnh này; nhánh `/video/` giữ contract video hiện có. URL người dùng nhập là canonical public post, không signed media URL.

**Analyze child:** tạo fresh RAM session, tối đa2GET metadata. Cobalt xử lý body đã giới hạn trong RAM bằng bridge Node không có network. Xác minh bodyID bằng inputID, imagePost/private/count1–50, từng image HTTPS/443 và dimensions theo contract đã kiểm. Chỉ phát public summary/formats, không phát image URL hoặc cookie ra API/DB/web/log.

Summary dùng `version='tt-photo-album-v1'`, `id`, `type='photo'`, `imageCount`, `images=[{index,width,height,itemKey}]`, `snapshotKey`. Giữ canonical hashing của `album_contract.py`: itemKey ràng buộc id/type/index/dimensions; snapshotKey ràng buộc toàn summary. **Đây là fingerprint cấu trúc, không phải SHA nội dung ảnh.** Đổi ảnh/đảo thứ tự có cùng kích thước có thể không bị phát hiện. Resolver hiện chưa cung cấp stable photo ID đã xác minh để giải quyết giới hạn này; không tự bóc token từ signed URL, không tuyên bố đảm bảo pixel identity từ metadata.

Mỗi album tạo một MediaItem kind `photo`; formats là các lựa chọn index. Mỗi format có:

```text
id = ttp1_{index:02d}_{snapshotKey64}      # 72 ký tự, hợp lệ giới hạn80 hiện có
label = Ảnh {index}/{imageCount}
size = null
kind=photo, contentId, imageCount, index, width, height, itemKey, snapshotKey
mime=image/jpeg
```

Public analyze vẫn có title/duration/formats, bổ sung kind/schema strict; photo duration null, title an toàn từ metadata nếu có hoặc `Album TikTok`. Không trả private picker. Worker chỉ lưu allowlist public descriptor vào formats JSON; không spread object extractor. Không thêm thumbnail GET trong analyze; UI chưa có thumbnail thì không cấp preview URL giả.

**Prepare child riêng:** nhận source canonical và formatId đã thuộc item/job. Tạo session mới, trích xuất lại metadata≤2GET; xác minh bodyID/imagePost/count, snapshotKey toàn album, index/itemKey/dimensions đã chọn. ID/snapshot/format sai → FAIL trước GET ảnh. Không giữ analyze child, dùng cookie ngoài phiên hoặc lấy signed URL từ DB. FormatId mang full snapshot nhưng không mang thêm64ký tự itemKey vì sẽ vượt80; so itemKey theo public summary tái dựng và stored descriptor tại server.

Sau metadata hợp lệ, chọn đúng một URL trong private picker RAM, GET JPEG bằng GuardedYDL/Requests hiện có, redirect0/retry0/HEAD0. Mở `image.jpg.part` độc quyền trong UUID folder đã sở hữu, không symlink/overwrite/đường dẫn từ upstream; cap trong lúc đọc. JPEG contract gồm magic/MIME phù hợp, ffprobe codec mjpeg một stream, dimensions1–8192/pixels≤16M, framecount1, full ffmpeg decode; so dimensions với metadata và kiểm size/input counters. Hash SHA256, atomic rename sang `image.jpg` cùng filesystem sau contract. Packet chỉ `{file:'image.jpg',size,inputBytes,...public contract}`; chỉ thành công sau native child exit0 và ProcessGroup đóng. Mọi lỗi/kill/timeout dọn đúng `.part`/output do lượt đó tạo, không xóa output người khác hoặc file đang có transfer lease.

## 5. Ngân sách workflow hai child và vòng đời

Các con số dưới là thiết kế cho **một ảnh/job**, không kế thừa lab stateful2metadata+5JPEG. Thiết lập ứng dụng chặt hơn luôn thắng.

| Phạm vi | Trần đề xuất và cách enforce |
|---|---|
| Analyze | ≤2GET metadata, redirect/retry/HEAD0, deadline≤30s; decoded≤8MiB/response,≤16MiB tổng; parent deadline độc lập event loop |
| Prepare metadata | Fresh≤2GET, subdeadline≤30s và không vượt prepare còn lại; decoded8/16MiB, không reset counters để giấu metadata input |
| Prepare JPEG | Conditional đúng1GET; decoded input≤20MiB, output≤16MiB; response policy JPEG phải tách khỏi default8MiB metadata |
| Tổng prepare | ≤180s gồm fresh metadata/download/contract/full decode/hash/exit; input≤min(appMaxInput,36MiB), output≤min(appMaxOutput,16MiB) |
| Item | Download/contract window≤60s và≤prepareEnd−10s; không đủ reserve thì FAIL trước spawn; decode dùng contract ảnh hiện tại≤30s, clamp còn lại, không bỏ full decode |
| HTTP | connect≤10s/read≤20s, clamp theo phase/item còn lại; absolute parent cap không bị callback/blockingread vượt |
| Toàn workflow | ≤2+2+1=5GET, decoded input≤52MiB, output≤16MiB; không preview/audio/resolve phụ; không tự retry khi thiếu nguồn |

Core metadata/JPEG phải dùng bộ đếm shared trong mỗi child và decoded streaming, không chỉ Content-Length. App worker parent vẫn enforce app input/output/disk/process/time/cancel ownership. Mọi request và redirect reject qua own-egress, không bypass proxy khi fixture/session thay thế bị dùng sai môi trường.

State mapping giữ `idle→analyzing→selectable→queued→preparing→ready`, lỗi→failed, cancel→cancelled, owner/metadata/asset hết hạn→expired. Photo selectable có N lựa chọn nhưng mỗi job chỉ chọn một. MetadataTTL không gia hạn bởi heartbeat; chuẩn bị phải fresh revalidate. Job/session hết hạn không được cắt native transfer lease đang hợp lệ; sweeper vẫn khóa job→asset, đợi ProcessGroup và lease đóng trước xóa. `ready`/server_finished không chứng minh browser đã lưu tệp.

Giữ session cookie, Origin/x-csrf-token, item/job ownership, idempotencyKey và admission/monthly quota. Sửa index/snapshot/formatId bằng client phải bị so với stored item trước child. Không cho dùng cùng idempotencyKey để đổi ảnh, không thay asset khi ticket cũ tồn tại. HEAD ở download API chỉ đọc asset local, không HEAD nguồn.

Tài nguyên: lab nguồn trước chứng minh worker512MiB/CPU0,75+egress96MiB/CPU0,25=608MiB. **App Compose hiện worker768MiB/CPU1**, còn Node worker/API/DB/Redis có phần riêng; không suy tổng app608MiB từ lab Python. Bước tích hợp thử riêng tuần tự, đo RAM thực dưới cap đã giao, không chạy thêm stack/build đồng thời trên8GB. Thiếu tài nguyên phải báo số đo, không tự nới. Không đổi main Compose ở bước đầu.

## 6. Khoảng trống proxy cần giải quyết trước nguồn app

Stock egress kiểm tất cả IP public, nhưng chưa có raw256→ordered unique64, DNS subprocess cancellation/IPC/reap, HE socket≤2/policyC hay deadline setup10s toàn nhóm như lab đã nghiệm thu. Connect timeout10 cho từng IP tuần tự không tương đương cả setup10. Không được coi app đã đạt bảo vệ lab nhờ dùng cùng tên service `egress`.

Phương án sau core: tách module DNS admission/connector/ownership đã kiểm từ lab để gọi trong **egress hiện có**, giữ CONNECT parser/tunnel/TLS và allowlist; không mang source authority/stage_control/fixed lab paths/runner/claims vào sản phẩm, không dựng proxy thứ hai ngoài kiểm soát. Dùng [aiohappyeyeballs2.7.1 public start_connection](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/impl.py), giấy phép từ vendor hiện có; hiện dependency này chưa nằm trong app lock. Việc port/pin/hash/build phải là bước được giao riêng, không thuộc core bước1 và chưa cài trong phiên này.

Giữ kiểm **mọi raw row≤256 trước dedup**, reject private/malformed ở bất kỳ row, unique≤64 giữ thứ tự, setup10s chia nhóm policyC, socket/helper/thread registry đóng thực, trace thiếu/mâu thuẫn fail-closed và cleanup không phụ thuộc trace callback. Không tăng64/timeout hoặc bỏ kiểm DNS row trùng. Fixture phải dùng loopback trong namespace offline riêng, không cho phép loopback trong policy nguồn.

CONNECT HTTPS không thấy path; policy theo hostname TikTok/CDN có thể ảnh hưởng cả TikTok video. Phải đánh giá/kiểm hồi quy video liên quan, không hứa chỉ ảnh bị tác động. Nhánh YouTube/domain ngoài phạm vi giữ hành vi. Capability photo chỉ được coi source-ready sau parity proxy đã review, image/deps đúng hash và offline pipeline đầy đủ; không phải điều kiện để viết module thuần offline bước1.

## 7. Chia bước triển khai và điều kiện hoàn tất

1. **Core ảnh chưa nối entrypoint (bước code kế tiếp):** port nhỏ hợp đồng/picker/JPEG vào media module mới; dùng GuardedYDL/Operations. Không đổi adapter/CLI/API/worker/web/DB/Compose. Offline module analyze→fresh prepare với body fixture và JPEG thật qua thư viện, fake source có kiểm request/cap. Đạt khi đúng ID/selection/budgets/native exits/full decode/SHA/cleanup, video module cũ nguyênbyte trừ delta projection resolver có regression hẹp.
2. **Nối CLI/worker/API default-off:** cờ `TIKTOK_PHOTO_ENABLED=0` kết hợp existing TikTok flag+verified platform; CLI hai child, allowlist output; processor public metadata/kind; API chọn format và native HEAD/GET JPEG MIME/filename. Giữ request prepare shape/DB schema một asset/job. Test fixture xuyên CLI→worker→API bằng dữ liệu/volume/namespace riêng; không settings/main data. Cờ tắt phải từ chối ảnh trước network và không quảng cáo capability; video/YouTube liên quan không đổi.
3. **Port egress bảo vệ đã chứng minh:** phạm vi mục6, khóa dependency nếu được giao, image lab riêng nếu cần. Offline DNS mixed/public/private/duplicates/overcap/deadline, proxy/TLS delayed cases, socket losers/reuse/origin/registry closure/cancel/trace-error; whole metadata→JPEG thực qua proxy. Không lặp hàng trăm historical cases không liên quan; chọn bộ kế thừa trực tiếp và delta chính xác.
4. **Luồng chọn ảnh trên web và nghiệm thu offline:** đọc Taste Skill trước sửa; tận dụng trang/hooks/native link hiện có, không redesign. Test chọn ảnh, không thumbnail giả, disabled capability, mobile/keyboard/focus/reduced-motion; API/worker contract+CSRF/ownership/idempotency/tamper/TTL/cancel/process-kill/lease/Range/MIME/cleanup. Tạo job mới để đổi ảnh; không tải cả album ngầm. Fixture không là nguồn thật.
5. **Đề xuất E2E nguồn riêng sau review:** chỉ sau1–4 đạt; một canonical album/một index, budget2+2+conditional1, hash image/source chính xác, actual exits/counters/time/cleanup/file decode/SHA/human visual. Chủ phải giao nguồn cụ thể; không dùng human visual đã có làm quyền tải mới. Lỗi dừng, không fallback/retry. App/source E2E đạt vẫn không tự bật main hoặc deploy; activation là bước riêng.

Bộ kiểm cần thiết xuyên các bước: wrong/missing bodyID, private/nonphoto, count/index/dimensions/snapshot invalid, same-dimension identity limitation ghi rõ; expired metadata/source; token URL không lọt stdout/stderr; late/PASS→exit20/PASS→hang; JPEG giả đuôi/MIME/oversize/truncated/multiframe/dimensions mismatch/full decode error; app strict limits nhỏ hơn lab; two-child session tách/no persisted secret; groupkill/cancel/cleanup đúng ownership và lease. Tất cả dựa fixture/local media, không nguồn thật để sửa lỗi contract.

Trở ngại code thực: core chưa hỗ trợ imagePost; worker/API MIME/output hardcode video; egress chưa parity; web chưa mô tả loại photo. Không có blocker visual mẫu5ảnh nữa. Chưa có stable upstream image identity và chưa đo full app RAM là giới hạn bằng chứng, không được che bằng fixture PASS. Thiếu quyền source/deploy không phải lỗi code.

## 8. Prompt cho bước code nhỏ kế tiếp — chưa thực hiện trong phiên kế hoạch

> Làm việc tại D:\WED SNAP. Đọc AGENTS.md, PLAN_WORKFLOW_VIDEO_DOWNLOADER_V1.md, STRUCTURE, AUDIT/PROGRESS mới nhất và docs/TIKTOK_PHOTO_ALBUM_APP_INTEGRATION_PLAN.md. Triển khai bước1: core ảnh TikTok ở apps/media/src/tiktok bằng module mới, chưa nối vào media_adapter.py/adapter.py hoặc ứng dụng đang chạy.
>
> Tách phần thuần từ labs/tiktok/photo-album-authority-mount-fix/runtime/album_contract.py thành photo_contract.py (summary/strict validation/single selection/formatId72ký tự, không Ledger/all5 authority), photo_picker.mjs từ body bridge/picker hiện có, photo_file.py từ JPEG contract, photo_core.py cung cấp analyze_album/prepare_photo dùng GuardedYDL/Requests/Operations hiện có. Chỉ thêm delta annotation photo id/resolvedPostId/privateItem/dimensions ở vendor/tiktok.js nếu cần; không đổi thuật toán picker upstream/video branch. Giữ LICENSE/NOTICE/PROVENANCE và ghi file nguồn/delta đúng commit Cobalt a636575b09de1fc55d9b8cd98cac88f5f2f16b42. Không copy worker/runner/claims/sampleID/author/paths/fixture vào runtime.
>
> Hai hàm chạy như hai phiên độc lập: prepare fresh metadata kiểm bodyID/count/snapshot/index/itemKey, signed URL/cookie chỉ RAM. Chỉ canonical /@author/photo/id; normalize metadata path một lần theo matcher TikTokIE đã ghim. Ngân sách analyze≤2GET/30s/8–16MiB; prepare≤2GET metadata trong30s+conditional1GET JPEG, tổng180s/input36MiB/output16MiB hoặc giới hạn app thấp hơn; JPEG20MiB input, deadline item60s/prepare reserve10, HTTPconnect≤10/read≤20, redirect/HEAD/retry0. Default metadata cap8MiB không được áp nhầm JPEG. Không viết HTTP/TLS/parser/solver mới. Snapshot chỉ ràng buộc cấu trúc, không hứa pixel identity. Output image.jpg, exclusive .part, full JPEG contract/ffprobe/decode/SHA và cleanup đúng UUID ownership; parent chỉ PASS sau child exit0/group đóng.
>
> Kiểm offline hẹp trong lab/namespace evidence mới, dùng đúng source cuối và image cache phù hợp, không install/build/pull dependency trong bước này. Fixture fake HTTP adapter qua extractor/bridge/downloader/file contract; media nhỏ tạo bằng FFmpeg hiện có. Kiểm hai session tách, budgets/caps/deadline, ID/snapshot/index, tamper/JPEG sai, PASS→worker error/hang/cancel và cleanup. Giữ thư viện/pins hiện có; nếu image cache thiếu capability thì báo cụ thể, không lách bằng host install. Chạy tuần tự trên RAM8GB; runtime lab≤512MiB/CPU0,75 + proxy96MiB nếu cần (không tự tăng), rootfsRO/nonroot/capdrop/NNP và own-egress/SSRF/TLS hiện có. Fixture loopback chỉ namespace test, không nới policy nguồn.
>
> Không sửa CLI entrypoint/API/worker/web/shared/DB/Compose/settings/main/YouTube hoặc egress trong bước1, không source/cold/claim/reset/renew/retry TikTok/CDN hoặc gallery/deploy. Không chạy lại test lịch sử không liên quan. Evidence riêng lưu lệnh thực, image/version/source hashes, actual exits/counters/time, fixtures phân biệt nguồn thật; giữ tất cả raw/golden/manifest và docs insert chain. Cập nhật AUDIT/PROGRESS và bàn giao để review core; chưa tự làm bước2 hoặc gọi nguồn.

## 9. Bằng chứng lần lập kế hoạch

[Scope/inventory](evidence/tiktok-photo-album-app-plan-20261015/scope.json), [kết quả kiểm bảo toàn](evidence/tiktok-photo-album-app-plan-20261015/verification.json), [lệnh và phạm vi đọc](evidence/tiktok-photo-album-app-plan-20261015/READ_LOG.md). Hash before/after kiểm các source roots đã đọc và bốn hồ sơ source/audit/dispatch/human hiện hành. Đây là kiểm bảo toàn tài liệu/mã, **không phải test core ảnh, fixture pipeline, app E2E hoặc nguồn mới**. Không chạy lại verifier13768 lịch sử để lập kế hoạch; kết quả đó được dẫn từ reviewer audit nguyên trạng.
