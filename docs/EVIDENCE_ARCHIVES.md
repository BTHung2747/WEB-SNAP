# Bằng chứng lưu trữ dạng nén

Ngày07/10/2026, chủ yêu cầu kiểm toán và xóa phần không cần thiết để giảm dung lượng. Ledger `p36-20261004-commands-completion-ledger.json` có320.524.705byte (~305,7MiB), phần lớn là metadata lặp do PowerShell serialize. File này không chạy trong ứng dụng nhưng vẫn là một phần hồ sơ nghiệm thu.

Đã nén **nguyên bản, không sửa nội dung** thành `docs/evidence/archives/p36-20261004-commands-completion-ledger.json.gz` (18.423.388byte/~17,6MiB), xác minh hash của dữ liệu giải nén, chạy script khôi phục thật và kiểm size/hash trùng trước khi bỏ lại bản chưa nén. Tiết kiệm302.101.317byte/~288,1MiB từ ledger.

- SHA256 nguyên bản: `212a0f9dba3ea50694c80949c13fff3953f7573e73187fee7c7abb1cdf4659c6`.
- Đường dẫn, kích thước và SHA của file nén/nguyên bản ở `docs/evidence/archive-index.json`.
- Các manifest lịch sử vẫn giữ nguyên đường dẫn và hash nguyên bản; không đổi golden hashes để ép PASS.

## Kiểm tra hoặc khôi phục

Từ gốc dự án, dùng PowerShell đã có trong runtime Codex:

```powershell
cd 'D:\WED SNAP'
$taskPwsh = 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
# Chỉ đọc: xác minh file nén và hash dữ liệu giải nén, không tạo file320MB.
& $taskPwsh -NoProfile -File scripts/restore-evidence.ps1 -VerifyOnly
# Khi thật sự cần ledger hoặc chạy verifier cũ: khôi phục đúng đường dẫn và bytes.
& $taskPwsh -NoProfile -File scripts/restore-evidence.ps1
```

Script dùng GZip/SHA256 có sẵn trong .NET, đọc theo stream, không cài thư viện hoặc nạp toàn bộ ledger vào RAM. Script kiểm phạm vi đường dẫn, từ chối ghi đè file khác nội dung và chỉ nhận các file có trong archive index. Sau khôi phục, dung lượng320MB của bản chưa nén sẽ xuất hiện lại; bản gzip vẫn giữ để phục hồi.

Verifier lịch sử dùng Get-FileHash/Get-Content trực tiếp cần khôi phục file trước; file chưa được khôi phục không đồng nghĩa dữ liệu mất hoặc manifest bị sửa. Các before-set chứa cache `.pyc` đã được chủ cho phép xóa cũng cần được đọc cùng hồ sơ cleanup; không coi cache sinh lại là bằng chứng nghiệp vụ.

## Những gì được giữ

Code ứng dụng/lab, video nghiệm thu YouTube, backup DB, raw launch TikTok, snapshots, manifests và scripts đang được dùng không bị xóa. Chỉ hai file cache Python3.14 trong `tests/p37/__pycache__/` bị xóa trực tiếp; chúng không được runtime Linux3.11 sử dụng. Ignore rules đã bổ sung để cache không đi vào Git hoặc Docker build context.

Các thao tác lưu trữ và số liệu trước/sau ở `docs/evidence/cleanup-20261007/`. Việc này không xóa Docker images/volumes, không build/start dịch vụ và không phê duyệt thay seccomp/sandbox.
