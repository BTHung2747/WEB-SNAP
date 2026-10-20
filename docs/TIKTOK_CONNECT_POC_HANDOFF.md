# Bàn giao PoC kết nối so le — 10/10/2026

**Kết luận để review: REJECT/UNKNOWN cho toàn gate; chưa được mở trial nguồn.**
Bản cuối offline-7 đạt 21/22 nhóm nhưng suite/container/runner exit1. Nhóm HTTPS
success đã có fixture HTTP200/218byte rồi lỗi kiểm cuối, chưa biết assertion nào.
Một diagnostics-1 mới, đúng mã giữ nguyên, public sys.settrace chỉ fixed phase/count,
đạt HTTP/TLS/FD4→4/thread1/native0. Lần PASS riêng này không chứng minh cause của FAIL
trước, không thay verdict offline-7 hoặc sửa raw/golden. Dừng ở offline/review.

## Mã/API và pin

Chỉ thêm `labs/tiktok/connect-poc/`; apps/, các lab cũ, lock/dependencies ứng dụng giữ.
`candidate.py` là glue guard/deadline/ownership; `test_poc.py` là fixture;
`supervise.py` là OS/process watchdog; `run.ps1` là runner network-none.
Không chép private helper hoặc tự viết Happy Eyeballs/HTTP/TLS/DNS/parser/solver.

- aio-libs/aiohappyeyeballs **2.7.1**, tag v2.7.1, annotated tag object
  be824dea5fac3a24aa64e785f2a26d00d6714b7f, commit
  **4dfc926e30eea8d24c1a71602d73c0e9a895c191**.
- Wheel SHA256 **9243213661e29250eb41368e5daa826fc017156c3b8a11440826b2e3ed376472**.
  Vendored nguyên wheel dưới vendor/; không pip install, pull/build hoặc đổi image.
  LICENSE PSF-2.0 ở dist-info/licenses, tác giả J. Nick Koston/contributors;
  NOTICE/requirements.lock/PROVENANCE giữ package/commit/file pins.
- `impl.py` SHA **eb32b7ba4aa27993fe187deb56cf16af8dfcb4fbfe63b4f5846802ca02a64bb2**
  khớp raw official commit, wheel và runtime. Wheel yêu cầu Python>=3.10,
  không Requires-Dist; changelog release01/07/2026 cho thấy có bảo trì. Đây là rà
  source/API hẹp, không kiểm toán toàn bộ vulnerability hoặc suy gói hoàn toàn an toàn.
- Cache **sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e**:
  actual Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19;
  core23file trong image khớp host. Không giả định pin từ tên image.

