# Bảo trì mã và dung lượng

Sau mỗi thay đổi: build và chạy kiểm tra thích hợp trước khi dọn. Chỉ xóa artifact thuộc dự án đã được thay thế/hết mục đích, không còn tham chiếu hoặc phụ thuộc và có thể tái tạo. Không xóa chỉ vì không dùng trong lần chạy hiện tại.

1. Rà mã/cấu hình/tài liệu bằng `rg`; kiểm tra container, tiến trình, job và mounts còn dùng artifact/image.
2. Giữ `.env`, migration, PostgreSQL/Redis/media volumes, backup, bộ test, báo cáo và bằng chứng cần thiết; giữ smoke/restore vì còn phục vụ nghiệm thu.
3. Script chuyển cấu trúc một lần và bản sao mã trước refactor có thể dọn sau khi nghiệm thu refactor; ghi rõ tên, byte đo trước/sau. Formatter/test scripts sử dụng lại vẫn giữ.
4. Image công cụ không được container dùng và có thể build lại được gỡ bằng **đúng tên/tag thuộc dự án**. Không dùng force nếu container còn tham chiếu. Docker layers có thể dùng chung nên kích thước image không phải số byte thật thu hồi.
5. Không chạy `docker system prune -a --volumes`, `docker volume prune` hoặc xóa cache/image toàn máy. Cache BuildKit chưa xác định phạm vi chỉ được báo dung lượng bằng `docker system df -v`; để chủ máy quyết định dọn cache phù hợp sau khi kiểm tra dự án khác.
6. Windows recursive cleanup: resolve đường dẫn tuyệt đối, kiểm tra nằm trong `D:\WED SNAP` rồi dùng `Remove-Item -LiteralPath` trong cùng PowerShell. Không trộn cmd/batch/shell và không dọn đường dẫn từ input người dùng.
7. Sau dọn, kiểm tra Compose config, health và kiểm tra build/import nếu artifact liên quan mã. Ghi danh sách đã xóa và dung lượng **đo được**, phân biệt ước tính/kích thước khai báo của image.

Những mục chưa đủ căn cứ hết mục đích phải được giữ, kèm lý do trong PROGRESS. Không xóa video có lease đang truyền, không dùng thao tác filesystem thay thế sweeper có khóa DB.

Dọn01/10/2026:20.427.204 byte artifact đo được, chi tiết trong cleanup.json/PROGRESS. Image công cụ gỡ khi0 container tham chiếu; mục Images Docker giảm741MB nhưng cache BuildKit vẫn5,432GB. Không đồng nhất với dung lượng vật lý ổ/VHD đã thu hồi. Cache giữ để build lại, không prune toàn máy.
