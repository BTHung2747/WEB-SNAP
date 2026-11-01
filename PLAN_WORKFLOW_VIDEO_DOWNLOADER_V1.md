# PLAN & WORKFLOW — WEBSITE TẢI VIDEO/ẢNH ĐA NỀN TẢNG

Phiên bản 1.1 • Ngày 30/09/2026 • Tài liệu bàn giao cho Codex

## 0. Môi trường dự án và cách làm việc với Codex

- Tên thư mục dự án: WED SNAP (giữ đúng tên người dùng cung cấp).
- Đường dẫn Windows: `D:\WED SNAP`. Đây là thư mục trên máy người dùng, không phải thư mục đã được tạo bởi tài liệu này.
- Đặt tài liệu này tại `D:\WED SNAP\PLAN_WORKFLOW_VIDEO_DOWNLOADER_V1.md`. Tên file giữ nguyên để tránh hỏng tham chiếu; phiên bản nội dung hiện tại là 1.1.
- Máy phát triển: Windows, RAM 8 GB; Docker Desktop đã chạy thành công hello-world, dùng WSL 2.
- Giới hạn WSL đã được hướng dẫn, chưa xác nhận áp dụng: RAM 3 GB, 2 CPU logic, swap 2 GB, autoMemoryReclaim=gradual. Không tự sửa cấu hình toàn máy.
- Dùng Docker cho toàn bộ runtime và dịch vụ; không bắt người dùng cài thêm Node.js, PostgreSQL, Redis, yt-dlp hoặc FFmpeg trực tiếp trên Windows.
- Stack áp dụng cho bản kế hoạch này: TypeScript; React + Vite + Tailwind CSS; NestJS trên Node.js; PostgreSQL + Prisma; Redis + BullMQ; worker riêng; adapter đánh giá yt-dlp; FFmpeg; Docker Compose.
- Không áp dụng phương án hàng đợi PostgreSQL thay Redis từng được nêu khi chưa có Docker. Giữ Redis + BullMQ theo phương án Docker hiện tại.
- Đọc AGENTS.md và kiểm tra dữ liệu có sẵn trước khi sửa; không xóa hoặc ghi đè mã nguồn không liên quan.
- Nếu Codex chạy trên Windows, làm việc tại đường dẫn trên; nếu chạy trong WSL, kiểm tra đường dẫn gắn ổ thực tế (thường là `/mnt/d/WED SNAP`) trước khi dùng. Không giả định cloud Codex có quyền truy cập ổ D:. Nếu không thấy repository, báo rõ cần mở/tải repository vào môi trường đó.
- Đường dẫn có dấu cách phải được đặt trong dấu ngoặc kép trong PowerShell. Trong cấu hình container dùng đường dẫn Linux nội bộ, không hardcode ổ D:.

### Chạy local trên máy RAM 8 GB

- Có `compose.yaml` ngay tại thư mục gốc; project name Docker Compose dùng `wed-snap`, không dùng dấu cách.
- Các service gồm web, api, worker, postgres, redis. Worker local chỉ xử lý 1 tác vụ chuẩn bị cùng lúc; không build/test nhiều tác vụ nặng song song.
- Cung cấp `.env.example`, hướng dẫn tạo `.env`, tạo secret, migration và admin trước khi dùng. Không commit secret hoặc tài khoản mặc định.
- Node dependencies cài trong image/named volume Linux, không bind mount node_modules từ Windows; hỗ trợ hot reload mã nguồn theo cấu hình dev.
- CSDL và Redis có named volume phù hợp; video tạm có volume riêng với sweeper. Không dùng volume dữ liệu thật trong test phá hủy.
- Bind cổng phát triển vào 127.0.0.1; DB/Redis không publish mặc định. Đề xuất frontend `http://localhost:5173`; API truy cập qua proxy `/api` để đơn giản cookie. Codex kiểm tra cổng và ghi URL thực tế vào README.
- Đo RAM bằng docker stats, xác nhận tổng dịch vụ hoạt động dưới giới hạn WSL thực tế; nếu thiếu RAM, báo số liệu và điều chỉnh quy trình build/concurrency trước, không tự tăng giới hạn máy.
- Không tự mở Docker khi đăng nhập Windows; không cài công cụ bổ sung toàn máy mà không giải thích nhu cầu.

Lệnh sử dụng sau khi Codex đã tạo code, cấu hình Compose và hoàn tất hướng dẫn khởi tạo trong README:

```powershell
cd "D:\WED SNAP"
docker compose up -d --build
docker compose ps
```

