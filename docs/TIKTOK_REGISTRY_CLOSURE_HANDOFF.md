# Registry closure evidence — bàn giao offline 11/10/2026

F-REGISTRY-CLOSURE-EVIDENCE/P2 đã sửa trong successor riêng
`labs/tiktok/wholephoto-registry-closure/`, evidence
`docs/evidence/tiktok-registry-closure-20261011/`. Trạng thái
**CLOSED_OFFLINE_IMPLEMENTATION_PENDING_INDEPENDENT_REVIEW**.
Ba counterexamples F-BATCH-RECEIPT-TRACE-CONSISTENCY vẫn CLOSED_OFFLINE_CONFIRMED;
không mở lại finding hoặc thay proof lịch sử. Gap closure được audit tái hiện trên
fixture copy; không chứng minh runtime thực bị rò socket hoặc đã tải ảnh TikTok.

## Thư viện, ownership và sửa đổi

Đã đọc chỉ thị/pins/locks và các trace/receipt/summary audit6. Tái dùng
batch_validation/operation_coverage/Trace/stdlib và public socket.close;
không có thư viện networking nào biết hợp đồng closure receipt của WED SNAP,
nên chỉ tự viết phần validation/boundary và fixture glue cần thiết.

Đối chiếu chính thức đúng phiên bản:

