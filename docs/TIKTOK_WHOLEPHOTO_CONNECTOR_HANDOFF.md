# Lab wholephoto với connector/DNS/trace — 10/10/2026

Kết quả **PASS_WHOLEPHOTO_OFFLINE: 32/32 expectations** theo suite-result/assessment/verifier của
`docs/evidence/tiktok-wholephoto-connector-20261010/`. Đây là lab riêng,
không TikTok source/main/gallery/API E2E/deploy hoặc review watermark.
History gate38/21-of22/audit/P2/raw/humanreview giữ nguyên; historicalcauseUNKNOWN.

## Code, thư viện, wiring

`labs/tiktok/wholephoto-connector/` chỉ glue nối component đã kiểm:
stock CONNECT parser/443/header16KiB/tunnel240-idle30, TraceSink và trace-cleanup
ownership/best-effort/connector/DNSIPC, photo worker-parent/Cobalt picker,
Requests/urllib3/FFprobe/FFmpeg và validator JPEG. Không parser/HTTP/TLS/resolver/
race/solver/privatehelper mới hoặc dependency/build/pull/install/app changes.

Proxy và worker dùng cache31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e,
actualPython3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/aio2.7.1.
Unmodified aio vendorRO/PSF/LICENSE/J. Nick Koston/contributors, commit
4dfc926e30eea8d24c1a71602d73c0e9a895c191/wheelSHA
9243213661e29250eb41368e5daa826fc017156c3b8a11440826b2e3ed376472 giữ.
Photo/core AGPL/Cobalt imput contributors/NOTICE/lock giữ, không nhập wholeapp.

- Proxy96MiB/CPU0,25/UID65534/pids64; worker512MiB/CPU0,75/UID1000/pids96;
  swap=RAM/RO/capALL/NNP/privateIPC/sourceRO/ownoutRW/tmp32/nohostport.
  Helper cùng proxycgroup, semaphore1 và registry/epoch; tổng608MiB.
  Validator96/user65534/networknone chỉ chạy khi roles chính đã dừng.
- Hai mạng Docker fixture **internal**, worker chỉ private, proxy private+fixture.
  Không outbound/direct bypass. Mapping `/etc/hosts` www.tiktok.com→hai public
  stand-ins, media.tiktokcdn.com→một stand-in; helper gọi **socket.getaddrinfo
  hostnameRAM** thật trong child, stdin16KiB/stdout32KiB/answer64, không argv/logIP.
  Child outputs RAM, entireanswer guard trước socket; no re-resolve/order change.
  Đây là hosts/internal fixture, không DNSInternet hoặc source hostname thử thật.
- Original stock parser được import nguyên mã, chỉ socket dependency facade của
  owned fixture/proxy module. Candidate group2/delay0,25/interleave0 nhận IP đãpin.
  Event loop public sock_connect delegate mappednumericloopback TCP sau guard.
  DNS helper publicPopen/close_fds/start_new_session/epoch/cancel-reap giữ.
- Setup min(now+10,phaseRemaining) trước helper spawn/import, connectend−1reserve,
  no reset address/group/family preference. Worker ghi phaseDeadline số trướcmetadata/
  prepare; nguyênclient Budget clampconnect10/read20/meta30/prepare60. Socketnonblocking
  được handoff thành blocking-with-timeout cho stock sendall/select; close loser/
  winner/request/helper theo ownership. CONNECT200 là sendall thành công, khôngTLSPASS.
- FixtureCA ephemeral thêm vào trustbundle gốc, verifyTrue/certnegative. Offline-only
  env/runner enum không live flag; mappedrouting/CA/source mount có hash/config proof.
- Trace256/run32owner/registry64/privateUID65534/mode0600. Numeric health0644/readonly
  cho workerUID1000: mode/owner/count/incomplete checked trước conditional image.
  Mode600 không đổi; actual UID1000 read1byte denied và nobypass proof mỗicase.
  Cap/I/O faults giữ incomplete nhưng không ngăn physical finish/shutdown/close/barrier.
- Sau worker exit0 chỉ **provisional file**. Proxy shutdown, physicalownedbarrier,
  Trace.close/finalsummary, validator actual0/private trace rows/caps mới nhận file.
  Missing/incomplete/diagnostic failure reject và unlink onlyowned image/.part,
  preexisting/hash giữ. PacketPASS không override worker/proxy/validator FAIL.