Nguồn chính thức đã đối chiếu:
[start_connection đúng tag](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/impl.py),
[metadata/changelog](https://github.com/aio-libs/aiohappyeyeballs/tree/v2.7.1),
[PyPI2.7.1](https://pypi.org/project/aiohappyeyeballs/2.7.1/),
[CPython3.11.2 socket loop](https://github.com/python/cpython/blob/v3.11.2/Lib/asyncio/selector_events.py),
[timeout_at3.11.2](https://github.com/python/cpython/blob/v3.11.2/Lib/asyncio/timeouts.py),
[public subprocess](https://docs.python.org/3.11/library/subprocess.html),
[multiprocessing contexts/terminate](https://docs.python.org/3.11/library/multiprocessing.html),
[public event-loop API](https://docs.python.org/3.11/library/asyncio-eventloop.html).
Docs3.11 hiện là patch mới hơn; exact source tag/runtime3.11.2 được ghi riêng.
HTTPAdapter/urllib3 và photo/core/proxy API cũ được tái dùng, không thay backend.

## Scheduling, ngân sách và ownership

`start_connection(addr_infos, happy_eyeballs_delay=.25, interleave=0,
socket_factory=registry.factory, loop=loop)` là API công khai đã chạy. Không có
max_concurrent: glue chia từng nhóm tối đa2 theo **thứ tự gốc**, không ưu tiên family.
Guard **toàn danh sách** IP global/443/SOCK_STREAM trước socket đầu, và kiểm lại
trong factory; không lọc bỏ private answer để tiếp tục. Host dùng stock allowlist.
IP pre-resolved giữ trong RAM; thư viện không resolve lại hostname. Fixture loop
override public sock_connect để tiêm delay và delegate real numeric IPv4/IPv6
loopback; không override/private monkeypatch code thư viện. Đây không phải observer
per-attempt production; terminal/correlation production vẫn UNKNOWN.

Deadline tuyệt đối do supervisor lập **trước spawn/import**, truyền numeric sang
child. Child clamp min(deadline chung, start+budget≤10); DNS/connect dùng end−1s,
không reset theo address/group. Ngân sách nhỏ FAIL trước DNS spawn/socket. Reserve1s
chỉ là thiết kế handoff/CONNECT/TLS/cleanup cần review, không bảo đảm mọi TLS xong1s.
Socket thắng nonblocking; fixture kiểm public settimeout/sendall về stock tunnel
contract. Caller nhận ownership và phải đóng winner khi handoff/cancel/lỗi.
Registry/library đóng loser/cancel; thực đo peak≤2 và live0 ở cuối từng receipt.

DNS PoC là **child fixture**: sleep độ trễ rồi stock getaddrinfo numeric với
AI_NUMERICHOST, không gọi DNS hostname ngoài mạng. Public multiprocessing
get_context('fork')/Pipe/terminate/join/kill/close; child timeout/cancel được reap.
Chỉ Linux/single-thread PoC; reject active thread count khác1. Không được transplant
fork vào ThreadingTCPServer thật. Chưa có resolver-hostname isolation đã tích hợp,
chưa chứng minh OS DNS đang kẹt/D-state bị hủy ngay. Async timeout không phải hard
deadline OS. Đây là blocker thiết kế cho bước review/integration kế tiếp.

Supervisor Popen/start_new_session/communicate(timeout=remaining) độc lập event loop;
đến10s killpg(SIGKILL), communicate/wait, kiểm group không còn. Watchdog số vẫn10;
jitter native khoảng12–14ms trong các ca cuối, không hứa hard realtime0jitter.
TLS-stall/stock-control/eventloop-block được kiểm bằng containment kill, **không**
gọi −9 là worker exit0 hay graceful TLS cleanup. Thiếu child receipt/TLS detail
ghi UNKNOWN. Các FD/socket của process lỗi đóng bởi OS, groupLeft0 sau reap.

## Kiểm mới và kết quả thực

Lệnh: bundled `pwsh -NoProfile -File labs/tiktok/connect-poc/run.ps1 -Attempt N`,
tại D:\WED SNAP; các attempts không ghi đè nhau.

| Attempt | Actual kết quả giữ nguyên |
|---|---|
|1|Docker pipe sandbox denied trước tạo container; wrapper1, không functional/source test|
|2|mount con photo_lab dưới parent coreRO lỗi OCI trước test; wrapper1/native start1; cleanup0|
|3|16 network/cancel nhóm đạt, TLS fixture class shadow + media tmp reuse lỗi; suite1; host runtime comparison lẫn node_modules lỗi, giữ raw|
|4|TLScert/stall đạt, TLSsuccess arbitrary image URL không đúng provider prerequisite; suite1/cleanup0|
|5|TLSsuccess/cert đạt, added stock fixture class shadow lỗi; suite1; không gatePASS|
|6|stock actual/candidate/TLScert đạt; hai deadline bị −9 vì parent/child lệch clock startup; suite1; TLSsuccess cũng lỗi kiểm cuối chưa biết|
|7|**21/22**, suite/container/runner1; absolute deadline sửa có chứng cứ, TLSsuccess FAIL sau HTTP200; verdictREJECT|
|diagnostic-1|`pwsh -NoProfile -File docs/evidence/tiktok-connect-poc-20261010/run-diagnostic.ps1`; đúng một TLS case/sys.settrace công khai, native0/HTTPstatus check/outcomePASS/FD4→4/thread1; không thay verdict gate7|

Snapshots/lỗi trước sửa và runtime/native/state/source-before/after/cleanup đều giữ.
Package retrieval sandbox DNS denied được ghi riêng, sau đó lấy official tag/PyPI/wheel
qua quyền network; actual0/hash đúng. Không có TikTok request trong bất kỳ attempt.

Final22 groups: one/two/manyIPv4, mixedIPv6→IPv4→IPv6→IPv4 unchanged, allfail,
near success, **double-success cả2 TCP END** rồi chỉ1 winner/loser đóng, stock actual,
serial-policy control, candidate latency, DNScancel/deadline, connectcancel,
after-winnercancel, smallbudget, mixedprivate/badhost deny, exceptionidentity,
HTTPSverifyTrue success/cert/stall và independent event-loop block.

- Độ trễ fixture DNS6,353045s + firststall10s + second0,421074s:
  **candidate setup7,048269s**, còn2,452079s đến externaldeadline sau tính startup;
  socketpeak2, firstCANCEL/secondEND, FD4→4/thread1/child0/pending0/socket0.
- Stock **handler nguyên mã** qua cùng injected DNS/firststall profile: DNSEND6,401426s,
  firstTCPBEGIN6,428966s; watchdog10,013318s/−9, groupLeft0, chưa có200/TLS receipt.
  Serial control qua API thư viện delayNone: deadline FAIL đúng kỳ vọng, native0,
  setup8,175837s/whole9,10s; không gọi control này là stock implementation nguyên bản.
- DNS deadline native0, child−15/reaped; external whole9,16s. Cancel DNS/connect/
  afterwinner và nhỏbudget native0, sockets/children/pending0/FD4→4.
- TLScert verifyTrue → TLS_VERIFY_ERROR/native0. Stall và blocked event loop:
  watchdog−9 khoảng10,012/10,014s/groupLeft0, TLS details UNKNOWN.
- TLSsuccess cuối: origin fixture200/218byte, process1, không receipt cuối.
  Không được suy FD race đã chứng minh: đó chỉ là giả thuyết vì diagnostic fresh0.

HTTPS chỉ first metadata page fixture để kiểm TLS/tunnel; không photo metadata
acceptance/JPEG tải/full pipeline mới. Reuse photo provider/stock HTTP parser/
Requests; không bỏ cap/body/pixel/decode/SHA/job ownership trong core hoặc tuyên bố
fixture là nguồn. Các fixes duration/body-timeout giữ hash. Chưa chạm đường ảnh nên
không chạy lại regression lịch sử không liên quan.

## Guards, evidence và bước review

Một container mỗi lượt, network-none/nohostports, 512MiB/swap512/CPU0,75/pids96,
UID1000/RO/capALL/NNP/privateIPC/defaultseccomp, source mountsRO/ownoutRW/tmp32.
Tổng512≤608MiB; không build/pull/install main, đổi Docker/WSL/kernel hoặc DNS/TLS.
Cleanup exact lab/runID; mỗi actual container đã remove, final label0;
mainimage e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b giữ.
Bằng chứng ở `docs/evidence/tiktok-connect-poc-20261010/`, baseline4019, old raw/
golden/verifiers/humanreview giữ; AUDIT/PROGRESS chỉ prepend qua successor mới.

**Review tiếp chỉ offline:** chốt cause TLS cuối bằng begin/end/error fixed codes
cho output/FD/thread/handler-finalization, không log message/repr/stack/secrets;
kiểm socket handoff/close và shared absolute clock. Sau đó review public DNS process
isolation thích hợp proxy threaded, ownership và phần reserveTLS trước một nhiệm vụ
wire lab riêng. Không chấp nhận diagnosticPASS làm gatePASS hoặc mở trial nguồn.
Prompt review ở NEXT_PROMPT.md của namespace này. TikTokmainOFF/gallery chưa tích hợp/
sourceAPI E2ENOT_RUN/deploy0; video2/3/mẫu3NEEDS_VISUAL_REVIEW không đổi.
