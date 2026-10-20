# Bàn giao lab renderer37 — 07/10/2026: dừng ở capability, chưa gọi nguồn

**Đã build đúng một image lab riêng; preflight offline FAIL khi launch Chromium với sandbox bật. Đã dừng theo điều kiện được giao, không nới bảo vệ.**0/1navigation TikTok,0prepare/download. Metadata lab, byte-budget browser, ffprobe/fileSHA/visual/watermark đều NOT_RUN. Không biến build thành metadataPASS, và không gán browserlaunchFAIL thành lỗi nguồn TikTok. IAB trước đó thấy metadata27s/playAddr/4bitrates vẫn là quan sát browser ngoài lab, không là kết quả mới của phiên này.

## 1. Đọc, kế thừa và nguồn thư viện

Đã đọc AGENTS/PLAN, kết luận kiểm chứng browser/chỉ thị “Tiếp tục37 — lab renderer”, PROGRESS/ADAPTERS/TEST_REPORT; kiểm dependencies/code hiện tại. Playwright chưa có trong media dependencies; dùng đúng thư viện chính thức cho lab, không cài wholeCobalt/F2/TikTokPy, không viết TikTokparser/transport/signer.

Before-set1.701file, copies4docs. Repairmanifest108entries SHA `cf4566b17c4eeebeb98d6da2ba9e3a35474591929201d59e596d0a5daefbd757`/selfmetadata giữ;107entries ngoài liveAUDIT khớp SHA/bytes trước sửa. AUDIT đã được phiên kiểm chứng browser cập nhật được chốt exactcurrentSHA trong `predecessor.json`. Không sửa verifier/manifest/pins/logs19–37.4-R choPASS; successor mới chỉ chấp nhận đúng4docs được giao, source/raw trước-set giữ nguyên. Production/lifecycle/main không đổi.

