# Wholephoto batch C — bàn giao offline 11/10/2026

Successor `labs/tiktok/wholephoto-batch/`, evidence
`docs/evidence/tiktok-wholephoto-batch-20261011/`. Old labs/apps/vendor/locks,
cache/raw/golden/manifests/verifiers/codecopies/human review giữ nguyên. Source
runner unconditional OFF; source claim đã tiêu thụ và SHA giữ. Nhiệm vụ này
triển khai/kiểm offline, không tải TikTok thật, main/gallery/API E2E hoặc deploy.

## Implementation và thư viện

`candidate.connect` vẫn guard toàn DNS set trước factory (cả suffix sau8), giữ
DNS order/duplicates/publicIP/family. `batch_policy.connect_groups` gọi public
aiohappyeyeballs2.7.1 start_connection với slice<=2, delay.25/interleave0/public
socket_factory/loop. Không có max_concurrent, không gọi/chép private _staggered/
_connect_sock, race/resolver/TCP/HTTP/TLS mới hoặc dependency/build mới.

K=min(groups remaining,trace capacity,floor(actualR/min)); pair min1/max2s,
natural singleton min.60, cancel/reap reserve.10. H=min(T,now+Q), A=H−.10;
registry deadline T=setupEnd−1 không reset theo group. Factory closure kiểm
localA/epoch rồi delegate OS socket qua API thư viện. Group sau chỉ mở khi
public library call/worker tasks done và physical losers0. Fail nhanh trả thời
gian thừa ngay; winner dừng scheduling; caller cancel reraise, không advance.
Timeout local chỉ advance nếu reaped trước H. Missing H giữ GROUP_REAP_DEADLINE,
abort cleanup dùng phần global còn lại, không chạy group tiếp hoặc tăng T.

.10 là điều kiện kiểm, không guarantee. Public create_task/wait/cancel và
current_task tracking dùng ownership của chính registry, không tính unrelated
tasks trong loop là loser. Nếu còn task sau global cleanup, proxy containment
fail. Một watchdog threading.Timer độc lập cho **setupEnd hiện có** chỉ kill
own proxy exit30 khi loop không hợp tác; không gọi host/privileged API. Timer
được cancel/join khi TCP call kết thúc. Probe child loop cố ý block đã exit30
qua independent timer, PROCESS_CONTAINMENT, parent FD/thread baseline giữ;
không coi process containment là graceful operation coverage PASS.

Exception từ public library call giữ object identity khi truyền ra; thư viện
có thể aggregate các exception khác nhau. Glue không log message/repr/stack/
URL/header/cookie/token/HTML. Constructor callback trong registry mặc định là
stdlib socket.socket; fault callback chỉ nằm trong fixture. Cookie nguồn vẫn RAM,
chưa có source mới. CONNECT200 không là TLS/client receipt hoặc tệp PASS.

Pin PSF-2.0/J. Nick Koston+contributors, commit
`4dfc926e30eea8d24c1a71602d73c0e9a895c191`, wheel SHA
`9243213661e29250eb41368e5daa826fc017156c3b8a11440826b2e3ed376472` giữ.
API official/vendor được đọc trước code:

