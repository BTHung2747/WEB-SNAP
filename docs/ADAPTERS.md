# Báo cáo adapter local

## Hiện trạng15/10/2026 — Một ảnh TikTok nguồn qua backend đã đạt, main vẫn tắt

**PASS_INDEPENDENT_SOURCE_PHOTO2_TECHNICAL_AND_VISUAL_MATCH**: một workflow canonical7678209751167110421/index2 qua API/BullMQ/2child/own-egress,5response200 trong≤2+2+1budget, native0/group0→prooftrue→release; JPEG2132×2132/322655B/SHA62308e…5a8b/2probe/fullDecode/nativeHEADGETRange vàcleanup đạt. Reviewer đã mở chính file mới, không thấy watermarkTikTok thêm và đối chiếu exactbyte với ảnh2 đãhumanaccepted; không tạo humanreplymới hoặc sửa visualpendingsealed. [Nghiệmthu](evidence/tiktok-photo-source-fixed-live-review-20261015/ASSESSMENT.md), [tệp mới](evidence/tiktok-photo-source-fixed-runtime-20261015/source-once/cases/source/native-image.jpg).

CodephotoAPI/shared/worker/media/nativeJPEG đã có trong ứngdụng, nhưng lượt đạt chạy lab riêng với mountedsource/DNSchildenvfix/diagnosticsoverlay/runnerfixed đãreview; cácfixwiring này chưa mainapply. MainTikTok/gallery vẫn tắt; chưaUIA/browsercombined/shortlinkAPI/toànalbum/mọiTikToklink/deploy. Mộtảnhkhông mở quyềnnguồn tiếp hoặc thay kếtluận video/YouTube. Xem [contract bàn giao UI](TIKTOK_PHOTO_UI_BACKEND_HANDOFF.md) để dùng itemId/formatIdpublic, capability và nativeJPEG/session-job-lease đúng. Lượt này chỉ cập nhật tài liệu, không code/test/runtime/nguồn mới.

Các mốc09/10 và renderer/Cobalt07–08/10 bên dưới là **lịch sử tại thời điểm ghi** (bao gồm “chưa nguồn/no photo/mẫu3chờ”), được giữ nguyên để bảo toàn hồ sơ; không dùng chúng phủ nhận mốc một ảnh nguồn15/10, cũng không suy mốc mới thành mọi luồngTikTok đã nghiệmthu.


## TikTok core ứng dụng — 09/10/2026: offline hai phase, chưa nguồn/API E2E

apps/media/src/tiktok tái dùng core/validator Cobalt AGPL3 đãghim vàyt-dlp2026.08.19/Requests2.34.2/FFmpeg. Two-child CLI analyze/prepare/stdinignore/media.mp4/schema giữ; preparefreshbodyID/publicformat descriptor, noformatfallback, sourcecookies/signedURLs chỉRAM. LongURL≤2GETanalyze+2GETmetadataPrepare+1GETMP4; shortlinks hiệnUNSUPPORTED_CONTENT/0requests, nophotogallery/downloadAddrwatermarked/thumbnailGET.

19CLI fixture cases vàprivateAPI/worker/DB/Redis đãPASS metadata→selectable→prepare→ready→nativefull+Range, childexit/ProcessGroup/cancel/expired/deadline/ownedcleanup/CSRF/lease. Đây làsynthetic/transportdouble, sourcecalls0; khôngsourceTikTok/YouTube hoặcno-button/shortlinkE2E/no-watermarkclaim. Mẫu3fullclipreviewvẫnchờ, tổngaccepted2/3.

TIKTOK_ADAPTER_ENABLED mặcđịnhoff; VERIFIED_PLATFORMS/mainsettings/env/compose khôngbậtTok. NhánhYouTubelegacycode giữbyte vàfixturecheck, khôngmainbuild/deploy. Handoff/provenance/pins ởTIKTOK_APP_INTEGRATION_HANDOFF.md vàapps/media/src/tiktok/; raw/goldenlịch sửgiữ.

## Điều tra Cobalt — 08/10/2026: bổ sung quan sát, chưa đạt nguồn

