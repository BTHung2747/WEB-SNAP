# TikTok app core integration — 09/10/2026

**Core đã tích hợp vào apps/media và kiểm CLI/API-worker bằng fixture offline. TikTok vẫn tắt trên main; chưa nguồn/API E2E/deploy.** Mẫu3 lab vẫn NEEDS_VISUAL_REVIEW, accepted2/3; không dùng kỹ thuật/fixture để nâng3/3.

## Hợp đồng hai phase

Worker tiếp tục gọi python3 /app/infra/media_adapter.py analyze|prepare URL jobfolder [format], detached ProcessGroup/stdinignore và deadline/workerToken cũ. TikTok default-off dispatcher thêm ở đầuscript; toànnhánhYouTube từ importyt_dlp giữ nguyên từngbyte, khôngđổiYTselect/options/errors. Worker chỉ thêm ADAPTER_ANALYZE_TIMEOUT/ADAPTER_PREPARE_TIMEOUT từlimits; lifecycle/process-group/processor/API/shared/schema/UI/CSRF/nativelease khôngđổi.

Analyze vàprepare làhai child độc lập, khôngđợistdin hoặcgiữjarworker qua selectable/queued. Analyze≤2metadataGET; prepare táiextract≤2metadataGET vàchỉdownload≤1MP4 khiID/formatvalid. TổngworkflowlongURL≤5GET, khácpipeline lab3GET. Metadata30 nằmtrongprepare180, respectappsmallerlimits; HTTPconnect10/read≤20,totalremaining, decoded8MiBresponse16MiBmetaaggregate, per-phaseinputapp≤250MiB inclmetadata+MP4/output≤200MiB/duration≤600. SourceAPI có thểfail đúnglimits nhỏ hơn, khôngnới đểpass.

High yt-dlp extract_info(processFalse) vàprocess_ie_result/native downloader cùnginstance chỉtrong mộtpreparechild. Cobaltvalidator dùngbodyRAM cùngparser/vendorghim đểkiểmactualbodyID/content/duration, khôngfetchphụ. Format publicID tt1_nativeID_digest gồmpublicid/codec/dimensions/duration; signedURL/cookie không nằmtrongfingerprint hoặcDB. Prepare tínhlại exactID, changed/missing→FORMAT_UNAVAILABLE trướcMP4, khôngautoformat/downloadAddrfallback. Play/H264+audio/MP4/nonDRM/nonwatermarked/noHLS policygiữ; publicformats giới hạn30. TitleURL redacted, khôngpreviewfetchphụ. Shortlink/photo/unsupported failclosed; khôngclaimshortlinkE2E.

Output media.mp4, analyze title/duration/formats vàprepare file/size/inputBytes JSON cũgiữ. InputBytesprepare tínhcảdecodedmetadata mới+MP4. MP4/containerbrand/H264+audio/durationtolerance/selectedwidth-height/full decode/SHA kiểm; decode remainingprepare−10reserve, exhaustedfailurebeforePopen. Cookie/sourceURL/HTML raw chỉRAM/privatepipe, closejar khi childexit, noprofile/account/cache/cookiefile/netrc. Khôngsource secrets trongDB/tệp/log.

Folderphải trực tiếpunderMEDIA_ROOT/nameUUID, nosymlink/rootescape; preexistingfixedmediafilesfail khôngoverwrite/delete. Failure chỉunlinknewownedmedia/.part/.ytdl; diagnostics ownjobpath O_NOFOLLOW vànumericfixedfields. Nativevalidator/FFprobe/FFmpeg khôngdetach, ởworkerProcessGroup; cancel/expiry/timeout vẫnwaitconfirmedgroup trướcleases/filescleanup, quarantinepolicycũgiữ.

## Core/library/provenance và packaging

apps/media/src/tiktok gồmminimalcore, adapterglue, filecontract/Operations/sanitizeddiagnostics, CobaltRAMvalidator/vendor, LICENSE/NOTICE/UPSTREAM/INTEGRATION/PROVENANCE vànpm package-lockSRI. Khôngrunner/driver/fixture/verifier/benchmark trongruntimecore. Cobaltcommit a636575b09de1fc55d9b8cd98cac88f5f2f16b42/AGPL3/imput+contributors giữ; vendorfilesexactSHAcopies. Adapter/newpublicformatfingerprint/ownedpaths/phasebudget làglue WED SNAP, khôngparser/solver/HTTP/TLS/decoder mới.

