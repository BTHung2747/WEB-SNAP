# Bàn giao lượt nguồn all5 — 15/10/2026

**FAIL_STOP_NO_RETRY — OCI start proxy; không có metadata hoặc JPEG mới.** Đây là kết quả thực của đúng một entry được chủ giao, không phải kết quả fixture. Không sửa runtime sau lỗi và không thực hiện lượt thứ hai.

## Quyền, mã và lệnh thực chạy

Đọc AGENTS/PLAN/STRUCTURE/AUDIT/PROGRESS/WORK_COORDINATION và TASK của reviewer. Preflight đọc đúng packet reviewer/human đã seal, raw human/question binding và `WorkflowGates` real (không Fixture) đạt. Human approval mới tại chat reviewer khác với review ảnh1 lịch sử. Task `00afc96711584f568a94804857f0abf9`, allocation `7a74d04994154f14b2d127e54711fa09`; proposal `5b71d271292b430db3ef0c731a4d671a`.

- ProposalSHA `d675f8b685b8b668546ffea0ca47edaf0ed73d56a4d919202cef37a19e91535a`.
- FreezeSHA `a8b983281646a1b2a0316b972b107e788ef0d21126bfbebf616704109b5a2911`.
- Orchestration codeHash `bae83c01b2031aea286a912444d274808ff17eeb36b01ed216cf6a614b98b423`.
- Candidate sourceHash `175af656c2a108e3d8f564030c872c530045bfd7d960815306346f5c16af9ee1`; runtimeHash `c000b715baf471373fab65bbd83b30ab9b9b76542d24ef2bfcfa9e000604458b`.
- Orchestration packet manifest `c5cf1e45be68006d6e16f27cd3031a42a1c5e7c87edf346ebdd97f579b3b7821`; human manifest `87c23c4302ae23f6507b382be1a5be6f736e424ce5ba8311eb65883ae71c5aab`.

Lệnh duy nhất: `pwsh -NoProfile -File labs/tiktok/photo-album-reviewer-capture/run.ps1 -Mode source`. Entry thực exit20, UTC `2026-10-14T19:07:58.3825051Z` → `19:08:42.4876814Z`, VN `15/10 02:07:58` → `02:08:42`. Không retry/reset claim/renew TTL/task replacement. Đã chạy preflight, inventory trước/sau, collector và verifier bằng chứng riêng; các lệnh này không gọi nguồn. Collector ban đầu nhầm trường `bootstrap.expiresUTC`, exit1; giữ bản trước sửa và receipt lỗi rồi sửa riêng công cụ evidence, không sửa runner.

## Kết quả thực và nguyên nhân

| Chặng | Kết quả |
|---|---|
| Review/human/hash preflight | PASS, đúng bản review |
| Fresh cold networknone | Native0/container0; noOOM, cleanup0 |
| Binding v4/human provenance | Tạo đúng task/allocation, expiry bằng cold lease, không tăng |
| Atomic admission | Đã tạo task latch và allocation claim; giữ nguyên |
| Source runner | Native20, không timeout |
| Docker start proxy | Native1, không timeout; khoảng0,363s |
| Proxy/worker/validator process exit | Không có process exit; chưa khởi chạy |
| Metadata/bodyID/count/snapshot mới | NOT_RUN/NOT_OBSERVED |
| JPEG/full decode/SHA/visual | NOT_RUN; 0 JPEG mới |

Daemon stderr nguyên bản trong task `native.jsonl` chứng minh: OCI/runc thất bại **trước container init**, vì không tạo được mountpoint `/authority/source-claim.json` dưới thư mục `/authority` bind read-only. Runner tạo `/authority` từ release directory rồi bind file claim/latch vào hai đường con. Release directory của lượt này không có hai file mountpoint đó. `guard-proxy.json` đã lưu trước start: state created, Running=false/Pid0, resource/mount/isolation guard đã qua. `start-proxy` exit1; không có `create-worker/start-worker` hoặc validator. Đây là lỗi wiring mount; chưa có phép đo TikTok/DNS/TCP/TLS/HTTP, không quy cho CDN/nguồn.