Giữ Cobaltcommit/parser/canonical@i và5deps/yt-dlp/image đãghim; không lỗi URLintegration được chứngminh. Lab thêmclassifier boolean bằng HTMLhelpersyt-dlp qua pipeRAM/timeout2s/output4KiB/bodySHA, không solver, fullHTML/token/cookielog hoặc đổiTLS/header/selection. Offline9Nodecases+Brotli/hash/caps/watchdogPASS.

Mộtsourceattempt mớiFAIL trướcresponseheaders, Abort28s/worker28,369s/exit20, decoded0; classifier nguồnNOT_RUN. Không hồi tốfalse/true cho challenge củaHTTP200/1462cũ, nguyênnhâncònchưađo. Download0/file/ffprobe/decode/audio/visual/watermarkNOT_RUN; samples2/3khônggọi; cleanup0/runtime608MiB/guardsgiữ. KhôngbậtTikTokmain/deploy. [Bàn giao điều tra](TIKTOK_COBALT_INVESTIGATION_HANDOFF.md) vàsuccessor riêng giữevidencecũ.

## Cobalt kiểm lại — 08/10/2026, lab chưa đạt nguồn

Giữ resolver Cobalt commit `a636575b…42`, image `5fcc01bb…3f3a6`,5npmdeps/yt-dlp2026.08.19/FFmpeg và own-egress. Bổ sung receipt source/config/lock/image + runtime-installed dependency hash gate trước nguồn; log loại toàn bộ URL/path/query trong transport/runner/downloader. Không sửa parser, HTTP/cookie/download libraries hoặc bộ media ứng dụng.

Offline cap8/16MiB/watchdogOS30s/hash/redaction PASS trên đúng mã; source mới **một** analyze metadataFAIL (`COBALT_fetch.fail`), HTTP200/br/1.462byte, rehydration=false, native20/0,695s. Download0; format/file/audio/visual/watermark chưa kiểm thực; hai mẫu còn lại không gọi. UID/SSRF/TLS/RO/privateIPC/defaultseccomp/caps giữ,512+96MiB runtime, cleanup0left. Không nhận TikTokmain/P0/no-buttonE2E/deploy. Evidence cũ không sửa; [successor bàn giao](TIKTOK_COBALT_RECHECK_HANDOFF.md) ghi đầy đủ hash/API/lệnh/cause và giới hạn.

## Cobalt TikTok lab — 08/10/2026: đã triển khai, mẫu đầu lỗi tích hợp, dừng nguồn

**Kết luận hiện hành: theo lựa chọn trực tiếp của chủ, resolver TikTok Cobalt đã tách/build/nối yt-dlp trong lab riêng. Một analyze nguồn đầu không hoàn tất metadata do lỗi vòng đọc/deadline trong lớp tích hợp; nativeexit137 sau~165,344s, vượt30s nên không nghiệm thu deadline/source.** Tôi đã dừng đúngowncontainer, giữrawvi phạm; chưadownload/file/watermark, hai mẫu cònlạiNOT_RUN. Finalcode sửa short-read vàwatchdogOS đã kiểmoffline7caPASS, **không gọi lạiTikTok** hoặcdùngfixturethaylive. Nhiệm vụ Cobalt ưu tiên hơn kế hoạchbrowser/chroot cũ; không đổi seccomp/host/browser/production.

