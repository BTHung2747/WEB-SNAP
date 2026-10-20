# Review chia ngân sách kết nối và trace — 11/10/2026

**Quyết định thiết kế:** chọn phương án C — phân bổ thích ứng theo thời gian thực
còn lại và số nhóm còn được trace cho phép, có sàn cho candidate thứ hai. Chỉ
chuẩn bị successor offline; **chưa sửa code, timeout, scheduling, caps hoặc chạy
nguồn**. Cấu hình đề xuất phải được kiểm trong nhiệm vụ triển khai kế tiếp trước
khi có thể nghiệm thu. Hai finding receipt ID/order đã được kiểm độc lập và vẫn
đóng offline; không chạy lại các nhiệm vụ đó trong review này.

## 1. Bằng chứng được đọc và điều chưa biết

Đọc `labs/tiktok/wholephoto-order/{candidate,proxy_entry,offline_glue,ownership,
tcp_observer}.py`, DNS helper/IPC, finalizer, vendor/lock và bàn giao observer order.
Đối chiếu audit hiện hành `docs/evidence/tiktok-observer-order-audit-20261011/`.
Source set195 file và vendor10 file khớp các hash đã ghim. Những số dưới là đọc
evidence cũ, không phải chạy lại suite hoặc source:

| Evidence | Quan sát đã có | Giới hạn kết luận |
|---|---|---|
| `tiktok-observer-order-20261011/probe-4/probe-result.json` — first pair stall | Trong budget fixture0,5s chỉ TCP1/2 bắt đầu, timeout≈0,5014s; thử riêng candidate3 kết nối được; socket peak2, cleanup0 | Phân biệt starvation trong fixture, chưa đo khả năng kết nối IP nguồn khác |
| Cùng probe — fail nhanh7 | Cả7 bắt đầu trong≈0,00249s; TCP gate0, socket peak1 | Probe numeric TCP, không wholephoto/file/source gate |
| Cùng probe — fail nhanh45 | Cả45 bắt đầu trong≈0,01035s, TCP outcome PASS; chỉ32 TCP rows được collector giữ, incomplete/diagnostic20 | Không được coi PASS của socket là nghiệm thu tệp; collector probe không gồm toàn chi phí wholephoto |
| Source trial `tiktok-wholephoto-source-20261010/source-1/` | Metadata5 ảnh, prepared2/1, send2/0; prepare setup OS_ERROR≈9,160s/Adapter PROXY_ERROR≈9,174s, status/body UNKNOWN/0. DNS45IPv4, TCP BEGIN2 trước deadline; chưa CONNECT200 cho prepare | 43 IP còn lại reachable hay không và network root cause **UNKNOWN**. Index terminal raw lịch sử có lỗi đã sửa ở successor; chỉ dùng totals/BEGIN lịch sử, không khẳng định liên kết socket từ raw cũ |
| Trace whole control normal/latency/source cũ | Normal70rows/13owners/max14; latency74/13/max16; source54/8/max16 | Đếm phase đọc nguyên trace đã sanitize; không đo mới, không suy TLS fine detail hoặc source thành công |

Source claim đã tiêu thụ vẫn SHA
`cfb1d25d0f9eac42063d44686751a18d6069bcdd6ccfcd6dfdedf10e632748a7`.
Source ảnh/decode/SHA/visual chưa đạt; video2/3 và mẫu3 NEEDS_VISUAL_REVIEW giữ.

## 2. Thư viện và điểm mở rộng đã xác minh

Tái dùng **aiohappyeyeballs2.7.1**, PSF-2.0, J. Nick Koston và contributors;
commit `4dfc926e30eea8d24c1a71602d73c0e9a895c191`, wheel SHA
`9243213661e29250eb41368e5daa826fc017156c3b8a11440826b2e3ed376472`.
Vendor là wheel chính thức không sửa, không có runtime dependency mới;
Python>=3.10 tương thích cache Python3.11.2. Có repository/changelog/tag chính
thức; review dùng đúng pin, không suy tình trạng release mới nhất hoặc nâng bản.

