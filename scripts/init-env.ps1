$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path $PSScriptRoot -Parent)
if (Test-Path -LiteralPath '.env') { throw '.env đã tồn tại; không ghi đè.' }
function New-Secret {
  $bytes = New-Object byte[] 32
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $rng.GetBytes($bytes)
  $rng.Dispose()
  return ([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant()
}
$text = [IO.File]::ReadAllText((Join-Path $PWD '.env.example'))
$text = $text.Replace('POSTGRES_PASSWORD=', ('POSTGRES_PASSWORD=' + (New-Secret)))
$text = $text.Replace('ADMIN_SESSION_SECRET=', ('ADMIN_SESSION_SECRET=' + (New-Secret)))
[IO.File]::WriteAllText((Join-Path $PWD '.env'), $text, (New-Object Text.UTF8Encoding($false)))
Write-Host 'Đã tạo .env với secret ngẫu nhiên. Không đưa file này vào Git.'