- Cobaltcommit `a636575b09de1fc55d9b8cd98cac88f5f2f16b42`, resolverHTML/JSON/playAddr gốc vàcookie/URLhelpers tốithiểu trong `labs/tiktok/cobalt/`. Originalfiles/SHA, LICENSEAGPL-3.0/imputcredit/NOTICEmodifications giữ; khôngwholeCobalt/server/frontend/cluster hoặcTikTokextractor tựviết.
- Mộtimagelab actualID `5fcc01bb…0fb3f3a6`, baseB/yt-dlp2026.08.19/FFmpeg giữ,5exactnpmdeps/registrySRI khóa riêng. UndiciProxyAgent+TLS/decodedread8MiBresponse16MiBaggregate; cookieanonRAM+pipe/privatecontract; sourceplay khớp formatterpinned, no downloadAddrwatermarked fallback. Tải/ffprobe/decode/visual path chưa chạy trênfile thực.
- Actualsourceguard2services512+96=608MiB≤1GiB, userRO/privatePID-IPC/capdrop/no-new-privileges/defaultseccomp/noports/mainenv/DB; resolverinternal chỉown-egressSSRFDNS. Khi bịkẹt90.34MiBsnapshot/70.98%CPU/13PIDs; HTTPstatus/decodedbytes/marker cuốiUNKNOWN vìkhôngresult, không suyIP/TLS/TikTokparserFAIL.
- Offline1 FAILconfigUAextraction được giữ; offline2 5PASS. Saufirstliveerror, offline3 6Nodecases+1externalwatchdogPASS. Metadeadlinefinal làPythonprocess30s, prepare180s, độc lậpJSCPUloop; livefinal vẫnNOT_RUN. CleanupexactownIDs/run-label3offlinecontainers và2sourcecontainers/2networks,0left; khôngrequestmẫu2/3/retry/solver/mạngkhác/proxy/browser.
- Before1.904file/history/archive compressed giữSHA, VerifyOnlylosslessexit0khôngfunctionalPASS. Chỉlabnewcode+docsliênquan; khôngproduction/YouTube/API/UI/DB/lifecycle/main/deploy. [Bàn giao Cobalt](TIKTOK_COBALT_HANDOFF.md) ghisource nào, glue/limits, lệnh/UTC-VN/exits vàgiới hạn nghiệmthu.

TikTokchưađạtP0/file/visual/no-buttonE2E, khônghứatải khôngwatermark. Chưađềxuấttíchhợpappsmédia cho đếnkhi correctedlab đượcgiao kiểmnguồn vàcómẫuđầuthựcđạt; khôngtựgiao thêm request trongphiên này. Kếhoạchbrowser/chroot bên dưới là lịch sử so với lựa chọn Cobalt này.

## Tiếp renderer37 — 07/10/2026: log đã sửa, sandbox chroot bị chặn; dừng chờ quyết định bảo vệ

**Kết luận triển khai hiện hành: F-R37-LOG/FIELDS đã sửa, chờaudit. Một launch offline mới vẫn FAIL: Chromium báo sys_chroot("/proc/self/fdinfo/") thấtbại trướczygote và kết thúc bằngSIGTRAP; script/container/runnerexit30.** Đã xác định xung đột profile chroot/capdrop; không nới bảo vệ, không chạy lượt2. Nguồn vẫn0/1navigation/download0; byteguard/metadata/file/visualNOT_RUN. Image/buildcũ giữnghiệmthu; main/lifecycle/TikTok/no-watermark chưaapply/nghiệmthu.

- FullChromiumstderr181byte vàlaunchstack4.449byte đãsanitize, truncatedfalse; stdout0byte. Thu exit/close thật quaNode22ChildProcess, không giảbrowserexit30. DebugPlaywrightpw:browser giữfullstdout/stderr vàNativeCLI có deadline ngoài15s/35s; timeoutnode30s giữ. Context/TLS đổi requested/observed; context/page/CDPfalse, TLSNOT_RUN đúngstage.
- Actualguard giữcachedimagee3e77637…2baf9, user1000/seccompSHA cũ/rootfs-sourceRO/privatePID-IPC/capdropALL/no-new-privileges/networknone/928MiB/CPU1/PIDs256. ProfiledefaultERRNO chỉ allowchroot nếucóCAP_SYS_CHROOT, cònCapAddnull/CapDropALL. Cgrouppeak~386.44MiB, memory.eventsOOM0/pids.eventsmax0; không suyIP/TLS/captcha hoặcRAMthiếu.
-3fixturelog nhỏ PASS (full/tail/redaction), khônglaunch/source. Lỗi wrapperhost chọn2Dockerpaths trước runtime được giữ riêng vàsửa; không đếm thànhlượtbrowser. Launch1/2; lượt2NOT_RUN vìthửfixchroot phải thayprofileguard. CleanupexactownID/run-label,0resourcesleft; khôngegress/TikTok/CDN/rebuild/install/pull/hostpolicychange.
- Proposal lab-only successorseccompallowchroot trong `proposal-not-applied.json`, **chưaápdụng**, cầnquyếtđịnhriêng theo chỉthịbước3; không root/no-sandbox/privileged/capadd/hostIPC hoặcgiao thêm mạng/proxy/account. Giữ149artifactspredecessor/raw/selfSHA; successor chỉđúng2tools+4docs, không nới exemptionhistory.

