# Bàn giao37.4-R — 07/10/2026, hai finding đã sửa, chờ audit

Đã sửa F37.4-SUM và F37.4-DEFAULT, kiểm bằng nhánh runner thật với dữ liệu fixture offline. Chủ chỉ có mạng hiện tại; **không gọi TikTok, không chạy đối chứng mạng, không yêu cầu hotspot/proxy/JSON/proof**.37.4 nguồn vẫn0/2 NOT_RUN; metadata/marker/target/exit của nguồn mới chưa có. TikTok/P0/P2/no-watermark chưa nghiệm thu; main chưa apply. Không suy fixture PASS thành tiến độ tải thật.

## Thay đổi và lý do

Chỉ sửa `tests/p37/run-374.ps1` ở summary và default CaseDir; thêm fixture, successor case/evidence/verifier và bàn giao này; cập nhật4docs được giao. Probe374, guard374, Compose, deps/images và production giữ SHA. Không sửa gate/receipt/protocol, không install/rebuild/deploy hoặc khởi động Docker.

Luật ưu tiên thư viện: tiếp tục dùng cmdlet PowerShell có sẵn `ConvertFrom-Json`, `ConvertTo-Json`, `Get-FileHash` và AST parser; đã đọc Get-Help JSON cmdlets, kiểm trên bundled PowerShell7.6.5. Không tự viết JSON parser, HTTP/TLS/parserTikTok. Phần bổ sung là chính sách kết luận/completeness của report và nối case đúng — phần runner cũ chưa xử lý được, không phải chức năng cần thêm dependency. yt-dlp2026.08.19/curl_cffi/egress và lockfile đã nghiệm thu không thay đổi; nguồn/API đã xác minh ở373/374 giữ nguyên.

| Đầu vào summary | Sau sửa |
|---|---|
| Hai report hoàn tất nhưng configuration/actualtarget/preparedheaders/byte khác hoặc thiếu chứng cứ so sánh | `OBSERVED_TWO_REPORTS`; giữ metadata PASS/FAIL, `comparability_limits`, `cause=UNKNOWN`; chỉ ghi outcomes tại hai mốc, không kết luận network-condition sensitivity |
| Report thiếu, JSON hỏng, NOT_COMPLETED, thiếu fields cần thiết hoặc PASS có formats sai schema | `PARTIAL`, input harness UNKNOWN; giữ các metadata flags đọc được, không nhận MEASURED hoàn chỉnh; parseerror chỉ ghi nhãn chung, không echo raw nội dung |
| Hai report hoàn tất, controls so được | `MEASURED_TWO_NETWORKS` cho input pair; metadata riêng với harness. FAIL→PASS chỉ ghi tương thích với nhạy điều kiện mạng tại hai mốc, không chứng minh nguyên nhân cụ thể/mọiIP/ổn định |
| Hai report so được nhưng cả hai FAIL | Giữ FAIL/FAIL, nguyên nhân vẫn unproven |
| Không có report nguồn | `NOT_RUN`, metadata rỗng; summary process exit0 chỉ là hoàn tất tổng kết |

Byte consistency xét cờ diagnostic, response_bytes_sum/aggregate và tổng decoded_bytes theo request. Header signature chuẩn hóa thứ tự keys; không suy target từ requestedtarget khi response không cho biết. Không đọc/chế tạo networkreceipt trong việc sửa summary; kết luận chỉ dựa chứng cứ report được cấp, không phải xác minh độc lập mạng hoặc headers đầy đủ trên wire.

**F37.4-DEFAULT:** mặc định mới là `docs/evidence/p37-4-r-20261007/case-current-final/`. Case mới có5/5sourcepins đúng và configpin giữ `6c2c655ffc39af3c658c6b58c26da013b504092fb4f32f4d39bf4d05a7bc6121`; configfileSHA giữ `f7afc8bf4cbed20cb47abd8a048c345d0e4ee088e349135b2e38c2ce5eae3544`. Không sửa pins của `network-case/`, `network-case-final/` thuộc gói374 cũ. `case-current/` là draft đầu của lượt repair, giữ evidence và superseded bởi case-current-final sau bổ sung kiểm formats-array; không dùng draft. Caseprepare dùng format đã có, không tạo protocol/proof mới và không cấp quyền gọi nguồn.

## Kiểm thực sự chạy và raw FAIL→PASS

Fixture `test_374_repair.ps1` tạo các report **synthetic**, gọi bundled PowerShell bằng argv/UseShellExecute=false chạy script đầy đủ `-Stage summary`, không chép lại implementation/không double JSON reader. Missing-input gọi nhánh preflight `-Stage analyze` không plan/proof, exit40 trước Docker/source. Metadata FAIL/PASS trong fixture không là extraction thật.

