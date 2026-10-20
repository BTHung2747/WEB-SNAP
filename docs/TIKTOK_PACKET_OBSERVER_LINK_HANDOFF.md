# Packet–observer linkage, successor offline — 11/10/2026

Lab `labs/tiktok/wholephoto-linkage/`, evidence
`docs/evidence/tiktok-packet-observer-link-20261011/`. Old labs, apps, raw/golden,
manifests/verifiers/codecopies và source claim của trial trước giữ nguyên.

## Validation v3

Receipt v2 kiểm packet và observer độc lập. Hai synthetic counterexamples của audit
vẫn exact dù IDs khác hoặc send vượt prepared. Đây là lỗi validation, không bằng
chứng nguồn đã gửi dư GET. V3 liên kết nội bộ worker trước khi công bố COMPLETE.

Packet map phase/index→row/requestID; identical aggregate rows dedupe, mọi content
khác conflict. RID phải16hex và unique across budget indices/phases. Metadata và
prepare có index reset riêng nhưng requestID không reuse. ConnectionID có thể reuse
cho request mới; khi observer ghi connectionID thì nó phải khớp packet.

Observer map phase/requestID→boundary events; mọi extra/unaccounted RID, phase lệch,
RID trống/missing/malformed, repeated RID, missing/duplicate terminal đều PARTIAL.
Send/header phải thuộc Budget requests, send≤prepared≤caps; header cần sendEND.
HTTP_RESPONSE cần packet status hợp lệ, headerEND và sendEND. Adapter error không
được có response status/headerEND/bodybytes. Diagnosticstatus và packet terminal
summary khi có phải khớp observer. Không sửaIDs, thêmfakepacketrow hoặc bỏextraevents.

Known Budget accepted counts có thể giữ2/1 trong khi linked-send làUNKNOWN.
`budgetWithinCaps` chỉ packet budget; `withinBudget` v3 đòi exact linked evidence
và toànphase đủbằngchứng. `exact` false khi conflict/missing/partial/cap. V3 không
thay schema/API app. Lowerbounds là measurement, originReceipt luônUNKNOWN;
worker requestIDs không được truyền thành HTTP header hoặc sharedCID với proxy.

WorkerUID1000 đọc private observer600, export boundednumeric/enum0644. Validator
UID65534 chỉ đọc receipt, không chmod hoặc đọc privateworker observer. Final file
gate thêm accountingv3 exact/withinBudget vào native/file/trace/ownership gates.

## API và code giữ

Budget/Requests public observer hiện có được tái dùng; đọc API chính thức đúng
Requests2.34.2/urllib3-2.8.0. sendDiagnostic bọc HTTPAdapter.send; successful status
được quan sát sau send trả Response. Connection observer dùng public connect/
request/getresponse, lưu opaque IDs. Không parser/transport/solver/privatehelper mới.

- https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py
- https://github.com/urllib3/urllib3/blob/2.8.0/src/urllib3/connectionpool.py
- https://docs.python-requests.org/en/stable/api/

Pin/cache31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e,
Python3.11.2/yt-dlp2026.8.19/aiohappyeyeballs2.7.1/FFmpeg/Cobalt giữ.
LICENSE/NOTICE/AGPL/imputcontributors/PSF/J.Nick Koston và vendor locks giữ.
candidate/DNS/ownership/TCPindices/stock/main transport/scheduling không sửa.
No build/pull/install/dependency/host changes; source runner chặn trướcclaim/network.

## Bộ kiểm đã thực hiện

Targeted cuối probe2: 40accounting (15 kếthừa +25 linkage), 7TCPindex/coverage và
4batch, cả51case native0. Accounting controls valid giữnativeaccountinggate0;
disjoint/extraRID/phase/repeatedRID/empty-missing-malformedidentity/status-header-
send/diagnosticstatus/aggregatecontent/connection/partial/missingcontradictions có
**accounting_gate.py child exit20** thật. Gate này kiểm receipt, khác TCPnumericgate
và khác wholefile/source acceptance. Missing TCP terminal/tracecap vẫn TCPgate20.
Delegateidentity/FD/thread/socket cleanup giữ. Probe1 trước cập nhậtNOTICE/provenance
được lưu riêng; không dùng thay probe2 trên snapshot cuối.

Whole targeted đầu3case: observer-disjoint, observer-extra, observer-extra-preexisting.
Pipeline metadata→Cobaltpicker→JPEGfixture/contract/decode/SHA/nativeworker0 thực
chạy qua proxy96+worker512. Chỉ sau pipeline, offlinefixture inject mismatch vào
privateobserver600, lưu pre-injection log riêng và giữ nguyên packet. Receiptv3
partial/UNKNOWN, validatoractual20 dùparent/worker/proxy0/fileprovisionalPASS;
ownedimage.jpg bịdọn. Keep.bin unrelatedpreexisting giữSHA; historical32case vẫn
có test preexisting image.jpg theo hợp đồng cũ.

