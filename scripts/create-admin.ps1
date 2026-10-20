$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
$adminEmail = Read-Host 'Email admin'
$adminPassword = Read-Host 'Mật khẩu admin (ít nhất 12 ký tự)' -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPassword)
try {
  $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  @{ email = $adminEmail; password = $plain } | ConvertTo-Json -Compress | docker compose run --rm --no-deps -T api npm run admin
  if ($LASTEXITCODE -ne 0) { throw 'Không tạo được admin.' }
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
  $plain = $null
}
