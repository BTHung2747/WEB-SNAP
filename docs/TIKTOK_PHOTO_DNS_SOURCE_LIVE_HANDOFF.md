# Trial ảnh nguồn DNS — 12/10/2026

**SOURCE_FAIL_STOPPED_AT_METADATA_DNS_ANSWER_CAP.** Một runner source invocation duy nhất theo nhiệm vụ human, target public `https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421`, bodyID7678209751167110421/typephoto/index1. MetadataFAIL CONTENT_UNAVAILABLE trước origin TCP/header/body; prepare0/JPEG0/visual NOT_REVIEWED. Không retry/HEAD/fallback/ảnh2 hoặc thay mạng/timeout/cap/transport. Không main/gallery/API E2E/deploy. Evidence successor `docs/evidence/tiktok-photo-dns-source-live-20261012/`; runner/lab/source/libs/images/gate nguyên byte.

## Nguyên nhân quan sát và giới hạn

DNS helper receipt mới ghi **statusERROR/codeANSWER_CAP/typeOBJECT/answerCount0/evidenceCOMPLETE/resolutionFAIL**; native helper0, reapedtrue/pipesclosedtrue/group0/inheritanceCleantrue/helperThreads1, IPCresponse87bytes. Outer elapsed1.425205868s, nested1.436621784s (khác thời điểm, không ép equality). COMPLETE ở đây là chẩn đoán đầy đủ, không DNS PASS; finalizer DNS gatefalse/PARTIAL, batchNOT_STARTED/PARTIAL như kỳ vọng lỗi trước connector.

Trong `dns_helper.py` đã ghim, hostname mode dùng stdlib socket.getaddrinfo(host,443,typeSOCK_STREAM); nhánh ANSWER_CAP chỉ xảy ra khi len(answers)>64 và deadline chưa hết, rồi trả answers=[] thay vì danh sách. Vì thế suy luận có căn cứ từ code+receipt rằng raw resolver entries vượt64; **exact count, unique count, duplicate/family breakdown không được giữ**, không biết tại sao môi trường trả nhiều entries. IPCanswerCount0 là kết quả guard bỏ answers, không phải DNS không có địa chỉ. Không log hostname/IP/answers hoặc thêm DNS query để tìm hiểu.

Proxy trace có DNS_HELPER BEGIN→ERROR1.4252s, DNS_RESULT0/TCP_CONNECT0/CONNECT_OK0; socketPeak0/socketsLeft0/setupFinishedfalse/batchNOT_STARTED. Client CONNECTION_SETUP ERROR/OS_ERROR1.53187s, timeout10; Adapter.send PROXY_ERROR1.5407s. Đây là boundaries quan sát, không tách client TCP-to-proxy/CONNECT/TLS riêng. Source TCP/TLS không đạt theo proxytrace; source header/status UNKNOWN/body0. Không đoán CDN/nguồn từ lỗi này.

requestAccounting v3 exact/withinBudget/linkageCOMPLETE/observerCOMPLETE: **preparedmetadataGET1/prepareGET0**, adapterAttempts1/0, requestSendBEGIN0/0/headerEND0/0/httpstatuses[]/decodedbytes0/0. Workflow/analyzeInvocations1/sourceAnalyzeAttempts1/sourceCalls UNKNOWN_USE_REQUEST_ACCOUNTING; prepared GET không chứng minh request đã được origin nhận. Metadata packetFAIL, parent20/workerChild−9(signal9) do parent terminate/reap sau FAIL, workercontainer20/proxy0/validator20/runner20. Không file/JPEG/visualPASS.

Lượt lịch sử trước cũng có87bytes nhưng không giữ code, vẫn **UNKNOWN_NOT_RETAINED/networkrootcauseUNKNOWN**; không áp ANSWER_CAP mới ngược vào raw cũ. Lượt mới chứng minh guard ANSWER_CAP đã kích hoạt; underlying resolver/network cause và mọi khả năng tải ảnh nguồn còn UNKNOWN.

## Review, gates và claim

Precheck mới PASS baseline35.245files +2.484 frozen audit/wiring artifacts, sealed auditPASS/newFindings0. Source423/runtime96/canonicalhash **a5492e613c9f322f52dd8ef2c78aa586df947df833e7194912734c6277dc1c06**, gateSHA **88d03e9c65e9b2444044647ad6926545c354fff822d5f5df9f8da43897016221**, raw737proofs/harness/image/trust/mount pins đúng. Không sửa code/proof/gate/goldens để mở nguồn. Exact review bytes copied CreateNew và linkedSHA tại fixed SourceRoot; human authorization ghi theo task này, scope ONE_PHOTO_SOURCE_TRIAL/typedquota.

TaskID **2713473edcf94a139dd91d1d82939d0a**, allocationID **a0c19e584c614c9badfa47bbc46b35b2**, scope ONE_PHOTO_SOURCE_ALLOCATION. Original source evidence tại `docs/evidence/tiktok-photo-dns-source-wiring-20261011/source-task/a0c19e584c614c9badfa47bbc46b35b2/`; exact copy toàn raw vào live/source-task-copy. Root latch/source claim **CONSUMED_BEFORE_NETWORK_CAPABILITY** giữ nguyên, không reset/reuse/UUID khác. Wrapper có source-invocation.json CreateNew trước gọi runner; sourceInvocations1. Claim/latch UTC chứng minh consumption trước first network creation, verifier đối chiếu.

