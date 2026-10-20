# Tiếp renderer37 — 07/10/2026: đã rõ lỗi chroot, dừng ở bảo vệ đã ghim

**F-R37-LOG và Requested/observed đã sửa, chờ audit. Một launch offline mới vẫn FAIL: Chromium kết thúc bằng SIGTRAP sau lỗi sandbox chroot trước zygote.** Không có thay bảo vệ được áp dụng. Lượt2 NOT_RUN vì không có fix đã chứng minh giữ nguyên profile; byte/deadline/browsermetadata/file/visual vẫnNOT_RUN. TikTok0/1navigation vàdownload0. Image/build cũ giữ nghiệm thu, không rebuild/install/pull hoặc mainapply.

## 1. Kế thừa và thư viện

Đã đọc AGENTS/PLAN/PROGRESS/TIKTOK_RENDERER_HANDOFF và đầy đủ kết luận/chỉ thị tiếp renderer37. Before1.848file có SHA/bytes; copies2tools+4docs. Renderer149manifestSHA `8e902b964cb65e6d967bf575ff39725a2091db3471885adfbef243df255659c3`/selfmetadata giữ;148entries ngoài liveAUDIT khớp trước sửa. ExactAUDIT mới từaudit được ghi `predecessor.json`; không sửa historicalmanifest/verifier/raw đểPASS.

Scope chỉ sửa `renderer_capability.js`/`run_renderer_capability.ps1`, thêm loggingglue/evidence/verifier/handoff mới và4docs được giao. Giữimage cached `sha256:e3e776372b598eb8eaf57dea5ce293f79a1c834e6e92dce9e6b9bb9a2bf2baf9`, Playwright1.63.0/Node22.22.3/yt-dlp2026.08.19 vàseccompSHA `cc3e61cabda6bbc1e53e54d27ba4d55a9d3be829b6dd1a596f4a7b31b1cc7849`. Production/base/egress/lifecycle/code/data giữ; không sửaprofile pinned.

