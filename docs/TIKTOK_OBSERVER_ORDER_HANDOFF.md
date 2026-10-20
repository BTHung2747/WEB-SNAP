# Bàn giao observer order — 11/10/2026, chỉ offline

Successor: `labs/tiktok/wholephoto-order/`. Evidence:
`docs/evidence/tiktok-observer-order-20261011/`. Không sửa lab cũ, ứng dụng,
vendor, lockfile, image, raw, golden, manifest, verifier hoặc human review lịch sử.
Source claim của trial cũ đã tiêu thụ và vẫn giữ SHA.

## Phần sửa và giới hạn

F-ACCOUNTING-OBSERVER-ORDER là lỗi validation: v3 trước đếm BEGIN/terminal mà
không kiểm vị trí ghi. `accounting.py` mới tiêu thụ JSONL theo thứ tự nguyên bản,
giữ trạng thái từng `(phase, requestID, boundary)`. Mỗi boundary chỉ có một BEGIN,
theo sau bởi một END hoặc ERROR. Terminal trước BEGIN, duplicate, reopen, missing
và header BEGIN trước send END đều gây PARTIAL với reason `ORDER_*`; send ERROR
không được nối tiếp header. Không sort theo elapsed, sửa ID hoặc sửa observer.

Setup có thể kết thúc trước send hoặc lồng trong send. Reuse không có setup mới,
setup failure trước send, nested setup ERROR rồi send ERROR đều được giữ.
Các request/phase có thể xen kẽ; không áp tổng thứ tự toàn workflow hoặc đoán
TCP/TLS từ thứ tự này. Linkage/status/adapter/packet terminal/connection/caps v3
vẫn được đối chiếu. `orderPolicy=PER_REQUEST_JSONL_V1` mô tả validation mới;
schema ứng dụng không đổi. Known Budget counts và `budgetWithinCaps` giữ theo
packet; mâu thuẫn khiến linked counters UNKNOWN và exact/withinBudget false.
Lower bound chỉ là đo observer; originReceipt vẫn UNKNOWN.

Worker UID1000 đọc observer0600, xuất receipt0644 có numeric/enum bounded.
Validator UID65534 chỉ đọc receipt và private proxy trace theo quyền vốn có.
File gate vẫn yêu cầu native exits, full file contract, trace và accounting.

## Thư viện và API đã xác minh

Requests2.34.2 vẫn gọi urllib3 qua HTTPAdapter.send. Trong urllib3-2.8.0,
HTTPS pool validate kết nối trước request; HTTP request→endheaders có thể gọi
connect bên trong send qua CPython3.11.2. Vì vậy một thứ tự setup→send cứng
không phù hợp. Existing public observer của WED SNAP được giữ nguyên byte.
Chỉ viết validation glue cho hợp đồng evidence riêng, không client/parser/TLS.

Probe loopback dùng Requests Session và observer thật: request thứ nhất có
send BEGIN→setup BEGIN/END→send END→header BEGIN/END; request thứ hai dùng lại
connectionID với requestID mới và không có setup mới. Probe giữ row/terminal
summary do observer thật cấp, rồi đổi BEGIN positions để kiểm hai lỗi audit.

