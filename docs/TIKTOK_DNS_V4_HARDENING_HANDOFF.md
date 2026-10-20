# DNS v4 outer admission hardening — 13/10/2026

**FIXED_PENDING_INDEPENDENT_REVIEW.** Bước1 của nghiên cứu OSS đã triển khai và
kiểm offline. Không tự đóng F-V4-OUTER-ADMISSION-TYPED-LINK P2. Ảnh TikTok thật
vẫn FAIL/JPEG0/visual NOT_REVIEWED; JPEG trong lượt này là fixture TLS.

## Mã đã sửa và lựa chọn thư viện

Successor: `labs/tiktok/dns-unique-admission-hardening/`; evidence riêng:
`docs/evidence/tiktok-dns-unique-admission-hardening-20261013/`.
Reuse `stats_valid` hiện có để kiểm outer `dnsAdmission` trước Python dict
equality/link với `dnsDiagnostic.admission`. Sai schema/type/missing trả PARTIAL,
accepted=false, reason `HELPER_ADMISSION_SCHEMA`; không viết parser/deep comparator.
Giữ kiểm nested, missing bytes, native exit, cap, helper ID và trace như bản PoC.

Thay đổi chức năng duy nhất: cổng kiểm schema và một comment trong
`dns_diagnostic.py`. `run.ps1`/`lab_contract.ps1` chỉ đổi namespace/mount/labels/hash
inventory cho successor; thêm HARDENING_NOTICE. Các file còn lại byte-identical
với PoC, provenance ghi cả SHA bản gốc và bản dẫn xuất. Freeze trước checks:
**92 source files/90 runtime files**; không refreeze hoặc đổi code sau thử.

Đã đọc nghiên cứu OSS, heads/official-references/cobalt-parity và code schema
đúng pin. Cobalt a636575b09de1fc55d9b8cd98cac88f5f2f16b42/AGPL-3.0 hiện có giữ;
stdlib JSON/dict, Requests2.34.2/urllib3-2.8.0, public HE2.7.1, yt-dlp2026.8.19 và
FFmpeg giữ. Gallery-dl/DouK/F2 chỉ đối chiếu từ nghiên cứu đã đóng băng, không
cài/chạy/copy parser/private helpers. OSS ngoài không có hợp đồng receipt riêng
này, nên chỉ bổ sung glue còn thiếu. LICENSE/NOTICE/locks/classifier nguyên byte.

## Kết quả thực chạy

- **99 fresh narrow checks/native0** trong cached image, networknone96MiB/CPU.25.
  Bốn outer-only counterexamples JSON roundtrip (version=true, rawCap=256.0,
  endpointCount=1.0, duplicateCount=false) tái hiện false acceptance trên module
  PoC frozen; cùng dữ liệu trên successor bị structured reject. Equal float/bool
  ở mọi numeric field, thiếu mọi admission key/outer object, extra key, valid
  schema nhưng link mismatch, bad nested, native/byte/trace conflicts đều deny.
  Typed control accepted; missing-byte fix không phát sinh KeyError.
- **9 native helper subprocess**: numeric và mock129 accepted; raw129/40unique/
  89duplicates giữ. Late cleanup/observer ~1.043s vượt deadline1s vẫn TimeoutError
  dù helper0; primary OSError giữ đúng object; cancel CancelledError/native−15;
  kill−9; packet PASS→exit20 và PASS→hang−15 đều FAIL. Helpers reaped, pipesclosed,
  groups0; FD/thread không tăng. Đây là subset mới, không rerun matrix lịch sử.
- **1 fresh whole TLS mock129**: metadata2 GET + conditional1 JPEG; parent/child/
  worker/proxy/validator actual0. JPEG2170bytes,64×64,1frame,fullDecode PASS,
  SHA `3c94b9a6bbfab0c44c02d0c520dca952e23dc7a396e30a6ef3b0fe00bcc0cc3e`.
  Receipt v4 raw129/validated129/endpoint40/duplicate89/admitted40, native0 và
  closure0. Không có nguồn TikTok/CDN/DNS/HTTP ngoài mạng fixture.