- Lượt đầu:11ca, baseline4PASS/7FAIL, actualfixtureexit1 tạiUTC08:45:13.860/VN15:45:13.860; sau sửa11/11PASS/exit0 tạiUTC08:48:43.738/VN15:48:43.738. Giữ nguyên raw ở `fixtures-before/`, `fixtures-after/`.
- Bổ sung đúng1ca PASS/formats sai kiểu để kiểm malformed schema. Bộ cuối12ca dùng cùng fixture: baseline từ runner snapshot cũ4PASS/8FAIL/exit1, final12/12PASS/exit0. Raw ở `fixtures-before-2/`, `fixtures-after-2/`; không overwrite các lượt đầu.
-12ca gồm config/header/actualtarget/byte mismatch, NOT_COMPLETED, malformedJSON, malformedformats, missingreport, comparableFAIL→PASS, comparableFAIL/FAIL, default5sourcepins+configpin, missingnetworkinput. Chỉ kiểm2finding, không rerun fixtureHTTP/yt-dlp/19–36 hoặc testbacklog khác.
- Mỗi native summary exit được lưu riêng trong `native.jsonl`, cùng stdout/stderr/argv/UTC/VN. Baseline malformedJSON childexit1→finalchildexit0/PARTIAL; các assertion baseline fail dù childexit0 cũng được giữ, không gọi childexit0 là test PASS. Fixture overall1→0, metadata flags và input harness ở summary tách nhau.
-0Docker/0network/source calls trong toàn lượt này. Không có container/network cần cleanup; file fixture giữ làm evidence, không xóa log/gói cũ. Không kiểm Docker/main/datastores hiện tại hoặc quảng cáo việc offline này là backendlive.

## Bảo toàn và successor

Trước sửa:1.596file có SHA/bytes; copies runner và4docs ở `before/`. Manifest374 cũ SHA `c76ca5e89b2c9f9559a8cf96f1c0855de5be5ee32e007c63f7dd3633f22f7a3e`/selfmetadata giữ;39/39entries ngoàiAUDIT đúng trước repair. LiveAUDIT do phiên kiểm toán trước cập nhật được ghi exact currentSHA trong `predecessor-374.json`. Runner trước sửa được copy byte-for-byte để giữ source của gói cũ sau khi sửa live runner.

Sau sửa, successor chỉ nhận **đúng SHA mới của runner và4docs được giao**, không exemption chung:35entries374 ngoài5paths đó giữ SHA/bytes; before-copy runner khớp old manifest source; mọi artifact dưới gói373/374 và pins cũ giữ nguyên. Verifier lịch sử373/374, manifests/selfmetadata/raw không sửa đểPASS. Handoff374 cũ giữ để bảo toàn gói; trạng thái mới và defaultcase đúng được xác định bởi bàn giao37.4-R này.

`verify-374-repair.ps1` chốt toàn bộ before-set còn lại, casepins/configpin, rawfixture outcomes, default summary NOT_RUN và manifest mới full distinct path/size/SHA. Manifest tựexcluded và có hash riêngselfmetadata. Các `ab-attempt-B.json` **bên dưới fixtures-*** là inputs giả lập; không đếm chúng là analyze nguồn. Case-current-final không có report nguồn/current/alternate hoặc receipt.

## Lệnh đã chạy và trạng thái tiếp

```powershell
cd 'D:\WED SNAP'
$pwshRepair = 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
# Trước sửa runner; actual exit1, giữ raw.
& $pwshRepair -NoProfile -File tests/p37/test_374_repair.ps1 -Phase before
# Sau sửa, prepare dùng default mới và proof config offline lịch sử, không request.
& $pwshRepair -NoProfile -File tests/p37/run-374.ps1 -Stage prepare
& $pwshRepair -NoProfile -File tests/p37/test_374_repair.ps1 -Phase after
# Sau bổ sung malformed-formats: prepare successor final; baseline dùng snapshot nguyên bản.
& $pwshRepair -NoProfile -File tests/p37/run-374.ps1 -Stage prepare
& $pwshRepair -NoProfile -File tests/p37/test_374_repair.ps1 -Phase before -Attempt 2 -Runner docs/evidence/p37-4-r-20261007/before/run-374.ps1
& $pwshRepair -NoProfile -File tests/p37/test_374_repair.ps1 -Phase after -Attempt 2
```

Hai lần prepare trên là các thời điểm default khác nhau: draft rồi final, đều giữ artifact. Không chạy lại vào những directories đã có; fixture/prepare từ chối overwrite. Lệnh `-Stage summary` không CaseDir hiện trỏ đúng successor final và trảNOT_RUN, không cần owner viết đầu vào nào.

Hai finding đã sửa, **chờ audit**, đối chứng hai mạng vẫnNOT_RUN vì chủ chỉ có mạng hiện tại. Không đề nghị hotspot/VPS/proxy, không mở thêm quy trình proof hoặc yêu cầu mua dịch vụ. Theo PLAN P0, phần kiến trúc có thể tiếp tục với nền tảng đã kiểm chứng; công việc sản phẩm khác cần một phạm vi riêng, không tự khởi động trong37.4-R. Chưa cómetadata TikTok/3file/visual/no-buttonE2E nên không nghiệm thu tải không watermark.