[Bàn giao launch renderer37](TIKTOK_RENDERER_LAUNCH_HANDOFF.md) cófullstderr/processsignal/cgroup/guard/UTC-VN, cause vàgiới hạn syscalltrace, proposal cụthể vàhashcoverage. Các cổngnguồn/file chỉđược tiếp khi launch/context/CDP/byte/deadlineđạt; mộtfile chưađủ3mẫu/no-buttonE2E/TikTokmain.

## Lab renderer37 — 07/10/2026: image đã build, capability FAIL, dừng trước nguồn

**Trạng thái hiện hành: build đúng1image lab Playwright chính thức thành công; kiểm offline thất bại ngay khi launch Chromium với sandbox bật, đã dừng theo điều kiện được giao. 0/1 navigation TikTok và0prepare/download; metadata lab/byte-budget browser/ffprobe/fileSHA/visual/watermark đều NOT_RUN.** Không nới guard hoặc dùng buildPASS thay metadataPASS.37.4-R đã được audit nghiệm thu offline; IAB trước đó quan sátmetadata27s/playAddr/4bitrates là bằng chứng ngoài lab, không là kết quả mới. TikTok/P0/P2/no-watermark/main chưa nghiệm thu/apply.

- Image riêng `wed-snap-media-renderer-lab:37-20261007`, actualID `e3e77637…2baf9`; playwright-core1.63.0 SRI/SHA từNPM chính thức, headlessshellrevision1243/declaredversion153.0.8010.12, binarySHA `ded93a9c…bf39e`. BaseB `c66f52ea…900d8f`/11layerprefix vàyt-dlp2026.08.19 giữ. Browserhash là hash tính trong image, không giả registry/upstreamdigest.35systempackages thêm riênglayerlab/0upgrade; không càiWindows/production.
- Preflight actualguard:1container networknone,UID1000/rootfs-sourceRO/privatePID-IPC/noports/capdropALL/no-new-privileges/seccompofficial đúngtag,928MiB/swap928MiB/1CPU/PIDs256. Sandboxlaunch trả “Target page, context or browser has been closed”, native/container/runnerexit30, State.OOMKilledfalse; chưa cóusagepeak/memory.events. Context/TLS/streamcap chưa được kiểm thật. Lỗi chi tiết bịclip sau1200ký tự, rootcauseUNKNOWN, không suyIP/captcha/SSRF/namespace.
- Cleanup đúngownID/run-label,0resourceleft; khôngstart egresstopology hoặc gọiTikTok/CDN. Dừng, khôngtắt sandbox/thêmprivileged/SYS_ADMIN/hostIPC hoặcretrynguồn. Các guard/caps cho bước nguồn không bị bỏ; budget8MiB/16MiB chưa verify nên nguồnNOT_RUN.
- Bảo toànbefore1.701file vàpredecessorrepair108entries/107 ngoàiAUDIT trước sửa, manifest/selfSHA/raw/pins giữ. Chỉ thêmimage lab/tool/evidence/docs mới và cập nhật4docs được giao, khôngproduction/lifecycle/deploy. Lỗi wrapperbuild đầu shadowdocker được giữ; sửa trướcnativeDocker, không cóimage thứhai.

[Bàn giao renderer37](TIKTOK_RENDERER_HANDOFF.md) ghi đủ5bước với điều kiện dừng, dependency/API/hash/actualexits/UTC-VN/ownership/giới hạn. Hướng tiếp cần giao riêng là làm rõ launchstderr vàcapability giữsandbox/guard, rồi mới chứng minhstreambyte/deadline trướcnavigation. Không yêu cầu mạng/account/proxy mới; mộtfile nếu đạt sau này vẫn chưa đủ3mẫu/no-buttonE2E/TikTokmain.