Những lần làm tiếp, mở Docker Desktop trước, rồi:

```powershell
cd "D:\WED SNAP"
docker compose up -d
```

Khi nghỉ, lưu code và công việc trước, rồi:

```powershell
cd "D:\WED SNAP"
docker compose stop
```

Sau đó Quit Docker Desktop ở khay hệ thống và chạy `wsl --shutdown` trong PowerShell để dừng toàn bộ WSL. Không dùng `docker compose down -v` để nghỉ làm. Các lệnh Compose chưa dùng được khi mới chỉ có tài liệu, chưa có code và compose.yaml.

## 1. Mục tiêu và quyết định sản phẩm

Xây website tiếng Việt, dùng tốt trên điện thoại và máy tính, phục vụ tải video/ảnh từ đường dẫn công khai mà người dùng có quyền tải. Mục tiêu vận hành thật và kiếm tiền qua quảng cáo. Người dùng không cần đăng ký tài khoản để tải.

Các quyết định từ cuộc trao đổi:

- Nền tảng mục tiêu: TikTok, Facebook, YouTube và X. Chỉ bật nền tảng/loại nội dung đã kiểm chứng tải thật trên môi trường triển khai.
- Tự vận hành bộ xử lý; không bắt buộc mua API lấy video từ bên thứ ba.
- Ưu tiên tải trực tiếp từ nguồn nếu khả thi; chỉ truyền qua máy chủ hoặc lưu tạm khi cần.
- Có quảng cáo trong lúc xử lý và trang quản trị quảng cáo.
- Rời trang khi chưa tải: hủy công việc sau thời gian chờ. Đã bắt đầu tải qua máy chủ: cho hoàn tất rồi dọn tệp.
- Không dùng việc phát hiện đóng trang làm cơ chế dọn tệp duy nhất.
- Làm và kiểm chứng trên máy phát triển trước; kiểm tra lại trên VPS ngắn hạn trước khi mở công khai. Chưa mua máy chủ/tên miền trong phạm vi tài liệu này.

Stack trong mục 0 là phương án triển khai của bản cập nhật này. Các con số giới hạn dưới đây là mặc định thiết kế do người lập tài liệu đề xuất, không phải giới hạn của nền tảng hay số liệu hiệu năng đã đo. Codex triển khai thành cấu hình thay đổi được, không âm thầm mở rộng phạm vi.

## 2. Phạm vi MVP

### Bao gồm

- Nhận link, nhận diện nền tảng, phân tích thông tin, hiển thị ảnh xem trước, loại nội dung, chất lượng và kích thước nếu biết.
- Video đơn; bài có nhiều ảnh thì cho tải từng ảnh. Loại nội dung nào chưa kiểm chứng phải hiện thông báo không hỗ trợ.
- Chỉ chuẩn bị tệp sau khi người dùng chọn định dạng và nhấn tải; không tải sẵn mọi chất lượng.
- Lấy chất lượng nguồn cung cấp, có thể ghép hình và tiếng bằng chế độ copy nếu tương thích. Không tự tạo chất lượng cao hơn nguồn.
- Theo dõi tác vụ, hủy tác vụ, hết hạn phiên, dọn tệp tự động và giới hạn tài nguyên.
- Banner/hộp tài trợ, mở link quảng cáo khi người dùng chủ động nhấn, quản trị chiến dịch, số liệu hiển thị/nhấp.
- Bổ sung theo chủ31/10/2026: trang ủng hộ tự nguyện và tab quản trị cạnh Quảng cáo để cấu hình lời kêu gọi, mã QR và thông tin nhận ủng hộ; không chặn luồng tải.
- Trang hướng dẫn, thông tin quyền riêng tư, điều khoản và kênh báo cáo nội dung. Nội dung liên hệ thực tế cấu hình bởi chủ website.

### Chưa làm trong MVP

- Playlist, tải hàng loạt video, livestream, chuyển mã video, dịch vụ lưu video lâu dài, tài khoản trả phí.
- Nội dung riêng tư, yêu cầu đăng nhập, DRM/paywall; không nhận cookie tài khoản của khách, không xây cơ chế vượt kiểm soát truy cập.
- Tự mở tab quảng cáo, ép nhấp, nút tải giả, tự chuyển trang sang Shopee/YouTube.
- Cam kết tải mọi link, xóa watermark trên mọi nền tảng, hoặc cam kết lượt xem YouTube/doanh thu affiliate.
- Tích hợp mạng quảng cáo cụ thể khi chưa có tài khoản, yêu cầu và phê duyệt của mạng đó.

