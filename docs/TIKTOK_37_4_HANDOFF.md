# Bàn giao37.4 — 07/10/2026: chuẩn bị xong, chưa chạy nguồn

**PREPARED / NOT_RUN: thiếu mạng khác do chủ cung cấp, thông tin/quyền đường truy cập và cách kiểm chứng outbound thực của lab.** Chưa chạy analyze trên cả mạng hiện tại lẫn mạng khác:0/2lượt, metadata/target/marker/byte/exit của nguồn đều NOT_RUN. Không suy dữ liệu37.3 thành kết quả37.4.37.3 đã được audit nghiệm thu image/đối chứng theo phạm vi, A/BmetadataFAIL; TikTok/P0/P2/no-watermark vẫn chưa nghiệm thu. Thực hiện nhánh chuẩn bị được giao khi điều kiện mạng chưa đủ.

## 1. Kế thừa và phạm vi

Đã đọc AGENTS/PLAN/PROGRESS/kết luận nghiệm thu37.3 và toàn bộ chỉ thị37.4, ADAPTERS/TEST_REPORT/handoff373. Trước sửa: manifest373SHA `f46fcf1a35ee369538935b01b6e97484219b9f35c0d001c5d514fb1be8ded1fe`, selfmetadata đúng;74/74entries ngoàiAUDIT giữ SHA/bytes. LiveAUDIT mới đã khác hash cũ do phiên nghiệm thu được giao; ghi đúng currentSHA vào `predecessor-373-proof.json` trước lần cập nhật374, không sửa manifest/verifier373 để tạoPASS.

`before-all-sha.json` chốt1.558file; `frozen-current/` giữ source runner/probe/Compose373 và4docs trước sửa. Source/executed-source/raw/manifest373, lịch sử19–37.3, production adapter/config/deps giữ nguyên. Chỉ thêm package374/evidence374/handoff374, cập nhật4docs được giao. Successor374 kiểm đúng hash trước/sau của4docs; không exempt source/raw hoặc bỏ qua bất kỳ sai khác khác. Kết luận audit373 giữ trong lịch sử; trạng thái374 mới không thay nghiệm thu đó.

## 2. Package dùng lại thư viện và cấu hình

Không rebuild/install/upgrade: cached imageB `sha256:c66f52eace47d01e59a54c4b37f2d4d3db8b65326abff670b3673cb7d8900d8f`, yt-dlp2026.08.19; egress `sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10`. Offline guard kiểm imageID thực trước start. Không đổi base/main/production/settings/.env, Windows/VPN/router/WSL/Docker hoặc dịch vụ của chủ.