- [aiohappyeyeballs2.7.1](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/impl.py)
- [library staggered cleanup2.7.1](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/_staggered.py)
- [CPython3.11.2 public task APIs](https://github.com/python/cpython/blob/v3.11.2/Lib/asyncio/tasks.py)

## Trace/admission/validation

`ownership.Trace` thêm reservation dưới RLock, không đổi total256/owner32/map64
hoặc Requests registry64. Reserve ctx lifecycle phần còn lại của12 rows, TCP2
mỗi attempt; registry socket2/candidate+library2/group và4 future close rows
(final+emergency). Current counts+outstanding reservations phải cùng fit cap
trước group spawn; global concurrent reservations không overbook. Ceiling vẫn
4groups/8addresses, không rotate/reset owner IDs. Admission counters chỉ quyết
định slot; toàn event pairs thực vẫn được giữ. Unused group slots chỉ release
khi public tasks reaped; future lifecycle/close slots giữ tới physical shutdown.

`operation_coverage.py` kiểm toàn paired phases bằng owner/phase/operationIndex
theo thứ tự ghi, không elapsed sort. TCP operationIndex lấy immutable TCP attempt
index, cho phép hai BEGIN song song; các operation tuần tự có chỉ số riêng.
Constructor failure phải có SOCKET_CREATE ERROR; source/library/registry phases
không missing terminal. Single-END lifecycle snapshots whitelist riêng.
Trace cap/IO fault không ngăn physical close; incomplete luôn khiến diagnostic/
file gate20, không biến TCP winner/closed0 thành PASS. Finalizer UID65534 thêm
operationGate và batchGate vào existing native/file/trace/accounting/ownership.

Profile lấy các facts đã biết: group Q/active/elapsed, sockets created/closed/live,
pending, stop code, epoch, suffixUnknown. DNS fail trước group hoặc early init
có thể profile NOT_STARTED/UNKNOWN; không dùng chúng suy origin/TLS/network cause.
TRACE_ADMISSION_LIMIT trước spawn có trace prefix COMPLETE nhưng connector/file
FAIL20. Candidate9+ chưa thử UNKNOWN, không bị gọi unreachable. Requests/egress
CONNECT parser/tunnel/TLS và body/deadline guards không viết lại.

## Ma trận kỳ vọng và lệnh thực

Bảng `expectations.json` được chốt trước code. **78 unchanged contracts** gồm
71 accounting (ID/order/known-vs-UNKNOWN) +7 TCP index/coverage/exception/cleanup.
Không gọi82 expectations cũ unchanged. Bốn derived cases:

| Tên giữ | Predecessor | Successor đã kiểm |
|---|---|---|
|first_pair_stall_third_control|.5s, only1/2 timeout, third chỉ thử riêng|4.2s, group1cancel/reap/live0 trước group2, winner3 thực|
|many_immediate_fail|.5s/all7/winner7|4.2s/all7/winner7/full operation/native0|
|first_winner|.5s/winner1|4.2s/winner1, không group2|
|many45_trace_cap|.5s/all45/TCPPASS/tracecap20|8.5s/prefix1..8/suffix37UNKNOWN/TRACE_ADMISSION_LIMIT, operation gate0 nhưng connector20|

**55 new policy gates**: floor pair.5/.9, singleton.59/.60/.61/.90, fast64 prefix,
dual winners, caller cancel, slow cancellation/reap FAIL, late epoch factory,
bad suffix answer, constructor identity, owner/global/map admission boundaries
and concurrency,30 full-operation fault controls,4 I/O faults, DNS remaining
deadline và blocked-loop process containment. Mỗi coverage fault có actual
native operation child0/20; connector gate phân biệt coverage0 với download0.
FD4→4/thread1→1/pending/socket0 ở bản final, peak<=2.

Singleton nominal.60s thực còn≈.5999s khi admission nên reject/no factory đúng
sàn; .61 test ghi explicit clock slack.01 và actualremaining≥.60 đã thắng;
.90 thắng, .59 reject. Không lấy nominal.60 làm runtime exactly.60 PASS; không
nới threshold. DNS helper trễ có thể hết absolute deadline trước TCP: phase
code SETUP_DEADLINE khác TCP_BUDGET_EXHAUSTED khi DNS đã về nhưng R thiếu sàn.
Đây là runtime/observed code, không arithmetic model cũ gán thành socket PASS.

Targeted whole9 rồi **whole40 inherited +8new** trên cùng final code:
normal/latency/batch-stall-third/batch-fast7 positive native0/JPEG fixture decode/
SHA; fast45/64 prefix<=8 →worker20/validator20/noJPEG; admission/epoch/phase
postfile faults dù parent/worker0/JPEG provisional PASS vẫn validator20, dọn
only-owned image.jpg/part, keep.bin sentinel giữ SHA. Source không chạy.

Lệnh thực bundled pwsh: run-probes.ps1 -Kind policy -Attempt1..5;
-Kind contracts -Attempt1; save-code.ps1 theo Kind/Attempt; run-policy.ps1;
run-targeted.ps1; run-suite.ps1 -Start20; canonical/runtime/exact gate;
inspect-final.ps1; record/verify successor. Runtime inventory84/source222 bao
gồm27 successor files, current library/stock/photo/trace/core pins. Hash gate
đối chiếu toàn bộ file, không chỉ filename đã biết. UTC/VN/native/guards/ownership
và manifest/receipt coverage nằm trong namespace mới.

Các FAIL được giữ: policy1 thiếu PYTHONPATH vendorRO, sửa wiring không install;
policy2 bookkeeping operation key không tách TCP song song nên dual winner
trace incomplete, sửa immutable index; policy3 harness gán DNS timeout thành
TCP budget code, sửa theo phase quan sát được, không tăng DNS/setup timeout.
Policy4 PASS trước chốt gate/runner wiring giữ riêng; policy5 và contracts1
trên hash final. Code snapshots tất cả attempt lưu. Không đổi78 expected hoặc
fixture an toàn để che regression, không sửa old code/raw/golden/verifier.

## Guards, giới hạn và bàn giao kiểm độc lập

Image31742091…dfa417e/Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/
aio2.7.1/FFmpeg/Cobalt/NOTICE/LICENSE giữ. RAM8GB chạy tuần tự, proxy96+worker512
=608MiB/CPU.25+.75/pids64/96; validator96 sau roles stop, probe512-network-none.
Nonroot1000/65534/rootfsRO/sourceRO/swapRAM/capALL/NNP/privateIPC/internalfixture/
nohostports; original TLS/SSRF/DNS allset/body8–16+20–16MiB/workflow36/answer64/
IPC16–32KiB/semaphore1/metadata30/prepare60/connect10/read20/setup10/reserve1/
delay.25/interleave0/JPEG8192/16Mpixel/redirect-retry-HEAD0 giữ. No install/build,
main/app/DB/settings/lifecycle/UI/API/schema/host changes.

Source claim SHA cfB1…48a7 giữ, sourceFAIL20/metadata5 lịch sử giữ. 43 IP khác/
network root cause UNKNOWN; JPEG fixture và scheduling PASS không là sửa được
nguồn hoặc tải no-watermark. Ảnh nguồn chưa đạt, video2/3/mẫu3NEEDS_VISUAL_REVIEW,
main/gallery/API E2E chưa đạt. Kiểm độc lập ở NEXT_PROMPT.md chỉ offline/read-only;
không tự mở nguồn kể cả toàn gate offline đạt.

Kết quả chốt: targeted9 và whole48 đã hoàn tất; exact178 container/114 network do phiên tạo đều không còn. Main image e7f93577…d0184b giữ. Final source snapshot SHA=af9dc529e30a49e6ae31805865ea9d870e6711ddf74310969ab1ef03d3143098; source222/runtime84 cùng hash cho contracts1/policy5/whole48. Manifest/verifier mới ghi native integrity riêng, không rerun functional hoặc mở nguồn.