## 3. Kiến trúc triển khai

| Phần | Lựa chọn v1 | Vai trò |
|---|---|---|
| Giao diện | React + TypeScript + Vite + Tailwind CSS | Trang tải và trang quản trị responsive |
| API | NestJS + TypeScript | Phiên, tác vụ, chính sách, quảng cáo, quản trị |
| Dữ liệu | PostgreSQL + Prisma | Metadata, cấu hình, chiến dịch, nhật ký tác vụ |
| Hàng đợi | Redis + BullMQ | Giới hạn worker, lease, rate limit và trạng thái ngắn hạn |
| Worker | Tiến trình riêng từ cùng repository | Phân tích nguồn, lấy tệp, ghép hình/tiếng, dọn dẹp |
| Bộ lấy nội dung | Adapter theo nền tảng | Có thể đánh giá yt-dlp hoặc công cụ mã nguồn mở phù hợp |
| Xử lý media | FFmpeg khi cần | Ghép luồng tương thích, không chuyển mã trong MVP |
| Triển khai | Docker Compose local Windows/WSL 2; sau này trên VPS Linux | Web/API/worker/DB/Redis, TLS và reverse proxy |

Đây là kiến trúc áp dụng cho kế hoạch, chưa triển khai mã nguồn hoặc kiểm chứng phiên bản thư viện. Codex phải kiểm tra tài liệu chính thức, giấy phép, khả năng hỗ trợ, chốt phiên bản và lockfile trước triển khai. Không coi việc thư viện liệt kê một nền tảng là bằng chứng tải được trên IP máy chủ thật.

Giai đoạn đầu cùng VPS, DB và Redis chỉ ở mạng nội bộ. Không cần Kubernetes, microservice độc lập, managed database hay object storage. Worker tách tiến trình để hủy xử lý không ảnh hưởng API. Giao diện có thể chuyển sang nơi phục vụ tĩnh khác về sau; không giả định một gói miễn phí cho phép backend media.

## 4. Plan triển khai và cổng nghiệm thu

| Giai đoạn | Công việc | Đầu ra / điều kiện hoàn tất |
|---|---|---|
| P0 — Chứng minh tải thật | Kiểm tra adapter với mẫu nội dung được phép; đo trực tiếp/proxy/tệp tạm | Báo cáo hỗ trợ theo nền tảng và loại nội dung; tệp tải mở được; ghi rõ phần bị chặn |
| P1 — Nền móng | Khởi tạo monorepo, Compose, migration, cấu hình, phiên khách, admin | Khởi chạy có hướng dẫn; DB/Redis không lộ ra internet; không có mật khẩu mặc định |
| P2 — Luồng tải | Analyze, chọn định dạng, queue, prepare, download, lỗi | Một luồng tải thật xuyên suốt; endpoint bảo vệ theo phiên; giới hạn byte/thời gian hoạt động |
| P3 — Vòng đời tài nguyên | Heartbeat, release, transfer lease, sweeper, phục hồi sau crash | Qua các ca đóng tab, đang tải, mất mạng, worker chết, race với cleanup |
| P4 — UI và quảng cáo | Responsive, trạng thái thực, chiến dịch và thống kê | Link tài trợ đúng; không cản tải; không có quảng cáo cũng tải được |
| P5 — Kiểm chứng triển khai | VPS ngắn hạn, TLS, log, cảnh báo, giới hạn tải | Test thật từ máy chủ, đo RAM/CPU/byte/lượt; chọn giới hạn vận hành từ kết quả |
| P6 — Mở công khai có kiểm soát | Bật nền tảng đạt kiểm thử, backup DB, runbook | Kiểm tra restore và dọn tệp; có cách tắt adapter/tiếp nhận tác vụ khi xảy ra lỗi |

P0 nên thử tối thiểu 3 mẫu hợp lệ cho mỗi loại nội dung dự kiến bật, kèm URL sai, bài đã xóa và bài cần đăng nhập. Ghi ngày, môi trường, phiên bản adapter, kết quả; không suy rộng 3 mẫu thành bảo đảm mọi link.

Nếu P0 chỉ một nền tảng hoạt động, tiếp tục hoàn thiện kiến trúc với nền tảng đó và ghi rõ hạn chế. Không dựng kết quả mẫu rồi báo hoàn tất 4 nền tảng.

## 5. Workflow người dùng