Whole acceptance:32contracts kếthừa +3negative mới=35cases cùngcode với probe2/
coldpolicy1/canonical runtime inventory. Filefixture control normal/latency phải
nativeparent-worker-proxy-validator0; trace/health/privateUID/SSRF/TLS/helperIPC/
epoch/deadline/cancel/tracefault/finalsummary/postfile/preexisting/cleanup giữ.
Runner0 của negative là expectation đúng, không phủnativevalidator20/worker20/proxy30.
Nguồn thật/DNSInternet/ảnh2/gallery/API E2E/main/deploy chưa thực hiện.

Lệnh: bundledpwsh -NoProfile -File run-probes.ps1 -Attempt1/2;
run-policy.ps1 -Attempt1; gate.ps1 -TestCanonical/-TestRuntime;
run.ps1 -Attempt1/2/3 -Caseobserver-*; run-suite.ps1 -Start4;
gate.ps1/-Verify và verifier mới. Actual UTC/VN/exit/hash/caps/cleanup ởnamespace mới.

## Bảo vệ và phần chưa thay đổi

RAM8GB chạy tuần tự; proxy96MiB CPU0,25 UID65534/pids64 +worker512MiB CPU0,75
UID1000/pids96=608, helper chungcgroup96/semaphore1. Validator96/networknone sau
roles dừng, singleprobe512/networknone. RO/swapRAM/capALL/NNP/privateIPC/sourceRO/
nohostports/2internalnets/TLSverifyTrue/SSRF/DNSwholeanswer/order/noresolveagain giữ.
Setup10/end−1reserve/connect10/read20/meta30/prepare60/body8–16+20–16MiB/workflow36/
IPC16–32KiB/64answers/JPEG8192/16Mpixel/redirect-retry-HEAD0/trace256-owner32-registry64.

Batch chỉ observation/đềxuất review riêng: first2stall cóthểtiêu globalremainingend,
thirdavailable chưa thử; source43IP khác reachable/rootcause UNKNOWN. 45immediate
failfixture TCPPASS nhưngowner32drop/nativeTCPgate20. Equalshare8,63/23≈.375s chỉ
~.125s chosecond sau.25; không hứa đủ45/TLS hoặc áp dụng cap/timeouts/familypreference/
new scheduling trong taskvalidation. SourceFAIL20/metadata5 của trial cũ, sourceclaim
đãtiêuthụ, ảnhnguồnmagic/decode/SHA/visualNOT_RUN/video2/3/mẫu3NEEDS_VISUAL_REVIEW giữ.

Chốt F-ACCOUNTING-PACKET-OBSERVER-LINK chỉ tại successoroffline khi targeted vàwhole
hash gate đạt. Bước tiếp review độc lập evidence/validation; transport hoặcsource
trial cần nhiệm vụ riêng, không suy filefixture thành nguồnPASS.

## Kết quả thực và phạm vi nghiệm thu

Bản mã cuối đã qua 51 probe (40 accounting, 7 TCP index, 4 batch) và 35 ca
whole pipeline. Ba ca mâu thuẫn mới đều có parent/worker/proxy exit 0, JPEG
fixture provisional PASS, nhưng validator exit 20; owned image.jpg được dọn.
Ca có keep.bin giữ nguyên SHA. Hai control normal/latency có native exit 0
ở tất cả các role, JPEG 2.170 byte, 64×64, full decode PASS; đây là ảnh giả lập.

Hash gate capture đạt 649 checks, source inventory 173 file và runtime inventory
77 file/role. `TestRuntime` có dòng stdout kế thừa “entire72”; inventory JSON
và kiểm so sánh toàn bộ thực tế là 77, không dùng nhãn stdout để xác định coverage.
Probe đầu trước khi hoàn thiện NOTICE/provenance được giữ riêng; probe thứ hai
và whole suite chạy trên đúng bản mã cuối.

Kiểm Docker bằng exact IDs xác nhận 117 container và 76 network do phiên này
tạo đều không còn. Main image vẫn là
`sha256:e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b`.
Native exit, UTC/VN, receipts, guards và hash nằm trong namespace evidence mới;
manifest/verifier mới bảo toàn 11.107 file baseline và hai phần lịch sử tài liệu
bằng successor chỉ chèn nội dung mới. Kết quả verifier được ghi riêng tại
`verification-result.json` và native exit tại `verification-native.json`.

Finding chỉ được đóng **offline**. Transport, timeout, source claim và kết luận
nguồn thật giữ nguyên. Chưa gọi TikTok, chưa tải ảnh nguồn, chưa deploy.
