# Bước3a chuẩn bị source trial v4 — 13/10/2026

**SOURCE_TRIAL_V4_PREPARATION_PENDING_INDEPENDENT_REVIEW.** Successor
`labs/tiktok/photo-source-trial-v4-preparation/`; evidence riêng
`docs/evidence/tiktok-photo-source-trial-v4-preparation-20261013/`.
Nguồn thật chưa được gọi; sourceGate=false/realClaims0. Ảnh TikTok vẫn
FAIL_NO_JPEG/visual NOT_REVIEWED, video2/3/mẫu3pending/galleryOFF/app/API E2E/deploy giữ.

Đã đọc wiring106/104 và review seal+readonly252artifact, xác minh parent582 và
dispatch successor; giữ nguyên các P2 đã CLOSED_OFFLINE_CONFIRMED. DNS v4,
stats_valid outer+nested, missing byte, classifier/SSRF, parser Cobalt, downloader,
HTTP/TLS/yt-dlp/FFmpeg, raw256/unique64/fullkey/order và lifecycle không đổi.
Chỉ sửa source_contract/source_policy/common/runner và admission glue của child,
kiểm trước DNS và trước prepare. Freeze mới **108source/106runtime**, codecopies/
provenance/hash/source-before-after/runtime thực chạy, không sửa code sau freeze.

## Hợp đồng và API tái dùng

Gate version2/dnsProtocol4, roles cold-v4/authority-v4/whole-v4. PREPARATION_NO_SOURCE
sourceGate=false và OFFLINE_SOURCE_TRIAL_V4_FIXTURE_ONLY khác scope/status với gate
ONE_PHOTO_SOURCE_TRIAL_V4 đã review cần cho lượt sau. Builder hiện chỉ xuất gate
chuẩn bị, không cấp source gate, authorization, allocation hoặc claim thật.
Không thể dùng fixture, đổi một cờ, hoặc chỉ bỏ deny để chạy nguồn.

Contract strict typed/exact keys/caps/schema, hash code/runtime, canonical path/
ancestor reparse deny, new task+allocation IDs, target mẫu7678209751167110421 và
selectedIndex1. Reject hai task/allocations consumed cũ. Human/review/preclaim
attestation riêng cần cho live; auth/allocation expiry UTC còn hiệu lực và tối đa
10phút, không tăng metadata/prepare deadlines. Latch CreateNew trước claim và
trước capability; crash sau latch/reuse/cùng task allocation khác đều không reset.
Source claim/control chứa hash/IDs/quota/expiry, không cookie/signed URL. Child
kiểm runtime inventory thật và hai claim RO trước source imports/request/prepare;
expiry, CA/env/cookie/proxy/fixture imports được từ chối. Source Docker guard giữ
noExtraHosts/no fixture CA/env/mount; source_contract được runner dùng đồng bộ.