API chính thức đã đọc đúngtag:
[CPython3.11.2 socketserver](https://github.com/python/cpython/blob/v3.11.2/Lib/socketserver.py),
[socket/getaddrinfo](https://github.com/python/cpython/blob/v3.11.2/Lib/socket.py),
[subprocess](https://github.com/python/cpython/blob/v3.11.2/Lib/subprocess.py),
[aio2.7.1](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/impl.py).
Requests2.34.2/urllib3-2.8.0 API/core/validator tái dùng đã pin, không đổibackend.
Glue cần vì không library nào tự sở hữu proxyhealth/finalfile gate/role ownership.

## Budget và các ca kiểm

Mỗifixturecase: analyze1, metadata≤2GET/30s/decoded8MiBresponse16MiBtotal;
freshbodyID/typephoto/orderedindex1+healthgate hợp lệ mới image1GET/60s/input20MiB/
output16MiB/workflow36MiB/staticJPEG≤8192px/≤16Mpixel. Redirect/retry/HEAD0.
Cookies/signedURL/body chỉ RAM; logs numeric/fixed/masked, noaccount/profile/stealth/
browser/crop/transcode/fallback. Casecancel/expiry mini deadline lànegative fixture,
không đổi phase caps của path chính. Source thật requests0 cho toàn nhiệm vụ.

Lệnh actual: bundledpwsh -NoProfile -File labs/tiktok/wholephoto-connector/run.ps1
-AttemptN -CaseNAME; ma trận `docs/evidence/tiktok-wholephoto-connector-20261010/run-suite.ps1`.

|Evidence|Ý nghĩa|
|---|---|
|run1normal|sandboxpipe denied trướccontainer/source0/raw giữ|
|run2normal|smoke toàn JPEG/parent-proxy-validator0 trước thêm finalguards|
|run3normal|permissions/nobypass/finaltrace smoke0|
|run4normal|matrix đầu normalPASS trêncode cóNOTICE|
|run5candidate-latency|metadataPASS nhưngprepareFAIL20/proxy0/validator20: fixture cũngstallimagehost1addr nên không thể cósecondwinner; raw/cause/snapshot giữ|
|suite Start6|matrixmới cùngsource sau sửa fixturelatency chỉmultiaddr; không tăngdeadline/đổianswer list hoặc rerunnguồn|

Suite32 cases: normal/candidate-latency; imageDNS/TCP/cert/TLSstall/HTML;
wrongbody/redirect/mixedprivate; healthmissing/incomplete; tracecap/open/write;
helpercrash/cap/late/answercap; failedhandoff/ownerabort; finalclosefail/missingsummary/
postfilediagnostic; preexisting/parentnonzero/expiry; caps+18photo regression;
SSRF literal/host; cancel vàproxy-parentblocked containment.

Fixture success đi workerextractor/anonymouschallenge→Cobaltpicker→oneJPEG→magic/MIME/
ffprobe1frame/64×64/pixels/fullDecode/SHA/native0. Không standalonePoC làm evidence
integrationPASS. Guards regression chạy cùngworker512, không main settings/data.
SOURCE/filevisual/watermark NOT_RUN/NOT_REVIEWED dù JPEGfixture contractPASS.

Native được ghi riêng: runner0 của negative là expectation đúng; worker20/proxy30/
validator20 giữ lỗi thực. Worker−9 sauparentFAIL chỉ reap/cancel, không gracefulPASS.
Proxy parentblocked có helper epochregistry kill/reap/containment receipt; request/
thread còn trướcprocessend không bị gọigraceful0. Memory cgrouppeak/events/RSS/OOM
và maxhelper1 ở finalsummary; mức96 không bịnới. OSresolver/D-state/jitter/TLSdetail/
CIDcorrelation/sourcecauseUNKNOWN, không ghép request/proxy chắc bằngtimestamp.

## Evidence và bàn giao

Baseline5578/sources trước-sau/provenance/runtime/vendor/core23, guards/networks/mounts/
uid/permissions/budgets/health/trace/finalsummary/native/file SHA/owned cleanup được
chốt trong namespace mới. Mọi FAIL→PASS giữ; chỉ AUDIT/PROGRESS prepend qua successor.
Cleanup exactIDs/net labels; mainimagee7f93577…0184b giữ. No oldmanifest/verifier rewrite.

Nghiệm thu PASS_WHOLEPHOTO_OFFLINE chỉ theo suite/assessment/native/manifest mới,
không mở trial nguồn từ runner này. Sau review mới có nhiệm vụ riêng và budget nguồn
tối thiểu; nhiệm vụ hiện tại không TikTok/main/deploy/API/gallery acceptance.
Video2/3/mẫu3NEEDS_VISUAL_REVIEW và hai core fixes giữhash. NEXT_PROMPT chỉ hướng
review, không source authorization. Khoảng trống hoặc failurecause tiếp phải ghi
FAIL/UNKNOWN với stage/exit, không retry/fallback mù.

Source snapshot cuối119 SHA48bc41e8d9d43474fb89b3dba634579094cf3e42f2c02e2c5c008a3461ca64f5;
runtime69/role: integration12/photo20/core23/trace4/vendor10. Mọi final32 source-before/
after giống byte/hash và mã hiện tại. Proxy31summary có peak tốiđa33.775.616bytes,
RSS35.291.136bytes, cap100.663.296bytes, observed oom_kill0. Summary-missing thiếu
phép đo RSS/cgroup và bị reject; Docker OOMKilledFalse không thay phép đo thiếu.

Supplementary inheritance-proof native0: helper hostnameRAM trong role65534/96MiB/
networknone, 3FD accepted socket/trace/output cố ý inheritable, child không kế thừa,
close_fds/reap/group0/pipesclosed/socket-thread0. Proof cùng helper/wiring thực này
không có nghĩa mọi path của32ca đều inject sentinels. Cgroup và UID giữ đúng proxyrole.

Final suite kết thúc UTC07:24:57.943/VN14:24:57.943 ngày10/10; supplementary proof
cleanup UTC07:29:37.121/VN14:29:37.121. Việc chốt hồ sơ muộn hơn có timestamp riêng.
Mỗi finalcase cleanup3containers+2networks exactIDs/runlabel với native0. Mạng chỉ có
runlabel; filterlab không dùng để suy cleanup mạng. Finalinspect đối chiếu tồn tạiIDs
và native removals, giữ nguyên mainimage. Verifier mới chỉ kiểm hash/receipts, không
chạy lại functional hoặc sửa verifier/manifest lịch sử.
