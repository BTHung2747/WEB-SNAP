# Runner nguồn ảnh DNS — wiring offline 11/10/2026

**PASS_OFFLINE_WIRING_PENDING_INDEPENDENT_REVIEW; SOURCE_NOT_AUTHORIZED.** Successor `labs/tiktok/photo-dns-source-trial/`, evidence `docs/evidence/tiktok-photo-dns-source-wiring-20261011/`. Source branch đã viết/defaultOFF; không TikTok/InternetDNS nguồn, real allocation/claim hoặc source invocation. Gate offline không đủ mở mạng: còn cần receipt review và human authorization thuộc nhiệm vụ nguồn riêng. Các file đó chưa tồn tại. Lab đã nghiệmthu/claims/latch cũ/apps/image/locks giữ nguyên.

## Mã và API

- Giữ byte-exact validators, DNS helper, connector/race, proxy HTTP/TCP parser, observer/accounting/batch/registry và photo library/fixtures. Chỉ sửa common.py (nối source policy), run.ps1 (namespace/capability/telemetry), source_contract.ps1 (inventory/gate/quota/claims); thêm policy/probes. Verifier so từng file kế thừa ngoài ba file đó.
- Source policy strict control stage/source+finite nonnegative nonbool deadline; reject fixture/CA/trust/proxy/netrc/accountcookie/header/browser env, fixture imports và trust sai. GuardedYDL.close có sẵn xóa cookie RAM. Không parser/solver/HTTP/TLS/getaddrinfo/Popen/selectors mới.
- Image startup có `/usr/lib/python3.11/sitecustomize.py` bảy dòng của distro, hash43d81125d92376b1a69d53a71126a041cc9a18d8080e92dea0a2ae23be138b1e. Đo/giữ bytes networknone; chỉ cho exact path/hash khi apport_python_hook absent; fixture hook khác vẫn reject. Không tắt sandbox/site hoặc đổi image.
- Bundled **PowerShell7.6.5/.NET10.0.11** dùng public CreateNew/FileShare.None/Flush(true)/Dispose và ConvertFrom-Json -DateKind String để giữ UTC đúng kiểu string trước TryParse. Tham khảo [FileMode/.NET10](https://learn.microsoft.com/en-us/dotnet/api/system.io.filemode?view=net-10.0), [ConvertFrom-Json/PS7.6](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json?view=powershell-7.6), [Requests2.34.2 adapter](https://raw.githubusercontent.com/psf/requests/v2.34.2/src/requests/adapters.py). Giữ thư viện public/pins trước, không deps/build/pull/install/host changes.

Image sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e; Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/aiohappyeyeballs2.7.1; trust9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f. LICENSE/NOTICE/vendor/locks giữ.

## Gate và source capability

Final **source423/runtime96/canonical hash a5492e613c9f322f52dd8ef2c78aa586df947df833e7194912734c6277dc1c06**. Đây là SHA CanonicalSource UTF8, khác SHA JSON pretty-print. Gate ghim exact code/runtime/image/trust/typedquota/16proof roles và full raw+harness inventory. Missing/type/unknown/hash/rawfile/proof drift reject. Không dùng preparation384/91/hash cũ; source runtime đối chiếu sealed inventory, recheck gate sau consumption trước egress và code after run.

Default disabled native20/SOURCE_OFF_NO_NETWORK; source thiếu hồ sơ native20/SOURCE_GATE_OR_HUMAN_TASK_REQUIRED_NO_NETWORK trước Docker/network/claim. Real runner không nhận Mock switch. Allocation strict typed version/taskID/allocationID/target/bodyID/type/index1/image/trust/code/gateSHA/quota/UTC/fixed namespace, bool/float không integer. Mock proof scope không thành source gate.

Nhiệm vụ human nguồn sau review (chưa thực hiện) cần tại root wiring:

1. independent-review.json: version1/status PASS_INDEPENDENT_SOURCE_WIRING_AUDIT/actualExit0/sourceCalls0/gateSHA/sourceHash/utc.
2. human-source-authorization.json: version1/status HUMAN_AUTHORIZED/scope ONE_PHOTO_SOURCE_TRIAL/taskID32hex/gateSHA/target/quota/reviewSHA/utc, ghi theo nhiệm vụ human rõ ràng. Đây là trusted local task artifacts liên kết hash, không chữ ký mật mã hoặc input API.
3. Fresh source-task/allocationID/allocation.json thuộc taskID đó, scope ONE_PHOTO_SOURCE_ALLOCATION. Root latch source-task/task-latch.json chống đổi allocationUUID tăng quota. CreateNew+Flush/dispose latch rồi source-claim.json trước network capability; duplicate/IO/cancel/crash giữa bước giữ consumed, không rollback/reset/UUID khác.

Hiện cả ba ABSENT/NOT_CREATED. Mock chỉ dưới mock/attempt-*/task-ID với suffix mock; invalid copy scope source bị reject, không allocation thật. Evidence nguồn/authorization tương lai là successor riêng: giữ wiring manifest/verifier nguyên bản, dùng successor kiểm frozen list/hash và bổ sung inventory mới; không sửa golden cũ để nhận thêm files/AUDIT. Raw proof folders giữ bất biến.

## Lệnh và bằng chứng thực

Shell C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe -NoProfile -File SCRIPT, cwd D:\WED SNAP; scripts dưới trong evidence mới.

| Lệnh | Kết quả |
| --- | --- |
| prepare.ps1 | baseline32.759files, successor riêng |
| run-cold.ps1 -Attempt1/2 | container20/tool1; SOURCE_IMPORT_POLICY nhầm distro startup là fixture |
| run-claims.ps1 -Attempt1 | script20/tool1 tại CONTROL do UTC tự parse DateTime; chưa latch |
| run-startup.ps1 -Attempt1 | native0, static distro startup path/hash/bytes |
| run-cold.ps1 -Attempt3/4 | 35/native0, intermediate code riêng |
| run-claims.ps1 -Attempt2/3 | 29mockcases/script0 |
| run-contract.ps1 -Attempt1/2 | container20/tool1 dimensions: fixture direct worker thiếu metadata guard, normalized widthnull vẫn JPEG; source guard vẫn đúng |
| run-contract.ps1 -Attempt3/4 | 5pipelines+3caps/deadline/native0 sau nối source_metadata_valid có sẵn |
| run-whole.ps1 | 12fresh intermediate fixtures1–12, raw giữ |
| run-cold.ps1 -Attempt5 | **final35/native0**, source cold policy/cookies RAM/3DNS cases |
| run-claims.ps1 -Attempt4 | **final29mockcases/script0**, quota/drift/duplicate/secondallocation/crash/cancel/IO/default-source blocked |
| run-contract.ps1 -Attempt5 | **final5pipelines+3caps/deadline/native0**, normal/type/dimensions/bodytimeouts |
| run-whole-final.ps1 | **final12fresh fixtures21–32**, same exact code before/after |
| run-revalidate.ps1 -Attempt1 | 29copies+12labels/native0 nhưng bind normal1 intermediate; harness giữ, không final proof |
| run-revalidate.ps1 -Attempt2 | **final29copies+12labels/native0**, bind normal21 đúng hash |
| build-gate.ps1; post-gate-probes.ps1 | exact gate/full raw pins;4raw evidence conflicts reject trong RAM, authorization còn thiếu |
| inspect-final.ps1 | exact85containers/48networks absent, mainimage giữ |
| insert-docs.ps1; verify.ps1 -Capture; verify.ps1 | docs insert nguyênbyte; freeze+readonly fullcoverage; actual checks/exits/UTC-VN ở terminal receipts |

Codeattempt1–5/codefinal/rawFAIL/harnessattempt1 giữ. Tool1 không thay native20. Finalizer copies là function return0/20, không native child20; native harness0 chỉ nghĩa test kỳ vọng xong. Không fullhistory37 rerun. Source/InternetDNS nguồn/realallocation/realclaim0.

## Fixture, negative và guards

Normal whole worker/proxy/validator/child0, bodyID7678209751167110421/typephoto/index1, metadata2GET+JPEG1GET internal. JPEG2170bytes/64×64/4096pixels/static1frame/fullDecodePASS/SHA3c94b9a6bbfab0c44c02d0c520dca952e23dc7a396e30a6ef3b0fe00bcc0cc3e. Đây là fixture, không ảnh nguồn/review.

Wrong-body/redirect/metadata-oversize/image-html/health-missing/preexisting/parent-nonzero/parent-expiry worker20/proxy0/validator20. Closure-live/missing worker0/proxy0/validator20/xóaownJPEG. Image-oversize LIMIT_EXCEEDED/worker20/proxy30/validator20, REQUEST_FINISH ERROR/traceincomplete nhưng helper/socket/thread/group0/noOOM và không ownJPEG/part. Named negative gate cho proxy0 hoặc30 chỉ với chứng cứ partial+physicalcleanup+byteerror; source thật gặp30 vẫn FAIL. Không clear trace hoặc suy lớp TCP exception chưa đo.

Contract networknone dùng library photo parent/worker/extractor/downloader thật với fake adapter/body: normal fullDecode/SHA/native0, wrong-type và dimensions metadataFAIL trướcprepare (fixture callback dùng đúng source validator), bodytimeouts reject. Hai substitutions chỉ deterministic fake body fields, không parser mới. BoundedBody/Budget thật kiểm decompressed8MiB-response/16MiBaggregate và deadline exhausted. Native PASS→exit20/expiry/kill qua wholeparent reject/dọnpart.

Cold35 gồm strict control/env/import/trust, cookieRAMclear/netrc/account-env và metadata ID/type/dim trướcprepare. Ba real helper numeric/AI_NUMERICHOSTerror/traceprimary: FD7→7/thread1→1/reaped/pipesclosed/group0/upstreamsocket0; toàncoldFD4→4/thread1→1. DNS_ERROR native0 nhưng resolutionFAIL; traceprimary identity/PARTIAL. Không DNS tên nguồn.

Receipt29+12labels: count0 có packet/file reject; outer/nested DNS exit/reaped/pipes/group type/missing/UNKNOWN/conflict PARTIAL/reject, elapsed khác nhau control0. Three original contradictions return20/xóaownJPEG; unrelated keep.bin SHA f630f2c173e4715bcce254c5a166449adc05729c2bcaa6b58f4e2f3b7fc21926 giữ; preexisting-conflict20 giữảnh/SHA. Private worker observer UID65534 denied; copy tests không worker/HTTP/helper mới.

Quota giữ một analyze≤2preparedmetadataGET30s8/16MiB+conditional1JPEGGET60s20/16MiB/workflow36MiB. Connect10/read20clamp/setup10/end−1reserve/policyC pair1–2/singleton.60/reap.10/stagger.25/interleave0/2socket4groupsprefix8/helper1answer64/trace256-owner32-map64. Worker512/.75CPU/pids96/UID1000 +egress96/.25CPU/pids64/UID65534=608MiB; validator96 sau stop, probes512/revalidation96/networknone. RO/privateIPC/RAMswap/capALL/NNP/nohostports/SSRF/allDNS/TLS/mount guards giữ. No redirect/retry/HEAD/fallback/ảnh2.

Runner workflowInvocations đọc typed worker receipt hoặc UNKNOWN, không theo stage; sourceCalls nguồn UNKNOWN_USE_REQUEST_ACCOUNTING và requestAccounting ghi preparedGET/sendBEGIN/status/decodedbytes thực. Cookies/token/signedURL/rawHTML/message/repr/stack nguồn không log. Baseline/history/raw/goldens/verifiers/humanreview/old-newconsumedclaims/latch/apps/mainimage e7f93577…d0184b giữ.

## Bước tiếp

[Review độc lập wiring](evidence/tiktok-photo-dns-source-wiring-20261011/NEXT_PROMPT.md), chưa source task. GatePASS không chứng minh mạng/metadata/JPEG nguồn. Source trước FAIL metadata/DNS_HELPER trướcTCP/responseCodeUNKNOWN_NOT_RETAINED/networkrootcauseUNKNOWN; ảnhnguồn/humanreview chưađạt, video2/3/mẫu3reviewchờ/main-gallery/API E2E-deploy giữ. Chỉ human nguồn task riêng sau review mới authorization/allocation/một analyze+conditionalảnh1; mọi lỗi dừng/no retry, technicalfilePASS vẫn human visual/watermark review.