Raw runner `sourceCalls=UNKNOWN_USE_REQUEST_ACCOUNTING` giữ nguyên; không chỉnh thành PASS/0. Accounting không sinh. Kết luận riêng 0 metadata GET/0 JPEG GET dựa trên lifecycle OCI thất bại trước Python proxy và trước tạo worker, không phải counter HTTP đo được. Bytes/timing/body nguồn chưa đo; quota cấu hình không phải proof source byte guard đã chạy. Không có file để trình visual, không dùng xác nhận ảnh1 cũ cho all5.

## Giới hạn và thư viện

Giữ nguyên cached image `sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e`, CA/pins/LICENSE/NOTICE/locks và thư viện đã review: Requests2.34.2, urllib3-2.8.0, yt-dlp2026.8.19, HE2.7.1, Cobalt/FFmpeg hiện có. Chỉ dùng runner, Process/native/API Docker, reader/hash validator đã có; không cài, build hoặc viết parser/transport/solver. Phiên này không thay chức năng thư viện; tham chiếu xác minh API/pins kế thừa ở workflow/reviewer-capture handoff.

Target duy nhất `https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421`, expectedID7678209751167110421, count5/indices1–5/key `8fa38af83f8dc423d4d78b8044d5d7b26ae3fdef9ec73eab59fe04f8475c2127`. Budget≤2GETmetadata+conditional≤5JPEG; HEAD/redirect/retry0, meta8/16MiB, JPEG20/16MiB, tổng116/80MiB; meta30/prep180/item60/reserve10/HTTP10–20/active225; worker512CPU.75+proxy96CPU.25=608MiB. Fresh cold96CPU.25/networknone/user65534/rootfsRO/privateIPC/dropALL/NNP/deadline30/lease590. SSRF/TLS/DNSraw256unique64/policyC/trace/IPC không đổi.

## Evidence và cleanup

Evidence `docs/evidence/tiktok-photo-album-all5-source-20261015/`; manifest liệt kê riêng current evidence, handoff, shared docs và đúng current workflow root/execution root/task root/global reservation file; không scan base real để nhận bằng chứng người khác. Fresh execution `7caf558ad3cf45ae8caf8786258e300a`; namespace-index ghi absolute paths. Source claim, latch, workflow reservation và release/provenance/raw giữ nguyên, kể cả đã lỗi. Không thêm file vào frozen root cũ hoặc sửa golden/verifier.

Cold own container và source own proxy/2network đã dọn bằng ownership; inventory sau xác nhận cả4 ID không còn. Images13/oldcontainers25/volumes35 và main image giữ nguyên, renderer vẫn absent. Baseline có một network ID biến mất và một ID ngoài current ownership xuất hiện; nguyên nhân **UNKNOWN**, không coi network toàn host nguyên trạng và không thao tác các ID ấy. `cleanup-assessment.json` ghi tách own cleanup khỏi drift này.

AUDIT/PROGRESS cập nhật insert-only từ snapshot ngay trước chèn (giữ cả snapshot đầu phiên có thể trước dispatch). Protected-before/after và verifier bảo vệ history/packets/source/runtime; trạng thái fail nguồn không bị đổi thành PASS vì verifier evidence đạt.

## Bước tiếp theo

Kiểm độc lập evidence và lỗi wiring mount trước. Đề xuất successor **chỉ offline**: dùng authority mount tree riêng có mountpoint claim/latch sẵn, hoặc flat file mounts nếu chứng minh guard/reader tương đương; tuyệt đối không mở quyền ghi `/authority`, rootfs, tăng cap hoặc thay host. Phải kiểm start với cấu trúc source thật nhưng không network nguồn, read-only canonical claim/latch, tamper/path/cleanup và đúng hash. Chỉ sau review sửa offline và **nhiệm vụ nguồn mới riêng** mới xét lượt khác; quyền/latch/claim hiện tại không được tái dùng. Main/gallery/API/UI/DB/deploy không bật.