1. Mở trang: ô dán link, thông tin nền tảng đang hỗ trợ, nút “Phân tích link”.
2. Dán link và gửi: backend xác thực URL, kiểm tra giới hạn, tạo tác vụ phân tích thuộc phiên khách.
3. UI hiện “Đang lấy thông tin”; có thể hiển thị banner/hộp tài trợ, không trì hoãn giả để tăng thời gian xem.
4. Thành công: hiển thị preview và lựa chọn khả dụng. Kích thước chưa biết ghi “Chưa xác định”; không bịa phần trăm tiến độ hoặc 4K/HD.
5. Chọn một video/ảnh và định dạng; nhấn “Chuẩn bị tải”. Backend kiểm tra lại token, format và hạn mức, chống tạo trùng do nhấn hai lần.
6. Chọn chế độ trực tiếp, proxy hoặc tệp tạm theo khả năng đã kiểm chứng của adapter.
7. Nếu cần chuẩn bị: hiển thị chờ hàng đợi/lấy tệp/ghép hình và tiếng. Khi sẵn sàng, hiện nút “Tải xuống” rõ ràng. Không phụ thuộc trình duyệt cho phép tự tải sau tác vụ bất đồng bộ.
8. Người dùng nhấn nút tải. Chế độ máy chủ tạo transfer lease trước khi truyền byte; chế độ trực tiếp dẫn tới URL nguồn đã xác thực.
9. Cho phép tải đang chạy hoàn tất dù trang đã đóng. Dọn tệp theo mục 7.
10. Khi lỗi: hiện mã lỗi và hướng xử lý phù hợp; không quay vòng tự thử vô hạn.

### Quy tắc lựa chọn đường truyền

| Chế độ | Chỉ dùng khi | Giới hạn cần hiển thị/ghi nhận |
|---|---|---|
| Direct | Trình duyệt truy cập nguồn được, URL còn hạn, không cần cookie/header bí mật hay ràng buộc IP máy chủ | Có thể mở media thay vì lưu tùy nguồn/trình duyệt; không bảo đảm theo dõi tải hoàn tất |
| Proxy streaming | Nguồn phù hợp truyền luồng, không cần ghép | Không lưu toàn bộ tệp nhưng vẫn tốn dữ liệu ra; hủy upstream khi client ngắt |
| Temporary file | Cần ghép hình/tiếng hoặc phải chuẩn bị tệp để tải đúng | Giới hạn disk/byte/thời gian; tệp có TTL và transfer lease |

Direct không được gọi là tải hoàn tất chỉ vì người dùng nhấn link. Nếu không xác minh được khả năng tải đúng trên thiết bị đích, dùng fallback đã kiểm thử hoặc báo giới hạn. Không dựa vào thuộc tính download để giả định tải được mọi URL khác origin.

## 6. Trạng thái nghiệp vụ

Không gộp phiên trang, tác vụ và lượt tải thành một trạng thái duy nhất.

| Đối tượng | Trạng thái chính |
|---|---|
| Tác vụ | analyzing → selectable → queued → preparing → ready; nhánh failed/cancelled/expired |
| Tệp | staging → available → deleting → deleted |
| Lượt truyền | started → server_finished / disconnected / timed_out |
| Phiên sở hữu tác vụ | active → released hoặc expired |

Tác vụ ready có thể có nhiều request HTTP Range của cùng lượt tải. Không được xóa tệp vì request đầu tiên kết thúc. server_finished chỉ có nghĩa máy chủ kết thúc truyền, không chứng minh người dùng đã lưu tệp vào thiết bị.

## 7. Workflow rời trang, tải và xóa tệp

### Mặc định cấu hình ban đầu

| Tham số | Giá trị đề xuất |
|---|---|
| Heartbeat | 15 giây khi trang có thể chạy |
| Hết hạn phiên tác vụ | 120 giây không có heartbeat |
| Grace khi có thông báo rời trang | 30 giây, chỉ là tín hiệu hỗ trợ |
| Tệp ready chưa tải | Tối đa 10 phút, kể cả trang vẫn mở |
| Sweeper | Mỗi 30 giây |
| Gia hạn transfer lease phía máy chủ | 15 giây; lease hết hạn sau 90 giây nếu không gia hạn |
| Grace cho tải lại/Range | 120 giây sau khi request truyền cuối cùng kết thúc |
| Thời gian tuyệt đối mỗi lượt tải | Tối đa 30 phút; thông báo và chấm dứt nếu vượt |

Đây là mặc định thử nghiệm; điều chỉnh bằng đo thực tế. Không thể cam kết phát hiện chính xác thời điểm đóng tab, đặc biệt trên điện thoại.

### A. Chưa bắt đầu tải

