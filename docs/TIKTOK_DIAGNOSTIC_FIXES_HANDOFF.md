# Diagnostic successor offline — 10/10/2026

Lab mới: `labs/tiktok/wholephoto-diagnostics/`. Evidence mới:
`docs/evidence/tiktok-diagnostic-fixes-20261010/`. Kết quả cuối phải đối chiếu
assessment, offline-gate, native receipts và manifest của namespace này.

## Hai bản sửa

F-SOURCE-ATTEMPT-LABEL: receipt version2 tách `preparedGETAttempts` (Budget accepted
rows theo phase/index), `adapterAttempts` (sendDiagnostic trong packet),
`requestSendBegin/End`, `responseHeadersEnd`, HTTPstatus và decodedbytes. Metadata
và preparePacket có thể cùng chứa metadata rows; identity phase/index/requestID
được dedupe, dữ liệu mâu thuẫn bị reject. Setup lỗi trước send vẫn prepared1/
adapter1/send0. Request thứ hai trên TLS reuse có requestID/index mới, counted
riêng. Không gán sendBEGIN/END là origin receipt; originReceipt luônUNKNOWN.

Missing packet/phase, observer absent/partial/cap, identity conflict hoặc numeric
không hợp lệ giữUNKNOWN/incomplete và không mở file gate. Metadata-only hoặc parent
chưa gửi prepare có thể chứng minh prepare0; không áp dụng zero đó cho prepare
đã bắt đầu nhưng thiếu packet. Adapter không đủ bằng chứng làUNKNOWN. Exact receipt
và caps là điều kiện bổ sung cho final acceptance, không thay native exits/trace/file.
WorkerUID1000 đọc observer600 locally và chỉ export bounded numeric/enum0644;
validatorUID65534 đọc receipt này, không đọc/chmod private worker observer.
Stageoffline `sourceCalls=0` là scope, không cộng sourceCalls từ send counters.
Raw 2/0 của trial trước giữ nguyên và được giải thích bằng version2 successor.

F-SOURCE-TCP-INDEX: SourceLoop và OfflineLoop capture immutable local index trước
await, BEGIN/END/ERROR dùng cùngindex. Cancel được ERROR/CANCELLED, không suy thành
network refused. Bounded TCP coverage đòi mộtBEGIN và mộtterminal cho mỗi
owner/phase/index; missing/duplicate terminal hoặc invalididentity giữINCOMPLETE.
Proxy summary/final gate đọc coverage, đồng thời trace.incomplete/caps vẫn fail-closed.
Coverage của những row còn lại không thay complete coverage khi sink đã drop rows.
Delegate exception object và networking/timing vẫn do library/public loop sở hữu.

## Thư viện và giới hạn giữ nguyên

Requests2.34.2/urllib3-2.8.0/Python3.11.2/yt-dlp2026.8.19/
aiohappyeyeballs2.7.1/FFmpeg và Cobalt/photo parent/worker/validator giữ pin.
Cache31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e.
Candidate.py, DNShelper/IPC, ownership, stock CONNECT parser và oldlabs/vendor/lock
không sửa. NOTICE/AGPL/Cobalt imputcontributors/PSF/J.Nick Koston credits giữ.

API chính thức đã đối chiếu đúngtag: Python public SelectorEventLoop.sock_connect
và CancelledError; Requests public HTTPAdapter.send; aio start_connection accepts
validated addr_infos/socket_factory/loop/delay/interleave. Không copy private
helpers, solver/parser/HTTP/TLS/DNSresolver/customrace hoặc monkeypatch library.
Own offline loop overrides và fixture control chỉ dùng trong network-none/internal.

- https://github.com/python/cpython/blob/v3.11.2/Lib/asyncio/selector_events.py
- https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py
- https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/impl.py

Setup10 từ trước helper spawn/import/end−1reserve/connect10/read20/meta30/prepare60;
group2/delay0,25/interleave0/toànDNSanswer/order/no re-resolve/allowlist443/
header16KiB/tunnel240-idle30/TLS verifyTrue giữ. Meta8–16MiB/image20–16MiB/
workflow36MiB/staticJPEG8192px/16Mpixel/redirect-retry-HEAD0 giữ. Proxy96MiB
UID65534 CPU0,25/pids64/helpersemaphore1 +worker512MiB UID1000 CPU0,75/pids96=608;
validator96/networknone sau roles dừng. RO/swapRAM/capALL/NNP/privateIPC/sourceRO/
nohostports/trace256-owner32-registry64/private600/health644 giữ. Singleprobe512/
network-none chạy tuần tự. Source runner từ chối trước claim/network; source claim
và budget của trial trước không clear, reset hoặc sửa.

## Probes mới và giới hạn batch

