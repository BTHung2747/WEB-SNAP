$ErrorActionPreference='Stop'
if((Get-Location).Path -ne 'D:\WED SNAP'){throw 'Wrong workspace'}
function Check($value,[string]$message){if(-not $value){throw $message}}
function Hash([string]$path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
Write-Output 'COMMAND powershell -NoProfile -File scripts/validate-p27-handoff.ps1 (offline only; no Docker/server/app/datastore)'
$p27Manifest=Get-Content docs/evidence/p27-20261003-after-manifest.json -Raw|ConvertFrom-Json
Check ($p27Manifest.files.Count -eq 9 -and $p27Manifest.commands.Count -eq 6) 'Manifest9files/6commands'
foreach($file in $p27Manifest.files){Check ((Hash $file.path) -eq $file.sha -and (Hash $file.snapshot) -eq $file.sha) ('File snapshot '+$file.path)}
foreach($run in $p27Manifest.commands){Check ((Hash $run.log) -eq $run.sha) ('Raw SHA '+$run.log)}
Write-Output 'PASS own9file after manifest/6actual phase commands and raw hashes'
$p27Snapshot=Get-Content docs/openapi.json -Raw|ConvertFrom-Json
Check ((Hash docs/openapi.json) -eq 'f4b6cd7bbf6631f89265def504fed869e6f1aa6853303c47e5f3c7c39540b16a') 'Accepted26 whole snapshot changed'
$p27Ops=@();foreach($property in $p27Snapshot.paths.PSObject.Properties){foreach($method in $property.Value.PSObject.Properties){if($method.Name -in @('get','post','put','delete','patch','head','options','trace')){$p27Ops+=($property.Name+' '+$method.Name)}}}
Check (@($p27Snapshot.paths.PSObject.Properties).Count -eq 19 -and $p27Ops.Count -eq 23 -and @($p27Snapshot.components.schemas.PSObject.Properties).Count -eq 20) '19paths23ops20schemas'
Write-Output 'PASS full accepted26 snapshot exact SHA unchanged,19paths23operations20schemas'
$p27History=Get-Content docs/evidence/p26-20261003-after-manifest.json -Raw|ConvertFrom-Json
foreach($file in $p27History.files){Check ((Hash $file.snapshot) -eq $file.sha) ('Frozen26 copy '+$file.snapshot)}
foreach($run in $p27History.commands){Check ((Hash $run.log) -eq $run.sha) ('Frozen26 raw '+$run.log)}
# Current API prose27 deliberately differs; preserve its frozen26 copy rather than rewrite old validator.
Write-Output 'PASS frozen26 snapshots/raw hashes; no historical validator rerun against live27 API prose'
$p27Readme=Get-Content README.md -Raw
$p27Section=(($p27Readme -split '## 6\.17\.')[1] -split '## 7\.')[0]
$p27Blocks=[regex]::Matches($p27Section,'(?s)```powershell\s*(.*?)```')
Check ($p27Blocks.Count -eq 2) 'README6.17 two PowerShell blocks'
foreach($block in $p27Blocks){
  Check ($block.Groups[1].Value.TrimStart().StartsWith('cd "D:\WED SNAP"')) 'README starts with required cd'
  $p27Tokens=$null;$p27Errors=$null
  [Management.Automation.Language.Parser]::ParseInput($block.Groups[1].Value,[ref]$p27Tokens,[ref]$p27Errors)|Out-Null
  Check ($p27Errors.Count -eq 0) 'README PowerShell syntax'
}
Write-Output 'PASS README6.17 two PowerShell blocks syntax/cd, read-only; examples not executed'
foreach($path in @('docs/PROGRESS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md')){
  $content=Get-Content -LiteralPath $path -Raw
  Check ($content.Contains('36case') -and ($content.Contains('79HTTP') -or $content.Contains('79request HTTP')) -and ($content.Contains('261protected') -or $content.Contains('261hash protected'))) ('Handoff scope '+$path)
}
Write-Output ('PASS P27 handoff UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::Now.ToString('o')+' current snapshot/frozen26/manifest/README syntax/scope; offline only, no HTTP rerun')
