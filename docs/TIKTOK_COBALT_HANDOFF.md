# Cobalt TikTok lab — 08/10/2026, triển khai và thử mẫu đầu; chưa nghiệm thu

**Đã tách resolver Cobalt, build image lab, nối transport có proxy/budget với yt-dlp và chạy một lượt nguồn thật. Mẫu đầu dừng ở lỗi tích hợp metadata: vòng đọc bị kẹt và deadline JavaScript không cắt được.** Container resolver bị dừng đúngownership, nativeexit137 sau khoảng165,344s — **vi phạm giới hạn30s của lượt nguồn, không được nhận PASSdeadline**. Metadata/HTTPstatus/decodedbyte cuối không được giữ vì worker không kết thúc; chưa tảifile hoặc kiểmwatermark. Code đã sửa và kiểmoffline7caPASS; không gọi lạiTikTok, hai mẫu còn lạiNOT_RUN theo điều kiện mẫu đầu phải đạt. Không dùng fixture thay kết quả nguồn.

Nhiệm vụ Cobalt trực tiếp của chủ ưu tiên hơn đề xuấtbrowser/chroot trongAUDIT. Không chạybrowser, sửaseccomp/host/WSL/Docker hoặc tiếp thủ tụcproposalrenderer. Production/YouTube/API/UI/DB/lifecycle/main/deploy giữ nguyên.

## 1. Source Cobalt và license