## Sửa37.4-R — 07/10/2026: F37.4-SUM/DEFAULT đã sửa, chờ audit

**Kết luận hiện hành: đã sửa hai finding công cụ offline; bộ fixture cuối12/12 PASS. Đối chứng mạng37.4 vẫn0/2 NOT_RUN vì chủ chỉ có mạng hiện tại.** Không gọi TikTok, không chạy Docker/đổi mạng và không yêu cầu hotspot/proxy/JSON/proof.37.3 giữ nghiệm thu image/đối chứng scoped; TikTok/P0/P2/no-watermark chưa nghiệm thu; main chưa apply. Những đề nghị cung cấp mạng/proof ở bàn giao cũ là lịch sử, không phải yêu cầu hiện hành.

- F37.4-SUM: config/actualtarget/preparedheaders/byte không so được thì chỉ OBSERVED_TWO_REPORTS + comparabilitylimits, metadata PASS/FAIL riêng, causeUNKNOWN; không kết luận network sensitivity. Report thiếu/hỏng/NOT_COMPLETED hoặc PASS/formats sai schema thành PARTIAL/UNKNOWN, không MEASURED hoàn chỉnh. Hai report hoàn tất và so được mới nhận trạng thái đo; vẫn giới hạn kết luận ở chứng cứ được ghi.
- F37.4-DEFAULT: default CaseDir mới `docs/evidence/p37-4-r-20261007/case-current-final/`,5/5sourcepins và configpin đúng. Giữ nguyên mọi case/pin/gói374 cũ; không đổi pin cũ để lách guard. Probe/guard/Compose/deps/images/production không sửa.
- Kiểm hẹp dùng actualsummarybranch trong bundled PowerShell7.6.5, report files synthetic, không sao chép logic hoặc giả networkreceipt. Bộ cuối baseline4PASS/8FAIL(actualexit1)→12PASS/0FAIL(exit0); giữ các raw lượt đầu11ca và lượt cuối12ca. Missing-input vẫnexit40/0source trước Docker. Fixture PASS không là metadata/download PASS.
- Bảo toàn1.596file before-set; predecessor37439/39 ngoàiAUDIT và manifest/selfSHA chốt trước sửa. Successor chỉ nhận đúng SHA runner+4docs được giao; giữ lịch sử19–37.4, raw/manifests/verifiers/pins. Evidence mới ở `docs/evidence/p37-4-r-20261007/`.

[Bàn giao37.4-R](TIKTOK_37_4_R_HANDOFF.md) có raw FAIL→PASS/actualexits, defaultcase và coverage/preservation. Không rebuild/install/download/E2E/deploy hoặc mở testbacklog/phần37.5. PLAN cho phép tiếp tục kiến trúc với nền tảng đã kiểm chứng; nhiệm vụ sản phẩm tiếp theo là phạm vi riêng sau audit, không yêu cầu mua VPS/proxy để hoàn tất việc offline này.

## Chuẩn bị37.4 — 07/10/2026: NOT_RUN, thiếu điều kiện mạng đối chứng

**Trạng thái hiện hành: 37.3 đã được audit nghiệm thu image/đối chứng theo phạm vi; A/B metadata FAIL. 37.4 đã được giao và chuẩn bị gói chạy, nhưng chưa có mạng khác/quyền đường truy cập và phương pháp kiểm chứng outbound của lab do chủ cung cấp. Đúng 0/2 analyze mới; cả mạng hiện tại và mạng khác đều NOT_RUN.** TikTok/P0/P2/no-watermark vẫn chưa nghiệm thu; main chưa apply. Những nhãn chờ audit37.3 bên dưới là lịch sử.