Tái dùng stdlib/JSON schema v4 hiện có, .NET FileMode.CreateNew/FileShare.None/
Flush(true), JsonDocument parse và public Enumeration để từ chối duplicate/case
alias keys, không viết parser/transport/solver. RowsHash dùng ordinal path +NUL+
SHA+LF để khớp PS/Python, không phụ thuộc thứ tự JSON/culture. Runtime giữ Python
3.11.2/Debian classifier, Requests2.34.2/urllib3-2.8.0/HE2.7.1/yt-dlp2026.8.19/
FFmpeg/Cobalt a636…AGPL/LICENSE/NOTICE/locks, no install/build/pull. Host harness
bundled PS7.6.5/.NET10.0.11 đo thực. API đã đối chiếu nguồn chính thức:
[FileMode](https://learn.microsoft.com/en-us/dotnet/api/system.io.filemode?view=net-10.0),
[Flush](https://learn.microsoft.com/en-us/dotnet/api/system.io.filestream.flush?view=net-10.0),
[JsonDocument.Parse](https://learn.microsoft.com/en-us/dotnet/api/system.text.json.jsondocument.parse?view=net-10.0),
[Python3.11 datetime](https://docs.python.org/3.11/library/datetime.html).

## Kết quả mới thực chạy, không nguồn thật

- 50 authority-contract checks/native0: typed fixture accepted, mock consume;
  reuse/otherallocation same task/callback fail sau latch giữ consumed; version
  bool/protocol float/index bool/quota/target/old IDs/expired/future/missing expiry/
  schema/scope/hash/proof/roles/path/duplicate keys deny trước capability. Fixture
  không authorize live. Capability1 chỉ counter injection, DNS/HTTP không gọi.
- 21 cold checks/native0/96MiB networknone: imports thật proxy/worker/finalizer,
  runtime hash và original CA đúng; claims ở cold/authority là bytes mô phỏng có
  FIXTURE_LABEL, không quyền thật. Runtime/claim/hash/expiry/target/quota/index/
  type/env/cookies/proxy/imports/CA drift deny, DNS/TCP hooks0. Cold valid policy
  không chứng minh live network/source; guard kiểm networknone/noExtraHosts.
- 1 whole TLS mock129 qua **runner mới với FixtureAuthority**: mock latch/claim
  consume trước capability; metadata2GET+conditional1JPEG, parent/child/worker/
  proxy/validator0,2170bytes/64×64/1frame/fullDecode/SHA
  `3c94b9a6bbfab0c44c02d0c520dca952e23dc7a396e30a6ef3b0fe00bcc0cc3e`.
  V4 raw129/40endpoint/89duplicate synthetic. Không metadata nguồn TikTok.
- 7 runner refusal tests: default/source missing, fixture/preparation gate aslive,
  source+FixtureAuthority, consumed mock, invalid mock quota đều20; native logs
  không tăng/không network mới. Gate chuẩn bị vẫnfalse.
- 3 copied-fixture finalizer replays/networknone96MiB: control0, outer bool20/
  DNSgatefalse/dọn ownJPEG+part, sentinel bool20/giữ JPEG preexisting SHA/dọnpart.
  Packet/file provisional PASS chưa acceptance cuối, no newHTTP/DNS/download.

Giữ raw FAIL: prepare1 parent docs đã có dispatch successor, trước lab/resources;
wire-runner1 lỗi quoting PowerShell trước execution; cold1 OCI nested core-RO
mountpoint lỗi trước Python/nativeStart1/state128. Scripts/raw/state/cause giữ;
successor chỉ lookup chain/quoting/harness mount, không đổi guard/runtime để PASS.
Cold2 dùng cached core đã hash kiểm, giữ ROphoto/UID/dropALL/NNP/privateIPC.

Guards: metadata30/prepare60/HTTP10–20/2meta+1conditionalimage/redirect0/retry0/HEAD0,
8–16MiBmetadata/20input–16output/workflow36MiB, helper1/setup10/reserve1/scan250ms/
retained96-design128KiB/IPC16–32KiB/stats512/trace256-owner32-map64/policyC giữ.
RAM8GB sequential/cached image/narrow96CPU.25/whole512+96=608/validator96saurolesstop/
UIDRO/privateIPC/dropALL/NNP/ROcode/noports/owninternalnets. Own8containers/2nets
absent;13images/25oldcontainers/35volumes/main/rendererđúngID giữ, global drift
UNKNOWN nếu có/nohostfix. Protected4696/source106/104/history/P2/goldens/claims giữ.

Lệnh thực bundledpwsh -NoProfile -File: prepare1FAIL→prepare lookup dispatch;
wire-runner1FAIL→wire-runner; freeze; contract-tests; run-cold1FAIL→run-cold2;
make-offline-gate; run-whole; build-gate; boundary-tests; wire-replay/replay;
collect; insert-docs; verify -Seal/readonly. Current proof/schema/hash/actualexits/
native/signal/UTC-VN/coverage được lưu, không sửa verifier/golden cũ để PASS.

## Giới hạn và bàn giao

Chưa chạy real live gate/authorization/source Docker network hoặc source child
HTTP. Giao thức source đã đồng bộ và cold/contract/offline được kiểm; không
tuyên bố dormant path đã được nghiệm thu live. Không kiểm lại fullheap/IPv6/
timingmọiCPU hoặc mọi matrix lịch sử. Trust/task authority là hồ sơ local của
người dùng và review, không phải chữ ký dịch vụ bên ngoài. Cần kiểm độc lập code,
scope separation, consume/expiry/paths, raw evidence và mọi guard trước lượt sau.

[Prompt kiểm độc lập](evidence/tiktok-photo-source-trial-v4-preparation-20261013/NEXT_PROMPT.md).
[Dự thảo nhiệm vụ nguồn riêng](evidence/tiktok-photo-source-trial-v4-preparation-20261013/SOURCE_TRIAL_DRAFT.md)
chưa có hiệu lực hoặc quyền nguồn; chỉ người dùng giao riêng sau review mới xét.
