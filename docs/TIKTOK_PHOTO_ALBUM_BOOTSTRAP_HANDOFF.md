# Bàn giao producer/bootstrap album — 14/10/2026

Producer và thủ tục đã triển khai trong `labs/tiktok/photo-album-bootstrap/`.
**DEFAULT OFF, PENDING INDEPENDENT REVIEW**; freeze-2 tại
`docs/evidence/tiktok-photo-album-bootstrap-20261014/`. Chưa cấp source release,
review PASS thật, human authorization, task/allocation hay latch/claim thật.

Bootstrap nhận preparation + review đúng hash/quota/trust và lease≤600s riêng,
không cần cold proof/human/claim nguồn. Stage bootstrap bị parent/pipeline,
worker/proxy và finalizer chặn trước capability. Source vẫn cần đầy đủ bundle
cold/review/human + hai claim consumed atomic; thêm đọc cold-control/report/
state/mounts/native liên kết SHA. Không dùng self-test làm proof thật.

Producer `run-bootstrap.ps1` không tham số là nhánh thực: chỉ đọc fixed path
`reviewed/input`, mặc định thiếu review thì dừng trước Docker. `-SelfTest` chỉ
nhận OFFLINE review/scope tại `self-test/input`, chỉ tạo SELF_TEST result.
Image cache, CA gốc, UID65534/RO/none/96MiBCPU.25/privateIPC/dropALL/NNP/noports,
timeout KILL30s; bounded create-once output, ownership label cho cleanup.
Raw report + actual native exit/state/noOOM/mounts/guard/pins/hash/thread/FD/UTC
được nối qua completion SHA. Cobalt/LICENSE/NOTICE/locks và mọi downloader/
parser/transport/caps/budget giữ nguyên; chỉ thêm entry guard trước pipeline.

Thực chạy: 11 host cases trên final hash (7binding +4profile), 3extra refusals
(fixture review vào nhánh real, self-proof-as-real, create-once) và lệnh real
default-off native nonzero. Một cold đầu và một cold final sau bổ sung raw
native/binding: đều native0/noOOM, 4entry capabilities bị chặn +2scalar guards,
threads1→1, FD4→4, sourceCalls/DNS/HTTP/main0. Không chạy lại31/26/7 hoặc whole
album. Host profile lần đầu dùng guard lịch sử có Cmd khác, nên không dùng
4negative đó làm chứng minh; final dùng actual bootstrap guard có control PASS.
Chi tiết raw và receipt là nguồn kết quả; fixture PASS chưa phải source PASS.

Runtime worker512CPU.75+proxy96CPU.25=608MiB, source watchdog225, 50/5/2meta+N,
8/16metadata,20/16image,max116/80,metadata30/prepare180/item60reserve10,
HTTP10-20/picker2/raw256unique64/trace256owner32map64/IPC600/SSRF-TLS/policyC giữ.
Ảnh1 historical human accepted (SHA7fc489…2f0d2) giữ riêng; ảnh2–5 chưa chạy.
Main/gallery/API/UI/DB/settings/host/deploy/video3 không đổi/không chạy.

Xem RUNBOOK.md và binding-request-final.json trong evidence. Bản mã mới chưa
có reviewer độc lập đúng hash; real cold proof còn PENDING. Sau review thủ tục,
mới soạn nhiệm vụ nguồn all5 riêng để chủ giao; không có lệnh nguồn trong phiên.
Một cold PASS không chứng minh tải album. Visual mỗi SHA còn bắt buộc sau nguồn.