APIreuse xácminh [yt-dlp2026.08.19 YoutubeDL](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/YoutubeDL.py), [TikTok extractor](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/extractor/tiktok.py), [Requests2.34.2 adapter](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py); core/validator/policies nối từlab đãnghiệmthu, source pins vàmodifications ởPROVENANCE/NOTICE. Runtimeactualyt-dlp2026.8.19/Requests2.34.2/urllib3-2.8.0/Brotli1.2.0/FFmpeg5.1.9 và5npmdeps undici6.24.1/set-cookie-parser2.7.2/@imput-psl2.0.4/url-pattern1.0.3/punycode2.3.1 khớp.

apps/media/Dockerfile vàrootDockerrecipe thêmminimalnpmci khóa; rootCOPYproductonly(apps/packages/prisma/adminscript/config), khôngcopylab/test vàofutureproductruntime. Khôngbuild cácrecipeproduction này trongnhiệm vụ. Labimage COPY-only từ cachedmain e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b vàCobalt5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6; 5npmdeps copy từlockedcachednode_modules, khôngregistry/pip/installWindows. FinalintegrationimageID d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e. Runtimechecksha củaexecutables/packages/locks/license chứngminhhostcode=testedimage; NOTICE/PROVENANCE documentation cậpnhật sautest khôngđổilogic.

## Kiểm đã thực chạy

| Môi trường/case | Kết quả |
|---|---|
| CLI5network-none512MiB/CPU0,75 |19casesPASS; actualextractor/nativechallenge/Requests fakeadapter/Cobaltvalidator/downloader/FFmpeg đi qua haiPID riêng|
| Contract/workflow |2GETanalyze+2GETpreparemeta+1GETMP4; SHAinput/output synthetic26531byte khớp, media.mp4/JSONoldschema|
| Freshselection/body |changedpublicformat/bodyIDreject trướcMP4; nofallback|
| Limits/ownership |lowerinput/output/duration/prepare10reserve/symlink/preexisting/actualmediawrongdimensioncleanup đạt|
| Negativepolicy |private/age AUTH_REQUIRED, watermark-only CONTENT_UNAVAILABLE/noMP4, redirectreject/decodedoversize đạt|
| YouTube |legacycodebyte-identical; two-phasefixture/probePASS, no realsource/extractorclaim|
| API2fixture |Nest/Prisma/BullMQ/worker thật, DB/Redisown tmpfs/internalnetwork/noports, caps960MiB|
| APIguards |CSRF403/foreignjob404/foreignticket410/idempotentprepare/nodeadchild retained acrossselectable|
| Transfer |nativefull200+Range206/100bytes; two server_finishedleases, source/hashbyteequal|
| ProcessGroup |cancel/ownerexpired/deadline vớihelperignoreTERM, PIDgroup0/token/processleaseclear/ownfolderdeleted|
| Codevalidation |runtimepinsPASS; TypeScriptcurrentshared/API/prisma-clienttmpfs typecheck2exit0|

Fixtureloader/sitecustomize chỉmountở/fixture vàexplicitTIKTOK_APP_FIXTURE labenv; khôngcopy trongruntimecore/imageproductrecipe. Runtimebridge vẫnprepare_request/HTTPAdapter.send/boundedread thật, fixture thay response transportdata nguồn đểnetwork0. YouTube fixture doubleextract_info/process_result nênchỉsmokelegacybranch/fileprobe; TikToknativeparser/challenge/downloader/contract thật. KhôngTikTok/YouTube sourceGET, khôngexternalAPI E2E hoặc watermarkclaim.

APIlabpostgres128MiB/redis64MiB/app768MiB total960MiB; RO/nonroot/capdropALL/NNP/privateIPC/PID/sourceRO/noports/internalnetwork; DBdatatmpfs/migrate/testsettings chỉprivateendpoint tiktok_app_fixture/Redis7. MainDB/settings/volume/env khôngđọc/ghi; mainimages/compose/.env giữhash. Khôngwebtest/UI redesign/frontendbuild.

## FAIL history và cleanup

