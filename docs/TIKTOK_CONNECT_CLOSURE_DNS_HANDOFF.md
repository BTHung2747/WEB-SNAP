# Nghiệm thu lab closure/DNS đa luồng — 10/10/2026

**PASS_CANDIDATE_OFFLINE: gate cuối offline-5 đạt38/38; suite/container/runner exit0.**
Chỉ nghiệm thu lab mới, chưa wiring own-egress/wholephoto, chưa nguồn hoặc deploy.
Gate cũ offline7 của connect-poc vẫn REJECT21/22/native1; cause TLS lịch sử UNKNOWN.
Barrier mới xử lý thiếu contract đã quan sát, không chứng minh đó là cause cũ.

## Mã và pin

`labs/tiktok/connect-closure-dns/` là successor riêng. `candidate.py`, test/runner/
supervisor kế thừa glue PoC; `owned_fixture.py` kế thừa fixture photo-trace. Oldlabs,
apps/, lock/deps ứng dụng và mọi evidence/verifier/golden/humanreview giữ nguyên.

- `ownership.py`: public socketserver dispatch/finish/shutdown/close, Event/Condition,
  thread join theo ownership; cap64request, trace256/run32/owner/fixed code/numeric/
  opaque ID. Flush từng dòng, giữ handle đến kết thúc case rồi đóng trước đoFD;
  không dùng sleep để đoán closure. Socket vẫn đóng khi trace lỗi.
- `dns_helper.py` và `dns_ipc.py`: process/IPC/ownership glue, stdlib socket.getaddrinfo;
  Popen/start_new_session/close_fds/stdin-stdout, stderrDEVNULL, selectors đọc trong
  cap, terminate/kill/wait đúngPID/group. Không fork-context/preexec_fn/resource_tracker,
  resolver/HTTP/TLS/race/private helper mới. IPCinput16KiB/output32KiB/64answers;
  host/IP chỉRAM, không vào command/log/evidence.
- Public aiohappyeyeballs start_connection vẫn delay0,25/interleave0/nhóm≤2/thứ tự
  gốc. Dùng nguyên vendor **2.7.1** tại connect-poc/vendor, mount riêngRO; lock giống
  predecessor, PSF-2.0 LICENSE/tác giả J. Nick Koston/contributors giữ.
  Commit **4dfc926e30eea8d24c1a71602d73c0e9a895c191**; wheelSHA
  **9243213661e29250eb41368e5daa826fc017156c3b8a11440826b2e3ed376472**.
  ImplSHA **eb32b7ba4aa27993fe187deb56cf16af8dfcb4fbfe63b4f5846802ca02a64bb2**.
  PROVENANCE ghi predecessor/hash và phạm vi sửa; LICENSE/NOTICE AGPL của fixture/
  core/Cobalt cũ được giữ, không nhập lại toàn ứng dụng hoặc parser/solver.
- Cache **sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e**;
  actualPython3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/aio2.7.1. Runtime
  newlab12/vendor10/core23 khớp host; source/deps93 trước/sau khớp. No build/pull/install.