- Thêm runner single B cho mỗi mạng, giữ cached image `c66f52ea…900d8f`, yt-dlp2026.08.19, egress `8bc0a567…7f10`, caps8MiB/16MiB/30s và cấu hình lab2services480MiB. Headers được cố định bằng option `http_headers` đúng API/version; actual target vẫn ghi riêng từng HEAD/GET, không ép extractor hay dùng solver.
- Gói đang dùng `docs/evidence/p37-4-20261007/network-case-final/` khóa source/config; mỗi slot current/alternate một lượt, gate plan/proof trước Docker/source, không tự chuyển mạng. Gate không thay thế kiểm chứng provenance của privateproof: cần đối chiếu đường own-egress thực, không suy từ SSID/token tự điền. Chưa gọi publicIPservice hoặc TikTok.
- Kiểm mới: predecessor373 giữ74/74 entries ngoài AUDIT cùng manifest/selfSHA; snapshot1.558file trước sửa. Missing-input branch exit40, không Docker/source. 3fixture nhỏ trong imageB networknone/256MiB PASS, native/container/runnerexit0; cleanup1container đúng ID/run-label,0resourceleft. Compose chỉ render exit0; chưa start topology2mạng. Source metadata/marker/target/actualexit vẫn NOT_RUN, không dùng log373 làm kết quả374.
- Production/config/deps, source/raw/manifest373 và lịch sử19–37.3 giữ. Successor374 chỉ nhận đúng hash4docs được giao, không sửa verifier hoặc manifest cũ. Không rebuild/install/download/E2E/deploy hoặc mở testharness backlog.

Điều kiện cần để tiếp tục trong phạm vi đã giao: chủ cung cấp mạng khác sẵn có, cách/quyền truy cập và phương pháp/privateproof xác minh outbound của chính lab thay đổi. [Bàn giao37.4](TIKTOK_37_4_HANDOFF.md) có package, lệnh chưa chạy, templates cố ý fail-closed, actualexits và giới hạn bằng chứng. Metadata nếu thành công sau này vẫn chưa là nghiệm thu tải không watermark.

## Bàn giao37.3 — 07/10/2026, chờ kiểm toán

**Kết luận triển khai hiện hành: đã thực hiện5bước image lab/đối chứng metadata, đúng2analyze; A FAIL, B FAIL và đã dừng nguồn.**36 giữ nghiệm thu scoped; review37.2 offline đã được audit theo phạm vi.37/P0/P2 TikTok vẫn PARTIAL, chưa có tệp/visual/no-buttonE2E, main chưa apply. Các nhãn “hiện hành” cũ bên dưới là lịch sử so với cập nhật này.

- Build đúng1image lab bổ sung3wheel hash-locked, baseID `ecb3e747…65737b` và yt-dlp2026.08.19 giữ. B imageID `c66f52ea…900d8f`; capability offline A0/B37targets; source cài cả2image khớp tag chính thức, mọi dependency cũ giữversion.
- A handler `requests`, HEAD shortURL timeout10s,10.394s, metadataFAIL/nativeexit20. B handler `curl_cffi`, HEAD target thực `chrome-136:macos-15`, GET target thực **`chrome-146:macos-26`**, resolvevideo7692808825228807442; GETHTTP200/text-html/br/headerlength688/aggregate1.462byte,1.344s, extractor không có parsedrehydration; metadataFAIL/nativeexit20. Runner/harnessCOMPLETED, runnerexit20=BOTH_FAIL, khôngPASSmetadata. Solver upstream bị chặn theo phạm vi; không chứng minh cóchallenge.
- RawB byte/marker theoresponse chốt sớm do underlyingread gọiclose; các markerfalse **không được dùng để kết luận HTML không cóJSON/maintenance/captcha**. Fixtureoffline tái hiện3PASS/1FAIL(exit1,runner30)→sửa4/4PASS(exit0), giữraw/executedsource và khônganalyze lại. DefaultUA ngẫu nhiên còn khácA/B; không suy đối chứngTLS đơnbiến/chặnIP/curlkhôngtácdụng.
- Guardactual/SSRF/egress/caps giữ;2services480MiB, mỗiarm<30s,8MiBresponse/16MiBaggregate, khôngport/DB/mainenv/mount. Cleanup đúngownID/run-label:3containers/2networksA-B đã gỡ,0resourcesleft; imageB giữcache ghim đểtái hiện. Evidencecũ/sourceproduction giữexactSHA; mới ở `docs/evidence/p37-3-20261007/`.

