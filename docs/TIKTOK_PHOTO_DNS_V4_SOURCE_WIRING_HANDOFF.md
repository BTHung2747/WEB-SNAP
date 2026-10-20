# Source wiring DNS v4 offline — 13/10/2026

**SOURCE_WIRING_OFFLINE_PENDING_INDEPENDENT_REVIEW.** Đã nối DNS v4 đã nghiệm
thu vào successor riêng và chạy kiểm offline. SourceGate=false; chưa chạy
TikTok/CDN/provider/source DNS-HTTP, cấp quyền nguồn hoặc tiếp bước3–5.

## Mã và provenance

Lab mới `labs/tiktok/photo-dns-v4-source-wiring/` xuất phát từ
`photo-dns-inspection-source-trial` (103source/runtime101), giữ bản RAW64-v3 gốc.
Producer/admission/IPC/observer/receipt/guard/finalizer từ bản
`dns-unique-admission-hardening` đã kiểm độc lập CLOSED_OFFLINE_CONFIRMED được
tái dùng nguyên byte: dns_admission, dns_counts, dns_helper, dns_ipc,
dns_diagnostic, candidate, common, finalize. Module fixture_helper cũng giữ byte.
F-V4-OUTER-ADMISSION-TYPED-LINK và missing-byte giữ trạng thái đã đóng offline.
Source proxy_entry/worker_entry, ownership, policyC/batch/accounting/trace và bộ
tải giữ nguyên từ source baseline. Finalizer đọc observed admission v4 thay
inspection v3; validator gọi đúng strict outer/nested stats_valid trước equality.

Glue mới chỉ namespace/hash inventory/ROmount/labels, gate offline đúng freeze,
source deny trước capability và fixture malformed suffix rõ ràng. OfflineLoop/
mock129 từ bản v4, chỉ thêm mode malformed-tail vào fixture producer actual.
Runner từ chối default/source trước import hợp đồng/source allocation; child
stage_policy chỉ nhận offline. Source_contract được giữ với root/hash namespace
successor, không được runner import và không có authority nào được tạo/chạy.
Đường source dormant chưa được mở, không được coi đã đủ điều kiện chạy nguồn.

Freeze trước checks: **106 source files/104 runtime files**. Provenance từng tệp
ghi SHA origin v4/source baseline và successor; codecopies, source-before-after,
runtime inventory thực chạy, hash module Python được lưu. Không sửa code sau freeze.
Giữ Cobalt a636575b09de1fc55d9b8cd98cac88f5f2f16b42/AGPL-3.0, Requests2.34.2,
urllib3-2.8.0, HE2.7.1 public API, yt-dlp2026.8.19, FFmpeg, stdlib và Debian
ipaddress SHA8fc7549e…5355e1. Đã đọc nghiên cứu OSS/lock/code/schema đúng pin;
không cài gallery-dl/F2/DouK, viết parser/resolver/downloader/TLS hoặc private API.
LICENSE/NOTICE/credits/dependencies nguyên byte; thêm notice wiring riêng.

## Kiểm mới thực chạy

- **33 focused checks/native0**, 5 native helper trong networknone96MiB/CPU.25.
  Typed v4 control accepted, 4 outer bool/equal-float counterexamples reject
  HELPER_ADMISSION_SCHEMA. Nested bool/missing outer/missing byte receipt+trace/
  native float/trace order deny có cấu trúc. Raw257, unique65, private sau65unique,
  malformed duplicate sau64 deny; fullkey proto0vs6/first order giữ. Classifier
  actual Debian SHA đúng; child source deny là unit injection vào public Path,
  không coi là chạy source child. Native mock129 returns40/raw129/duplicate89,
  late cleanup/observer ~1.042s vượt helper1s vẫn TimeoutError dù native0; primary
  OSError exact object/cancel CancelledError−15/physical closure0 giữ. FD4→4/thread1→1.
- **5 fresh whole TLS fixture** trên wiring mới, cùng final code/hash. Mock129
  metadata2GET+conditional1JPEG, worker/proxy/validator/parent/child0, JPEG2170bytes/
  64×64/1frame/fullDecode PASS/SHA
  `3c94b9a6bbfab0c44c02d0c520dca952e23dc7a396e30a6ef3b0fe00bcc0cc3e`.
  V4 raw129/validated129/40endpoint/89duplicates/admitted40 thực qua producer,
  IPC/observer/receipt/trace/finalizer. Unique65→ENDPOINT_CAP, raw257→RAW_PARSE_CAP,
  private-tail→POLICY_DENIED, malformed-tail→ROW_INVALID: helper0 nhưng metadata
  FAIL, origin TCP0/imageGET0/JPEG0, worker20/validator20/proxy0. Wrapper0 của các
  ca lỗi chỉ nghĩa là đúng kỳ vọng từ chối, không metadata/file PASS.