Buildfirstexit1: FROMlocalimageID bịDockerhiểu thànhrepository; sửa sangexistingcachetags verifiedexactIDs, raw giữ, noimagedeployed. COPYbuildnext0 vàdimension/outputguardcopyupdate0, noinstall. CLI1exit1 sourcebindche imagenodemodules, bỏbindđó vàkiểmactualruntimehash; CLI2exit1 expectationwatermarkFORMAT_UNAVAILABLE sai, actualpinnedvalidatorCONTENT_UNAVAILABLE/noMP4; CLI3/4/5pass. Khôngsửaformerraw đểépPASS.

API1functionalPASS nhưngrunnerouter1: Composeuprecreatedapp, trackedoldIDcleanupfailed. OwnerfilteredactualIDs/net đượcguard/capture/remove đúngrun, cleanup-repair0left; API2usesstart-only nênbeforestartIDs=actualtestedIDs/outer0/cleanup0. Typecheck1native2/outer1 vìcacheshared/Prismacũ khôngkhớpcurrentworker; typecheck2sourceRO/currentgeneratedclienttmpfs0, khôngschemachange/mainDB. Toolpatchsyntax/contextpreflights trướcghi đượcghi nhận; khôngsourcecalls từcáclỗi này.

Allfinal owncontainers/networks0; historical/main khôngprune/reset. NativeUTC09/10: CLI5 03:56:32.992–03:56:51.128 (VN10:56:32.992–10:56:51.128); API2start03:47:30.102/waitend03:48:01.431(VN10:47:30.102–10:48:01.431), cleanup03:48:03.603/VN10:48:03.603. Typecheck2completionUTC04:08:43.221/VN11:08:43.221. Lệnh/exits khác xemnative.jsonl riêngtừngattempt.

## Lệnh và bàn giao

~~~powershell
cd 'D:\WED SNAP'
docker build --network=none --pull=false -f labs/tiktok/app-integration/Dockerfile -t wed-snap-tiktok-app-integration:20261009 .
$pwshI='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
# Cáccli1..5/API1..2 làhồsơ trước khi runner đượcparameterize; khôngoverwrite:
& $pwshI -NoProfile -File labs/tiktok/app-integration/run-cli.ps1
& $pwshI -NoProfile -File labs/tiktok/app-integration/run-api.ps1
& $pwshI -NoProfile -File labs/tiktok/app-integration/run-cli.ps1 -Mode typecheck -Attempt 1
& $pwshI -NoProfile -File labs/tiktok/app-integration/run-cli.ps1 -Mode typecheck -Attempt 2
& $pwshI -NoProfile -File labs/tiktok/app-integration/verify.ps1 -Capture
& $pwshI -NoProfile -File labs/tiktok/app-integration/verify.ps1
~~~

Currentrun-cli hỗtrợModecli/runtime/typecheck vàAttempt mới, refusereuseddirs. Currentrun-api giữapi2 evidence-exclusive; cầnnewnamespace/nhiệm vụ nếuđượcgiao test thêm. Không dùng lệnh đểsource/deploy.

Evidence docs/evidence/tiktok-app-integration-20261009/ cóbefore2876files/exactsnapshots/provenance/attempts/build/pins/CLInegatives/two-phasePIDs/actualJSON/SHA/APIleases/groupstates/privateguards/nativeUTC/cleanup/mainoff/verifier/successor/manifest. Oldgolden/raw/verifiers/labCobalt/renderer/history/archives/video/humanreview1+2+pending3 giữhash, khôngrunnerfixturelab đượcnhập vàoappsruntime. HồsơSTRUCTURE/ADAPTERS/TEST_REPORT/PLAN/AUDIT/PROGRESS cậpnhật đúngoffline scope.

Verifier mới -Capture đầu exit1 trước ghi manifest do đã đòi CLI3 (image trước cập nhậtdimension/outputcap) khớp image cuối. Sửa đúng verifier mới để giữ CLI3 là evidence trước, gatefinal chỉCLI4/5/API2/runtime/typecheck2 cùngfinalimage. Raw/receipt/image cũ khôngsửa, khôngsource/testhistory rerun; verifier-preflight.json giữ cause.

DefaultgateTIKTOK_ADAPTER_ENABLED không1 nênoff; mainverified/environment/data/settings chưabật. Mẫu3reviewcònchờ/accepted2/3. Source/API E2E thật/no-button/shortlink/negativeactualsource chỉxét saureviewmẫu3 vànhiệm vụriêng. CodefixturePASS khônglàdownloadwatermarkacceptance hoặcquyềnmainapply/deploy.
