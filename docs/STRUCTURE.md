# Bản đồ mã nguồn WED SNAP

## Bản đồ hiện hành 16/10/2026 — Ảnh TikTok/backend và phần lab

Mộtảnhcanonical TikTok qua API/worker/egress đã được kiểm nguồn và reviewer mở tệp thật, đốichiếu hash với ảnhđãhumanaccepted. UI A đã tíchhợp vào `apps/web` và hai nhánh ảnh đã nghiệmthu offline với API fixture; main/photo/gallery chưa bật, chưa có UI+backend+nguồn thật trong cùng luồng, chưa shortlinkAPI/deploy. [Nghiệmthu nguồn](evidence/tiktok-photo-source-fixed-live-review-20261015/ASSESSMENT.md), [nghiệmthu UI](evidence/ui-photo-branches-review-20261016/ASSESSMENT.md), [bàn giao backend→UI](TIKTOK_PHOTO_UI_BACKEND_HANDOFF.md). Các mô tả07–09/10 bên dưới lưu **lịch sử cấu trúc/khả năng lúc đó**; dùng bảng hiệnhành này cho nhánh ảnh.

| Điểm nối hiện có | Vị trí |
|---|---|
| PhotoCLI/core/contract/proxy | `apps/media/src/tiktok/photo_adapter.py`, `photo_core.py`, `photo_contract.py`, `photo_proxy.py`; output ảnh `image.jpg`, video giữ `media.mp4` |
| Validator public / MIME-name | `packages/shared/src/tiktok-photo.ts`; photo formats/snapshot/selection/filecontract, nativeJPEG |
| Session capability / jobAPI / native transfer | `apps/api/src/services/session.service.ts`, `jobs.service.ts`, `downloads.service.ts` |
| Parentworker / phaseproof / cleanup | `apps/worker/src/adapter.ts`, `processor.ts` và helper lifecycle hiện có |
| UI hiện tại / hooks | `apps/web/src/pages/Home.tsx`, `hooks/useSession.ts`, `useJobLifecycle.ts`, `useDownloadLink.ts`, `types.ts`, `lib/api.ts` |
| DNSchildenvfix (chưa mainapply) | `labs/tiktok/photo-dns-child-offline/common/dns_child_environment.py`, `proxy_entry.py` |
| Diagnostic completeness overlay (chưa mainapply) | `labs/tiktok/photo-dns-diagnostics-fix/proxy_collect.py`, `overlay_entry.py` |
| Sourcewiring riêng đã chạy một lượt | `labs/tiktok/photo-source-fixed/run.ps1`, `mounts.ps1`; runtime/evidence riêng, không productioncompose |
| UI hướng A đã tíchhợp/nghiệmthu offline | `apps/web/`; prototype nguồn ở `design/ui-redesign-v1/`, không coi fixture là backend thật |

Backend giữ analyze và freshprepare hai child riêng; UI dùng descriptorpublic và tải mộtJPEG/job qua liênkết native, khôngCDNURL/cookie/tokensource hoặc giữchildqua selectable. SSRF/TLS/DNS256raw→64unique/phaseproof/CSRF/session-job-transferlease không được nới khi tíchhợp UI. Chuyển labfix vào recipevận hành hoặc bậtmain là nhiệm vụreviewriêng, không phải hệ quả của ảnhnguồnPASS.


Cập nhật07/10/2026 theo yêu cầu phân chia thư mục. Mục tiêu là tìm được code sản phẩm và phân biệt với lab, kiểm thử, bằng chứng. Đây là thay đổi vị trí file; các trạng thái nghiệm thu chức năng vẫn ghi trong PROGRESS/ADAPTERS/AUDIT.