`start_connection(addr_infos, *, local_addr_infos=None, happy_eyeballs_delay=None,
interleave=None, loop=None, socket_factory=None)` trả socket. **Không có tham số
max_concurrent hoặc group deadline**. `happy_eyeballs_delay=.25`, `interleave=0`
phải truyền rõ: nếu interleave=None khi dùng delay, thư viện mặc định interleave1.
Candidate tiếp theo được bắt đầu khi candidate trước fail hoặc hết delay;
fail nhanh có thể bắt đầu candidate2 trước0,25s. Gọi mỗi lần với<=2 addresses
giữ peak<=2; đưa cả45/64 vào một call không đáp ứng giới hạn này.

Mã thư viện cho thấy winner khiến các task khác bị cancel và await; finally
đóng các runner-up sockets. `_connect_sock` đóng socket khi failure/cancel.
Đó là hành vi cần tiếp tục kiểm bằng API public, không gọi/chép `_staggered`
hay `_connect_sock`. Khi chỉ một exception hoặc tất cả message giống nhau,
thư viện có thể ném cùng exception object; lỗi khác nhau có thể được thư viện
tổng hợp thành exception mới. Glue bảo toàn **object mà public call ném ra**,
không hứa luôn là object lỗi thấp nhất; không in message/repr/stack.

Nguồn chính thức đã đọc cùng vendor/hash:

- [aiohappyeyeballs2.7.1 implementation](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/impl.py)
- [staggered scheduling2.7.1](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/_staggered.py)
- [CPython3.11.2 asyncio timeouts](https://github.com/python/cpython/blob/v3.11.2/Lib/asyncio/timeouts.py)

`asyncio.timeout_at` dùng clock của loop, cancel task và chuyển cancellation do
chính timeout thành TimeoutError. Việc chờ cancellation/cleanup có thể vượt
thời điểm timer nếu delegate không hợp tác; timeout này không phải watchdog độc
lập event loop. Kế hoạch phải giữ parent/child containment và fail khi không
reap được, không detach task để mở group mới. Thư viện xử lý TCP; Requests/TLS/
HTTP/stdlib DNS hiện có giữ nguyên. Chỉ cần glue deadline/admission/ownership
và validation trace của WED SNAP, không viết race/resolver/parser/transport mới.

RAM8GB: không cài/pull/build; reuse image
`sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e`.
Proxy96MiB +worker512MiB=608MiB; một tác vụ tuần tự,<=2 active TCP sockets,
<=2 candidate tasks trong group, group sau chỉ mở khi group trước reap/close0.
Danh sách closed sockets và numeric ledger bounded theo answer64, không tạo
process/thread mới cho mỗi địa chỉ. LICENSE/NOTICE/locks/cache giữ.

## 3. So sánh phương án và số địa chỉ có cơ hội bắt đầu

Gọi E=min(start+10, phase deadline), T=E−1, R=max(0,T−now sau DNS/IPC/guard).
DNS và chờ semaphore đã tiêu thời gian trong E; không reset budget sau resolve.
G_raw=ceil(N/2), N<=64, nguyên DNS order (kể cả duplicate), all-public-answer
guard cả set trước socket đầu. Delay0,25 và interleave0 giữ.

Các tính toán là mô hình số học lý tưởng với event loop hợp tác, không đảm bảo
timer/CPU/kernel hay kết nối mạng. Không hứa mọi địa chỉ được bắt đầu.

| Phương án | Phân chia trong R=8,63s, N45/G23 | Khi mọi group stall | Fail nhanh và trace | Đánh giá |
|---|---|---|---|---|
| A — deadline toàn bộ như hiện tại | Group đầu dùng toàn R; candidate2 có thể bắt đầu sau.25 | Thường chỉ1 group/2 địa chỉ, candidate3 không được thử | Thời gian có thể cho phép7/45/64; trace32 có thể mất evidence trước khi hết địa chỉ | Ít thay đổi, nhưng không giải quyết starvation đã thấy trong fixture |
| B — group cố định, sàn cho candidate2 | Q=1,00s gồm.90 active+.10 cancel/reap; candidate2 còn≈.65s trong trường hợp candidate1 stall | Time-only8 full groups/16 địa chỉ; khi giữ trace admission bảo thủ chỉ4 groups/8 địa chỉ | Fail nhanh trả budget thừa ngay; có thể cắt winner chậm hơn.65s dù global còn nhiều | Dễ kiểm nhưng luôn cắt ngắn group, kể cả chỉ còn1 group |
| C — thích ứng theo **nhóm còn trace-admissible**, có sàn/cap | K=min(G_raw_remaining, trace capacity groups, floor(R/1)); Q=min(R,2,max(1,R/K)); với K4 Q2,00 | Chỉ tối đa4 groups/8 địa chỉ trong trace model chọn; candidate2 có≈1,65s active sau delay | Fail nhanh không đợi Q; tính lại R/K từ clock và capacity thực. Không dự đoán/ưu tiên IP hay family | **Chọn**: giữ cơ hội nhóm sau và cho group chậm nhiều thời gian hơn B, vẫn kiểm được bound |

Chia đều theo toàn23 groups:8,63/23≈0,375217s; candidate2 chỉ còn≈0,125217s
sau delay, và≈0,025217s nếu còn chừa.10 cancel/reap. Không chọn công thức này:
cắt quá ngắn và bỏ qua việc trace không đủ ghi cả23 groups.

| DNS time D trong mô hình | R=9−D | A, fully stalled | B time-only; sau trace bound | C trace/time-admitted; Q ban đầu; thời gian candidate2 sau delay/reap |
|---|---|---|---|---|
|.37s |8.63s |2 địa chỉ |8groups/16;4groups/8 |4groups/8;2.00s;1.65s |
|6.353045s |2.646955s |2 địa chỉ |2groups/4;2groups/4 |2groups/4;1.323478s;.973478s |
|8.10s |.90s |Có thể bắt đầu2 nếu loop kịp |0 pair vì thiếu sàn1.00 |0 pair, FAIL_BUDGET trước spawn |

D6.353045 là injection delay danh nghĩa trong fixture cũ, không phải tổng DNS
đã đo mới; IPC/reap/CPU thực còn tiêu thời gian. Code tương lai dùng R thực chứ
không lấy các D này làm hằng số. Đối với N2/7/45/64, G_raw=1/4/23/32:
với D.37, C có ceiling số bắt đầu2/7/8/8; với D6.353045 là2/4/4/4;
với D8.10 là0 cho pair đầu. Đó là ceiling điều kiện, không phải minimum bảo đảm.

## 4. Chốt policy C để triển khai offline

Các giá trị **đề xuất**, chưa áp dụng: GROUP_MIN_TOTAL1.00s,
GROUP_MAX_TOTAL2.00s, GROUP_CANCEL_REAP_RESERVE.10s; natural final singleton có
MIN_TOTAL.60s (.50 active+.10 reap). Đây là subdeadline trong TCP budget hiện có,
không tăng setup10/connect10/read20/meta30/prepare60. Sàn là heuristic để giữ
ít nhất.65s nominal cho candidate2 sau delay; chưa có bằng chứng đây là tối ưu
cho TikTok/network này. Không giải quyết DNS chiếm hết budget.

Trước mỗi group, tính trace admission cho toàn group tối đa2 candidates và
future cleanup; tính K như bảng. Với odd last singleton, K dùng sàn tương ứng;
không bỏ candidate thứ hai hay nhảy tới suffix để biến pair thiếu budget thành
singleton. Nếu R<sàn, FAIL_BUDGET trước factory. Nếu K0 vì trace, trả mã fixed
TRACE_ADMISSION_LIMIT và số suffix **chưa bắt đầu**, không gọi chúng là failed IP.
Nếu K0 vì thời gian, mã TCP_BUDGET_EXHAUSTED. Không bắt đầu group tiếp sau winner.

Group total deadline H=min(T,now+Q); active deadline A=H−.10. Gọi public
start_connection với đúng slice<=2, delay.25/interleave0, public loop/factory.
Factory wrapper chỉ kiểm A/epoch và ủy quyền registry.factory. Registry.deadline
giữ **T cho toàn CONNECT**, không cập nhật bằng group A rồi vô tình chặn group
sau (setter hiện tại chỉ min). Không gọi connect lặp cùng registry với deadline
ngày càng tăng; thay glue trong một call connect, một DNS resolve, một GET budget.

Mỗi group là một scoped task của **một public library call**, không race mới.
Timeout group: cancel rồi await/reap; xác nhận mọi candidate task đã done,
mọi loser socket fileno−1 và live0 trước group mới. Fast OSError: giữ object từ
library, nếu live0 thì tiến group ngay/tính lại R, không chờ đủ Q. Caller cancel
reraise cùng CancelledError; chỉ TimeoutError của local subdeadline mới có thể
đi group sau. Policy/trace error, global deadline, residual socket/task hoặc
reap quá H: epoch invalid, close owned registry/containment, **dừng**, không
detach task/đổi expected để tiếp. Late factory phải bị chặn sau cancel/deadline.

.10s không phải guarantee cleanup; nếu thư viện/delegate không reap được trong
số thời gian đó thì test phải FAIL. Trước loop.close cần pending group task0,
không dùng loop.close để che task đang chạy. Giữ exception primary; lỗi trace/
cleanup secondary không thay library exception. Không in exception message.

E−T=1s giữ cho CONNECT/handoff/cleanup theo contract hiện có. CONNECT200 không
chứng minh client nhận, TLS hoàn tất hoặc certificate hợp lệ. Proxy TLS opaque;
Requests verify/timeout/clamp theo phase vẫn giữ, TLS fine detail UNKNOWN.
Không hứa handshake xong trong1s hoặc dùng TCP winner làm file PASS.

## 5. Trace budget: chi phí và admission

Trong code hiện tại, registry.cid khác ctx.cid; DNS helper có owner riêng. Chỉ
liên kết chúng bằng ownership thật trong RAM/receipt; không rotate/reset owner
theo group hoặc ép worker↔proxy sharedCID/header mới. N dưới đây là số candidate
socket attempts, G là library calls; factory failure có thể tạo pair socket
mà không có TCP pair, phải đo riêng, không bịa TCP BEGIN.

| Family/event | Chi phí cần giữ | Owner/bound |
|---|---|---|
| DNS_HELPER BEGIN→END/ERROR |2 | Helper owner; DNS_RESULT END là snapshot1 ở ctx |
| TCP_CONNECT/FIXTURE_TCP BEGIN→END/ERROR |2 mỗi actual TCP, cancel cũng có terminal | ctx, immutable attempt index; không dùng counter tổng thay event pairs |
| SOCKET_CREATE BEGIN→END/ERROR |2 mỗi factory attempt | cùng registry owner; constructor lỗi cũng phải có terminal/incomplete |
| LIBRARY_SELECT BEGIN→END/ERROR |2 mỗi group | registry; thêm groupIndex/effective deadlines/closed/live vào event hiện có, không gộp/bỏ events |
| REGISTRY_CLOSE BEGIN→END/ERROR |2 mỗi close | Reserve4 rows cho final close và một emergency close như existing error path; không close có trace mỗi failed group khi library đã đóng/reap0 |
| ctx lifecycle, successful handoff |12 không-TCP =ACCEPT1+FINISH2+DNS_RESULT1+CONNECT2002+TUNNEL_CLOSE1+SHUTDOWN2+CLOSE2+RETURN1 | Reserve phần còn lại trước group đầu; failure có thể bớt CONNECT200 nhưng không dùng để hứa thêm slot |
| server close/closure barrier |Source4 global rows; fixture10 (4 listener close pairs+barrier pair) | Owner riêng thật, không đổi caps |
| Fixture origin ownership |8 mỗi accepted origin handler, normal2 handlers=16 | Không bỏ trace fixture để làm gate vừa cap |

Bound bảo thủ của policy đã chọn:

`ctxRows=12+2N`; `registryRows=2N+2G+4`; `dnsRows=2`.
N8/G4 ⇒28/28/2 rows per connection. Hai CONNECT source có thể tối đa
`2*(28+28+2)+4=120`; whole fixture hai CONNECT/two origin handlers và4 listener
close ⇒`2*58+16+10=142`, trong total256. Owner32 giữ, registry/owner64 giữ;
normal fixture13/source8 owners đã đọc. Additional connections/global concurrent
handlers vẫn phải reserve dưới lock, không coi142 là mọi workflow.

| Giả sử cố thử tất cả N | G | ctxRows | registryRows | Hai-CONNECT fixture upper bound | Đủ owner32/total256? |
|---|---:|---:|---:|---:|---|
|7 |4 |26 |26 |134 |Đủ theo model |
|8 |4 |28 |28 |142 |Đủ, **ceiling chọn** |
|10 |5 |32 |34 |162 |Không đủ registry32 với reserve emergency close |
|45 |23 |102 |140 |514 |Không đủ owner32/total256 |
|64 |32 |140 |196 |702 |Không đủ owner32/total256 |

Nếu chỉ dự phòng một final close, N10/G5 có registry32, nhưng không chừa emergency
close và bất kỳ event thêm nào. Không chọn bound sát cap này. Nếu thiết kế đổi
sang traced registry.close mỗi group, chi phí thành2N+4G+2 (và có thể thêm emergency):
G4/N8 đã34 trước emergency, nên phải hạ quota≤3 groups/6 addresses hoặc review
mới. Không được giữ quota8 trong khi thêm event mà không tính lại.

Admission phải atomic dưới trace lock: reserve full worst-case group plus các
terminal/future cleanup, kiểm ctx32/registry32/total256/owner-map64/Requests64.
Reserve không phải trace row giả; row chỉ được emit khi thao tác xảy ra. Completed
slots có thể release phần chưa dùng sau physical close/reap; không giả phóng
reservation của BEGIN chưa có terminal. Dùng counters cho admission thôi;
full per-attempt evidence vẫn bắt buộc để nghiệm thu. Receipt suffixSkipped
không thay full trace của attempts đã bắt đầu.

Trường hợp45/64fail nhanh: bounded successor chỉ thử prefix≤8, nếu winner ở
45/64 thì không được mở tới đó trong caps này; stop TRACE_ADMISSION_LIMIT,
connector/worker/file FAIL20. Trace của prefix có thể COMPLETE và numeric TCP
gate0 nếu đầy đủ; **không gọi đó là source/file PASS**. Trace cap/IOfault thực
sự xảy ra → incomplete/diagnostic20 dù physical sockets0 hoặc TCP winner.
Không gộp/reset/discard trace để đạt. Muốn coverage45/64 cần nhiệm vụ review
caps/evidence khác, không tự tăng trong successor này.

Coverage mới phải kiểm mọi BEGIN trong paired phases đúng một terminal theo
operation index/order, kể cả socket factory và library-select/registry-close;
single-END lifecycle snapshots được whitelist riêng. TCP numeric gate hiện
chỉ xét TCP pairs; finalizer hiện đếm schema/rows/caps, không đủ để suy general
operation coverage. Đây là yêu cầu thiết kế mới phải kiểm offline, không kết luận
source cũ đã sai vì phase chưa đo. Extend lab validator/ledger glue; không sửa
worker receipt ID/order đã đạt hoặc giảm completeness để mở file gate.

## 6. Phạm vi implementation successor tối thiểu

Tạo `labs/tiktok/wholephoto-batch/` và namespace evidence mới khi được giao triển
khai. Copy predecessor theo provenance; không sửa wholephoto-order/old evidence.
Thay candidate.connect orchestration để tính Q/admission/scoped group lifecycle;
thêm guard factory localA/epoch, dùng socket_factory/loop APIs public. Giữ SourceLoop
immutable TCP index toàn CONNECT, thêm numeric group/DNS-position mapping khi
thật sự biết; không đồng nhất factory attempt với TCP attempt nếu constructor fail.
Không resolver/TCP/HTTP/TLS riêng, không gọi private library helper.

Trong ownership.Trace thêm reservation ledger bounded/thread-safe và operation
coverage evidence; không đổi cap256/32/64 hoặc làm emit exception cản close.
Proxy/offline delegation/receipt wiring thêm mã stop và bounded fields, giữ original
CONNECT parser/tunnel/SSRF/DNS helper/TLS/user/rootfs/resource guards. Nếu phải
thêm LIBRARY_SELECT events/cleanup path, tính lại và hạ quota trước khi code.
Finalizer successor require operation coverage+existing trace/file/accounting/native;
unknown thiếu receipt phải reject. Source runner vẫn unconditional OFF/claim cũ giữ.

Thực hiện theo5 bước:

1. Chốt baseline/pins/API/model hiện hành và sourceOFF; code predecessor immutable.
2. Unit/offline glue group budget + reservation, lifecycle/exception identity;
   fixture loops chỉ route numeric public addresses tới loopback, không DNS nguồn.
3. Faults: cancellation/late factory/cap/IOfault/constructor failure; full phase
   coverage và physical FD/thread/socket/helper cleanup độc lập, không mask primary.
4. Nối fresh wholephoto metadata→JPEG pipeline, control và budget/coverage negatives;
   packet/file provisional PASS không đủ nếu diagnostics/native FAIL; only-owned cleanup.
5. Targeted rồi inherited82/whole40 và negative mới trên cùng hash/source/runtime
   inventory; preserve FAIL snapshots/actual exits/UTC-VN/exact IDs/cache main/claim;
   update AUDIT/PROGRESS/handoff. Không chạy nguồn sau gate offline.

## 7. Tiêu chí kiểm offline cần thực hiện ở nhiệm vụ sau

| Gate | Tiêu chí đạt/dừng |
|---|---|
| Firstpair stall, candidate3 available | N3; group1 cancel/reap/socket0 trước group2; candidate3 bắt đầu và thắng trong R đủ; original control starvation giữ chỉ đọc. Candidate2 chậm≈.421 vẫn có cơ hội với delay.25/sàn |
| Fast failure7 | Original order/index1..7, no delay khi preceding fail nhanh, winner7/file pipeline control có thể đạt; old exception object của public call giữ |
| Fast failure45/64 | Prefix≤8/≤4groups, suffix chưa thử được ghi; winner1/3 được kiểm, winner45/64 không thử/file FAIL20, trace prefix full; không pretend all reachable/unreachable |
| Scheduling boundaries | DNS0/.37/6.353045/7.90/8.10/≥9; actual R gồm IPC; R<sàn không spawn, odd singleton .60 boundary; E/T không reset, expired/missing deadline reject; measure scheduling slack thay vì giả đạt exact floating point |
| Cancellation | Winner/loser race, simultaneous winners, caller cancel, group timeout, global timeout, stubborn delegate; await tasks0/closed0 before advance; late factory rejected; blocked loop/fault phải containment FAIL, không bypass |
| Library errors | Single/multiple/same/different library errors, socket constructor error, cleanup secondary error; identity of public result/error retained; no message/repr/URL/cookie/IP/token/HTML |
| DNS/SSRF/TLS | Invalid last answer kể cả beyond prefix8 chặn cảset trước sockets; hostname allowlist/answer64/IPC caps/semaphore1; slow/crash/oversize helper reaped. TLS reserve remains1, cert bad/handshake stall FAIL via existing verifier/deadlines; CONNECT200≠TLS/source PASS |
| Trace admission | Just-below/at/above owner32/total256/map64; future terminal/cleanup reservations; two concurrent handlers cannot overbook; stable ownerIDs, trace fields numeric only. New event cost hoặc extra cleanup vượtmodel phải hạ quota/FAIL |
| Trace faults | Cap/open/write/flush/close faults at BEGIN/terminal/cleanup; missing/duplicate/reordered operation terminals reject; every paired phase covered, single-END snapshots explicit; diagnostic20 even when physical0; closing independent of emit errors |
| Whole photo | Normal and latency fixture controls retain full JPEG/ID/decode/SHA/native0; fresh budget/coverage fault negatives reject20 after provisionalfilePASS/dọnowned/part, preexistingSHA giữ; source claim/hash preserved |
| Resource/inventory | 608MiB/CPU.25+.75/proxy96/worker512/validator96 afterrolesstop; cache/pins/UID/private0600/public0644/RO/swapRAM/capALL/NNP/privateIPC/sourceRO/internal nets/nohostport. Exact owned IDs cleanup; observer receipts still pass independent controls |

Không dùng test arithmetic hoặc đọc historical log để gán runtime PASS. Không
rerun đến PASS; mỗi FAIL giữ code/input/raw/actual exit rồi sửa đúng cause.

## 8. Đầu ra review và giới hạn xác nhận

Evidence mới `docs/evidence/tiktok-connect-batch-design-20261011/`: input pins,
historical summaries, trace-cost totals, mô hình số học `budget-model-v2.json`,
successor hai docs và manifest/verifier review. Model v1 được giữ vì PowerShell
chọn overload integer cho Math.Max/Min và làm tròn R; v2 dùng double explicit,
không dùng v1 làm căn cứ. Các kết quả này là **design/arithmetic review**, không
new socket tests, inherited suite rerun, image build, source/file/watermark PASS.
Source/DNS nguồn/HEAD/retry/resetclaim/main/gallery/API E2E/deploy0; không chỉnh
DB/settings/host. Prompt implementation kế tiếp trong namespace này chỉ offline.
