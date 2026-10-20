# Controlled read20 — 09/10/2026

**Read20 forwarding/absolute deadline offline PASS; gate486s FAIL ở decode30. Nguồn chưa chạy.** Giữ mẫu1+2 nghiệmthu2/3, chưa cókết quảread20 trênTikTok. Không tăngdecodecap hoặcbypasslonggate đểthửnguồn.

## API và profile

Đọc AGENTS/PLAN/STRUCTURE/AUDIT/PROGRESS/prepare-operations handoff. Xác minh [Requests2.34.2 HTTPAdapter.send](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py) nhận object [urllib3-2.8.0 Timeout](https://github.com/urllib3/urllib3/blob/2.8.0/src/urllib3/util/timeout.py), total/read/connect dùnggiới hạnngắn hơn vàread giảm theoelapsedconnect. API này cósẵn trongimage, khôngthêmdependency hoặcviếttransport mới.

Budget.http_timeout tạo Timeout(total=phaseRemaining,connect=min(10,remaining),read=min(20,remaining)) ngaytrướcAdapter.send; phase hếtgiờreject trướcsend. Log effectiveTimeout chỉnumericconnectSeconds/readCeilingSeconds/totalSeconds/phaseRemainingSeconds, không objectrepr/stringcmd/URL/header/token/cookie. Đây làlimits chuyểnxuốngthưviện, khôngđồngnhất readceiling20 vớisocketreadactual sauconnect. Body nhiều read hoặcDNS khôngđược đảm bảo wallclock bởiTimeout library; existingparentOSmetadata30/prepare180 vàstreamingdeadline/capchecks giữ. ElapsedAdapter.send gồm nhiều chặng; chưađo riêngproxy/TLS/headerwait nênUNKNOWN. Mộtresponse nhanh/chậm hoặcPASS tươnglai khôngchứngminhread20 đãsửa rootcause lịch sử.

Chỉsửa runnernamespace/gate, yt_candidate bridgeTimeout, test_send_diagnostics expectation, test_all vàNOTICE; thêm test_read20/read20_blocking_worker. Giữmetadata budget2GET/redirect0/8MiBresponse16MiBtotal; conditional1MP4/redirect0/input250MiB/output200MiB/prepare180; retry0/HEAD0/fallback0. Decode30/probe10/nativeoperationtrace/contract/SHA/full decode/guard/backend/yt-dlp/main giữ. Existingparameter socket_timeout10 của yt-dlp khôngđổi; actualHTTP đi qua override urlopen với Timeout10/20 mới, khôngtransportfallback.

Imagecache5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6, egresspin8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10, Cobaltcommit/AGPL3/upstream/licenses/yt-dlp2026.08.19/Requests2.34.2/urllib3-2.8.0/FFmpeg5.1.9 giữ. Actual1364dependency-binary bằngpredecessor; final47host/39source, runtimeSHA7cb5bf96049e4c06ba56b13d4723b5697ad77686a292dbc3d88b07d83ad90fa2 khớp benchmark3/offline2. Operation/byte/SSRF/TLS/user/rootfs/caps/NNP/defaultseccomp/privateIPC/PID/mount/resourceguards giữ; khôngproduction/install/build/deploy.

## Offline timeout và absolute deadlines

Offline1 network-none512MiB/CPU0,75 exit0. RealHTTPAdapter/urllib3 vớifakepool chứngminhforwarding/dynamicread/subtractedconnect/redirectfalse/preloadfalse/retry0; deadlinefull30/180 vàremaining0,05s, expiredrequestreject0send. Fullshortpipeline/relatedcaps/hash/operationtests qua. Sau đọc testcase, metadatachildfixture0,15s cóthểchếttrongstartup, chưađủchứngminh adapter đãblock; giữraw/receipt/code, khôngdùng mởnguồn.

Offline2 đúngmã cuối bổsung adapter-entered marker trướcsleep3. Metadataexternalfixture1,5s vàprepare0,15s cómarkertrue, actualchild−9/parent20; production30/180 khôngđổi. Hai adaptercốýbỏqualibrarytimeout chứngminhparentindependent. Forwardingfullphase connect10/readceiling20, near-expiry cảconnect/readclamp≤remaining; total truyềnđúng xuốngrealpool, Timeout.start_connect/read_timeout publicAPI kiểmreadgiảm. Expiredbefore-send0calls. Fullshortpipeline metadata2GETfake/prepare1GETfake/worker0/MP4/decode/SHAinput-output cùngPASS; OSwatchdog/caps/native0/20/−9/poison/schema/hashtests giữ. FixturekhôngTikTok hoặcsourcewatermarkPASS.

Recordread20-fixtures.json ghi7cases/fullforwarding/expired/absolute deadline; markerxácnhận gửi tạiadapter chohai caseblocked, khôngsuy từstartup. Numericlimitsgầnhếtphase đượcghi lại, exampleeffectiveRemaining≈0,04s; khônglogfakeURI/cookie. Offline1tested-code giữ phiênbản test trướcmarker, khôngsửa golden hoặcreceipt cũ đểépPASS.

## Gate long mới và cause

Gatehiệncó yêu cầu long486pipelinePASS đúnghash trướcsource. Vì HTTPbridge/testcode đổi, kiểm đúngmã mới bằngbenchmark3 network-none512MiB/CPU0,75, seed2s→loop-copy486s/30fps/H264AAC1024×576. Source0/HTTP0 ởbenchmarkinspector.

| Operation trênfixturelong | Kết quả mới |
|---|---|
| FFprobe |END/OK/returncode0/0,087855s/timeout10|
| Contract |END/OK/0,023445s; MP4/H264AAC/duration486 đạt|
| Decode |ERROR/SUBPROCESS_TIMEOUT/subprocess.TimeoutExpired/30,069384s/timeout30/actualreturncode−9|
| Benchmark native/container/runner/outer |exit1; notOOM, owncleanup0|
| Longintegration |Khôngđạt/khôngtạo packetPASS, chưađược dùng làmgate|

Currentinput106286879byte, SHAf587381808e3f189ee0125e31a040d17d9f2c4100dde9738e169c93f7c3592bb trùng exactfile trongbenchmark3 operations08/10 đãfull-decodePASS28,065747s/worker0/source-input-outputSHA bằngnhau. Đây làbằngchứng threshold30 cóthểrejectcùngfileknown-valid khi executiontime đổi; khôngcóHTTPread ởphépđo đểđổcho read20. Chưađo currentcompletion sauthirtysecondskill; chưachứngminh causeTikToksource/prepare35s cũ. Khônghồi tốNOT_DEMONSTRATED củaraw08/10; outcome mới làsuccessor.

**Giữdecode30theochỉthịhiệnhành:** khôngtăngcap/đổiCLI/skipfull decode/rerunlongđểlấyPASS. Dù timeout-forwarding/suitecuối đạt, toànlonggatekhôngđạt. KhôngStage live/TikTokGET/analyze/HEAD/resolve/fallback, khôngcopyoldlongintegration hoặcoldreceipt vào namespace mới. source-not-run.json ghi0analyze/0metadataGET/0MP4GET. Input đãgiao expected7692288554839313682 khôngđượcthử mới. Metadata/bodyID/file/visual/source-read20outcomeNOT_RUN, historicalcauses/CONNECT-TLS-header substagesUNKNOWN. Haihumanreviews trước giữ, tiếnđộ2/3/no-button-shortlinkAPI E2E/main/deploy chưađạt.

## Thời gian, exits và lệnh

UTC08/10 tươngứngVN09/10/2026:

| Lượt | UTC | VN | Exit/cleanup |
|---|---|---|---|
| offline1 |17:12:50.477–17:13:37.980|00:12:50.477–00:13:37.980|0/own1container0left|
| benchmark3 |17:14:58.753–17:15:34.874|00:14:58.753–00:15:34.874|1/own1container0left|
| offline2 final |17:25:47.218–17:26:35.357|00:25:47.218–00:26:35.357|0/own1container0left|

Ba lượt tuần tự/RAM8GB, networknone/512MiB/memoryswap512/CPU0,75/PIDs96/user1000/rootfsRO/sourceRO/outputownRW/privateIPC/PID/capdropALL/NNP/defaultseccomp/noports vàexactCmd/mount/labels/IDs kiểmtrướcstart. Khôngsourceegress/network tạo; mỗicontainer own dọn0left, khôngtouchstackmain.

~~~powershell
cd 'D:\WED SNAP'
$pwshCobalt='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -Sample 3 -FixtureAttempt 1
# Bổ sung marker để absolute test chứngminh adapter đãchạy:
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage benchmark -Sample 3 -FixtureAttempt 3
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -Sample 3 -FixtureAttempt 2
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_read20.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_read20.ps1
~~~

Đây làlệnhthực, khônghướngdẫnretry/overwrite. Không cólệnhlive nguồn. EscalationDockerpipe khôngnới containerguards. APIreview quaofficialrepository khônglàrequestTikTok.

## Evidence và tiếp theo

docs/evidence/tiktok-cobalt-read20-20261009/ lưu baseline2595files/snapshots/provenance/APIreview/offline1+2/testmarkers/longFAIL/operationJSONL/receipts/inventory/guards/exits/cause/source-not-run/successor/manifest. Source hashes/goldensnapshot cũ vẫnkhớp; copyingbefore hoàn tấtmuộn sauedit nêncaptured-after-edit được giữ riêng. recover-before.ps1 undo exact5edits vào ownbeforecopies vàso SHA/bytes vớifrozengolden; before-recovery.json xácnhậnPASS. Lượt recoveryfirstexit1 doextra blankNOTICE bịhashguardreject, code/rawattempt1 giữ rồirepairblank ởrecovery mới; khôngsửa historicalgolden/baseline/sourcefixture đểépPASS. Mộtread-onlycomparisonPowerShell syntaxerror đượcgiữ preflight; khôngmutation từlỗi đó.

Chỉ5lab+AUDIT/PROGRESS cũ đổi; verifier/golden/raw/history/apps/video/humanreview cũ giữ. Verifiermới kiểmđúnglongFAIL/sourceNOT_RUN, khôngsửa verifier169 lịch sử vìmãcodeđổi. Bước saucầnnhiệm vụriêng nếuchấp thuận điều chỉnhdecode subdeadline hoặcCLI chínhthức vớiknown-validfile trongremainingprepare180/full decode/caps512; kiểmoffline+fullpipelineđúnghash rồimớixétlượtnguồn. Khôngtựthaydecode30/main/deploy hoặcgọiTikTok khi gateFAIL. Read20chưacóoutcome trênnguồn vàkhôngđượccoi đãsửa nguyênnhânREAD_TIMEOUT lịch sử.
