# Mẫu3 — prepare operation diagnostics, 08/10/2026

**Offline short/486s/fullpipeline đạt. Nguồn mới dừng ngaymetadata ReadTimeout, chưa chạyprepare.** Mẫu1+2 giữ nghiệmthu2/3; mẫu3chưa cótệpđạt. Chưachứngminh fixeddecode30 false rejection nên khôngnới cap/CLI. Causeprepare lịch sử vẫnUNKNOWN.

## API và thay đổi lab

Đọc AGENTS/PLAN/STRUCTURE/AUDIT/PROGRESS/send-diagnosticshandoff. Xác minh source [Python3.11.2 subprocess](https://github.com/python/cpython/blob/v3.11.2/Lib/subprocess.py) và [FFmpeg5.1.9 CLI](https://github.com/FFmpeg/FFmpeg/blob/n5.1.9/doc/ffmpeg.texi). Public Popen/communicate(timeout), kill rồicommunicate/reap trảreturncode thật; TimeoutExpired cócmd/output/timeout nhưngchỉtype+numerictimeout đượcxuất. Không chépprivatehelper hoặcviết lạiHTTP/parser/decoder; thưviện đã cóthi hànhmọioperation. Tựviết glue trace vìharnessWED SNAP cầnfixedoperationcode/sanitizedlifecycle/deadline.

prepare_operations.py lưu chỉoperation/event/code/elapsed/timeout/returncode vào ownJSONL;operation6nhãn fixed vàmax32events/instance. Unknownerror khôngstr/repr/stack; RuntimeError chỉdùngargstring nếuđúngwhitelistconstant. subprocess.TimeoutExpired tườngminh; actual−9 saukill/reap, khôngsuyerrno hoặcchildexit từmessage. Candidate.prepare instrumentDOWNLOADER→OUTPUT_CHECK→FFPROBE→CONTRACT→DECODE→HASH. Terminalrecords vào packet, BEGIN/END/ERROR đủ trongJSONL; khôngcmd/output/URL/token/cookie/header. Actualrc chỉcho subprocess; syncoperationrcnull khônggiả0. candidate_file táchvalidatecontract với cùngbrands/H264+audio/duration/tolerance; FFprobe10/decode30 giữ, fullFFmpeg -v error -i file -f null - giữ, không-t/skip/crop/blur/transcode nguồn. Timeout clampmin(cap,remainingprepare180). HTTP10/10,metadata30, bytecaps8/16MiB+250/200MiB,duration600 vàparentOS deadline giữ.

Runner namespace/evidence mới; benchmark stage mạngnone vàoffline suite tại512MiB/CPU0,75 theo yêu cầu. Benchmark outer300s chỉ làbudget của chuỗi phép đo offline riêng, không tăngprepare180; mọi individualprepare/nativecaps giữ. Livegate fullshortsuite+operationfixture+long486pipeline0/runtimehash vàhai humanreview/targethash cũ. fixtureworker chỉ thêm flaglongduration486 tổnghợp, không ảnhhưởngsourcebackend. Khôngbuild/install/dependency/host/main/UI/API/DB/lifecycle/deploy.

Cachedimage5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6; own-egress8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10. Cobaltcommit a636575b09de1fc55d9b8cd98cac88f5f2f16b42/AGPL3/LICENSE/upstream/yt-dlp2026.08.19/Requests2.34.2/urllib3-2.8.0/FFmpeg5.1.9 giữ. Actual1364dependency-binary files bằngpredecessor;45host/37source, finalruntimeSHA680ccef483f15b6744dc41d36eafbbb896ca6c13691fadb290f9469911797ca4 benchmark3/offline/live cùngnhau. Bench1/2mãđo trướcgatesuite cuối khácfingerprint, raw/inventory giữ, khôngdùngreceipt cũ; measure25-code giữ đúngsnapshot banđầu.

## Offline đo được và quyết địnhcap

Media seedH264AAC2s/testsrc2+sine,1024×576/25hoặc30fps,presetmediumthreads1; FFmpegstream_loop242/copy tạo486s (chỉtệp synthetic). Duration/containeraudio/video đượcffprobe vàcontract kiểm, sourcefile không transcode. Seedgeneration CLI dànhfixture, decoderCLI khôngđổi.

| Phép đo dưới512MiB/CPU0,75/network-none | Kết quả |
|---|---|
| Benchmark1 short25fps |probe/contract/decodePASS;decode0,193599s/rc0|
| Benchmark1 486s25fps |decode26,087393s,cap30/rc0;98291637byte|
| Benchmark1 samefile completion |full26,612378s,measurementcap120/rc0|
| Benchmark2 486s30fps |decode29,374628s,cap30/rc0;106286879byte|
| Benchmark2 samefile completion |full29,976818s,measurementcap120/rc0|
| Benchmark3 fulllongpipeline |realextractor/nativechallenge/Cobaltbodycheck/downloader/parent/filecontract;worker0/parent0;prepare31,095075s|
| Longpipelineoperations |download1,963541/output0,020340/probe0,085233/contract0,025999/decode28,065747/hash0,868900s|
| Longfile |MP4/isom/H264AAC/duration486/decodePASS;SHAinput/outputf587381808e3f189ee0125e31a040d17d9f2c4100dde9738e169c93f7c3592bb|

**Fixed30 false rejection chưađượcchứngminh trong cácfileđãđo:** tất cảlegacycap30PASS, mặc dù30fps gầncap. Khôngsuyđủcho mọiFPS/complexityvideo hoặccausepreparemẫu3 thật. FPS/profiledecode thực lịch sử chưaghi. Measurementcap120 củađốichứng làofflineexperiment only, khôngáp dụng vào candidate. Decodecap30/probe10/HTTP10–10/tổng180 giữ, khôngsửa theođoán.

Longpipeline fakeHTTP2metadata+1MP4input/output106286879byte trongcaps, actualnormalextractor/downloader/parent/fileinspector chạy, khôngmocktheseoperations. SHAinput/output bằngnhau, sourceRequests0. Cácshortpipeline/findings/caps/remainingdeadline/OSwatchdog/HTTPdiagnostics cùngđạt; operationfixtures actualsubprocess0/20/−9 vàTimeoutExpired/cyclic/poison/schemachecks. Khôngtính MP4fixture làvideoTikTok, khôngvisualreviewwatermark củafixture.

NativeUTC/VN ngày08/10:

| Lượt | UTC | VN | Exit/cleanup |
|---|---|---|---|
| benchmark1 |11:01:49.426–11:02:50.594|18:01:49.426–18:02:50.594|0/own1container0left|
| benchmark2 |11:04:12.837–11:05:17.627|18:04:12.837–18:05:17.627|0/own1container0left|
| benchmark3 |11:07:15.103–11:08:22.704|18:07:15.103–18:08:22.704|0/own1container0left|
| offline1 final |11:08:59.112–11:09:41.759|18:08:59.112–18:09:41.759|0/own1container0left|

Khôngruntimeoverlap trênRAM8GB. NguồnSSRFTLS khôngmởtrongbenchmark. Guardsrootfs/sourceRO/outownRW/user1000/capdropALL/NNP/defaultseccomp/privateIPC/PID/noports/memoryswap=512/CPU0,75/PIDs96/mounts/labels giữ, networknone. Sourceegress96MiB/user65534/CPU0,25/PIDs64, tổng608MiB/ownprivateinternal+outboundgiữ.

## Một lượt nguồn và giới hạncause

Giảthuyếtđểkiểm:35,194s prepare cũ sau input có thểDECODEtimeout30 hoặcoperation khác; safe6operationtrace phânbiệt được nếuprepare chạy. Offline đúngmãđạt nên mở đúngmộtanalyze URL dài @nguye003/video/7692288554839313682/expectedID theo nhiệm vụ, khôngshortlink/resolve.

Nhưng metadataGET1 tạiHTTPAdapter.send FAILREAD_TIMEOUT10,015407s/classes requests.ReadTimeout/urllib3.ReadTimeoutError/builtins.TimeoutError. StatusUNKNOWN/body0, khôngbodyIDmới đượcxácminh. PrepareNOT_RUN/MP4GET0/sourceoperationtracechưacó, file/probe/decode/SHA/reviewNOT_RUN. Parent/container/runner/outer20,worker−9/SIGKILLparentcleanup, runtimehashPASS. READ_TIMEOUT khôngtách đượcCONNECT/TLS/headerwait; causeprepare cũ vàtrue-sourcefalse-rejection vẫnUNKNOWN. Khôngđồngnhấtnativeworker−9 vớiDECODEtimeout chưachạy.

NativeUTC11:10:04.172–11:10:15.696/VN18:10:04.172–18:10:15.696; exact own2containers/2networks dọn0left UTC11:10:19.513/VN18:10:19.513. Khôngretry/HEAD/fallback/resolve thêm. Mẫu1+2vẫnhumanaccepted2/3; mẫu3 chưađạt, khôngtệpđểtrìnhbàytoànclip/noTikTokwatermark, shortlink/no-buttonAPI E2E/TikTokmain/deploy chưađạt.

## Lệnh/bằngchứng/bàn giao

~~~powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage benchmark -Sample 3 -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage benchmark -Sample 3 -FixtureAttempt 2
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage benchmark -Sample 3 -FixtureAttempt 3
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -Sample 3 -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage live -Sample 3 -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_prepare_operations.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_prepare_operations.ps1
~~~

Lệnh làhồsơ thựcchạy, khônghướngdẫnretry hoặcghiđèdirectory. QuyềnDockerpipe ngoàifilesystemsandboxkhôngnới guards. Đọcnhầm successorpath cótrongtoolread banđầu nhưng đãđọc đúng tiktok-cobalt-send-diagnostics-audit path; không mutation/source từlỗiđườngdẫn này.

Evidence docs/evidence/tiktok-cobalt-prepare-operations-20261008/ lưubefore2496files/snapshots/measure25-code/provenance/APIhypothesis/3benchmarks/full486fixture/shortsuite/operationJSONL/nativeUTC-VN/receipts/runtime/guards/sourcemetadataFAIL/cause/manifest successor. Old7lab+AUDIT/PROGRESS đổiđúngphạmvi; trace/benchmark/tests/verifier/handoff mớiđúnglab. Predecessor123manifest nối docs-onlyaudit; raw/golden/verifiers/history/archives/production/humanreviews/videos mẫu1+2 giữ hash. VerifierPASS làevidenceverification chứkhôngsourcevideoPASS.

Budgetnguồn đãdùng hết; dừng. Chưađủbằngchứngđểđổi subdeadline theofalse-rejection hoặcnghiệmthu3/3. Bước tiếp chỉđềxuất nhiệm vụriêng khi nguồntrảmetadata được; giữoperationtraceđãquaoffline, khôngnới30/180/HTTPguards hoặcmua mạng/thaybackend đểthửmù. Tệp thậtđạt vềsau vẫnphảifullcontract/SHA vàreviewtoànclip/hình/tiếng/watermark trước3/3.