Ưu tiên yt-dlp/curl_cffi đã có. [YoutubeDL.py đúngtag](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/YoutubeDL.py#L720) nhận `http_headers` và merge giá trị được cấp sau defaults; [ImpersonateRequestHandler](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/networking/impersonate.py#L110) chọn target từ requestextension/default và có thể loại header bằng default trước curl thêm profile headers. [_curlcffi.py](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/networking/_curlcffi.py) gọi chuẩn bị headers rồi Session.request; không dùng API transport phỏng đoán hoặc ép extractor đổi extensiontarget.

Phần tự viết chỉ là glue chẩn đoán/gate hữu hạn mà runner373 A+B chưa có: singleB mỗi mạng, freezeheaders/options, so markerbyte cuối với aggregate, nhãn mạng và điều kiện quyền/proof trước request. Probe374 kế thừa instrumentationfinalautoclose373; thư viện vẫn thực hiện metadata/redirect/HTTP/TLS/parse. Guard374 lấy từ guard/Native/cleanup373, đổi label riêng và thêm argv trong log; không nới egress/SSRF/cap. Không cài thư viện mới hoặc tham khảo Cobalt để viết resolver khi chưa có metadata.

- `probe_374.py`: một analyzeB, cùng originalshortURL `https://vt.tiktok.com/ZSbxenGuS/`; cookie jar mới độc lập, no-solver như373. Headers4trường cố định qua option chính thức; UA cố định Chrome136/macOS, không UA ngẫu nhiên của defaults. Requestedtarget `chrome-136:macos-15` giữa cả hai lượt; **actualtarget của từngHEAD/GET vẫn lấy response.extensions**, có thể khác vì extractor. Thu safe preparedheaders từ helper upstream trước send; đây chưa là toàn bộ headers trên wire sau curl thêm profile/cookie nguồn.
- `run-374.ps1`: stages offline/prepare/analyze/summary; analyze chạy đúng1B, mỗi slotcurrent/alternate chỉ một directory, từ chối lặp/đổi source/config; case lock cho chạy tuần tự. Không dùngrun373ab hai lần. Metadataexit0/20 tách harnessfailure30 và missingcondition40. Summary nhận targetunknown khi dispatch lỗi, không suy từ requestedtarget; đánh dấu limit nếu sequence/actualtarget/preparedheaders khác hoặc byte/aggregate không nhất quán.
- `compose.tiktok-lab-374.yaml`: ghim trực tiếp2imageID,2services; probe384MiB+egress96MiB=480MiB, swap=memory, CPU/PIDs như373; privateinternal/sourceRO/rootfsRO/capdrop/privatePID/noports/noDB/mainenv. Cácactualguard/ownership/commands chạy lại trước start khi có đủ mạng. Composepreview đã render, **chưa create/start topology2services**.
- Caps giữ8MiB/response/16MiBaggregate và30s tổng/analyze; khôngprefetch/outerretry/download/solver. Report chứa metadata/formats/sourceURLs đã sanitize, byte/encoding/markerfinal, native/container exits và UTC/VN. `response_bytes_sum == total_decoded_bytes` cần đúng để nhận diagnostic; không lưu body/cookies/signedquery/IP trong report công khai.

CanonicalconfigurationSHA `6c2c655ffc39af3c658c6b58c26da013b504092fb4f32f4d39bf4d05a7bc6121`. Case đang dùng: **`docs/evidence/p37-4-20261007/network-case-final/`**, chứa fixedconfiguration/configpin/sourcepin/preparation. Caseprepare đầu `network-case/` được giữ evidence, đã superseded sau sửa nhỏ summaryunknown/methodreference; sourcepin cũ sẽ failclosed, không dùng nó chạy nguồn. Không overwrite record cũ.

## 3. Điều kiện còn thiếu và xác minh mạng

Chủ cần cung cấp tên tham chiếu không nhạy cảm cho hai mạng, mạng khác sẵn có (ví dụ hotspot), quyền dùng/cách truy cập và tự chuyển host khi cần. Agent không tự chuyển adapter/router/VPN hoặc ngắt dịch vụ. Hiện chưa có các thông tin này; câu hỏi làm rõ đã gửi trong phiên, không coi chưa trả lời là quyền dùng mạng bất kỳ.

Cần chốt **cách xác minh đường outbound của chính lab egress đã thay đổi**, bằng một phép kiểm có sẵn/được phép hoặc privateproof do chủ/operator kiểm. TênWi-Fi/Windowsroute hay IP của browserhost đơn lẻ không đủ chứng minh Docker/WSL/egress đi qua mạng khác. Không chọn hoặc gọi publicIPservice tùy ý; chưa có endpoint/phương pháp được cung cấp nên không chạy phép đo mạng.

`network-plan-374.example.json` và `network-proof-374.example.json` là template cố ý có false/blank, không đủ điều kiện gọi nguồn. Plan xác nhận cả hai mạng đã có/được phép trước lượtcurrent. Receipt riêng cho từng lượt chứa thời điểm≤10phút, slot/label/methodreference, opaque privatelysalted routeToken khác nhau và SHA của privateevidence đã kiểm. Giữ rawIP/salt/routingproof ngoài publicevidence; không dùng unsaltedhashIP. Token thay đổi không được bịa chỉ vì đổiSSID.

**Giới hạn gate:** runner kiểm cấu trúc/độ mới/sourcepin/configpin/receipt khác nhau; không tự đo hoặc xác thực provenance của outboundproof bên ngoài. Boolean/routeToken tự điền không phải bằng chứng thực. Chỉ cho phép dùng receipt sau khi operator/agent đã đối chiếu privateproof thực của own-egress theo phương pháp được giao. Nếu chưa kiểm được điều này, vẫn NOT_RUN, không chạy mạngcurrent trước để tiêu một lượt.

Khi có đủ điều kiện: giữ mạngcurrent ổn định suốt analyze1, cleanupownlab; chủ chuyển sang mạngalternate, kiểm lại own-egress proof rồi analyze2 với cùng config/source/image. Ngừng sau2lượt dù cảhaiFAIL. Nếu actualheader/target khác, ghi comparabilitylimit; không quy chắc chắn choIP/TLS. Metadata khác giữa2mốc là bằng chứng nhạy với điều kiện mạng tại hai mốc, không bảo đảm mọiIP/ổn định. Nếu cảhaiFAIL, cause còn mở; không tiếp tụcsolver/proxy/thirdpartylibrary. Cómetadata mới giao bước nguồnplay/download/3file/visual/no-buttonE2E riêng.

## 4. Kiểm thực sự chạy trong phiên

| Kiểm | Môi trường/kết quả | Giới hạn |
|---|---|---|
| Predecessor |75entries373;74/74 ngoàiAUDIT đúngSHA/bytes, manifestselfSHA giữ | Offlinefile/hash, không rerun373runtime |
| Missingnetworkgate | Gọi run374 -Stageanalyze không cóplan/proof: actualexit40,0Docker/0source | Nhánhmissinginput thật, khôngdouble; khôngmetadataFAIL |
|3fixture nhỏ | CachedB/networknone/256MiB/user1000/RO/capdrop/PIDs64/CPU0.5;3/3PASS, native/container/runnerexit0 | HaiYoutubeDLobjects khôngrequest: effective/preparedheaders+target cố định vàfreshoptions; autocloseBytesIO giữmarker/byte. KhôngTikTok/backendlive |
| Cleanupoffline |1owncontainer được gỡ sau kiểm đúngID/lab/run-label; owncontainers/networks0; kết thúcUTC08:13:36.748/VN15:13:36.748 | Không tạo2servicesoutbound hoặc nhận mọi topologycleanup |
|Prepare/summary | Source/configpin mới; actualprepareexit0; summaryNOT_RUN/0reports | Khôngconsumeanalyze |
|Composepreview | actualexit0, envfile rỗng riêng, renderconfig | Khôngcreate/start/build/pull |
|Source37.4 |0analyze/0metadata/0target/0marker đo thật; sourceactualexit=null/NOT_RUN | Nguồn thiếu điều kiện mạng, không lấy raw37.3 làm37.4 |

Raw cóargv/UTC-VN/actualexit đã sanitize; fullinspectoffline ởguardJSON, stdouterrfixture trongrunnerjsonl. Không rerun19–36/testharnessbacklog/typecheck/production. Fixture3ca chỉ kiểm phầnoptions/instrumentation mới; native cleanup là container thật trên networknone. Runtime2mạng/headerwire/markerTikToklive cònNOT_RUN. Resource480MiB là trần cấu hình lab tương lai; runtimeoffline phiên này chỉ256MiB.

## 5. Lệnh và bàn giao tiếp

Những lệnh đã chạy: `run-374.ps1 -Stage analyze` khôngnetworkfiles(exit40); `-Stage offline`(exit0); `-Stage prepare` cho hai recordprepare; `-Stage summary` đầu báo0reports; DockerComposeconfigonly(exit0). BundledPowerShell path như khối dưới; package không yêu cầu cài runtime lênWindows.

**Các lệnh source dưới đây CHƯA CHẠY, chỉ dùng sau đủ networkcondition/permission/privateproof:**

```powershell
cd 'D:\WED SNAP'
$pwsh374 = 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
$case374 = 'docs/evidence/p37-4-20261007/network-case-final'
# Files do chủ/operator cung cấp và kiểm, giữ rawIP/proof ở nơi riêng.
$plan374 = '<private path to approved network plan>'
$currentProof374 = '<private path to verified current own-egress receipt>'
& $pwsh374 -NoProfile -File tests/p37/run-374.ps1 -Stage analyze -CaseDir $case374 -NetworkSlot current -NetworkPlanFile $plan374 -NetworkProofFile $currentProof374
# Chủ chuyển mạng thủ công, xác minh own-egress thực rồi cấp receipt mới.
$alternateProof374 = '<private path to verified alternate own-egress receipt>'
& $pwsh374 -NoProfile -File tests/p37/run-374.ps1 -Stage analyze -CaseDir $case374 -NetworkSlot alternate -NetworkPlanFile $plan374 -NetworkProofFile $alternateProof374
& $pwsh374 -NoProfile -File tests/p37/run-374.ps1 -Stage summary -CaseDir $case374
```

Không chạy lạiprepare/offline vào cácdirectory evidence đã có. Mỗi analyze directory được giữ ngay cả khiharnessabort; không tự retry vào slotkhác. Sourcepins khóa code final; muốn sửa/runtime mới phải lưu successor đúng phạm vi, không edit evidence cũ. Kết quả sau khi chạy mạng là successorartifactmanifest riêng, giữ manifestpackage374 và373; không overwrite frozenmanifest đểPASS.

`tests/p37/verify-374.ps1` chốt preservation và successor exactSHA4docs/fullartifactcoverage mới. Manifest374 tựexcluded, hash riêngselfmetadata; dùng nó kiểm bàn giao chuẩn bị, không biến thiếu mạng thànhPASSmetadata. Đã cập nhậtPROGRESS/ADAPTERS/TEST_REPORT/AUDIT:37.3 đãnghiệmthu scoped;37.4prepared/NOT_RUNthiếuđiềukiệnmạng;TikTokchưa nghiệmthu/mainchưaapply. Khi chủ cung cấp và cho phép mạng khác cùng phương pháp/proofoutbound, tiếp tục đúng2analyze của37.4 trong phạm vi đã giao, không cần link mới/tài khoản/dịch vụ trả phí.
