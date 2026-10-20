# Sửa hai gap adapter trước readiness — offline only

20/10/2026. Chuẩn nghiệm thu: `docs/evidence/ui-source-live-adapter-fix-review-20261020/ASSESSMENT.md` và `verification.json`. Input backend manifest `39a666e84a4a8d23b30b91ca1bee3d6ec706ee26a3246d72c6a6d4b4ca5e20a4`; giữ nguyên22source snapshots/pins và4787artifact đã seal, không sửa lịch sử/golden để tạo khớp. Đây continuation sửa chức năng đã giao, không GO readiness/B.

## Hai việc bắt buộc

1. **F-ADAPTER-DOCKER-PAYLOAD-FLAGS:** `Bridge-DockerArgs` hiện chặn PostgreSQL `-c` trong template chuẩn. Sửa phân biệt Docker global/subcommand options với image/container command hoặc xác minh exact approved template theo operation, dùng semantics CLI chính thức đúng phiên bản và mã hiện có. Giữ exact absolute exe/SHA/localpipe và từ chối overrides thật; không đổi PostgreSQL argv/template cũ, nới policy hoặc bỏ blanket toàn bộ gate. Kiểm đủ5 source templates qua public managed factory/context→wrapper→spy, payload flags hợp lệ được nhận; Docker endpoint/context/config/TLS forms thật sai bị chặn trước method. Không log argv/env/secrets. Không cần viết parser/framework tổng quát.
2. **F-ADAPTER-WINDOW-PROOF-UNCONSUMED:** consumer phải thực sự xác minh owner-private proof ngoài control/mount: derive exact namespace/root, proof ref/hash/mode/run/nonce/bindings, exact paths; kiểm numeric types/QPC/frequency/age và deadline/remaining/cutoff không vượt contract/private owner proof. Không tin canOpen/remaining/cutoffs caller tự khai. Khi service publication chưa xong, reader phải HOLD/fail closed trong budget1s hiện có, không coi file tồn tại là đã sealed; không overwrite/retry/reset/deadline extension. Tái dùng FileStream/nooverwrite/logger primitives; không tự viết serializer/transport. Kiểm service→client path thực trong managed mode, không chỉ tự tạo response fixture. Có positive, missing/tampered/privateproof/foreignpaths/inflated budget/stale/noncemismatch/partial publication đúng phạm vi, không tạo lại matrix lịch sử.

Phạm vi chỉnh chính `labs/tiktok/ui-source-live-attempt/bridge-runtime.ps1`, test-adapter và test helper mới cần thiết. Nếu integration test cần hook/API test hẹp trong `bridge-native.ps1`, `bridge-trust.ps1` hoặc5owner allowlist của task19/10, chỉ đổi đoạn liên quan và khai diff/lý do. Không app/UI/prelaunch template/budget/allocation/helper/anchor/locks/dependencies; không ghi lại cũ A manifests, final prior tests hoặc reviewer verifier để che lỗi.

Giữ phần cleanup/onehuman-once/CWT/cached-helper/root0-force/private result/deadline/reporting đã đạt offline. Human workflow chưa consume, không xin lại chủ. Không native/helper Engine.Run/Docker/compiler/port/browser/source/livekey/grant/sourceclaim/admission. Managed admissions trong namespace test riêng có nhãn tiếp tục được phép; không tạo giả REVIEWER_GO_B hoặc measured/live proof để test.

## Bàn giao rồi dừng

Evidence mới `docs/evidence/ui-source-adapter-final-gaps-20261020/backend/`: HANDOFF.md/NEXT_REVIEW.md, exact before/after/diff/current pins, test inputs+receipts/methods+actual tool exits, manifest và preservation rõ old source drift được giao. Ghi counts backend/reviewer/intermediate tách riêng, không cộng lặp. Nếu một proof cannot be checked trong scope, báo exact API thiếu và hẹp đề nghị, không tự báoready.

Callback chat nghiệm thu theo quyền chủ đã có rồi DỪNG; không nhắn frontend trực tiếp. Reviewer kiểm successor và cập nhật CURRENT rồi mới giao native readiness riêng. Frontend giữ READY, chưa browser/publisher/redesign. Không AUDIT/PROGRESS/main/gallery/deploy.