- Frontend heartbeat theo từng tác vụ/tab; trang bị ẩn không tự động bị coi là đã thoát. Khi quay lại, kiểm tra trạng thái và gia hạn nếu tác vụ còn hợp lệ.
- Khi pagehide hoặc điều hướng rời trang trong ứng dụng, gửi release best-effort; không phụ thuộc beforeunload. Nếu trang được khôi phục từ history cache, thực hiện kiểm tra/gia hạn lại.
- Release bắt đầu grace, không xóa ngay. Heartbeat mới có thể hủy trạng thái chờ giải phóng nếu công việc chưa bị hủy.
- Phiên hết hạn và không có transfer lease: bỏ việc trong queue hoặc hủy worker có kiểm soát; chờ tiến trình thoát rồi xóa tệp .part và staging.
- Nếu tệp đã ready nhưng chưa tải, hết hạn phiên hoặc TTL tệp thì dọn. Người dùng quay lại sau đó cần tạo tác vụ mới.

### B. Đã bắt đầu tải qua máy chủ

- Download handler xác thực quyền, kiểm tra tệp available và atomically tạo lease trước khi mở tệp.
- Mất heartbeat trang không được hủy transfer đang hoạt động. Server tự gia hạn lease; không nhờ trang duy trì.
- Nếu client ngắt: kết thúc stream, dừng upstream nếu có, giải phóng lease trong finally và cho grace tải lại.
- Nếu truyền xong: giải phóng lease, cho grace Range/retry; sau grace, chặn lượt tải mới và dọn khi không còn lease.
- Sweeper phải atomically đánh dấu deleting, ngăn lease mới; chỉ xóa khi mọi lease đã hết. Không chỉ kiểm tra một biến đếm trong bộ nhớ.
- Request Range hợp lệ dùng lại tài sản khi còn hạn; không gia hạn lưu tệp vô hạn. Tệp hết hạn trả 410 để UI hướng dẫn tạo lại.

### C. Direct

- Không có tệp trên máy chủ mình để xóa. Chỉ hết hạn metadata/token nội bộ.
- Không giả định mình có thể hủy URL tải trực tiếp đã giao cho trình duyệt hoặc thu hồi URL của nền tảng.

### D. Crash, mất điện và disk gần đầy

- Lease có hạn và sweeper chạy lại sau restart; đối soát DB với thư mục tệp tạm, dọn file mồ côi quá hạn.
- Không dùng tên tệp/đường dẫn do người dùng cung cấp. Chỉ dọn trong thư mục quản lý của hệ thống.
- Trên một VPS, phối hợp khóa tệp/khóa tài sản với lease; lease không được hết hạn chỉ vì heartbeat trang bị throttle.
- Từ 80% disk: ngừng nhận tác vụ cần lưu tệp, dọn tài sản đủ điều kiện; không xóa tệp đang truyền. Các con số là cấu hình.

## 8. Workflow quảng cáo và doanh thu

1. Admin đăng nhập, tạo chiến dịch gồm tiêu đề, ảnh banner, URL đích, loại liên kết, vị trí, lịch chạy, trọng số và trạng thái.
2. API chọn chiến dịch đang hiệu lực theo vị trí. Không có chiến dịch thì bỏ trống khu vực, luồng tải vẫn hoạt động.
3. Chỉ ghi impression khi quảng cáo thực sự xuất hiện đủ điều kiện UI: đề xuất ít nhất 50% diện tích trong 1 giây. Deduplicate theo event ID.
4. Người dùng chủ động nhấn “Xem ưu đãi” hoặc “Xem nội dung tài trợ”; mở URL HTTPS đã xác thực ở tab mới với noopener/noreferrer.
5. Ghi click theo campaign ID; không nhận URL tùy ý từ query để chuyển hướng. Thất bại thống kê không được làm lỗi tải.
6. Admin xem impression, click, CTR và thời gian; số này là thống kê nội bộ, không phải xác nhận hoa hồng hay lượt xem của nền tảng ngoài.

Banner hiện trong lúc xử lý; hộp tài trợ có nút đóng ngay. Giới hạn đề xuất 1 hộp/phiên/10 phút; không tự phát âm thanh, không bắt buộc nhấn quảng cáo để tải. Quảng cáo phải có nhãn “Quảng cáo” hoặc “Tài trợ”, tách biệt nút tải.

Không cho admin nhập JavaScript/HTML tùy ý trong MVP. Link YouTube/Shopee do chủ web cấu hình; link affiliate và điều kiện ghi nhận doanh thu phải được kiểm tra khi tích hợp chương trình cụ thể. Không tự tạo tài khoản quảng cáo hay giả định được duyệt.

