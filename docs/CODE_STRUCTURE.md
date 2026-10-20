# Cấu trúc mã

Mã nguồn được tách theo trách nhiệm sau khi ổn định luồng tích hợp; không đổi API, cookie, thuật toán khóa hay volume dữ liệu.

```text
apps/web/src/
  main.tsx                  điểm vào React và thứ tự CSS
  App.tsx                   chọn trang và ghép layout
  components/               Header, Footer, Icon, Advertising
  pages/                    Home, Admin, Legal
  hooks/                    phiên API, polling/heartbeat/lifecycle job và tạo liên kết tải khi ready
  lib/                      API client, thông báo lỗi, tên nền tảng
  types.ts                  kiểu response dùng chung UI
  style.css                 Tailwind + quy tắc nền
  styles/                   layout, home, admin, legal, responsive
apps/api/src/
  main.ts                   Nest bootstrap, helmet, cookie, OpenAPI
  openapi.ts                cookie/CSRF và hợp đồng streaming/202 trong tài liệu API
  app.module.ts             controller/service registration
  controllers/              route, decorator, chuyển tiếp lời gọi
  services/                 session, jobs, downloads, ads, admin, admission
  auth/session.ts           cookie, CSRF, quyền sở hữu, admin token
  security/                 danh tính IP qua proxy tin cậy và chính sách rate trước insert
  validation.ts             Zod schema và parse input
  filters/                  mã lỗi an toàn, không lộ stack
  common.ts                 facade export dùng nội bộ API
apps/worker/src/
  main.ts                   BullMQ concurrency 1 và chu kỳ sweeper
  processor.ts              claim/publish/fail tác vụ trong giao dịch
  adapter.ts                spawn, deadline, hủy process group, byte cap
  lifecycle.ts              expire lease, cleanup, outbox và orphan recovery
  process-registry.ts       biết child cục bộ đã thoát trước cleanup
packages/shared/src/core.ts cấu hình bounded, DB/queue, URL/Range/khóa/rate
infra/                      proxy SSRF, Python media adapter, runtime images
prisma/                     schema và migration đã quản lý
tests/                      unit, proxy, integration, admin và fixture riêng
```

Controller không giữ business state trong bộ nhớ. DB là nguồn quyền sở hữu/tài sản/lease/budget. Process registry chỉ trì hoãn cleanup của child cục bộ; không thay khóa hay lease DB. Media adapter chỉ trả metadata đã lọc; frontend không nhận cookie/header/URL media có chữ ký.

Các script chuyển cấu trúc một lần đã được dọn sau kiểm thử. Formatter Prettier được khóa trong image ứng dụng; không cần npm trên Windows. Chạy từ root để định dạng mã:

```powershell
cd "D:\WED SNAP"
docker run --rm --user 0 --memory=512m --cpus=1 --mount 'type=bind,source=D:\WED SNAP,target=/workspace' --workdir /workspace wed-snap-app:local /app/node_modules/.bin/prettier --write 'apps/**/*.ts' 'apps/**/*.tsx' 'apps/**/*.css' 'packages/**/*.ts' 'tests/**/*.ts'
```

Lệnh này chỉ sửa source bằng formatter trong container công cụ. Runtime API/worker/web vẫn chạy user không đặc quyền. `scripts/dependency-report.cjs` và `inspect-formats.py` giữ lại để chẩn đoán phiên bản/extractor; không phải đường xử lý URL của khách.

Sau sửa backend source trên Windows, nếu watcher không nhận sự kiện file, restart API; worker luôn restart rõ ràng. Build + kiểm thử tích hợp lại khi đổi auth, vòng đời hoặc cách stream. Tệp test/fixture chỉ được mount trong Compose test; không đưa fixture adapter vào worker chính.