- [CPython3.11.2 socket.py](https://github.com/python/cpython/blob/v3.11.2/Lib/socket.py),
  public close/fileno và lifetime. Không gọi/chép helper private.
- [aiohappyeyeballs2.7.1 impl](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/impl.py),
  public start_connection/socket_factory/loop/delay/interleave; library sở hữu race
  và losers. Không đổi lời gọi này hoặc viết lại TCP/HTTP/TLS/DNS/parser.

Sockets.close hiện có trace BEGIN best-effort, physical socket.close unconditional,
trace END và giữ error object; delegate_cleanup giữ primary khi secondary trace
lỗi. Candidate, Trace, DNS helpers, operation/tcp/accounting/order validators và
policyC giữ nguyên bytes của predecessor. Registry2 calls đã có trong batch_tests
(finally của call rồi finally outer); Trace reservation có4 close rows.
Nhiệm vụ này dùng thêm fixture `closure-idempotent` gọi đúng registry.close hai lần
thật trước context completion. Source producer vẫn gọi một lần; không thêm facts,
fake END, sharedCID/header hoặc thay source behavior.

`batch_validation.py` thêm kiểm REGISTRY_CLOSE đúng registryOwnerID map với context:
1–2 calls, mỗi pair BEGIN→END, operationIndex integer1..N, codeBEGIN/OK/schema,
elapsed finite/bounded và live typed. First BEGIN live0..1, subsequent BEGIN0,
mọi END integer0 tương ứng final socketsLeft0. Hỗ trợ delegated winner đã close
trước BEGIN và registry trực tiếp close winner; không ép winner group live1 thành0.

Raw JSONL positions phải: winner END < CONNECT_200 END < close pair(s) <
TUNNEL_CLOSE snapshot < REQUEST_FINISH END < WORKER_RETURN.
TUNNEL_CLOSE là snapshot handler xuất **sau** registry cleanup, trước receipt;
không phải mốc bắt đầu handoff. Chỉ so thứ tự cùng context/registry, không elapsed
sort hoặc suy clock tuyệt đối/TLS/origin. Extra/missing/orphan/wrong owner/index/
reopen/ERROR/noninteger/live>0/early/late đều PARTIAL/reason/native20.

Missing cả REGISTRY_CLOSE pair vẫn numeric operation coverage COMPLETE; validator
mới từ chối. Request-side owners/sockets0 không thay library upstream closure proof.
Typed receipt version2/group records/owner mapping/operation/accounting/native/
JPEG/ownership gates khác giữ. Finalizer cleanup có sẵn giữ nguyên; dọn image.jpg/
part do lượt tạo, giữ unrelated/preexisting SHA.

File mới duy nhất `closure_probes.py`; 31 file successor, source283/runtime88.
Fixture faults nối vào existing validation_faults/proxy glue; chỉ offline. Raw
trace/receipts trước fault giữ riêng, copied fixture summary reflects altered
trace/count/coverage để cô lập gap, không sửa producer/source evidence để ép PASS.

## Kiểm thực chạy trên cùng bản mã

Final source snapshot SHA `621509c15c3b9a6c842f12212c865d3c029c11afd3e2b392dfca55c761c693dc`; mọi source-before/after và runtime inventory
khớp. Hai controls fresh metadata→JPEG (normal1, idempotent2) cùng native worker/
proxy/finalizer0, full JPEG decode/fileSHA. JPEG64×64 là FFmpeg fixture tổng hợp,
không ảnh nguồn hoặc bằng chứng watermark.

| Bộ kiểm | Số ca | Kết quả |
|---|---:|---|
| Accounting/index hợp đồng giữ nguyên |78| đúng expectation/native0–20 cũ |
| Derived batch |4| stall→winner3/fast7/firstwinner; fast45 prefix8/suffix37 UNKNOWN, connector20 |
| Policy C kế thừa |55| guards/admission/epoch/reap/deadline/cleanup giữ |
| Receipt–trace validation kế thừa |55| control0/negative20, không đổi input |
| Closure validation mới |47| 2fresh one/two close controls0,45contradictions20 |
| Closure physical probes |8| socket/pending0,FD4→4/thread1→1;2valid diagnostic0,6trace faults20 |
| Targeted fresh whole |10| JPEG provisional hợp lệ nhưng finalizer20/dọn own output |
| Whole kế thừa + mới |56+11| 5controls finalizer0; negatives20; harness0 theo expectation |

Typed faults bao gồm bool/float/negative/UNKNOWN/NaN/infinite/null, begin/end/live,
index/gap/reopen/extra/schema, one/two calls lỗi, closure trước winner/handoff và
late sau snapshot/return. IO BEGIN/END, cap thực owner32 qua repeated cleanup,
trace raises và primary+secondary cleanup dùng sockets thật, networknone. Error
identity giữ ở raiseBEGIN/END/primarycleanup. Physical closed0 vẫn diagnostic20
khi trace thiếu; không coi containment hoặc counters0 là evidence COMPLETE.

Fresh targeted live1/missing wholepair còn trace/operation/accounting/JPEG khác
PASS, worker/proxy0 nhưng finalizer20/REGISTRY_CLOSE_LIVE hoặc CLOSE_COUNT.
Terminal-only giữ operation incomplete/proxy30/finalizer20; không ép nó vào
category chỉ batch fail. ERROR/wrong owner/early/late/extra cũng bị từ chối.
`closure-preexisting` giữ keep.bin SHA, image.jpg/part do lượt tạo không còn.

Lệnh thực chạy từ D:\WED SNAP bằng bundled PowerShell7:

```powershell
pwsh -NoProfile -File docs/evidence/tiktok-registry-closure-20261011/prepare.ps1
pwsh -NoProfile -File docs/evidence/tiktok-registry-closure-20261011/wire.ps1
pwsh -NoProfile -File labs/tiktok/wholephoto-registry-closure/run.ps1 -Attempt 1 -Case normal
pwsh -NoProfile -File labs/tiktok/wholephoto-registry-closure/run.ps1 -Attempt 2 -Case closure-idempotent
pwsh -NoProfile -File docs/evidence/tiktok-registry-closure-20261011/run-narrow.ps1
pwsh -NoProfile -File docs/evidence/tiktok-registry-closure-20261011/run-targeted.ps1
pwsh -NoProfile -File docs/evidence/tiktok-registry-closure-20261011/run-suite.ps1 -Start 20
pwsh -NoProfile -File docs/evidence/tiktok-registry-closure-20261011/run-gate.ps1
pwsh -NoProfile -File docs/evidence/tiktok-registry-closure-20261011/inspect-final.ps1
pwsh -NoProfile -File docs/evidence/tiktok-registry-closure-20261011/record.ps1
pwsh -NoProfile -File docs/evidence/tiktok-registry-closure-20261011/run-verification.ps1
```

run-narrow gọi sequential run-validation Kind closure/validation Attempt1,
run-probes Kind contracts/policy Attempt1, save-code cho từng bản và run-policy1
cold source import/trust networknone96MiB/source0. Bundled executable:
`C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe`.
Native command/exit/start-end UTC/VN/guard/state/hashes giữ ở mỗi run; expected
childFAIL20/proxy containment30 vẫn là nativeFAIL, harness0 chỉ nói test đạt.
Exact gate và verifier capture/readonly là revalidation, không source/full suite
mới. Các matrices bên trên thực chạy trong implementation lần này.

## Bảo vệ, dependency và integrity

Cache image31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e;
Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/aio2.7.1 giữ.
Aio commit4dfc926e30eea8d24c1a71602d73c0e9a895c191,
wheelSHA9243213661e29250eb41368e5daa826fc017156c3b8a11440826b2e3ed376472,
PSF-2.0/J. Nick Koston+contributors; AGPL/Cobalt LICENSE/NOTICE/locks giữ.
Không build/pull/install, host/WSL/Docker/seccomp/privileged/capadd/hostIPC changes.

RAM8GB tuần tự; proxy96+worker512=608MiB, CPU.25+.75, validator96 khi roles stop,
probe512networknone; UID65534/1000, source/rootfsRO, swapRAM, capALL/NNP/privateIPC,
internal fixture/nohostports/pids64–96/helper1/SSRF/allDNSpublic/TLS giữ.
Setup10/end−1reserve/pair1–2/singleton.60/reap.10/delay.25/interleave0,
connect10/read20/meta30/prepare60;≤2metadataGET+conditional1JPEG GET/redirect0/
retry0/HEAD0;metadata8MiB–16MiB/imageinput20MiB/output16MiB/workflow36MiB,
8192dimension/16Mpixel/full decode/IPC/answers64/trace256-owner32-map64 giữ.

Exact own IDs242 containers/158 networks không còn; main image
e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b giữ.
Baseline22.743 hiện vật cũ toàn SHA, new manifest fullcoverage/source283/runtime88;
AUDIT/PROGRESS chỉ insert mới có before copies/base64/offset/hash successor.
Old code/raw/golden/manifests/verifiers/codecopies/humanreview/claims giữ, gồm
initial proof trước floor/TCP END, Docker API precreateFAIL59/continuation100–116
và audit inspector103 FAIL/cause. Không rerun nhiệm vụ lịch sử hoặc sửa expected
của78/55/55/whole56 để ép PASS.

Source runner unconditionalOFF kể cả gateđạt. Source claim consumed SHA
cfb1d25d0f9eac42063d44686751a18d6069bcdd6ccfcd6dfdedf10e632748a7 giữ.
Source trước metadata5ảnh/prepareFAIL20/body0;43IP khác/networkcauseUNKNOWN;
ảnh nguồn/decode/SHA/visual chưa đạt. Video2/3, sample3NEEDS_VISUAL_REVIEW giữ.
Không TikTok/InternetDNS nguồn/HEAD/retry/reset claim/ảnh2/album/browser/solver/
fallback/main/gallery/API E2E/deploy/DB/settings/UI/schema.

## Bước tiếp

[Prompt kiểm độc lập](evidence/tiktok-registry-closure-20261011/NEXT_PROMPT.md).
Closure fix chưa mở quyền gọi nguồn/main/deploy; audit độc lập và source trial là
nhiệm vụ riêng. UTC kết luận 2026-10-11T10:28:23.8035034Z; VN 2026-10-11T17:28:23.8076167+07:00.