Chi tiết5bước, wheel/API/giấyphép, command/UTC-VN/exits, giới hạn diagnostic, artifactmanifest và hướng đối chứng trên mạng khác đã có cần giao quyền riêng: [TIKTOK_37_3_HANDOFF.md](TIKTOK_37_3_HANDOFF.md). Không tải/E2E/deploy/rerun19–36 hoặc tích hợpCobalt. Metadata nếu đạt sau này vẫn chưa nghiệm thu tải khôngwatermark.

> Cập nhật hiện hành 05/10/2026 sau review37.2: sửa runner/helper đạt scoped 6 PowerShell + 6 Python + 10 regression offline; image cache vẫn thiếu curl_cffi/targets. Tuyên bố đóng H1/H2/H3 bên dưới là lịch sử, không nhận A/B sẵn sàng chạy. Chưa build image mới hoặc tải TikTok; xem PROGRESS và evidence/p37-2-review-20261005.

Kiểm chứng 30/09/2026 UTC (rạng sáng 01/10 giờ Việt Nam), Docker Desktop WSL 2 trên Windows. yt-dlp 2026.08.19, Node 22.22.3 làm JS runtime, FFmpeg Debian; worker không có mạng ra trực tiếp, đi qua CONNECT proxy kiểm tra host/DNS/IP. Không dùng cookie tài khoản, remote solver hoặc vượt DRM.

## Phạm vi

| Nền tảng / nội dung | Bằng chứng | Quyết định local |
|---|---|---|
| YouTube, video công khai ≤600 giây | 3 tệp mới tải qua adapter, FFmpeg giải mã đầy đủ; một luồng API thật có Range + full download | Bật video MP4 có hình/tiếng trong giới hạn |
| TikTok, video/ảnh | Cobalt lab08/10 đãtriểnkhai commit a636575b…6b42; **một analyze nguồn lỗi integrationdeadline/native137, metadataUNKNOWN/chưafile/watermark**, dừng khôngretry. Final7fixtureofflinePASS, sourcefinalchưakiểm lại;2mẫu cònlạiNOT_RUN. Cobaltkhôngbrowser/seccompchange/main; xem TIKTOK_COBALT_HANDOFF.md. | Tắt |
| Facebook, video/ảnh | Chưa có mẫu được phép để kiểm chứng | Tắt |
| X, video/ảnh | Chưa có mẫu được phép để kiểm chứng | Tắt |
| Bài nhiều ảnh / tải từng ảnh | Chưa có adapter kiểm chứng | Chưa hỗ trợ |
| Direct / proxy streaming | Chưa kiểm chứng trình duyệt, URL hết hạn và ràng buộc IP/header | Tắt; chỉ dùng tệp tạm |
| HLS native | Chưa kiểm chứng | Không đưa vào danh sách định dạng |

Adapter trả MP4 HTTPS progressive hoặc ghép H.264 HTTPS + AAC/M4A bằng FFmpeg copy. Không chuyển mã hay nâng chất lượng. Kiểm tra lại format từ nguồn khi prepare; ffprobe xác nhận có video, audio, đúng chiều cao và thời lượng. Bộ mẫu cuối cùng kiểm chứng `160+140-drc`, không chứng minh mọi chất lượng hay mọi link đều hoạt động.

## Tệp mới của lần kiểm chứng cuối

| Mẫu Blender | Format | Byte đầu ra | Byte vào adapter | Giây theo ffprobe | Kết quả |
|---|---|---:|---:|---:|---|
| Big Buck Bunny `YE7VzlLtp-4` | 160+140-drc | 13.544.729 | 14.764.570 | 596,521 | H.264 + AAC, giải mã PASS |
| Spring `WhWc3b3KhnY` | 160+140-drc | 9.503.843 | 13.738.071 | 464,167 | H.264 + AAC, giải mã PASS |
| Coffee Run `PVGeM40dABA` | 160+140-drc | 4.529.195 | 5.811.053 | 184,692 | H.264 + AAC, giải mã PASS |
| ID không tồn tại `xxxxxxxxxxx` | — | — | — | — | CONTENT_UNAVAILABLE |

