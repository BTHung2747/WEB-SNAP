# F-DECODE-BUDGET — 09/10/2026

**Decodebudget sửa và kiểmoffline PASS. Lượt nguồn duy nhất FAIL ở DOWNLOADER/HTTP READ_TIMEOUT, chưa chạydecode thật.** Mẫu1+2 giữ2/3, mẫu3 chưa cótệpđạt đểreview; khôngTikTokmain/deploy.

## Sửa đúngfinding, giữAPI/guard

Đọc AGENTS/PLAN/STRUCTURE/AUDIT/PROGRESS/read20handoff và audit175successor. [Python3.11.2 subprocess](https://github.com/python/cpython/blob/v3.11.2/Lib/subprocess.py) và [FFmpeg5.1.9 CLI](https://github.com/FFmpeg/FFmpeg/blob/n5.1.9/doc/ffmpeg.texi) đượcxácminh đúngbản; publicOperations.timeout/native/Popen/communicate(timeout)/kill/reap đãcó, khôngchéphelper/viếtdecoder/transport.

candidate_file.py bỏfixed30, thayDECODE_RESERVE_SECONDS10; Operations.native(DECODE,existingfullCLI,180,reserve10) tínhmin(180,phaseDeadline−now−10). Ngân sáchkhôngđủ phảierrorbeforePopen; Operations.native thêmfixedBEGIN/ERROR/PREPARE_DEADLINE/timeout0/returncodenull chotrườnghợpnày, khôngspawn hoặcghi giảrc. Native timeout thực vàrc0/20/−9 saukill/reap giữ. Khôngcmd/output/message/URL/header/token/cookie/stack trongdiagnostics; subprocess.TimeoutExpiredwhitelist giữ. FullCLI ffmpeg -v error -i file -f null - vàcodec/container/duration/cappedtolerance khôngđổi, không-t/skip/crop/blur/transcode nguồn.

Totalprepare180 vàindependentparent deadline giữ;10sreserve dànhhash/exit/cleanup trongbudget, khôngcộngvào180. Probe10/metada30/HTTPconnect≤10/read≤20/phaseclamp/2metadataGET+conditional1MP4/redirect0/retry0/input250MiB/output200MiB/duration600 giữ. Runner chỉđổins/gatemớivàbenchmarkcommand; preseedbenchmarkchỉchấpnhận đúngmộtfileknown-valid vớiSHA đãghim, córaw/receipt rồi thìrefuserepeat. Livegate cầnfreshdecodefixture/longpipeline/runtimehash vàhaihumanreviews cũ. Main/UI/API/DB/lifecycle/host/Docker/WSL/seccomp/build/dependency khôngsửa.

Imagecache5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6; own-egress8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10, Cobaltcommit/AGPL3/upstream/libs giữ. Actual1364installeddependency/binary bằngpredecessor,49host/41source/runtimeSHA027dd72712ff94eef1e9921e58fb059432aac9fed86a41f63ee3a4abe0b290d1 khớp benchmark/offline/live. Sourceguard512MiB/CPU0,75/PIDs96/user1000+egress96MiB/CPU0,25/PIDs64/user65534,total608MiB,memswap=memory/rootfsRO/sourceRO/outownRW/privateIPC/PID/capdropALL/NNP/defaultseccomp/noports/privateinternal+ownoutboundSSRFTLS giữ. CookieanonymousRAM/noaccount/actualImpersonationfalse.

## Known-valid486s và fullpipeline thực

Saochép nguyênbyte từ docs/evidence/tiktok-cobalt-read20-20261009/benchmark-3/fixture-input.mp4 vàoevidence mới, khôngregenerate/tái mãhóa hoặcđổi sourceSHA. Known-valid106286879byte, SHA **f587381808e3f189ee0125e31a040d17d9f2c4100dde9738e169c93f7c3592bb** verifiedtrước/sau; oldrawfilekhôngsửa.

Mộtinspection vàmộtfullfakepipeline, khôngloopđếnPASS:

| Phép đo dướinetwork-none512MiB/CPU0,75 | Kết quả mới |
|---|---|
| Known-validffprobe/contract |rc0/0,653021s; contract0,022525s/OK|
| Known-validfull decode |32,004536s/rc0; effectivetimeout169,305004s, reserve10|
| Full486pipeline |worker0/parent0;prepare35,93876657s<180|
| Pipelineoperations |downloader1,835759/output0,032815/probe0,133829/contract0,024649/decode33,116003/hash0,720750s|
| Pipelinedecodebudget |effective167,911608s/rc0; phase remainingminus10, fullCLIunchanged|
| Pipelinefile |MP4/isom/H264AAC/duration486/decodePASS; input/output106286879byte; original/outputSHAđúngf587…592bb|

Hai decode>30 nhưng≤remainingbudget xácminh F-DECODE-BUDGET sửa tronglab. Đây làfixture tổnghợp known-valid, khôngTikToksourcePASS hoặcwatermarkreview. Fullfake adapter metadata2GET/challenge/cookieRAM+1MP4 đi qua actualextractor/CobaltRAMbody/downloader/parent/nativefilecontract/hash, khôngmockcácthao tác đó. Bằngchứng khônghồi tốcauseTikTok35s cũ.

Suiteoffline1 đúngmã cuối cùng0. Exhaustedremaining−1/0/5/10s: Popen0calls, fixedDECODE/PREPARE_DEADLINE/returncodenull. Native testschildexit0/20/selfSIGKILL−9/timeout−9 reaped, timeout=remaining−10; khôngoutput/message leak. Existingactualparentmetadata/prepare PASS→exit20/hang kiểmcleanupownednew video/.part, preexisting.ytdl giữ; sixcasefixtures trongfinding-fixtures.json. Read20forwarding/adapter-enteredabsolute deadlines/caps/hash/schema/shortfullpipeline/SHA đồngđạt. Giữfull decode vàkhôngnớiCPU/RAM.

## Lượt nguồn duy nhất — dừngđúngoperation

InputURL dài @nguye003/video/7692288554839313682/expectedID giao, khôngshortlink/HEAD/resolve. Metadata packetPASS, Cobalt từRAM xácminhbodyID/video/duration486s, chọnh264_540p_1544395/play-bitrate/H264AAC1024×576; khôngdownloadAddrwatermarked.

| Chặng nguồn | Kết quả thực |
|---|---|
| Metadata |2GET200, decoded1462+432931=434393byte≤8/16MiB;1,611752946s<30|
| Forwardedtimeout metadata |connect10/readceiling20,totalremaining29,954616 và29,599229s|
| MP4 attempt |conditional1GET; connect10/readceiling20,totalremaining179,982160s|
| Adapterfailure |READ_TIMEOUT/classesRequests.ReadTimeout/urllib3.ReadTimeoutError/TimeoutError10,009744s; statusUNKNOWN/decoded0|
| Operation |DOWNLOADERERROR/UNKNOWN_ERROR10,027542s; yt-dlpwrapperUnavailableVideoError; lowerHTTPREAD_TIMEOUT biết|
| Overallprepare |FAIL10,039227761s<180; OUTPUT_CHECK/probe/contract/decode/hash nguồnNOT_RUN|
| Native |worker−9/SIGKILLparentcleanup; parent/container/runner/outer20, runtimehashPASS; metadataAcceptedfalse|
| File/review |no video.mp4/.part/.ytdl; file/probe/decode/SHA/visual/audio/watermarkNOT_RUN|

Metadata packetPASS khôngđược nângacceptance khi worker khôngexit0.−9 làcleanupownworker sauFAIL, khôngDECODEnativekill vìdecode chưachạy. Noobservedstatus/header/body, nênkhôngkếtluận403/404/deleted/expiredURL. Elapsed10s dùreadceiling20 khôngtách đượcproxy/CONNECT/TLS/headerwait; urllib3 cóthểReadTimeout ởsetup, cácchặngvẫnUNKNOWN. KhôngquylỗiDOWNLOADER choF-DECODE-BUDGET đãsửa hoặcclaimread20 đãsửa cause lịch sử. Khôngretry/HEAD/fallback/resolve/ngẫu nhiêntuningTCP/TLS/backend.

## ActualUTC/VN, lệnh và bàn giao

UTC08/10→VN09/10/2026:

| Lượt | UTC | VN | Actualexit/cleanup |
|---|---|---|---|
| known-valid/full486benchmark |17:56:17.967–17:57:31.582|00:56:17.967–00:57:31.582|0/own1container0left/network0|
| offline1final |17:58:38.994–17:59:26.691|00:58:38.994–00:59:26.691|0/own1container0left/network0|
| source |18:01:24.687–18:01:37.801|01:01:24.687–01:01:37.801|20/own2containers+2networks0left|

Sourcecleanup hoàn tấtUTC18:01:41.376/VN01:01:41.376. Runs tuần tự/RAM8GB, guardinspect trướcstart vàremoveIDs/runlabelsownership; khôngprune/downstackmain. Benchmarkouter300 chỉharnesshai independentphase180, khôngtăngsourceprepare. Khôngrerunfixture/nguồn đếnPASS.

~~~powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage benchmark -Sample 3 -FixtureAttempt 3
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -Sample 3 -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage live -Sample 3 -FixtureAttempt 1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_decode_budget.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_decode_budget.ps1
~~~

Đây làlệnh thực, khônghướngdẫnrerequest hoặcoverwrite. Evidence docs/evidence/tiktok-cobalt-decode-budget-20261009/ cóbefore2696files/exactsnapshots/known-valid-copy/provenance/APIpolicy/benchmark/suite/nativeerrors+ownership/exitsUTC-VN/receipts/runtime/guards/sourceFAIL/cause/successor/manifest. Beforecopy hoàn tất trướcedit, hashes/bytes giữ. Chỉ5lab+AUDIT/PROGRESS cũ đổi; tests/verifier/handoff mớilab. Predecessor175manifest qua docs-only audit; raw/golden/verifier/history/apps/video/humanreviews cũ giữhash. VerifierPASS xácminh đúngsourceFAIL, khôngvideoPASS.

F-DECODE-BUDGET đạtphạmvi sửaoffline; nguồnfailkhác, tổngnghiệmthu2/3. Budgetnguồn đãdùng; dừng. Nếu tiếp tục cần nhiệmvụriêng cho READ_TIMEOUT ởDOWNLOADER, giữunknownsubstage thayvìđổiTLS/proxy/backend hoặcretrymù. TikTokmain/no-button-shortlinkAPI E2E/deploy chưađạt. Tệp thậtđạt vềsau vẫnphải fullcontract/SHA vàfullclip hình/tiếng/watermark review trước3/3; khôngxóa logotácgiả.