Repository chính thức [imputnet/cobalt](https://github.com/imputnet/cobalt), commit cố định **`a636575b09de1fc55d9b8cd98cac88f5f2f16b42`**, versionapi11.7.1. Commit metadata ởevidence/cobalt-commit.json; danh sáchbytes/SHA file ởlabs/tiktok/cobalt/UPSTREAM.json vàprovenance-final.json. Originalfiles ởupstream/ không sửa. GiữLICENSEAGPL-3.0 nguyên bản, CREDITimput+Cobaltcontributors vàNOTICE.md liệt kê thay đổi; lab/newglue cùngAGPL-3.0, không đổi licensecode ứng dụng chính hoặc deploywholeCobalt.

File lấy từ đúngcommit: LICENSE; apiREADME/package.json; pnpm-lock; services/tiktok.js; cookie/cookie.js/manager.js; processing/url.js/service-config.js/service-alias.js; config.js; misc/language-codes.js. Chỉtiktokresolver vàhelpers tốithiểu được thực thi; không Express/server/cluster/Redis/tunnel/media-caching/frontend củaCobalt.

| Mã tái dùng | Cách tách/modification |
|---|---|
| tiktok.js |Giữ parserHTML/JSONrehydration, status/age/error vàchọnplayAddr gốc. Đổiimports sangsubsethelpers; createStreamảnhfailclosed; videoresult thêmfieldsdetailđãparse(id/duration/video/provenance) cho contract. Callerh265/audio/gallery=false; khôngfallbackdownloadAddr. |
| cookie.js, language-codes.js, service-alias.js |Copy nguyênbytes. Cookie mới `{}` mỗiresolvercall, khôngaccountinput. |
| manager.js |Giữ nguyênupdateCookieValues/updateCookieexports; bỏaccountfile/cluster lifecycle vàkhóa isClusterfalse; Cookieanonkhôngmeta. Dùngset-cookie-parser gốc. |
| url.js |Giữ normalize/extract/alias/clean code, dùngconfig/serviceTikToksubset; bỏunrelatedresolveRedirectingURL/getRedirectingURLexport/import. |
| service-config.js/config.js |Giữ nguyênTikTokpatterns+UrlPatternconstruction vàgenericUAChrome138 củaCobalt; thay bootenv/version-info bằnglabdefaults. |

Resolver gốc dùngURL `https://www.tiktok.com/@i/video/<postId>` từidinput. Đây là cách canonical của **Cobalt đãghim**, khôngusername/chứng cứ redirect doWED SNAP suy đoán. Inputmẫuđầu vẫnverifiednxheitd.vln/7692808825228807442 vàoriginalvt…ZSbxenGuS được ghi provenance; không mở originalshortURL thêm. Không coi `@i` làtácgiả thực. Status/requestURL thực của lượt bị kẹt không córesult cuối, nên không bịa HTTP200/rehydration thiếu/maintenance/IPblock.

Dependencieslab exact: Undici6.24.1, set-cookie-parser2.7.2, url-pattern1.0.3, @imput/psl2.0.4 vàpunycode2.3.1; đúngresolvedversions trongupstreamlock, registrySRI trongpackage-locklab. Node22.22.3 cache đáp ứngengines>=18.17; dependencylicensesMIT, CobaltcodeAGPL. Không chọn theo sốsao. Khôngcài dependencies/browser toànWindows hay đổi apppackage/lock.

## 2. Phần tự nối và APIs có sẵn

HTTP/TLS/CONNECT/decompression vẫn là [Undici6.24.1](https://github.com/nodejs/undici/tree/v6.24.1), [ProxyAgent](https://github.com/nodejs/undici/blob/v6.24.1/docs/docs/api/ProxyAgent.md). Globalfetch củaresolver được nối vớiadapter; agentproxy luônhttp://egress:8888, TLSrejectUnauthorizedtrue; redirectsmanual giới hạn5 vàmọi hop qua cùngagent. Không HTTP/signature/TikTokextractor tựviết. Cookieanon nguồn cấp giữ trongCobaltCookie/RAM vàpipe; không log/cookiefile/accountinput. Cross-originredirect bỏCookie/Authorization từrequest trước.

Adapterđọc body **đãgiảinén** bằngNodeReadable.fromWeb/read(n), clampn≤min(response remaining+1, aggregate remaining+1,16KiB, chunkđãsẵn); không concatbodyvượtcap.8MiBresponse/16MiBaggregate, mộtbyte detection đểFAILclosed nhưadapter hiệncó; boundedbuffer/không HTMLoutput. Marker nhỏ/headers an toàn/status/finalURLsanitize đượcghi nếuworker kếtthúc.

Privatecontract(id/duration/video/sourceURL/cookie/provenance) đi **qua pipein-memory**, khôngpubliclog/HTML/signedURLfile. yt-dlp2026.08.19 helper `_extract_web_formats` đượcghim bằngmoduleSHA `3257fdea744811ea2e1bfee665a97d6ab85517339ee672f2e43e238e6b997c9e`; formatter chỉnormalize CobaltselectedplayURL, không metadatarefetch/alternateURLfallback. DownloaderchọnmatchingMP4/H.264/audiocandidate, bỏdownload/watermark/DRM, cap250MiBinput/200MiBoutput/600s, retries0; ffprobe/decode/fileSHA saufile. Việcformatter gáncodec/audio trongmetadata chưa là chứng cứfile thực — phảiffprobe; đườngdownload mới chưađược chạy trên nguồn.

**Deadline sửa cuối:** PythonOSprocess supervisor metadata30s/prepare180s, killownprocessgroup khiTimeoutExpired, độc lập eventloopNode; privatepayload vẫn trongRAM. NodeAbortSignal28s làphụ. Decoder/probe vàchuẩn bị thuộcprocessprepare≤180s. Code bảnđầu chỉtimerJS cộng outertimeout225s, đãvi phạmdeadline ởlive; không xóa hoặc sửarawđể che việc này. Finalcode chỉđược kiểmoffline, chưa nhậnlive30s.

## 3. Image, actualguards và giới hạn

Một dedicatedimage `wed-snap-tiktok-cobalt-lab:20261008`, actualID
`sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6`.
BasecachedB `sha256:c66f52eace47d01e59a54c4b37f2d4d3db8b65326abff670b3673cb7d8900d8f` và11baseLayers giữ trước/sau; nativebuildexit0/npmci5packages/SRI/assertyt-dlpversion. Không registrydigestclaim. Defaultseccomp dùng nhưmedia; khôngchrootprofile/browser.

Labsource2services: resolver/downloader512MiB+egress96MiB=**608MiB≤1GiB**, CPU0.75+0.25/PIDs96+64/swap=memory, concurrency1. Actualimage/user/rootfsRO/sourceRO/mounts/command/entrypoint/privatePID-IPC/capdrop/no-new-privileges/noports/labels/networkresources kiểm trướcstart, fullguardJSON+resolvedCompose trongsample1. Proxycached `8bc0a567…7f10` giữDNSpublic-IP/allowlist/CONNECTvalidatedIP/TLSend-to-end; resolver chỉinternalnetwork, egress thêmoutbound. Khôngmain.env/mainmount/DB/settings hoặchelperbrowser. Runtimeusage lúcstop: resolver90.34MiB/512MiB, CPU70.98%,PIDs13; làsnapshot, khôngpeak/benchmark.

## 4. Các phép thực sự chạy

| Lượt | Actualresult | Phân loại |
|---|---|---|
| ArchiveVerifyOnly |exit0, gzipledgerlossless theoindex, khôngrestore320MB |Read-onlypreservation, khôngfunctionalPASS |
| Offline1 |exit1 trướcfixture bởiconfigUAstringtruncatedtạisemicolon |LỗiWED SNAPextractionglue, rawgiữ/config-before-fix |
| Offline2 |5/5fixturePASS/exit0 |MockAgent/ReadableStream/CobaltHTMLfake: cap+aggregate/gzipdecoded/parseplay/deadlineAbort/redaction |
| Sample1live |1analyzeattempt; sourceCMDUTC17:47:42.834–17:50:28.178 ngày07/10, VN00:47:42.834–00:50:28.178 ngày08/10; nativeexit137 |WorkerCPUloop/noresult, **165.344s>30s**; exactownIDkill sauchốtstate/log/stats, khôngdownload |
| Offline3 |6Nodecases+1externalwatchdogPASS/exit0 |ThêmshortchunkEOF/timerturn vàPythonkillNodebusyCPU0.15s; khôngsourceHTTP, khôngbỏguard |
| Samples2/3 |NOT_RUN |Mẫuđầu khôngmetadata/file/visualPASS nênkhônggọi |

Lượtnguồn đầu cóattempt-reserved nhưngkhôngresult.json/metadata cuối. NetIO13.5kB/3.2kB làdockerstats, **không decoded-bytebudget**. KhôngHTTPstatus/finalredirect/byte/marker đủbằngchứng, không cócookie/token/bodylog. Nguyênnhânquan sát làintegrationreader/timer bịkẹt; fixture short-response sau sửa kiểmđúngEOF/yield. KhôngtracedCPUstack củaworker đãkill nên giữphânbiệt bugởadapter phùhợp dấu hiệu với nguyênnhânresponseTikTok cònchưađo. KhônggọiCobaltparserFAIL/nguồnchặnIP khiparser chưa trảkếtquả.

Bản source đãchạy đượcfreeze `source-before-live.json`/`executed-source-first/`, bao gồmvòngđọc/JSdeadline cũ. Mã final sửa khônghồi tốresultlive. `deadline-stop-observation.json`, `live-interpretation.json`, rawnative/logs giữgiới hạn này. Khôngbrowserfallback/solver/retry/paidproxy/đổimạng.

Metadata/file/ffprobe/decode/hình/tiếng/SHAvideo/watermark **chưađược kiểm thực**. Khôngcrop/blur/transcode, khôngsửa logo gốc. CóplayAddr trongfixture khôngnghiệmthu mẫu thật. Khôngmẫuphoto nào tính vào ba video.

## 5. Cleanup, preservation và lệnh

3lượt offline mỗi1containerdọnđúngID/run-label; source2containers+2networks dọnđúngownidentity,0resourcesleft. Lượtlive worker bịkill theoexact ID/run-label trướccleanup; khôngprune/down-v/flush/reset hoặcxóaartifactcũ. Imagecachelab giữ pin. TLS/proxy/seccomp/host/main nguồn cũ không đổi.

Before1.904file; copiesdocs vàarchive-index/GZip giữSHA. Apps/media/egress source mới đúngSTRUCTURE vẫnhashcũ; cấu trúc07/10 vàcacheđãxóa/archiveđãnén làkếthừa đượcgiao, không sửa verifier/golden hoặcuncompressscript nhưJSON. Verifier mới kiểm tập hiện tại trước/sau vàfullartifactcoverage, khôngrerunhistory. Chỉ4statusdocs+STRUCTURE đổi; code/config mới chỉlabs/tiktok/cobalt. LICENSE/originalupstream vàmodifiedsource/provenance đều trongpackage, license không sửa.

```powershell
cd 'D:\WED SNAP'
$pwshCobalt = 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/build.ps1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline
# Sau sửaconfigUA, khôngrebuild:
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 2
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage live -Sample 1
# Source đãstop/cleanup, chỉsửa vàkiểmoffline, khônglive lại:
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 3
```

Tải source/APIcommit/dependencyofficial metadata được thực hiện riêng, rawlệnhDocker cóUTC-VN/actualexits. LượtNetworkDNSbịsandboxchặn đãxin đúngtechnicalpermission, khôngphânloại thànhTikTokFAIL. Mộtlệnhrg dùngtham sốPowerShell khôngđúng đã lỗi, khôngxóa/sửa file.

## Kết luận và bước tiếp

**Labđãtriểnkhai, sourcefirsttestkhôngđạt; lỗiintegrationdeadlineđãsửaoffline/chờaudit, chưakiểm lại nguồn.** Khôngđềxuấttíchhợp vàoapps/media haybậtTikTokmain trước khicorrectedlab cómetadata/file/visual thật. Nếuchủ giao lượt kiểm tiếp sauaudit, dùng cùngsampleđãcó vàexternalwatchdog; không tựretry trong phiên này. Chỉkhi mẫuđầu đạt mớihai mẫu cònlại vàphạmvitíchhợp/appAPI/no-buttonE2E riêng. Ba mẫuđạt sau này cũngkhôngbảođảm mọiURL/P5–P6/deploy.