API chọn từ [Playwright Docker](https://playwright.dev/docs/docker), NPMpackage chính thức1.63.0 đã xác minh integrity, `types/types.d.ts`/`types/protocol.d.ts` trong package. `launch({chromiumSandbox:true})`, `newContext`, `newCDPSession` là API có sẵn; chưa dùng profile/IAB/account/cookies. PackageNode≥20, baseNode22.22.3 phù hợp; licenseApache-2.0, release1.63.0 có artifact chính thức. Không coi license/hash/install là kiểm toán toàn bộCVE hoặc chứng minh browser hoạt động.

Đã đọc nguồn pinned yt-dlp2026.08.19 `_extract_web_formats`/`_parse_aweme_video_web` ở `docs/evidence/p37-3-20261007/upstream/tiktok.py`, SHA `3257fdea744811ea2e1bfee665a97d6ab85517339ee672f2e43e238e6b997c9e`. Formatter có sẵn phân biệt play/bitrate và downloadwatermarked. Đây làprivateAPI phải giữ version/sourcehash; chỉ là lựa chọn tích hợp dự kiến, **chưa gọi formatter/chuẩn hóaformat/download** vì renderer không đạt capability.

Đánh giá bytecap trước nguồn: `route.fetch`/`APIResponse.body()` không được chọn làm chứng cứ cap trước cấp phát. Protocol chính thức trong package có `Fetch.takeResponseBodyAsStream` + `IO.read(size)`, nhưng phải kiểm semantics/bodydecoding, bao phủ responses/subresources và deadline bằng fixture browser trước nguồn. Browser không launch được nên các phép kiểm đó **chưa thực hiện**; không tuyên bố streambudget đãenforce hoặc Playwright không thể enforce trong mọi cấu hình.

## 2. Image lab, dependency và browser pin

Base cachedB giữ tag/ID và11layerprefix thực:
`sha256:c66f52eace47d01e59a54c4b37f2d4d3db8b65326abff670b3673cb7d8900d8f`.
Image lab mới:
`wed-snap-media-renderer-lab:37-20261007`, actualID
`sha256:e3e776372b598eb8eaf57dea5ce293f79a1c834e6e92dce9e6b9bb9a2bf2baf9`.
Không coi actualID này là registrydigest.

| Artifact | Pin/provenance |
|---|---|
| playwright-core1.63.0 | [Registry chính thức](https://registry.npmjs.org/playwright-core/1.63.0); SRI `sha512-rYCsBF/M5HjUch52bbtVONEFjv6Xu8sm8h72dNlR5bzIE1fvC/bxgspzkjSfU+MweEMmPM8KJebG6nnyxo5mCg==` |
| Tarball | SHA256 `208593d4e1bcd8f8fe5f869cad1cc332dc7f1d70dc1d58c102dc3ac36e30f26c`, kiểm SRI sau tải và sha256sum trongDockerfile trước unpack |
| Official Chrome Headless Shell | Revision1243, declared/build installer version153.0.8010.12; officialCLI tải từcdn.playwright.dev. Runtime browser.version() chưa trả được |
| Main executable | SHA256 tính trong image `ded93a9c9a53a1ae040f08124badcca95c938e9d5015ff340c3b5538c41bf39e`; không giả đây là checksum upstream công bố |
| Browser files | InventorySHA toàn bộ executable/lib vàPlaywrightFFmpeg1011 trong `/opt/renderer-browser-sha256.txt`, xuất ởcapability.json; không dùng nó transcode/videoQA |
| Seccomp | [Profile chính thức đúngtag](https://github.com/microsoft/playwright/blob/v1.63.0/utils/docker/seccomp_profile.json); SHA256 `cc3e61cabda6bbc1e53e54d27ba4d55a9d3be829b6dd1a596f4a7b31b1cc7849`; actualHostConfig payload đối chiếu với file: khớp |

Build tuần tự, không có service chạy lúc prebuild. Chỉ dùng core package tarball đã khóa, CLI chính thức `install --with-deps --only-shell chromium`. Aptinstaller dùng Debian repositories có ký; log ghi0upgrade/35newpackages trong layerlab, không chuyển host/base/main; packageversions xuất `/opt/renderer-system-packages.txt`. yt-dlp2026.08.19 giữ, build có import/assert versionexit0. Không cài browser/runtime toànWindows; packageunpack trong evidence chỉ để đọc source.

Lượt buildwrapper đầu actualexit1 do functionDocker shadow executable, call-depthoverflow trước nativeDocker; chưa tạoimage. Giữ `build-harness-before.ps1`, `build-harness-failure.json` vàemptycontext. Sau sửa tên wrapper, nativebuild **exit0**, chỉ một image thành công; nativecommands/UTC-VN/fulloutput trong `build.jsonl`. SandboxDNS ở lượt tảiNPM ban đầu bị chặn; đã xin quyền kỹ thuật đúng scope rồi tải/hash được. Không coi lỗi wrapper/sandboxhost làTikTokFAIL.

## 3. Preflight thật và điều kiện dừng

Chạy **một container offline** networknone, noports; UID1000:1000, rootfsRO/sourceRO, privatePID/privateIPC/devshm128MiB, capdropALL/no-capadd/nonprivileged, no-new-privileges và profileofficial. Actualguard kiểm image/ID/labels/command/entrypoint/mount/network/resources trước start; source chỉ `tests/p37`RO, output chỉfoldercapability riêng; khôngmain.env/mainmount/DB/settings.

Memorylimit928MiB/swap928MiB,1CPU/PIDs256; sourcepipeline nếu đạt sẽ dành96MiB choegress, tổng1GiB. Phiên này **không tạo/start egress hoặc topologyrenderer+egress**, chỉ container928MiB networknone. Timeoutcommand30s cho toànprocess vàlaunchAPI10s; không source navigation. State/limits đượcinspect thật; không có dockerstats/peakCPU/RAM/PIDsusage do launch kết thúc rất nhanh, không báo limits là peak đã đo.

| Kết quả | Quan sát thực |
|---|---|
| Node/library | UID1000, Nodev22.22.3, playwright1.63.0, executable/hashinventory có |
| Launch | `browserType.launch: Target page, context or browser has been closed`; chromiumSandbox=true được yêu cầu; native/container/runnerexit30 |
| MốcUTC/VN | Script bắt đầu10:11:54.997/17:11:54.997; kết thúc10:11:55.627/17:11:55.627. Runner cleanup/end10:11:56.585/17:11:56.585 |
| Context/CDP | Không tạo được context; không đọc cookies/pageDOM, không chạy Fetchinterception fixture;0source navigation |
| State | Runningfalse, State.ExitCode30, State.OOMKilledfalse. Cờ này không tự loại trừ mọichildOOM; memory.events không được thu |
| Cleanup | Kiểm lại exactownID/lab/run-label rồirm owncontainer; enumerateownlabelrỗng,0resourcesleft. Không network/volume/media phải dọn |

**Cause quan sát được là browser launch đóng trước context, rootcause còn UNKNOWN.** Errorstring đượcsanitize/clipped1200characters và phần launchargv dài chiếm log, nên stderr chi tiết sau đó không còn trongreport. Không bịa namespace/seccomp/IP/TLS/captcha là nguyên nhân chắc chắn. Raw thất bại giữ nguyên; `interpretation.json` bổ sung giới hạn này, không hồi tố log.

Các fields `privateContext:true`/`tlsValidation:true` ở đầu capabilityreport là **cấu hình dự kiến**, không phải context/TLS đã kiểm thực: launch đã lỗi trước newContext. `interpretation.json` ghi contextCreatedfalse/tlsRequestedOnly. Không nhập account/profile/cookies; IAB không dùng trong phiên này. Không tắtChromiumsandbox, thêmSYS_ADMIN/privileged, mởhostIPC/outbound, đổibrowser/image hoặc retrylaunch/TikTok để vượt lỗi. Điều kiện “thiếucapability thì dừng” đã áp dụng.

## 4. Metadata, file và visual: NOT_RUN

VerifiedURL dự kiến vẫn là `https://www.tiktok.com/@nxheitd.vln/video/7692808825228807442`, liên hệoriginalshortURL `https://vt.tiktok.com/ZSbxenGuS/` đãresolve373. Không resolve lại/prefetch, không navigation mới, không canon giả. JSON≤8MiB/responsebudget/aggregatebudget/deadlinebrowser chưa kiểm được; không được phép gọi nguồn khi preflight chưa đạt.

Không cómetadata mới để parse/normalize, không chọn format/play/downloadsource, khôngCDNrequest. Prepare≤180s/output≤200MiB/input≤250MiB không được kích hoạt. KhôngfileMP4/ffprobe/fileSHA/decode/audio/visualwatermark mới; khôngcrop/blur/transcode. Không nhậnmetadata/file/no-watermarkPASS, không gọi lỗi này làCDN/sourceFAIL.

Một tệp nếu sau này đạt vẫn thiếu2mẫu vàno-buttonAPI E2E trướcTikTokmain; phạm vi hiện tại không sửaAPI/schema/UI/lifecycle/mainapply/deploy.

## 5. Bàn giao, preservation và hướng xử lý

Evidence mới `docs/evidence/p37-renderer-20261007/`: predecessor/beforeSHA/docs snapshots; officialpackage+SRI/hash/source/types/browsermanifest; seccomppin; buildfail/buildevidence/imagepin; capabilityguard/nativeexits/rawJSON/interpretation; manifestfullcoverage vàcompletion. Artifact browser/runtime ở image được nhận diện bằng actualimageID+hashinventory, không download/copybinarybrowser raWindows để dựngproof.

Lệnh đã chạy bằngbundledPowerShell:

```powershell
cd 'D:\WED SNAP'
$pwshRenderer = 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshRenderer -NoProfile -File tests/p37/build_renderer.ps1
# Lượt đầu wrapperfail trước nativeDocker; nativebuild duy nhất ởAttempt2.
& $pwshRenderer -NoProfile -File tests/p37/build_renderer.ps1 -Attempt 2
& $pwshRenderer -NoProfile -File tests/p37/run_renderer_capability.ps1
```

Không chạy lại các directory/tag/lượt này trong scopehiện tại. Có thể đọc/evaluateevidence mà không khởi độngbrowser. Image mới giữcachepin cho tái hiện; khôngglobalprune/reset/flush/down-v hoặc xóa imagebase. Cleanupowncontainer đãxong, evidence giữ.

**Hướng tiếp theo cần giao riêng:** thu stderrlaunch nguyên vẹn đãsanitize và làm rõ khả năng browser sandbox trong labguard hiện có, trước khi xây fixturestream decodedbytes/deadline. Không đề nghị bỏsandbox/guard hay đổimạng/proxy/account. Chỉ sau khi browsercapability vàbyte/deadlineguard được chứng minh mới giao navigation≤30s rồiconditionalonefile; không tự retry trong phiên này. Kết quả này không phủ nhận quan sátmetadataIAB, chỉ cho thấy runtime lab hiện chưa dùng được.

PROGRESS/ADAPTERS/TEST_REPORT/AUDIT đã đồng bộ buildPASS/capabilityFAIL/sourceNOT_RUN, chờaudit;37.4-R giữ nghiệmthu scoped. Verifier mới chỉ kiểmfile/log/hash/ownership proof đã lưu, khôngrerun19–37.4-R hoặc runtime. Production/lifecycle/source/raw/manifests cũ giữ, chỉ4docs được giao có exactsuccessorSHA.