- **8 finalizer replays** trên owncopies của fresh mock129, networknone96MiB,
  không HTTP/DNS/helper/download mới. Typed control0 giữ JPEG; outer bool/rawCap
  float/endpoint float/missing và missing bytes20/DNSgatefalse, other gates và
  provisional file contract PASS. Dọn onlyownJPEG+part; 2 sentinel bool/float giữ
  preexisting JPEG SHA, dọn ownpart. Original fixture JPEG/receipts nguyên byte.
- CLI default/source20 trước capability; copied wrong-hash harness1 trước Docker
  native. Gate source/runtime/proofs khớp code final và sourceGate=false. Không
  task/allocation/claim/latch/authorization mới hoặc reset/retry consumed claims.

Không rerun author/history154/123/25/99/64 hoặc các whole matrix cũ để tăng count.
Các số raw129/40/89 trong lượt này là synthetic; raw nguồn cũ không được lưu nên
không recount hay suy nguyên nhân duplicate/IP nguồn. Fixture không ảnh TikTok.

## Guards, cleanup, bằng chứng và giới hạn

Raw≤256 validate-all trước stable fullkey dedup/unique≤64; SSRF/public flags/TLS/
policyC/setup10/end−1/helper1/scan250ms cooperative/end−10ms/retained96-design128KiB/
IPC16–32KiB/stats512/trace256-owner32-map64/cancel/native/owned cleanup giữ.
Metadata30/prepare60/HTTPconnect10-read20/2metadata+conditional1image/redirect0/
retry0/HEAD0/caps8–16+20–16/workflow36MiB/dimension8192/pixels16M giữ.
Sequential cached31742091…dfa417e/pullnever; worker512MiB/CPU.75+proxy96MiB/CPU.25
=608MiB, validator96 sau roles stop/UIDRO/privateIPC/dropALL/NNP/noports/ROcode/
owninternalnets. Không build/pull/install hoặc thay host/stack chính.

**Own24 containers/10 internalnets absent**,13 images/25 old containers/35 volumes/
main image giữ; renderer absent đúng ID theo Docker cleanup gốc. Globalnetwork
1old/1new ID, cause UNKNOWN; không sửa host hoặc dọn ngoài ownership. Protected
2841 current files và3197 historical files (hai tập có overlap), parent hardening/
audit manifests, source103/101 và accepted v4 92/90 giữ SHA. Original raw FAIL,
goldens/verifiers/claims/latches/LICENSE/libs giữ. AUDIT/PROGRESS insert-only bảo
toàn byte; namespace mới có manifest fullcoverage/seal+readonly verifier.

Prepare Attempt1 sai giả định tên AUDIT.before.md của hồ sơ audit; exit1 trước
lab/resources/tests. Script/raw/receipt giữ; successor lookup đúng beforePath
từ doc-successor immutable. Đây là lỗi công cụ chuẩn bị, không lỗi runtime/source.

Lệnh thực bundled PowerShell7 -NoProfile -File/cwd D:\WED SNAP: prepare Attempt1
FAIL rồi repairedprepare; wire-tests; freeze; run-checks g1Attempt1; make-gate;
cold-hash; run-whole (5case tuần tự); replay; collect; make-verifier; insert-docs;
verify -Seal/readonly. Native/state/signal/UTC-VN/hash/guards/case result được lưu
trong `docs/evidence/tiktok-photo-dns-v4-source-wiring-20261013/`.

Chưa kiểm fullheap/libc bulk allocation, mọi CPU<250ms, IPv6 connectivity hoặc
TLS/TikTok nguồn thật. Source runtime gốc vẫn RAW64-v3/FAIL_NO_JPEG; visual
NOT_REVIEWED/video human2/3/mẫu3pending/galleryOFF/app/API E2E/deploy giữ.
Wiring offline PASS chưa cho phép nguồn hoặc kết luận watermark. Cần nhiệm vụ
kiểm độc lập trước khi đề nghị bất kỳ source trial riêng nào.

[Prompt kiểm độc lập wiring](evidence/tiktok-photo-dns-v4-source-wiring-20261013/NEXT_PROMPT.md).