- [Requests2.34.2 adapters](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py)
- [urllib3-2.8.0 connection pool](https://github.com/urllib3/urllib3/blob/2.8.0/src/urllib3/connectionpool.py)
- [urllib3-2.8.0 connection](https://github.com/urllib3/urllib3/blob/2.8.0/src/urllib3/connection.py)
- [CPython3.11.2 HTTP client](https://github.com/python/cpython/blob/v3.11.2/Lib/http/client.py)

Không thêm dependency hoặc build image. LICENSE/NOTICE/Cobalt AGPL-3.0,
aiohappyeyeballs2.7.1 PSF-2.0 và credits hiện có được giữ. Các file adapter/
candidate/DNS/TCP/ownership/proxy/transport cũ không sửa.

## Kiểm mới và các lượt lỗi được giữ

Final targeted probe4: **82 ca =71 accounting +7 TCP index +4 batch**.
40 accounting trước được giữ; thêm31 order (7 valid control,24 contradiction).
Native `accounting_gate.py` exit0 cho valid và20 cho contradiction; đây không
phải numeric TCP gate, file gate hoặc source acceptance. Các ca mới gồm hai
audit faults, setup/header terminal trước BEGIN, early header, duplicate/reopen,
ERROR sequencing, nested setup, reuse, phase/request interleaving và elapsed
không phải timestamp. Packet và observer đầu vào không bị validator đổi.

Probe1/2 exit1 tại cleanup control HTTP thật, giữ raw và source/code snapshots.
Probe2 đo FD4→5, thread1→1, handler thread đã dừng. Explicit pool close bằng
API public khắc phục fixture ownership: Session.close xóa manager nhưng pool
còn được Response tham chiếu. Probe3 đạt sau close pool nhưng trước chốt cách
dùng extension API trong subclass; giữ nguyên proof của probe3. Probe4 dùng
offline `OwnedAdapter(ObservedAdapter)` override đúng hook
`get_connection_with_tls_context`, ủy quyền `super`, giữ ownership pool để gọi
public `HTTPConnectionPool.close` trong `close`. Hook này được Requests chỉ
định cho adapter subclass. Không gọi private API, monkeypatch hoặc sửa Session
ứng dụng. FD4→4/thread1→1/handler0 ở bản cuối; mọi attempt giữ code1–4.

Fresh whole pipeline targeted5 chạy metadata→Cobalt picker→JPEG download→parent
exit→public receipt→validator, không replay JPEG lịch sử. Modes:
`observer-order-send`, `observer-order-header`, `observer-order-header-preexisting`,
`observer-order-setup`, `observer-order-reopen`. Parent/worker/proxy0, JPEG fixture
provisional PASS/trace PASS nhưng accounting false/validator20; image.jpg/part do
lượt tạo bị dọn, unrelated keep.bin giữ SHA. Chỉ đổi BEGIN positions, packet và
chuỗi terminal summary giữ nguyên. Whole40 =35 kế thừa +5 negative mới kiểm trên
cùng snapshot với probe4/cold policy/runtime gate. Normal/latency controls giữ
native0, JPEG64×64/full decode/SHA; các native failure của negative không bị
runner expectation0 diễn giải thành tải PASS.

## Guards và evidence

Giữ cached image
`sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e`,
Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/aiohappyeyeballs2.7.1.
Runtime source inventory79 file/role, source set195 file gồm successor22 file
và toàn các phần đã ghim. Baseline12.549 file được giữ; AUDIT/PROGRESS chỉ chèn
kết luận mới, successor chứng minh phần lịch sử nguyên byte. Manifest mới có
full coverage; verifier mới capture một lần rồi kiểm lại không -Capture.

RAM8GB chạy tuần tự. Proxy96MiB CPU0,25 +worker512MiB CPU0,75=608MiB; validator96
sau roles dừng, probe512/network-none. UID1000/65534, source mounts RO, rootfsRO,
swapRAM, capALL drop, NNP, privateIPC, nohostport, internal fixture/own-egress,
SSRF/TLS và original trust hash giữ. Setup10/end−1reserve/group2/delay.25/
interleave0/DNS order/TLS reserve/trace256-owner32-registry64/meta30/prepare60/
connect10/read20/body8–16+20–16MiB/workflow36/IPC16–32KiB/64answers/JPEG8192/
16Mpixel/redirect-retry-HEAD0 không đổi. Exact Docker IDs được kiểm sau dọn,
image main giữ. Native stdout/exit/timing/UTC/VN/reasons/receipts/guards và cleanup
ở namespace mới; `assessment.json`/`verification-result.json` ghi kết quả chốt.

Lệnh thực: bundled pwsh `run-probes.ps1 -Attempt1/2/3/4`, `save-code.ps1`,
`run-preflight.ps1`, `run-targeted.ps1`, `run-suite.ps1 -Start6`,
`gate.ps1`/`-Verify`, `inspect-final.ps1`, `record.ps1`, `verify.ps1` capture và
đọc kiểm lại. Script nằm trong namespace evidence mới, runner ở successor lab.

Shell `run-suite.ps1` ngắt với mã Windows1073807364 sau37 ca hoàn tất, trước
native Docker create của thư mục43. Cause host UNKNOWN; không coi đây là native
worker/validator failure. Giữ partial43 và interruption receipt. Tiếp đúng3 ca
thiếu bằng `run-remaining.ps1`/attempt46–48, không rerun37 ca hoặc đổi mã.
Combined suite dùng completion/native/hash của37 ca cùng3 lượt mới và ghi rõ
continuation. Kiểm CIM process không có quyền đọc; không đổi quyền/host để xử lý.

## Phần chưa nghiệm thu và bước tiếp

Finding chỉ đóng trong phạm vi offline khi exact gate/verifier mới đạt.
Source0, claim SHA giữ; sourceFAIL20/metadata5 của trial trước giữ. Ảnh nguồn,
decode/SHA/visual chưa đạt; video2/3 và mẫu3 NEEDS_VISUAL_REVIEW giữ. Chưa TikTok,
Internet DNS, HEAD, retry, ảnh2/album, browser, solver, fallback, main/gallery/
API E2E hoặc deploy. Không suy fixture hay diagnostic fixes thành network fix.

Review độc lập receipt order và coverage là bước tiếp. Batching/trace budget là
review riêng: first2stall có thể hết global deadline, 43 IP khác và network root
cause UNKNOWN. Equal share8,63/23≈.375s chỉ còn khoảng.125s cho candidate2 sau
delay.25; không hứa đủ45IP/TLS, tăng cap/timeout hoặc tự bật nguồn sau gate.

Kiểm exact IDs sau mọi lượt: 140 container/90 network do phiên này tạo đều không còn; main image e7f93577…d0184b giữ nguyên. Partial43 chưa tạo container/network và không được tính thành ca đã đạt. Manifest mới giữ toàn artifact partial43, failed probes, code snapshots và continuation receipts.
