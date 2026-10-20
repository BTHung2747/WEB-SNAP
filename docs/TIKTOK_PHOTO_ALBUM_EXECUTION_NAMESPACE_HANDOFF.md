# Bàn giao sửa namespace execution album — 14/10/2026

**FIXED_PENDING_INDEPENDENT_REVIEW** cho P2
F-ALBUM-BOOTSTRAP-EXECUTION-NAMESPACE-FROZEN-EVIDENCE; chưa tự đóng.
Candidate `labs/tiktok/photo-album-execution-namespace/`, freeze-1/evidence tại
`docs/evidence/tiktok-photo-album-execution-namespace-20261014/`.

Candidate/freeze/hồ sơ tác giả tách khỏi mutable execution. Dữ liệu mới nằm tại
`lab-runs/tiktok-photo-album-namespace-v1/{offline,real}/execution-{32hexID}`.
ID là tên lưu trữ không phải task/allocation hay download grant. Không nhận root
tùy ý, slash/traversal; FixedPath/reparse kiểm ancestor trước mkdir/write/read.
BootstrapWrite bounded/CreateNew chỉ trong execution đang chọn; fixture không
được dùng nhánh real. ID/lease là dữ liệu, SourceSnapshot không chứa lab-runs,
nên thay lượt không đổi code hash. Hồ sơ author seal không được ghi input/proof.

Real release nằm tại execution/release. Real task-latch/allocation claim và
source-task output nằm trong registry chung `real/task-registry/task-{taskID}`;
đổi executionID không né task-latch. Consumer source vẫn cần review/cold/human/
claims exact hash/expiry/quota/trust và scope thật. Runtime Python/Cobalt,
downloader/parser/transport/budget/cleanup/licenses/pins byte unchanged.
Chỉ host path glue và notice thay; không dependency/build/install/main change.

Kiểm 9 ca namespace/binding: valid, sai scope/missing review/hash/expiry,
crossing/reparse/create-once/fixture vào real; output reuse và default real
thiếu review native nonzero. Junction thuộc fixture được bỏ riêng, không xóa
target. Một cold actual source-only network none/96MiBCPU.25/UID65534/RO/30s
native0/noOOM; 4 capability guards +2 scalar guards giữ chặn, thread/FD ổn định.
Không matrix/history/whole rerun. Lỗi chuẩn bị harness scope/projection/junction
permission đã giữ script +raw receipt; successor sửa harness, không sửa runtime.

Nguyên hàm Entries của verifier cũ được chạy riêng read-only trước/sau input và
cold: 241 entry và manifest gốc giữ nguyên. Manifest mới bao phủ candidate,
author evidence và **danh sách explicit 16 root offline sở hữu của phiên**;
không scan base execution chung hoặc thêm ngoại lệ wildcard. Future execution
ID có scope/proof/seal riêng, không đổi manifest hiện tại. Không chạy verifier
cũ ghi đè terminal receipt hay sửa golden để ép PASS.

Caps50/5/2meta+N/8–16metadata/20–16image/max116–80,meta30/prep180/item60reserve10,
HTTP10–20/picker2/watchdog225/DNSraw256unique64/trace256owner32map64/IPC600/
SSRF-TLS/policyC/worker512+proxy96=608 giữ. Không nguồn/claim thật; photo1 human
accepted giữ, photos2–5 chưa chạy; main/gallery/API/UI/DB/host/deploy/video3 OFF.
RUNBOOK/NEXT_PROMPT và raw inventory/cleanup/manifest/seal/read-only trong evidence.
