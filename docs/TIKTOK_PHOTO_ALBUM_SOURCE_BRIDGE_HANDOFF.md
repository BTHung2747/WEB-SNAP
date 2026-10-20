# Bàn giao bridge nguồn album TikTok — 14/10/2026

**Implemented/default-off; author offline PASS, chờ kiểm độc lập.** Chưa released,
không có human task/review/freshcold/allocation/expiry/claim thật. Không tải album
nguồn, bật main/gallery/API hoặc deploy. Successor ở
`labs/tiktok/photo-album-source-bridge/`, evidence riêng
`docs/evidence/tiktok-photo-album-source-bridge-20261014/`; final **freeze-8.json**.

Reader live và Python admission bind exact version4/scopes/types/target/photo/
all5/count5/indices1..5/structural snapshot/validatedN/quota/current hashes/pins/
trust/image/expiry tới prep+independent review+cold guard/native completion+
human task+allocation. Không issuer hoặc always-deny stub. Consume CreateNew+
Flush latch trước capability, retain consumed khi crash/reuse/collision. Fixed
path/reparse ancestors được áp dụng cả write namespace. Old3 onephoto IDs deny.

Source-only bundle `runtime/` và `photo-runtime/` tái dùng cùng consumer/Cobalt/
JPEG contract/locks/licenses, không providers/tests/offline glue/sitecustomize.
Mount source picker tại `/app/apps/media/src/tiktok/source_photo` để dùng deps
đã cache, không qua fixture provider path. OriginalCA, no fixture env/ExtraHosts/
customCA/accountcookie/browser/solver. Mandatory admission trước imports/DNS/
HTTP/prepare/từngGET; readonly finite cleanupPolicy trước metadata giữ hai P2
admission đã đóng. Không thay transport/backend hoặc code ứng dụng.

## Kết quả thực trên bản mã cuối

- 27 pure contract cases PASS; valid harness accepted/consume, 26 negative native
  contract exit20. Gồm wrongscope/flag/types/ID/all5/quota/hash/expiry/trust/review/
  cold/human/allocation/missing proof/oldIDs/reuse/crash-after-latch/junction/claim
  collision. Latch retained; junction không ghi neighbor và link own đã dọn.
- Default/source-missing-proof/harness-as-source: host exit20 trước Docker.
- Cold9 actual source-only imports/networknone/original trust/pins/native0/noOOM/
  provider modules0, current inventory tương đương rglob cũ. Refs vẫn harness,
  `liveProof=false`; không thành fresh live permission. Cold container dưới30s,
  host wrapper còn Docker setup/inspect/cleanup, không claim hostE2E30.
- Whole4 all5: TLS **FIXTURE_ONLY**, 2metadata+5image GET, child/parent/proxy/
  validator exits0; five JPEG magic/MIME/ffprobe/1frame/full decode/dimensions/SHA
  PASS; sentinel giữ. Đọc bytes/SHA đầy đủ trong validator receipt.
- Whole5 fail-second: ảnh2 HTTP503; imageGET2, khôngGET3, child-9/signal9, parent20/
  validator20/proxy0; JPEG/part sở hữu0, sentinel giữ. Wrapper0 chỉ test đúng lỗi,
  không là source/file PASS. Các P2 quota/Operations/HTTP giữ nguyên guard.

Raw FAIL và attempts1..8/code attempts/freeze1..7 được bảo toàn: sort mismatch
LIVE_PREPARATION (tập file/hash khớp nhưng thứ tự PS/Python khác); stale expiry sau
ngắt vài giờ; metadata HTTP200/body fake nhưng picker MODULE_NOT_FOUND ở mount
mới; public Node probe xác nhận resolution cause; extra cold Node OTHER và
TimeoutExpired5s ở CPU.25; cold137/noOOM do watchdog30; lỗi wrapper quote/import
trước capability. Không sửa manifest lịch sử hoặc nâng fixture thành nguồn PASS.

Inventory dùng public os.walk pruning cùng excluded set; normalize **thứ tự**
rows, không row/hash. Node CLI được kiểm trong whole đúng workerCPU.75 và timeout
runtime2s giữ nguyên. Empty Node probe ở cold không cùng profile, FAIL được giữ;
không tăng runtime timeout để lấy PASS. API đúng pin/lý do/glue/provenance tại
API_NOTES.md/code-diff/runtime-mirrors/derivations; không build/pull/install deps.

## Giới hạn và phần chưa biết

metadata≤50/selected≤5/2meta+N/redirectretryHEAD0/8–16MiB metadata,
20input16outputMiB/ảnh/max116–80MiB; meta30/prepare180/item≤60reserve10,
HTTPconnect≤10read≤20, picker≤2s, watchdog225 active không hostE2E;
DNSraw256unique64/trace256owner32map64/IPC600/SSRF-TLS/policyC không đổi.
512MiB CPU.75+proxy96MiB CPU.25=608; validator/cold96 sau roles stop; userRO/
privateIPC/dropALL/NNP/defaultseccomp/noports/ROcode/own nets.

Chưa tạo producer/issuance/bootstrap proof thật. Cần thủ tục riêng được review
để phát fresh real cold và human all5 task; không rename harness scope/flags hoặc
lấy ảnh1 claim đã consumed để mở5ảnh. Draft real refs/IDs/expiry null, quyềnNONE.
Source structural snapshot không phải content identity; signed URLs/cookie/body
chỉ RAM. Live runtime/TikTok/CDN/DNSHTTP/ảnh2–5/API E2E đều NOT_RUN ở đợt này.

Ảnh1 thật đã human accepted riêng, SHA
`7fc4899a9e249f93789724dd036852110f360eb570b4b85539fb38ebdde1f0d2`;
chủ xác nhận “Hình đúng, không thấy watermark TikTok”. Không sửa visual lịch sử.
Không coi5JPEG synthetic là watermark/album nghiệm thu. Video3/các backlog khác
giữ nguyên, YouTube/production/API/UI/DB/lifecycle không sửa.

## Lệnh, bảo toàn và bước tiếp

Đã chạy scripts contracts/cold/dependency/final/remainder theo actual-commands.json;
native JSONL ghi exit/UTC/VN/timeout/stdout cố định. Chốt cuối06:11:55UTC =
13:11:55VN ngày14/10/2026. Guard/state/budget/accounting/operation/trace/DNS/registry/
file contracts đầy đủ trong mỗi attempt. Chỉ remove own IDs theo labels, không
global prune. Inventory cuối13images/25oldcontainers/35volumes, main digest giữ;
renderer expected absent giữ. Trước mới full container inventory thiếu: snapshot
đầu chỉ-running, nên đối chiếu inherited reference và ghi đúng giới hạn đó.

Full manifest/seal+readonly và protected-before/after/code/runtime hash/docinsert
ở namespace mới. Prompt review độc lập NEXT_PROMPT.md; chưa giao source permission
từ author PASS. Sau review bridge mới xét procedure/cấp quyền và một workflow
nguồn5ảnh riêng, review từng JPEG/SHA; không tự chạy source/main/gallery/deploy.