- **8 finalizer replays** trên bản sao fresh fixture, networknone96MiB, không
  HTTP/DNS/helper/download mới: control0 giữ JPEG; outer version bool/rawCap
  float/endpointCount equal float/missing version và missing bytes đều20,
  DNSgatefalse trong khi packet/file/trace/batch/operation/accounting vẫn PASS.
  Chỉ ownJPEG và ownpart bị dọn. Hai sentinel bool/float: JPEG preexisting có
  SHA giữ nguyên, ownpart dọn, validator20. Không biến provisional PASS thành
  acceptance cuối. Original fresh JPEG/receipts không sửa.
- Default/source CLI20 trước capability; copied dirty-hash harness1 trước Docker
  native command, sourceGate=false. Không tạo nguồn authority/task/allocation/
  claim/latch. Gate/proofs/source-before-after/runtime inventory cùng final hash.

Narrow Attempt1 bị sandbox từ chối Docker pipe tại inventory/native1, trước
container/network/tests. Raw và wrapper-failure giữ. Attempt2 dùng cùng frozen
code/harness với quyền Docker lab đã được giao; không sửa runtime để PASS.

## Guards, bằng chứng và giới hạn

Raw≤256 validate-all trước dedup, unique≤64/fullkey/first order, SSRF/TLS/policyC,
actual Debian classifier, helper1/setup10/end−1/scan250ms cooperative/end−10ms,
IPC16–32KiB/stats512/retained96–design128KiB giữ. Metadata30/prepare60, HTTP10–20,
2 metadata GET/conditional1image/redirect0/retry0/HEAD0, caps8–16/20–16/workflow36MiB
và dimensions/pixels giữ. Whole worker512MiB/CPU.75+proxy96MiB/CPU.25=608MiB;
validator96 sau roles stop; cached31742091…dfa417e/pullnever, UID/RO/privateIPC/
dropALL/NNP/owninternalnets/no hostports giữ.

**12 own containers/2 internal networks absent**;13 images/25 old containers/
35 volumes/main image giữ. Renderer absent đúng ID từ hồ sơ Docker cleanup.
Global network1old/1new ID khác, cause UNKNOWN, không sửa host hoặc dọn ngoài
ownership. Protected3197 files và parent manifests (PoC/audit/OSS) được hash-check;
original missing-byte FAIL/attempts, audit startup FAIL, source claims consumed,
goldens/verifiers/code/libraries giữ nguyên. AUDIT/PROGRESS insert-only nguyên
byte lịch sử; manifest successor bao phủ raw/scripts/codecopies/JPEG/docs.

Không kiểm lại heap toàn bộ/libc getaddrinfo, mọi CPU có hoàn tất250ms, IPv6
connectivity hay TLS nguồn; code các phần này không đổi. Không chạy author
154/123/25/11whole hoặc history302/105 để tăng số ca. Chưa wiring vào source;
accepted source RAW64-v3 vẫn FAIL/JPEG0. Video human2/3/mẫu3 pending/galleryOFF/
app/API E2E/deploy giữ. Fixture PASS không chứng minh tải ảnh TikTok hoặc watermark.

Lệnh thực: bundled PowerShell7 `-NoProfile -File`, cwd `D:\WED SNAP`: prepare,
wire-checks, freeze, run-checks g1Attempt1FAIL rồi g1Attempt2, make-gate, cold-hash,
lab run `-Stage offline -Attempt 1 -Case mock129`, replay, collect, insert-docs,
verify `-Seal` và readonly. Native exits/state/signal/UTC-VN/hash/cleanup nằm evidence;
terminal verifier chỉ kiểm integrity/offline proof, không tải nguồn.

[Prompt kiểm độc lập successor](evidence/tiktok-dns-unique-admission-hardening-20261013/NEXT_PROMPT.md).
Chỉ đề nghị review offline; bước2–5 của nghiên cứu cần nhiệm vụ riêng sau đó.