### 8.1. Ủng hộ tự nguyện — chủ bổ sung31/10/2026

- Trang `/ung-ho` có lời kêu gọi duy trì máy chủ và QR/thông tin nhận tiền do chủ cấu hình. Admin có tab Ủng hộ cạnh Quảng cáo: bật/tắt, sửa tiêu đề/nội dung, tải/thay/gỡ QR, ngân hàng/chủ tài khoản/số tài khoản/nội dung chuyển khoản tùy chọn. Cấu hình và QR phải lưu bền qua restart/redeploy, không lưu ở job/media tạm hoặc chỉ browser state.
- Mặc định chưa công khai QR/thông tin nhận tiền khi chưa cấu hình; không bịa tài khoản, QR thanh toán, số người ủng hộ hoặc tiền đã nhận. Nội dung là plain text, file ảnh được giới hạn/kiểm loại. Ghi rõ thao tác lưu/đăng hiển thị, không đăng bản nháp âm thầm.
- Ủng hộ luôn tự nguyện, không popup ép buộc hoặc điều kiện tải; không tự thu tiền, tích hợp cổng thanh toán, webhook, tài khoản trả phí hoặc xác nhận đã nhận tiền trong phạm vi này. Chi tiết triển khai/kiểm cần thiết ở `docs/tasks/SUPPORT_PAGE_ADMIN_20261031.md`.

## 9. Giới hạn để kiểm soát chi phí

Mặc định thử nghiệm: video tối đa 10 phút, đầu ra tối đa 200 MiB, worker local xử lý tối đa 1 tác vụ chuẩn bị cùng lúc; môi trường máy chủ có thể cấu hình 2 sau khi đo tài nguyên, 1 tác vụ chuẩn bị/phiên, hàng đợi tối đa 20. Byte đầu vào của các luồng thành phần cộng lại cũng phải có trần; không chỉ kiểm tra output cuối.

- Rate limit ban đầu: 10 yêu cầu phân tích/phút/phiên và 30/phút/IP; điều chỉnh để tránh chặn nhầm người dùng chung mạng.
- Deadline phân tích 30 giây, chuẩn bị 180 giây. Retry tối đa 1 lần cho lỗi tạm thời; không retry URL sai, quyền truy cập hay định dạng không hỗ trợ.
- Cache metadata tối đa 2 phút và không dài hơn hạn URL nguồn; không chia sẻ tệp tải giữa phiên trong MVP để giảm phức tạp vòng đời.
- Nếu không biết kích thước trước, đếm byte thực khi tải; vượt trần thì hủy và dọn partial.
- Đếm dữ liệu ra, thời gian worker, CPU/RAM, disk, queue, lỗi theo adapter. Thêm ngân sách dữ liệu ra tháng cấu hình bởi admin; vượt ngưỡng đặt trước thì tạm ngừng nhận tải qua máy chủ mới. Cảnh báo không thay thế bộ chặn.
- Dự toán: dữ liệu ra tháng ≈ lượt tải × kích thước trung bình × hệ số tải lại, chỉ tính các lượt đi qua máy chủ. Đối soát hóa đơn nhà cung cấp; số đếm ứng dụng không phải số tính phí tuyệt đối.

## 10. API và dữ liệu bàn giao