```text
WED SNAP/
├── apps/
│   ├── web/                 Giao diện React: trang tải, quản trị
│   ├── api/                 NestJS: phiên, job, download, quảng cáo
│   ├── worker/              Hàng đợi, tiến trình tải, vòng đời tài nguyên
│   ├── media/               Bộ lấy/tải media dùng yt-dlp và FFmpeg
│   │   ├── src/media_adapter.py
│   │   ├── src/tiktok/         Core TikTok hai phase, default-off; chưa source/API E2E
│   │   ├── requirements.lock
│   │   └── Dockerfile
│   └── egress/              Proxy kiểm soát kết nối tới nguồn
│       ├── src/egress.py
│       └── Dockerfile
├── packages/shared/         Kiểu dữ liệu và logic dùng chung
├── labs/tiktok/renderer/    Thử nghiệm browser TikTok chưa tích hợp
├── tests/                   Fixture, hồi quy, nghiệm thu theo từng đợt
├── infra/                   Cấu hình Compose, env mẫu, security profile,
│                            recipe Docker cho các lab lịch sử
├── scripts/                 Khởi tạo/vận hành và chạy kiểm tra
├── prisma/                  Schema và migrations
├── docs/                    Hướng dẫn, tiến độ, bàn giao
│   └── evidence/            Raw logs, snapshots, manifests đóng băng
├── compose.yaml             Ghép các dịch vụ ứng dụng
└── Dockerfile               Image ứng dụng API/worker/web dùng chung
```

## Muốn sửa tính năng thì mở file nào?

| Việc cần làm | File chính |
|---|---|
| Dán link, chọn định dạng, nhấn tải | `apps/web/src/pages/Home.tsx` |
| Tiếp nhận analyze/prepare và kiểm quyền phiên | `apps/api/src/services/jobs.service.ts` |
| Trả tệp, download ticket và Range | `apps/api/src/services/downloads.service.ts` |
| Xử lý job và gọi adapter | `apps/worker/src/processor.ts`, `apps/worker/src/adapter.ts` |
| Lấy metadata, chọn/tải MP4 bằng yt-dlp, kiểm ffprobe | `apps/media/src/media_adapter.py` |
| Allowlist, DNS/public-IP và CONNECT tới nguồn | `apps/egress/src/egress.py` |
| Browser renderer TikTok và diagnostic launch | `labs/tiktok/renderer/renderer_capability.js`, `renderer_diagnostics.js` |

YouTube hiện dùng adapter chung trong `apps/media/`; yt-dlp cung cấp extractor theo nền tảng. Không tạo một bản sao adapter cho từng nền tảng chỉ để phân loại thư mục. Khi cần chính sách riêng cho nền tảng, bổ sung phần có căn cứ trong component media, giữ worker/API/lifecycle dùng chung.

## Lab TikTok

Core TikTok được nối vào apps/media/src/tiktok ngày09/10 theo nhiệm vụ offline, không bật stack chính. Worker vẫn spawn CLI analyze/prepare riêng và output media.mp4; prepare fresh metadata/bodyID/selected public fingerprint, source secrets chỉ RAM. labs/tiktok/app-integration chứa fixture/runner/Docker lab riêng, không nằm trong runtime core. Cobalt lab/evidence lịch sử giữ nguyên. Chi tiết ở TIKTOK_APP_INTEGRATION_HANDOFF.md; source/API E2E cần review mẫu3 và nhiệm vụ riêng.

Code đang phát triển:

- `labs/tiktok/renderer/build_renderer.ps1`: build image thử nghiệm theo recipe được giao.
- `labs/tiktok/renderer/run_renderer_capability.ps1`: kiểm launch offline với guard/cleanup.
- `labs/tiktok/renderer/renderer_capability.js`: gọi Playwright, ghi các bước requested/observed.
- `labs/tiktok/renderer/renderer_diagnostics.js`: thu stderr/process/cgroup và sanitize log.

Các file cùng tên trong `tests/p37/` chỉ là điểm chuyển tiếp nhỏ cho lệnh/import cũ, không có bản sao implementation. Các verifier và probe lịch sử còn lại trong `tests/p37/` phục vụ hồ sơ từng đợt; không coi chúng là implementation renderer hiện tại.