Wiring/audit manifest+verifiers giữ; successor verifier kiểm frozen hashes với AUDIT/PROGRESS before-substitution khi cần, fullcoverage source artifacts/copies/capability+newdocs riêng. Không chạy verifier lịch sử Capture hay sửa inventory cũ nhận thêm file.

## Lệnh thực và native kết quả

Shell `C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe -NoProfile -File SCRIPT`, cwd D:\WED SNAP. Scripts trong live evidence.

| Lệnh | Kết quả thực |
| --- | --- |
| prepare.ps1 | readonly gates/review/image/manifests+baseline PASS, source invocation0/claim0 lúc đó |
| run-once.ps1 | materialize authorization/allocation, đúng **một** nguyên runner source invocation; wrapper/script20/tool1, marker runner20/worker20/proxy0/validator20 |
| collect.ps1 lần1 | tool1 ở biến PowerShell Error chỉ đọc; chưa ghi cause, giữ script collect-attempt-1 và failure; không nguồn thêm |
| collect.ps1 sau sửa biến local | exit0, thu raw/cause/hash/cleanup và exact copies; chỉ thu hồ sơ, không sửa runner/source |
| annotate.ps1 | exit0, đối chiếu ANSWER_CAP với pinned helper code, phân biệt quan sát/suy luận/UNKNOWN |
| insert-docs.ps1 | chỉ chèn AUDIT/PROGRESS, history nguyênbyte |
| verify.ps1 -Capture; verify.ps1 | freeze manifest successor và readonly integrity; terminal receipts ghi actualchecks/exits |

Lệnh source thực (đúng một lần, không được chạy lại):

```powershell
& 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe' -NoProfile -File labs/tiktok/photo-dns-source-trial/run.ps1 -Stage source -AllocationPath 'D:\WED SNAP\docs\evidence\tiktok-photo-dns-source-wiring-20261011\source-task\a0c19e584c614c9badfa47bbc46b35b2\allocation.json' -GatePath 'D:\WED SNAP\docs\evidence\tiktok-photo-dns-source-wiring-20261011\offline-gate.json'
```

Invocation runner UTC **2026-10-12T00:36:00.4261684Z→00:36:48.2815112Z**, VN **07:36:00→07:36:48+07**. Khoảng47.86s bao gồm gates/claim/Docker/init/stop/validator/cleanup; không thời gian metadata HTTP. DNS fail1.43s trước body. API thư viện/glue đã xác minh ở wiring task: dùng nguyên public Requests/urllib3/stdlib/.NET CreateNew+Flush, không thêm implementation/dependency hoặc officialAPI suy đoán mới.

## Guards và cleanup

Quota giữ≤2metadataGET/30s/8MiBresponse16MiBtotal +conditional1JPEGGET/60s/input20MiB/output16MiB/workflow36MiB. Connect10/read20clamp (effective total29.909458119s)/setup10/end−1reserve/policyC pair1–2/singleton.60/reap.10/stagger.25/interleave0/2socket4groupsprefix8/helper1answers64/trace256-owner32-map64. Không tăng cap sau ANSWER_CAP.

Worker512MiB/.75CPU/pids96/UID1000 +egress96MiB/.25CPU/pids64/UID65534=608MiB, validator96 networknone sau stop. RO/privateIPC/swapRAM/capALL/NNP/nohostports/sourceROmounts/privateUID/SSRF/allDNS/TLS và original trust9cc2…730f giữ; source env không fixtureCA/ExtraHosts/account/profile/proxyoverride. Image31742091…dfa417e/mainimagee7f93577…d0184b giữ. Runtime/code before-after đúng, cold proxy/worker isolation sourceSafe/no fixture imports.

Exact **3containers/2networks** mới absent, sourceproxy accepted1/closed1/workerReturned1/errors0/socket0/thread0/helper0/group0; helper pipesclosed/reaped. Private observer/mount permissions không nới. Own JPEG/part không có, preexisting không có; history và unrelated files/old claims SHA được baseline kiểm. Integrity PASS không sourcePASS.

## Bước tiếp

[Kiểm độc lập kết quả nguồn](evidence/tiktok-photo-dns-source-live-20261012/NEXT_PROMPT.md), không trial mới. Có thể điều tra **offline** vì sao policy đếm raw getaddrinfo entries và cách phân biệt raw/unique/duplicates bằng API đã ghim; trước sửa phải review bảo vệ all-DNS/public-IP và bounded policy, không âm thầm tăng64/truncate/filter địa chỉ làm né guard. Không source query hoặc đổi transport/timeout trong review. Nguồn/ảnh/humanvisual chưa nghiệmthu; video2/3/mẫu3reviewchờ/main-gallery/API E2E-deploy giữ.