Byte vào bao gồm response metadata/media được adapter đọc; không phải tổng dữ liệu tính phí trên mạng/TLS. Bằng chứng `docs/evidence/p0-secure.json`, ba `*-secure.mp4`; không tái sử dụng tệp cũ làm thành công của lần mới.

Luồng thật Coffee Run qua Nest API → PostgreSQL/Redis/BullMQ → worker → ticket → HTTP Range 206 và full 200: **PASS**, 4.529.195 byte trong 15.821 ms cho toàn luồng; prepare lặp cùng khóa không tạo thêm tài sản. `p0-api-smoke.json` và `youtube-coffee-api.mp4` ghi kết quả; FFmpeg giải mã đầy đủ PASS. Đây là smoke nhỏ, không phải benchmark tải đồng thời.

Các lần đầu progressive-only từng tải được Big Buck Bunny rồi thất bại ở lần sau. Các lần adapter đầu bị timeout và parser stdout sai; đã sửa chọn format trước extraction, tắt progress và đọc dòng JSON cuối. Giữ JSON lịch sử để không che lỗi nguồn; kết quả cuối ở trên thay thế trạng thái thử nghiệm trước. Tốc độ/khả năng nguồn có thể đổi theo IP và thời điểm.

Mẫu là phim mở Blender; giữ attribution và kiểm tra giấy phép cụ thể khi tái sử dụng: [Big Buck Bunny](https://peach.blender.org/), [Spring](https://studio.blender.org/films/spring/), [Coffee Run](https://studio.blender.org/films/coffee-run/). Website không cấp quyền tải nội dung bên thứ ba thay cho chủ sở hữu.

## Chạy lại adapter bảo mật

Dừng stack chính để giảm RAM; dùng volumes test riêng. Không chạy song song với build hoặc integration fixture:

```powershell
cd "D:\WED SNAP"
docker compose stop
docker compose -f compose.yaml -f compose.test.yaml up -d postgres redis egress
docker compose -f compose.yaml -f compose.test.yaml run --rm --no-deps api npm run migrate
docker compose -f compose.yaml -f compose.test.yaml -f compose.smoke.yaml run --rm --no-deps api node_modules/.bin/tsx tests/reset-settings.ts
docker compose -f compose.yaml -f compose.test.yaml -f compose.smoke.yaml up -d --no-build
docker compose -f compose.yaml -f compose.test.yaml -f compose.smoke.yaml run --rm --no-deps worker python3 scripts/p0-secure.py
docker compose -f compose.yaml -f compose.test.yaml -f compose.smoke.yaml run --rm --no-deps -v 'D:\WED SNAP\tests:/app/tests:ro' -v 'D:\WED SNAP\docs\evidence:/evidence' api node_modules/.bin/tsx tests/real-smoke.ts
docker compose -f compose.yaml -f compose.test.yaml -f compose.smoke.yaml stop
docker compose up -d --no-build
```

Script P0 ghi đè báo cáo của lần cuối và proof tương ứng; lưu bản báo cáo cũ với tên ngày nếu cần so sánh. Fixture chỉ dùng kiểm tra vòng đời, không được dùng chứng nhận adapter.

## Còn thiếu trước public

Chưa kiểm chứng bài thực đã xóa và bài thực yêu cầu đăng nhập; chưa nghe/xem bằng người trên điện thoại thật, chưa thử đủ chất lượng hoặc nguồn IP VPS. Thêm mẫu có quyền sử dụng, chạy lại P0 và end-to-end từ VPS trước P5/P6. Không mở nền tảng khác dựa trên danh sách extractor của yt-dlp. Nếu smoke nguồn thất bại, tắt nền tảng trong admin hoặc bỏ khỏi VERIFIED_PLATFORMS.