| API đề xuất | Mục đích |
|---|---|
| POST /api/v1/jobs/analyze | Nhận URL, tạo tác vụ phân tích; trả 202 + jobId |
| GET /api/v1/jobs/:id | Metadata, trạng thái, format hợp lệ, lỗi; thuộc phiên gọi |
| POST /api/v1/jobs/:id/prepare | Chọn itemId/formatId, idempotency key; tạo công việc tải |
| POST /api/v1/jobs/:id/heartbeat | Gia hạn phiên tác vụ còn hợp lệ |
| POST /api/v1/jobs/:id/release | Thông báo rời trang, bắt đầu grace |
| POST /api/v1/jobs/:id/cancel | Chủ động hủy chuẩn bị; không xóa tài sản đang truyền |
| POST /api/v1/jobs/:id/download-ticket | Cấp vé ngắn hạn, gắn phiên + item/format |
| GET /api/v1/downloads/:ticket | Direct redirect hoặc stream tệp theo chế độ đã chốt |
| GET /api/v1/ads | Lấy chiến dịch theo placement |
| POST /api/v1/ad-events | Ghi impression/click có validation và rate limit |
| /api/v1/admin/* | Đăng nhập/đăng xuất, CRUD ads, cấu hình giới hạn, thống kê, bật/tắt adapter |

Cookie phiên ngẫu nhiên, HttpOnly/Secure/SameSite; xác thực sở hữu ở mọi endpoint tác vụ. Job ID không phải bí mật đủ để cấp quyền. Vé tải cho phép nhiều Range request hợp lệ trong khoảng hạn, không dùng token một lần khiến tải lại bị hỏng. Bảo vệ CSRF cho thao tác cookie-auth. Không đưa cookie/header nguồn hoặc đường dẫn đĩa ra response.

Mô hình dữ liệu tối thiểu: AdminUser; Session; DownloadJob; MediaItem; TemporaryAsset; TransferLease; AdCampaign; AdEvent; Settings; AuditLog. Lưu quan hệ sở hữu, timestamps, deadlines, error code và byte counters. Không lưu vĩnh viễn URL nguồn có chữ ký; che query/token trong log. Chiến dịch và cấu hình được audit; dữ liệu analytics thô có TTL đề xuất 30 ngày, giữ tổng hợp không định danh nếu cần.

Lỗi có mã ổn định: INVALID_URL, UNSUPPORTED_PLATFORM, CONTENT_UNAVAILABLE, AUTH_REQUIRED, FORMAT_UNAVAILABLE, RATE_LIMITED, QUEUE_FULL, LIMIT_EXCEEDED, SOURCE_TIMEOUT, JOB_EXPIRED, CAPACITY_UNAVAILABLE. HTTP phù hợp: 400/403/404/410/429/503; không lộ stack trace cho khách.

## 11. Bảo vệ backend tải nội dung

- Allowlist host nền tảng và các host media mà adapter cần; kiểm tra cả link rút gọn và từng redirect. Chặn IP nội bộ, loopback, link-local, metadata cloud và DNS rebinding; áp dụng cả fetch thumbnail và request từ worker/công cụ ngoài.
- Chỉ HTTP(S) phù hợp; không nhận file://, ftp:// hoặc URL làm đầu vào shell. Spawn process bằng argument array, không nối shell command từ người dùng.
- Adapter trả format IDs; client không được tự đưa một URL tùy ý vào download endpoint biến máy chủ thành proxy công cộng.
- Giới hạn redirect, response size, timeout và process; worker chạy user không đặc quyền, quyền ghi chỉ thư mục tạm cần thiết.
- Admin hash mật khẩu, giới hạn đăng nhập, secrets qua môi trường, TLS khi public, backup dữ liệu quản trị và thử restore.
- Thông tin bài đăng/tiêu đề coi là dữ liệu không tin cậy; escape để tránh XSS. Upload banner kiểm tra định dạng/kích thước, không phục vụ HTML thực thi.

## 12. Giao diện cần xây

Trang chủ: tên sản phẩm cấu hình được; ô link và nút chính; khu vực trạng thái; preview; lựa chọn nội dung/chất lượng; nút tải; tài trợ; hướng dẫn ngắn. Không bắt người dùng hiểu proxy, queue worker hoặc FFmpeg.

Các trạng thái UI bắt buộc: idle, analyzing, selection, queued, preparing, ready, transferring nếu quan sát được, expired, cancelled, error, rate-limited, capacity-full. Nếu chỉ biết đã bắt đầu tải thì ghi đúng như vậy, không hiện “Đã lưu thành công”.

Trang admin: đăng nhập; dashboard thống kê; danh sách/sửa quảng cáo; bật/tắt nền tảng; giới hạn; tác vụ lỗi đã che dữ liệu nhạy cảm. Có bàn phím, focus rõ, độ tương phản tốt, không tràn trên màn hình điện thoại.

## 13. Kiểm thử nghiệm thu trọng yếu

| Ca | Kết quả yêu cầu |
|---|---|
| Link hợp lệ mỗi adapter đã bật | Tệp thật mở được; video có tiếng nếu format công bố có tiếng |
| Người dùng nhấn prepare hai lần | Chỉ một công việc nhờ idempotency |
| Rời trang lúc queued/preparing | Hủy sau grace/lease, tiến trình dừng, partial được dọn |
| Mất heartbeat nhưng đang tải | Transfer vẫn chạy tới khi xong hoặc đạt deadline tuyệt đối |
| Chuyển sang tab quảng cáo rồi quay lại | Không hủy ngay; UI kiểm tra phục hồi hoặc báo hết hạn trung thực |
| Nhiều Range request | Không xóa giữa chừng; trả 206/416 đúng khi hỗ trợ |
| Cleanup và lượt tải bắt đầu đồng thời | Khóa nguyên tử: được cấp lease hoặc bị từ chối rõ ràng, không đọc tệp đang xóa |
| Mạng bị ngắt / worker hoặc API crash | Lease hết hạn, không còn tiến trình/tệp mồ côi lâu dài |
| Disk gần đầy hoặc vượt ngân sách | Chặn công việc mới, không phá lượt tải đang hợp lệ |
| Direct URL hết hạn | Resolve lại có giới hạn hoặc báo hết hạn, không lặp vô hạn |
| Phiên A truy cập job của B | Bị từ chối |
| URL nội bộ, redirect vào nội bộ, URL shell injection | Bị chặn cả ở API lẫn worker |
| Không có quảng cáo/ad blocker | Tải vẫn dùng được |
| Thống kê click | Không coi click là doanh thu hay lượt xem YouTube |

Kiểm thử logic vòng đời với đồng hồ giả; tích hợp với upstream cục bộ có độ trễ/Range/ngắt kết nối; chỉ một tập mẫu nguồn thực cho smoke test. Không gọi nền tảng thật trong mọi unit test. Test desktop và điện thoại thực tế ít nhất một trình duyệt mỗi loại trước public.

## 14. Đầu ra Codex phải bàn giao

- Repository với apps/web, apps/api, apps/worker, packages/shared, infra và docs; có thể điều chỉnh theo repository sẵn có, giải thích thay đổi.
- README chạy local, .env.example không có secret, Compose, migration, tạo admin an toàn, lockfile.
- OpenAPI phản ánh endpoint đã triển khai; bảng trạng thái/TTL; cấu hình limits.
- Báo cáo adapter nền tảng/loại nội dung đã kiểm tra; test report và phần chưa kiểm chứng.
- Runbook restart, cleanup, disk đầy, rollback, bật/tắt adapter, backup/restore và theo dõi chi phí.
- Không báo hoàn tất thương mại chỉ vì build frontend thành công. Không deploy trả phí hay thêm dịch vụ trả phí khi chưa được chủ dự án đồng ý.

## 15. Prompt khởi động để dán vào Codex

> Làm việc trong dự án `D:\WED SNAP` của tôi. Đọc toàn bộ `PLAN_WORKFLOW_VIDEO_DOWNLOADER_V1.md` phiên bản nội dung 1.1 và AGENTS.md nếu có. Kiểm tra thư mục hiện tại trước khi sửa, giữ nguyên mã nguồn và dữ liệu không liên quan. Triển khai website tải video/ảnh đa nền tảng theo kế hoạch. Stack: TypeScript, React + Vite + Tailwind CSS, NestJS, PostgreSQL + Prisma, Redis + BullMQ, worker riêng, adapter đánh giá yt-dlp và FFmpeg. Máy tôi Windows RAM 8 GB, Docker Desktop dùng WSL 2 đã hoạt động. Cấu hình toàn bộ runtime chạy trong Docker, không yêu cầu cài riêng các runtime/dịch vụ trên Windows; tạo compose.yaml tại gốc với project name wed-snap và worker local concurrency 1. Kiểm tra giới hạn thực tế; không tự thay cấu hình WSL. Bắt đầu P0 bằng tải thật, rồi thực hiện P1-P4 và kiểm thử local. Nền tảng nào không kiểm chứng được phải báo rõ, không giả lập thành công. Giữ toàn bộ quy tắc phiên tải, quảng cáo, bảo mật và dọn tệp trong tài liệu. Bàn giao README tiếng Việt với lệnh PowerShell có cd "D:\WED SNAP", cách tạo .env, migration, admin, khởi động/dừng, URL local và kết quả kiểm thử. Ghi tiến độ vào docs/PROGRESS.md để tiếp tục được ở phiên sau. Chuẩn bị hướng dẫn P5-P6 nhưng chưa thuê dịch vụ hoặc deploy công khai khi tôi chưa yêu cầu. Nếu môi trường không truy cập được ổ D:, báo cần mở repository tại môi trường đúng; không giả vờ đã thao tác trên máy tôi. Tiếp tục những bước không bị chặn, chỉ hỏi lại khi thiếu thông tin thực sự cần thiết.


---

Tài liệu này chốt phạm vi thiết kế và kế hoạch thực hiện. Chưa có code, thử tải nền tảng, kiểm thử tải đồng thời hoặc triển khai thực tế được thực hiện trong bước lập tài liệu này.