Ưu tiên APIs đã có. Nguồn Playwright1.63.0 trong package SRI đã khóa cho thấy launcher gọi `child_process.spawn` rồi ghi exitCode/signal. [Node22.22.3 ChildProcess](https://nodejs.org/download/release/v22.22.3/docs/api/child_process.html) cung cấp stdout/stderr và events exit/close; dùng observer các events này, ủy quyền spawn nguyên args/options, không đổi browser/transport/sandbox. Đăng ký trước Playwrightimport để lấy process thật kể cả launchAPIthrow; không giả exit30 là browserexit. Bật debuglogger `DEBUG=pw:browser` có sẵn. Không dùng loggerAPI deprecated làm nguồnstderr duy nhất, không thêm dependency hay viết parserHTTP/TikTok mới.

## 2. Đóng F-R37-LOG và fields

- Chromiumstdout/stderr/launchError giữ toàn bộ tới1MiB; vượt ngưỡng thì giữhead+tail và báo bytesReceived/retainedBytes/sanitizedBytes/truncated/retention. URLuserinfo/query/fragment, tokenpairs vàheaders Cookie/Authorization đượcsanitize trước lưu. Rawcũ1200characters không đổi/hồi tố.
- NativeDockerCLI stdout/stderr tách riêng, full hoặc head+tail cómetadata; deadline ngoài15s choinspect/create/state/rm/enumerate và35s chostart-a, còncommandtrongcontainer `timeout --signal=KILL 30s node…`. TimeoutCLI không làPASScleanup; finally kiểmownidentity vàrecoversownrunID nếucreate xảy ra một phần.
- Context/TLS chuyển thành `requested` và `observed`: browserLaunch/contextCreated/pageCreated/CDP false khi bước đó chưa đạt; cookiecountnull, TLSconfigurationNOT_RUN, TLSHandshakeNOT_RUN_NETWORK_NONE. Không đo TLS quaabout:blank hoặc suy từ option đã cấp.
-3logfixture nhỏ chạy ngay trong lượt1: fullsmallerror, head/tail giữfatal cuối, redaction dummysecrets. PASS, khôngsource/khôngbrowserlaunch thứhai. Không rerun19–37.4-R hoặc harnessbacklog.

Một lỗi wrapperCLI phát sinh trước Docker do Get-Command trả hai executablepaths; ProcessStartInfo.FileName bị nối. Giữ rawfolder `harness-fail-before-launch`, source trước sửa vàactualexit1 trongharness-failure. Sửa chọn cụ thểdocker.exe/firstapplication; lúc này **0browserlaunch**, không đếm lỗi hostwrapper là lượtChromium hay lỗi nguồn.

## 3. Lượt offline thật và cause đo được

Lượt1 chạy đúngcachedimage, networknone, UID1000:1000, seccompfile đãghim vàactualpayload sođúng, rootfs/sourceRO, privatePID/privateIPC/shm128MiB, capdropALL/no-capadd/nonprivileged/no-new-privileges. Memory/swap928MiB/1CPU/PIDs256. Khôngports/main.env/mainmount/DB/profile/account/cookies/stealth/solver. Guard trước start vàfullinspect ở `attempt-1/actual-guard.json`.

| Quan sát | Giá trị thực |
|---|---|
| Node scriptUTC/VN |11:04:47.564–11:04:48.191 /18:04:47.564–18:04:48.191;~0.627s |
| Chromiumprocess |PID20 trongprivatecontainer; exit/close events đều quan sát được; exitCode=null, **signal=SIGTRAP** |
| Chromiumstdout |0byte, full, truncatedfalse |
| Chromiumstderr |181byte, full, truncatedfalse |
| Launcherror stack |4.449byte, full, truncatedfalse; có launchargv/calllog/stderr/processsignal |
| Script/container/runner |actualexit30; khácsignal củaChromium, không làmetadataFAIL |
| Cgroup |memory.peak405.213.184byte≈386.44MiB; memory.events max/oom/oom_kill/oom_group_kill0; pids.events max0; pids.current13 lúc lấy, không làpeakPIDs |
| Context/CDP/TLS |Chưa tạo context/page/CDP; TLSconfiguration/handshakeNOT_RUN; nguồn0 |
| Cleanup |inspectexactownID/lab/run-label trước rm; own-left exit0/rỗng,0resourcesleft |

Stderr thực:

```text
Check failed: sys_chroot("/proc/self/fdinfo/") == 0
FATAL:content/browser/zygote_host/zygote_host_impl_linux.cc:240 Failed to receive hello message from zygote
```

Đối chiếu actualHostConfig/profilefile: defaultAction `SCMP_ACT_ERRNO`; rule duy nhất cho `chroot` là `SCMP_ACT_ALLOW` với `includes.caps=[CAP_SYS_CHROOT]`; configuredCapDrop=[ALL], CapAdd=null. Đây là **xung đột chính sách cụ thể với bước sandbox chroot** và phù hợp lỗi đo được. [Docker seccomp](https://docs.docker.com/engine/security/seccomp/) mô tả mô hình denydefault/allowrule vàprofile được CLI gửi vào daemon. Không có syscallerrno/strace hoặc testpolicykhác, nên không khẳng định đã đo mọi tầngLSM/kernel hoặc sửa mộtrule chắc chắn làm toànbrowserPASS. Không suy nguyên nhânTikTok/IP/TLS/captcha/RAM từ lỗi này.

Cgroup snapshotsbefore/after là dữ liệu thật trongcontainer, không thaylimits bằngpeak; CPUusage vàPIDs làsample counters. Sysctl/hostpolicies không bị thay, không chạyroot/privileged/capadd/hostIPC/no-sandbox. Namespaceoptionaldiagnostic không có dữ liệu riêng trong lượt này; không bịa mộthostpolicy.

## 4. Dừng và proposal chưa áp dụng

**Lượt2 không chạy:** thử cho phépchroot/addcap/đổi sandbox sẽ thay chínhguard mà chủ đã cấm đổi trong scope. Không thử một biến thểmù hoặc gọiTikTok đểthửvậnmay. Khôngbyte/deadlinefixture trước launch/context/CDP; mộtnavigation vàconditionalMP4 trong phạmvi cũ vẫn chưa dùng. Khôngmetadata lab mới/formatter/file/ffprobe/SHAvideo/âmthanh/visualwatermark. Quan sátIAB27s trước giữ nguyên với giới hạn khácmôi trường.

Proposalreviewable ở `proposal-not-applied.json`, **applied=false**:

1. Nếu chủ quyết định giao riêng, tạo **một successor seccomp riêng cho lab** vớiSHA mới và ruleallow`chroot` không phụ thuộccap ởprofile; giữcapdropALL/UID1000/no-new-privileges/sandbox/rootfsRO/privateIPC/networknone/resource928MiB. Không editprofile cũ, không đổiDocker/WSL/kernel và không addCAP_SYS_CHROOT.
2. Đây vẫn là mở thêm mộtsyscall trong bảo vệ, không tự có quyền áp dụng. Seccomp không hạn chế được pathargument chỉ `/proc/self/fdinfo`; cần đánh giá riêng rủi ro trước khi giao. Không cung cấp hay dùng `seccomp=unconfined`.
3. Sau quyết định riêng mới thử mộtlaunch offline mới≤30s đểkiểmcause/fix; chỉcontext/CDP vàbyte/deadline đạt mới tiếpnguồn. Không cam kết tấtcảlỗi được giải quyết hoặc cótệp/no-watermark.

Proposal không thay quyền hiện hành hoặc đòi mạng/proxy/account/tiền; lựa chọn giữ dừng vàproduction nguyên trạng cũng được ghi. Việc cần quyết định riêng đến từ chỉthị tiếp renderer37 bước3 và yêu cầu trực tiếp “nếu cần thay bảo vệ/host thì dừng”, không phải auto-reviewrejection.

## 5. Commands, coverage và bàn giao

```powershell
cd 'D:\WED SNAP'
$pwshLaunch = 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshLaunch -NoProfile -File tests/p37/run_renderer_capability.ps1 -Attempt 1
# Lệnh đầu lỗi wrapper trước Docker/browser; artifact đã giữ ởharness-fail-before-launch.
# Sau sửa chọndocker.exe, cùngcommand trên chạy launchChromium duy nhất của phiên, exit30.
```

Không chạy lạiattempt1 hoặc tựdùngattempt2: evidence directoriesrefuseoverwrite; browserbudget của phiên dùng1/2 vàdừng cầnquyếtđịnhguard. Imagecached giữ, khôngrebuild/install/pull. Rawattempt1 gồmfullsanitizedstderr/stack, nativeargv/UTC-VN/stdout-stderr/deadline/exits, Chromiumexit/signal, cgroup/guard; source/toolhash trước/sau cósuccessor hẹp. Không cónetwork/volume/media mới cầnremove, ownedcontainerđãremoved.

149manifestcũ+selfmetadata/raw/handoff giữ; trước sửa148entries ngoàiAUDIT khớp. Hai live tool sửa được giữ originalcopies để bảo toàn source gói cũ; successor chỉ chấp nhận **đúng SHA của2tools+4docs** đượcgiao, không exemption toànsource/evidence. Before-set và mọi history19–37.4-R giữ ngoài đúng6paths đó. Verifier mới chỉ đọcfile/log/hash, khônglaunch lại hoặc mutatefrozenverifiers.

PROGRESS/ADAPTERS/TEST_REPORT/AUDIT đồngbộ: buildcachedđãaudit; LOG/FIELDSđãsửa/chờaudit; BOOTblocked chroot/policydiffcầnquyếtđịnhriêng; byteguard/metadata/file/visualNOT_RUN; TikTokmain chưaapply/no-watermarkchưanghiệmthu. Mộtfile nếu sau này đạt vẫn thiếu2video/no-buttonAPI E2E trước bậtTikTokmain.