Probe3 chạy mã cuối: 15accounting +7index/coverage +4batch. Actual loopback TCP
hai success BEGIN1/2→END1/2; reused loop index không mất; winner2/losercancel1;
two native errors giữ exceptionidentity; timeout/cancel và missingterminal. Native
diagnostic gate20 cho missingterminal và tracecap, gate0 cho đủ coverage/resources.
Đây là numeric diagnostic gate, không file/source acceptance. FD/thread trước–sau
khớp; sourceCalls0. Probe2 trước bổ sung nativegate giữ; probe1 lỗi runner selfname
trước Docker/source giữ cause/sourcehash, không ghi đè.

Budget `.5s` trong batch probe là fixture thấp riêng, không đổi source setup10.

|Probe3|Kết quả quan sát|Thời gian fixture|
|---|---|---|
|First2stall + thirdfast|TIMEOUT, chỉ1/2 thử; disjoint thirdalonecontrolPASS|0,501609s|
|6 immediatefail rồi7fast|PASS, indices1..7, peak1, 14TCProws|0,002416s|
|Firstwinner|PASS, chỉindex1/peak1/2rows|0,000261s|
|44 immediatefail rồi45fast|TCPPASS, 45attempts, 32TCProws/capdrop/incomplete, nativegate20|0,006841s|

Stalled first pair có thể dùng hết globalremainingdeadline nên nhóm sau không được
thử. Immediate errors khác stalled TCP: library có thể đi tiếp nhóm sau rất nhanh.
Source45answers/2TCPBEGIN trước chỉ phù hợp observation này; reachability43khác và
underlyingnetworkcause vẫnUNKNOWN. Diagnostic fixes không chứng minh sửa connection.

Chỉ đề xuất review transport riêng: giữ TCP end=setupEnd−1, dùng subdeadline nhóm
bounded trong remaining của global deadline; không reset/tăng10 hoặc đổiDNSorder/
family preference. Với remainingTCP khoảng8,63s và45answers→23nhóm, equal share
khoảng0,375s/nhóm chỉ còn~0,125s cho candidate2 sau delay0,25s. Mức0,5s/nhóm chỉ
có thể cấp đủ~17nhóm trong8,63s;0,75s chỉ~11nhóm, chưa tính overhead. Các mức này
là thiết kế đểreview, không API/config được áp dụng hay khuyến nghị tăng timeout.
Phải kiểm fair opportunity/winner close/erroridentity/cancel/TLSreserve và thời gian
jitter; không bảo đảm hết23nhóm hoặc một sourceIP sẽ reachable.

Trace cũng ràng buộc thiết kế: chỉ TCP BEGIN+terminal đã2rows/attempt,45attempts
cần90rows nên mộtowner32 không thể đầy đủ; measured45probe vẫn TCPPASS nhưng
diagnostic20. Registry Sockets dùng thêm SOCKET_CREATE và LIBRARY_SELECT cùngowner;
source total256 còn chia cho DNS/lifecycle/metadata. Per-group diagnostic owner
tương lai cần correlation bounded/registry64 và tổngcoverage256; không tự tăngcaps
hoặc chấp nhận survivingrows nhưcomplete. Task này giữ scheduling và tracecaps.

## Whole gate và phạm vi bàn giao

Whole offline gate mới phải cùng hash với probe3/cold policy1: canonical path/hash,
full runtime inventory, metadata→JPEGfixture/native/file/decode/SHA, health/private
UID/SSRF/TLS/deadlines/tracefault/helperIPC/epoch/cancel/preexisting/postfilediagnostic
reject/ownedcleanup. Không gọi32receipt trước là gate của bảnmã này.

Lệnh thực: bundledpwsh -NoProfile -File run-probes.ps1 -Attempt2/3;
run-policy.ps1 -Attempt1; gate.ps1 -TestCanonical/-TestRuntime; run-suite.ps1 -Start1;
gate.ps1 và -Verify sau suite. Native FAIL và exact hash/timestamp nằm evidence.
Chốt findings chỉ offline khi wholegate đạt. Unknown/sourcecauses và ảnh nguồn
magic/decode/SHA/visualNOT_RUN giữ; TikTokmain/gallery/API E2E/deploy không bật.
Video2/3/mẫu3NEEDS_VISUAL_REVIEW và priorP2cleanupclosed không đổi.

## Kết quả cuối

Whole32/32 và probe3 narrow26 đều actualexit0 trên cùng source153/runtime76/role
(integration19/photo20/core23/trace4/vendor10). Source snapshot SHA:
b86f8ee8564d183667dfd62fbee854f27505a1c7fde5354f1b7e6c796dffe012.
Gate tổng hợp591checks/native0; -Verify chỉ đọc currenthash/proofs, không chạy lại
functional. TestRuntime stdout kế thừa chữ72 là display cũ; JSON inventory thực76
được kiểm toànset. ExactID inspection:99containers+64networks đều absent;
mainimagee7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b giữ.
Baseline9944/sourceclaim trước giữ hash, source0/transport-scheduling-timeout changes0.
Findings chỉ đóng tại successoroffline. Oldraw/codecopies giữ labels2/0 và collision
để phản ánh đúng mã cũ, không rewrite. UTC/VN/native/coverage/manifest/verifier mới
ở namespace bàn giao; các phép đo batch ở trên là fixture, không Internet.
