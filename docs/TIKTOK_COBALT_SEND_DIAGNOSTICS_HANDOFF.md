# Mẫu3 — chẩn đoán HTTPAdapter.send, 08/10/2026

**Diagnostics offline PASS. Lượt nguồn mới nhận MP4 HTTP200 và93.936.477byte input, nhưng prepare vẫnFAIL; chưa có tệp đạt để review.** Mẫu1+2 giữ nghiệmthu2/3. Lỗi trước header/body cũ không lặp lại trong lượt này, rootcause lịch sử chưa được chứng minh.

## API đã xác minh và phần tích hợp

Đã đọc AGENTS/PLAN/STRUCTURE/AUDIT/PROGRESS/handoff/cause mẫu3. Xác minh [Requests2.34.2 adapters](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py), [exceptions](https://github.com/psf/requests/blob/v2.34.2/src/requests/exceptions.py), [urllib3-2.8.0 exceptions](https://github.com/urllib3/urllib3/blob/2.8.0/src/urllib3/exceptions.py), [connectionpool](https://github.com/urllib3/urllib3/blob/2.8.0/src/urllib3/connectionpool.py). HTTPAdapter.send ánh xạ lỗi urllib3 sang lớp Requests trước trả Response; MaxRetryError.reason và ProxyError.original_error chứa cause dạng exception. ReadTimeoutError có thể phát sinh lúc validation TLS/proxy hoặc chờresponse, nên class này không tự đo riêng chặng mạng. api-review.json ghi source/phiên bản/lý do/giới hạn. Runtime version/hash thực và fixture dùng đúng bản cache, không tải dependency.

Thư viện tiếp tục sở hữu HTTP, proxy/TLS, cookie, redirect và lỗi; chỉ tự viết observer vì default yt-dlp wrapper/logger không giữ phân loại an toàn WED SNAP cần. send_diagnostics.py delegating send, rethrow nguyên identity; chỉ exact class identity map thành string cố định/code whitelist. Duyệt tối đa12exception nodes qua cause/context/exception-valued args và hai thuộc tính public đã xác minh, bỏ toàn bộ string payload. Khôngstr/repr/message/stack/request/response URL/headers/cookie. Dynamic/custom subclass tên bất kỳ không xuất; worker exception ngoài whitelist làUNKNOWN. Observer không retry hoặc đổi timeout. Ghi phase metadata/prepare, boundary HTTPAdapter.send, elapsed monotonic, status chỉ khi Response thực trả; proxyConnect/originTLS/headerWait đềuUNKNOWN vì chưa có instrumentation riêng.

yt_candidate.py chỉ bọc call send và whitelist top exception. test_send_diagnostics.py mới, test_all gọi suite này; run.ps1 đổi namespace/gate diagnostics receipt mới, NOTICE ghi modification. Cobalt body parser/high yt-dlp/native downloader/format play-selection/file contract giữ. Khôngprivate-helpercopy/parser/solver/backend rewrite; không sản phẩm/UI/API/DB/lifecycle/host/build/install/deploy.

## Guards/pins và offline

Image cache5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6; own-egress8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10; Cobalt commit a636575b09de1fc55d9b8cd98cac88f5f2f16b42/AGPL3/LICENSE/upstream giữ. yt-dlp2026.08.19/Requests2.34.2/urllib3-2.8.0/Brotli1.2.0/Undici6.24.1/FFmpeg5.1.9 khôngđổi. Actual1364deps/binaries bằng predecessor,42host/34source, runtimeSHAd712775bf3529124240611ccc57a4d179ae79106bea6aa58e575356b7921300c khớp offline/live. Host code/config/lock/image/native0 + diagnostics/fullpipeline0 gate, entry cònkiểm installedruntime và reservation exclusive trước nguồn.

Timeout10/10 vàretry0/redirect0/2metadataGET+conditional1MP4 giữ; metadata30s độc lập/8MiBresponse16MiBtotal, prepare180s/input250MiB/output200MiB/duration≤600s. Runtime512+96=608MiB, memoryswap=memory/CPU0,75+0,25/PIDs96+64, users1000/65534/rootfs/sourceRO/outputownRW/capdropALL/NNP/defaultseccomp/privateIPC/PID/noports/owninternal+outboundSSRFTLS giữ. Cookie anonymousRAM/noaccount/actualImpersonationfalse.

Offline1 network-none256MiB outer/runner/container0. Real publicHTTPAdapter.send và response construction; chỉ pool.urlopen giả lập phản hồi/lỗi códelay ngắn.10case connect/readtimeout, proxy/TLS/newconnection vàHTTP200/302/403/404/500 chứng minh mapping/status, timeout10/10,retries0, redirectfalse/preloadfalse,1send/0decoded; status302 bịguardreject,403/404/500 bịHTTPstatusguardreject. Poisonedpayload/cyclic/longchain, exact exception rethrow và UNKNOWN khôngleak kiểm thêm. Không tạo lỗi connecttimeout bằng Internet hoặc nới timeout để fixture chạy nhanh. Độ trễ giả0,003s kiểm timing, không là real socket10s timeout/nguồn. Fullfake extractor→downloader→parent worker0→synthetic MP4/decode/SHA, cáccap/hash/OSwatchdog vẫnđạt. Fixture không là MP4TikTok.

OfflineUTC09:47:19.924–09:48:07.399/VN16:47:19.924–16:48:07.399; own1container/network0 dọn0left UTC09:48:08.587. Mọi native command exit0.

## Một lượt nguồn và cause quan sát được

URL dài đã giao @nguye003/video/7692288554839313682, expected bodyID mới được Cobalt kiểm, khôngresolve shortlink. Hai human-review/successor mẫu1+2 và historical target hash vẫn gate, rawvisual cũ giữ.

| Chặng | Kết quả thực |
|---|---|
| Metadata |packetPASS/bodyID/video/duration486s;2GET200;1462+439983=441445byte;1,737966132s|
| Format |h264_540p_1544395/play-bitrate/H264AAC1024×576; metadatafilesize93936477byte|
| MP4 send |1GET; HTTP_RESPONSE/status200 tạiboundary;0,276052s; proxyConnect/originTLS/headerWaitUNKNOWN|
| Input |decoded93936477byte≤250MiB; khôngredirect/retry/fallback|
| Prepare |FAIL35,194486692s<180; YTDLP_OR_FILE_FAILURE/top exceptionUNKNOWN whitelist|
| Native |worker−9/SIGKILL parentcleanup; parent/container/runner/outer20; OOMfalse; runtimehashPASS|
| Acceptance |metadataAcceptedfalse/statusFAIL/fileFAIL_DISCARDED; khôngpacketPASS-only success|
| File/review |Không video.mp4/.part/.ytdl; không kết quả probe/decode packet, các phép này chưađượcchứngminh riêng; khôngSHAfile/visualreview|

Proven: send trảHTTP200 và input được đọc trong lượt này; currentfailure sauresponse trongprepare. Không chứng minh thao tác nào sauresponse lỗi hoặc rootcause10s cũ. UNKNOWN top exception là giới hạn deliberate exact whitelist, không log tên chưaduyệt. inspect_file cũ cóFFmpegtimeout30s; elapsed35,194s tương thích với giảthuyết này sautransfer nhưng chưa cóstage/exception đểchứngminh, khôngkếtluận decodeFAIL hoặc tựnới cap. HTTP200/đủinput chưa làtệpMP4/duration/decode/SHA/hình/tiếng/watermarkPASS. Sourcefile trongfailurecleanup khônggiữ lại, không trìnhbày synthetic MP4 làmfilemẫu3.

NativeUTC09:48:57.567–09:49:36.422/VN16:48:57.567–16:49:36.422; dọn exact own2containers/2networks,0left UTC09:49:40.173/VN16:49:40.174. Đãdừng/lượtnguồn budgethết, khôngHEAD/retry/fallback/resolve thêm. Lỗi10s historical raw/golden khôngsửa hoặc gộp thành outcome mới.

## Lệnh/bảo toàn/bước sau

~~~powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -Sample 3 -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage live -Sample 3 -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_send_diagnostics.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_send_diagnostics.ps1
~~~

Lệnh thực với quyền Dockerpipe cầnthiết, không nới guard. Không dùnglệnh đểrerun directory/nguồn đãđóng. Evidence docs/evidence/tiktok-cobalt-sample3-send-diagnostics-20261008/ cóbefore2440files/snapshots/provenance/APIreview/fixtures/native UTC-VN/receipt/runtime/guards/source result/cause/manifest. Successor chỉ4lab+AUDIT/PROGRESS cũ đổi; observer/test/verifier/handoff mới đúng lab. Giữ predecessor116manifest qua doc-only successor audit, raw/golden/verifier/history/archive/apps và human-review/video mẫu1+2. VerifierPASS là xácminh bằngchứngFAIL, không sourcevideoPASS.

Hai preflight của verifier mới giữ riêng: shell generation exit1 do quoting trước mọi ghi/test; -Capture đầu exit1 trước tạo manifest vì regex FAKE đã bắt nhầm chữ “fake” trong nhãn môi trường fixture. Sửa verifier mới chỉ dò các sentinel payload cụ thể, không sửa fixture/raw/source receipt hoặc verifier/golden lịch sử. Không chạy lại offline hoặc nguồn để xử lý lỗi công cụ này.

Tiếnđộ vẫn2/3; mẫu3chưađạt/shortlinkAPI E2E/no-buttonAPI E2E/TikTokmain/deploy chưađạt. Đềxuất nhiệm vụriêng đo từngoperation downloader/ffprobe/decode, xácminh API TimeoutExpired và whitelist mã antoàn, kiểmoffline media dài trongguard512MiB/CPU0,75 thay vìtăngtimeout đểthửmù. Không tựtriểnkhai diagnostics tiếp hoặc gọi nguồn mới sauFAIL.
