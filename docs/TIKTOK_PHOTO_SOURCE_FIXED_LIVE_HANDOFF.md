# Một workflow nguồn fixed — 15/10/2026

**PASS_TECHNICAL_NEEDS_VISUAL_REVIEW**. Đúng một lượt nguồn mới đã hoàn tất qua API/BullMQ/twochild/ownedegress; tải được actualJPEGindex2. Chưa nghiệm thu watermark bởi chủ/reviewer, chưa UIcombined/main/gallery/deploy. Lời giao mới trong `tiktok-photo-source-fixed-source-dispatch-20261015/human-assignment.json` đã dùng cho workflow này; không retry/reuse hoặc tự mở lượt tiếp.

## Thực chạy và phạm vi

```powershell
& ./labs/tiktok/photo-source-fixed/run.ps1 -ExecuteSource
```

Native outer0/khôngtimeout/55.4985709s bao gồm startup+cleanup. UTC15/10/2026 16:07:58.0970652→16:08:53.5895704, Việt Nam23:07:58→23:08:53. Mộtworkflow job `bfed43b5-0c33-4ec7-9787-82327567f30d`, sourceGrantNew=true/sourceExecutionStartedtrue. Preflight128source/36frozen/6successor giữhash/runtimefolderabsent;4cachedimageinspect0; runnerSHA `b1b606f2e6d9797d5cc34aaf16794905a53d822b56cd13f2b6ee0fb8ab10e6e7`. Không sửa source/pins/runner, không chạy lại tests/build/pull/install/browser.

Canonical `https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421`, index2/count5. Analyze→selectable→freshsummarySELECTION_MATCH với snapshot `8fa38af83f8dc423d4d78b8044d5d7b26ae3fdef9ec73eab59fe04f8475c2127`, theo guard bodyID/order/dimensions/itemKeys trướcprepare; descriptor lấy API mới. Không ghi fullmetadataHTML/signedURL/cookie hoặcdescriptorsecrets ra evidence.

Analyze2metadataattempt/2HTTPresponses/416138decodedB; freshprepare2metadata+1JPEGattempt/3responses/738180decodedB. Tổng5attempt/5observedresponses,1154318decodedB; metadata831663B/JPEG322655B, không cósourceHEAD/redirect/retry/fallback/ảnhkhác. `wireGET=UNKNOWN`: diagnosticsattempt/response không phải packetcapture;3CONNECTownedconnections không là3GET. Thấyresponse200 cho cả5 trongmedia diagnostics; không lấycounthealth làm authority.

Hai child PID/PGID riêng, actualIDs lưu trong analyze.native.json và prepare.native.json. Cảhai coreExit0/parentactualExit0/signalnull/groupLive0/registryProtectedtrue → phaseacceptedprooftrue → registryreleasefalse; không coi packetPASS là đủ. Consumer0/API143chủýstop/appcontainer0/proxycontainer0, không bỏ lỗi native.

## Tệp mới và visual

Actualfile `docs/evidence/tiktok-photo-source-fixed-runtime-20261015/source-once/cases/source/native-image.jpg`,2132×2132/JPEG/MIMEimage/jpeg/322655B. SHA256 `62308e76366aece0368f8c326f6430669fa4601ff1d963bb99378507091f5a8b` khớp historicalindex2 nhưng **file mới cần review mới**. Đã qua contract/2ffprobeactual0/fullDecode0/HASH; operations2probeelapsed1.165168s+0.717104s,decode0.571202s/hash0.03035s, khôngcrop/blur/re-encode/xóa chữlogo. LocalHEAD200/no newtransferlease/fullGET200/fullSHA+size/Range206bytes0–99 đúng100B; cácrequestnative này không tính nguồn.