Lab đang bị chặn ở khởi động sandbox/chroot theo bàn giao launch. Việc sắp xếp thư mục không phê duyệt đề xuất đổi seccomp, không chạy browser/TikTok, không bật nền tảng hoặc deploy.

## Bảng đường dẫn cũ và mới

| Đường dẫn cũ | Đường dẫn mới |
|---|---|
| `infra/media_adapter.py` | `apps/media/src/media_adapter.py` |
| `infra/requirements-media.lock` | `apps/media/requirements.lock` |
| `infra/media.Dockerfile` | `apps/media/Dockerfile` |
| `infra/egress.py` | `apps/egress/src/egress.py` |
| `infra/egress.Dockerfile` | `apps/egress/Dockerfile` |
| `tests/p37/build_renderer.ps1` | `labs/tiktok/renderer/build_renderer.ps1` |
| `tests/p37/run_renderer_capability.ps1` | `labs/tiktok/renderer/run_renderer_capability.ps1` |
| `tests/p37/renderer_capability.js` | `labs/tiktok/renderer/renderer_capability.js` |
| `tests/p37/renderer_diagnostics.js` | `labs/tiktok/renderer/renderer_diagnostics.js` |

Python adapter, egress, lockfile và JavaScript renderer được giữ nguyên nội dung khi di chuyển. Dockerfile và runner chỉ sửa đường dẫn COPY/bind mount tương ứng. Worker vẫn chạy `/app/infra/media_adapter.py` trong container, proxy vẫn chạy `/app/egress.py`, để giữ hợp đồng với fixture/cached images. Đây là tên chạy bên trong container, không phải vị trí source trên Windows.

## Hồ sơ lịch sử và kiểm tra

Raw logs, snapshots, manifests trong `docs/evidence/` không được đổi nội dung hoặc di chuyển. Một số verifier lịch sử đối chiếu đường dẫn live trước khi sắp xếp nên có thể báo sai khác được giao khi chạy trên cây file mới. Giữ verifier làm hồ sơ đúng thời điểm của nó; không sửa golden hashes hoặc thêm ngoại lệ rộng để ép PASS.

Ngoại lệ lưu trữ được chủ giao ngày07/10/2026: ledger320MB được lưu gzip nguyên bản và bản chưa nén bị bỏ để giảm dung lượng. Bytes/hash nguyên bản được giữ, đã kiểm khôi phục thật. Xem `EVIDENCE_ARCHIVES.md` và archive index; khôi phục đúng file trước khi dùng verifier cũ cần đường dẫn đó. Các raw/manifest khác giữ nguyên.

`docs/evidence/structure-20261007/` ghi before-set, bảng di chuyển, content hashes và các kiểm tra đường dẫn mới. Dùng bản đồ này khi kế thừa bằng chứng; source runtime được đối chiếu hash tại vị trí mới, không gọi refactor là tính năng tải mới hoặc kết quả video mới.

Image/container đã có không được rebuild/restart tự động trong việc này. Những lần build sau dùng root Dockerfile hoặc `apps/media/Dockerfile`, `apps/egress/Dockerfile` với build context ở gốc dự án.

## Lab Cobalt TikTok — 08/10/2026

labs/tiktok/cobalt/ chứa resolver Cobalt ghim commit, helper tốithiểu/NOTICE+LICENSEAGPL, Undici proxy/budget, supervisorOS vàglue yt-dlp. Đây làlab đượcchủchọn thay hướngbrowser/chroot; khôngtíchhợp apps/media. Mẫuđầu lỗi integrationdeadline; bảnfinal sửaoffline nhưngnguồn/file chưanghiệmthu, xem TIKTOK_COBALT_HANDOFF.md. Image/Compose/build/run chỉthuộclab; production vàbảnđồ di chuyển cũ giữ.