[socketserver source3.11.2](https://github.com/python/cpython/blob/v3.11.2/Lib/socketserver.py)
liệt kê get_request/process_request/shutdown_request/close_request là extension points;
finish_request delegate tạo/finish Handler. Serve shutdown hoặc handle return riêng
lẻ không đủ đóng requestFD. [subprocess3.11.2](https://github.com/python/cpython/blob/v3.11.2/Lib/subprocess.py)/
[public docs](https://docs.python.org/3.11/library/subprocess.html) cho Popen/session/
close_fds/wait; [selectors](https://docs.python.org/3.11/library/selectors.html) dùng
với nonblockingpipe. [aio API2.7.1](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/impl.py)
không có max_concurrent nên cap nhóm thuộc glue.
[Requests Session.close2.34.2](https://github.com/psf/requests/blob/v2.34.2/src/requests/sessions.py),
[HTTPAdapter.close](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py),
[urllib3 poolmanager2.8.0](https://github.com/urllib3/urllib3/blob/2.8.0/src/urllib3/poolmanager.py)
được đối chiếu đúng tag. Python docs3.11 hiện patch mới hơn; exact tag/runtime ghi riêng.

## Contract closure và deadline

Accepted request nhận opaqueID, socket/thread sở hữu và state finish/shutdown/closed/
workerReturned; chỉ nhận closed khi fileno−1. Barrier chờ Condition rồi join từng
worker trong remaining absolute deadline, xác nhận socket/thread0 **trước** FD.
Kiểm expiry trước và sau wait/join kể cả predicate đã ready; không relax FDassertion.
Case đóng chậm giữ Event **sau Handle+finish, trước shutdown/close**; Timer0,15s chỉ
là latency injection có kiểm soát. Barrier phải thực sự chờ, không sleep để giảPASS.

Deadline chung10 lập trước spawn/import; DNS đã tiêu thụ+connect nằm end−1reserve,
không reset group/address. socket_factory pin cùng deadline và recheck ngay trước
socket sau ghi trace; expired factory không tạo socket. Clientconnect≤10/read≤20,
metadata30/prepare60 và corebody/input/output/pixel/full-decode/SHA/ownership giữ.
Fixture serve_forever poll0,05 thay0,5 để thu đóng listener; đây là poll cleanup của
lab, không tăng timeout hoặc đổi stock TCP/TLS/tunnel240/idle30/header16KiB/443.

DNS helper từ handler có4threads được kiểm. Child chỉ dùng numeric hoặc localhost
fixture, AI_NUMERICHOST cho public stand-ins, không DNS Internet. Output được guard
toàn danh sách trước upstreamsocket, không filter private/reorder family/resolve
hostname lại sauguard. Parent kiểm deadline trước spawn/read/parse/return/connect;
helper kiểm trước/sau getaddrinfo. Pipebytes không ghi raw; caps trong lúc đọc.
Helper registry chỉ PID/parent/startTicks để supervisor xử lý helper session riêng
nếu parent bị chặn. Helper epoch/group được kiểm trước signal, rồi kiểm group0.

Không hứa coroutine cancel hủy OS DNS/D-state hoặc hard realtime. Kill/wait/spawn/
signal jitter là giới hạn OS; pending late-reply fixture bị terminate trước nhận
payload (responseBytes0), không gọi đây là JSON muộn đã thực sự được phân tích.
Chưa có thử DNS hostname ngoài mạng, real-source TLS/substage/correlation vẫnUNKNOWN.

## Lệnh và kết quả mới

Bundled `pwsh -NoProfile -File labs/tiktok/connect-closure-dns/run.ps1`:

| Argument | Kết quả thực |
|---|---|
|Attempt1 CasesSmoke|Docker pipe sandbox denied trướccontainer; wrapper1/source0, giữ raw|
|Attempt2 CasesSmoke|6/6 native0, closure sớm/chậm/DNSthread success/error/inheritance/oversize|
|Attempt3 CasesAll|36/36 native0; toàn contracts22 cũ +2closure +12DNS mới|
|Attempt4 CasesAll|37/37 native0; review predicate-ready-expired, thêm explicit barrierclock guard/negative expiry; trace vẫn flush mỗi dòng|
|Attempt5 CasesAll|**38/38 native0**, thêm socket_factory deadline/negative socket-expired, đúng toàn source mới|

Các lượt sau có thay đổi code/contract cụ thể và kiểm đúng mã; không rerun mù đếnPASS.
Giữ attempts/snapshots/review trước sửa; không sửa verdict/history cũ. Tổng mới gồm
smoke6 và full36/37/38; không gọi các tests lịch sử đọc được thành test mới.

Final38 gồm original22 contracts, early/slow closure, DNSthread success/error/cancel/
deadline/crash/oversize/answercap/late-reply/localhost/inheritance/inputcap/parentblock,
closure-expired và socket-expired. Mọi expectation PASS được đối chiếu native thật:

- TLSsuccess native0/verifyTrue/FD4→4/thread1, accepted/closed/returned2/2/2,
  request socket/worker thread0, barrier còn8,359512s.
- Đóng chậm: trướcbarrier request socket/thread1, sau0; wait0,161730s,
  remainingBefore8,623058/After8,464227s. Serve loop đã đóng không tự coi request đóng.
- TLS cert → TLS_VERIFY_ERROR/native0. Stall → SETUP_TIMEOUT/native0,
  owned closure0/FD4→4; còn0,698701s saubarrier, không coi proxy200 làTLSsuccess.
- DNS inheritance: caller4threads/helper1, accepted socket/actual trace/output/sentinel
  FD đã cố ý inheritable nhưng child không kế thừa; noresource_tracker/childgroup0/
  pipesclosed/FD4→4. DNScrash helper20 → DNS_ERROR (case0); deadline/cancel/late
  helper−15/reaped, không upstreamsocket; inputcap trướcspawn, outputcap32769byte
  triggerFAIL so với32768, answer>64 và private localhost reject toàn bộ.
- Hai TCP cùng thành công vẫn chỉ1winner, loserclosed; externalcancel/afterwinner/
  mixedfamily/exception identity/order giữ. Candidate measured latency DNS6,353+
  firststall10+second0,421 đạt **setup7,096471s**, reserve2,656572s, peak2/FD4→4/
  child0. Stock nguyên handler firstTCP chưa hoàn tất trong10 (second chưa tới),
  serial control qua library delayNone có cùng plan, deadline theo expectation.
- Stockactual, loopblock, DNSparentblock là **negative containment −9/SIGKILL**,
  không graceful workerexit0. Wall including signal/reap10,018730/10,017591/
  10,051246s; DNSparentblock killed1helpergroup, mọi groupLeft0. Thiếu terminal
  handler/TLS của case kill ghi UNKNOWN, không dùng tracefragment làm full closure.
  Gate native0 nghĩa expectations đúng, không có nghĩa mọi child đều exit0.
- Negative expired barrier/socket native0 vì từ chối đúng; socketCreated0.

## Tài nguyên, bằng chứng, phạm vi nghiệm thu

Một container mỗi lượt, network-none/nohostports, 512MiB/swap512/CPU0,75/pids96,
UID1000/RO/capALL/NNP/privateIPC/sourceRO/tmp32; helper chia cùng cgroup nên tổng512≤608.
Không Docker/WSL/kernel/DNS/TLS/main settings change. Remove exact ownID/runlabel,
final label0container, networkcreated0. Mainimage
e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b giữ.
Completion cuốiUTC2026-10-10T05:34:51.7014742Z/VN12:34:51.7017207+07.

Evidence mới `docs/evidence/tiktok-connect-closure-dns-20261010/`: baseline4314,
predecessor lineage/package provenance, all attempts/native/runtime/source93/
trace/caps/childowner/FD/closures/deadline-review/snapshots, successor/manifest/verifier.
Chỉ AUDIT/PROGRESS prepend, no golden/verifier/raw/humanreview cũ chỉnh. Core hai fixes
giữhash; gallery/mainOFF/sourceAPI E2ENOT_RUN/deploy0/video2/3/mẫu3reviewchờ.

Nghiệm thu **PASS_CANDIDATE_OFFLINE của successor**, không đổi gate7REJECT và không
chốt causeTLS lịch sử. Bước sau cần review rồi nhiệm vụ riêng wiring own-egress+
wholephoto offline đúnghash/limits/ownership; chưa nguồn/rollout. NEXT_PROMPT trong
namespace mới là hướng review/offline, không cấp phép TikTok thật từ kết quả này.