Agent đã mở đúngfilemới bằng view_image (yêu cầuoriginal, toolpreviewresize2132→1600, bytesfile không sửa): nội dung tranhcậnmặt/chữ“Lights” cònnguyên, chưa thấy watermarkTikTok trongảnh đãxem. Đây là **agent observation**, không humanacceptance hoặc chứngminhabsencewatermark tuyệtđối. Giữ `NEEDS_VISUAL_REVIEW`; không tự áp humanaccepted5ảnhcũ chofilemới. Bản sao lossless trìnhreview ở `docs/evidence/tiktok-photo-source-fixed-live-20261015/runtime/cases/source/native-image.jpg` cùngSHA.

## DNS/proof và guard thực

Baownedcompletion mới dùngdiagnosticsP2:1analyze+2prepare, acceptedtrue/diagnosticCompletetrue/threadClosed/clientClosed/loopClosedtrue, traceIncompletefalse,24numericboundaries mỗirow/reasonCodes[]. DNSnativeexit0/reapedtrue/pipesclosedtrue/groupsLeft0/responseCodeOK/admissionOK. Hai metadata connections mỗi144rawrows/144validated/26unique/118duplicates/26admitted; image63raw/63validated/14unique/49duplicates/14admitted. Policy RAW_VALIDATE256_UNIQUE64_ORDERED, rawCap256/endpointCap64/publicstateALL_ALLOWED giữ, không bỏrawrow hoặc nângcap. Khôngloghostname/IP/answerrows/token. BodyTLSverifytrue, HTTPconnect≤10/read≤20/phaseclamp có hiệu lực theo recordedsettings.

CácfixDNSchild+diagnostics đều được runner reviewpin/mount dùng. Success lần này **không chứng minh DNSchildfix là nguyênnhân duy nhất của source-1 cũ**, vìlượt cũthiếuchildexit/path. Không suy mọiTikToklink hoặc galleryđạt từmộtảnh. Không chạyprobe/thửmạngphụ để “xác nhận” ngoài5attempt.

Actualtopology: app/PG/Redisinternal1network, proxyinternal+dedicatedbridge2networks/bridgeonlyproxy. Control exactinternalCIDR local+peer/newsecretRAM sanitized, nofixturemount/env.800MiB512/96/128/64/CPU.75/.25/.25/.25/PIDs160/96/64/32/nonrootRO/dropALL/NNP/privateIPC/noextraswap/noports/tmpfs giữ; noOOM. Metadata30/prepare180/HTTP10–20/item60/whole250/queue10/local20/appcleanup20/Dockercleanup20/watchdog360/bytecaps giữ. Caps không là peakRSS. PG/Redis đangrunning tại snapshotcleanupowner, không gọi State.ExitCode0 khirunning là nativeexit.

Physicalchildgroup/client/thread/listener/serveclosed và lease/mediaowncleanup đã ghi; evidencecopyhost giữ sau `/media/job`dọn. rm4owncontainers+2networks/absent0, cleanup2.9490171s<20/volumes0/ownResourcesLeft0. Không đụng stackmain/data/settings.

## Bàn giao

Runtime mới riêng `docs/evidence/tiktok-photo-source-fixed-runtime-20261015/source-once/`; gói bàn giao/verifier/manifest `docs/evidence/tiktok-photo-source-fixed-live-20261015/`.74runtimefiles đượccopylossless vàhash từngfile gốckhớp; logswhitelist/sanitized, không ghi nguồnHTML/pathquery/cookie/token/stack/message/repr. RawPowerShellwrapperstderrtrống.40artifactsprepare và manifest d179d…8acac nguyênbyte, oldsource-1/history không sửa. AUDIT/PROGRESS prependreceipt nối dispatchnguồnmới; khôngsửa historicalverifier/golden đểchạyxuyên docshash.

Đã dừng sauđúng1workflow thànhcôngkỹthuật. NEXT_PROMPT yêu cầu kiểmđộc lập/raw/native/gate/contract/DNS/counts/guards/cleanup và actualảnhmới để chủreview. Khôngnguồn nữa/retry/Attempt2/fallback/ảnhkhác/main/gallery/deploy. MộtảnhkhôngnghiệmthutảialbumUI/shortlinkAPI/browsercombined hoặcmọilinkTikTok.
