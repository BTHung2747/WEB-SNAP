$ErrorActionPreference='Stop'
if((Get-Location).Path -ne 'D:\WED SNAP'){throw 'Wrong workspace'}
Write-Output 'COMMAND powershell -NoProfile -File scripts/validate-p26-handoff.ps1 (offline, no Docker/server/app)'
$p26Manifest=Get-Content docs/evidence/p26-20261003-after-manifest.json -Raw|ConvertFrom-Json
if($p26Manifest.files.Count -ne 13 -or $p26Manifest.commands.Count -ne 10){throw 'Manifest inventory'}
Write-Output 'PASS manifest13 source/test/config/script files and10 actual commands/exits'
$p26Targets=@('/api/v1/ads','/api/v1/ad-events','/api/v1/admin/login','/api/v1/admin/logout','/api/v1/admin/dashboard','/api/v1/admin/settings','/api/v1/admin/campaigns','/api/v1/admin/campaigns/{id}')
$p26Old=Get-Content tests/p26/baseline.openapi.json -Raw|ConvertFrom-Json
$p26New=Get-Content docs/openapi.json -Raw|ConvertFrom-Json
foreach($p26Path in $p26Targets){$p26New.paths.$p26Path=$p26Old.paths.$p26Path}
$p26OldNames=@($p26Old.components.schemas.PSObject.Properties.Name)
foreach($p26Name in @($p26New.components.schemas.PSObject.Properties.Name)){if($p26Name -notin $p26OldNames){$p26New.components.schemas.PSObject.Properties.Remove($p26Name)}}
if(($p26Old|ConvertTo-Json -Depth 100 -Compress) -cne ($p26New|ConvertTo-Json -Depth 100 -Compress)){throw 'Whole snapshot preservation mismatch'}
Write-Output 'PASS independent whole snapshot restore8targets/remove8schemas; public12/security/old12 unchanged'
foreach($p26Name in @('matrix.ts','bootstrap.ts','expectations.ts','generate.ts','tsconfig.json','baseline.openapi.json')){
  if((Get-FileHash ('tests/p26/'+$p26Name)).Hash -ne (Get-FileHash ('docs/evidence/p26-20261003-before/'+$p26Name)).Hash){throw ('Before frozen harness changed '+$p26Name)}
}
Write-Output 'PASS before copies match current frozen p26 harness/expected'
$p26Readme=Get-Content README.md -Raw
$p26Section=(($p26Readme -split '## 6\.16\.')[1] -split '## 7\.')[0]
$p26Blocks=[regex]::Matches($p26Section,'(?s)```powershell\s*(.*?)```')
if($p26Blocks.Count -ne 2){throw 'Expected2 README6.16 blocks'}
foreach($p26Block in $p26Blocks){$p26Tokens=$null;$p26Errors=$null;[Management.Automation.Language.Parser]::ParseInput($p26Block.Groups[1].Value,[ref]$p26Tokens,[ref]$p26Errors)|Out-Null;if($p26Errors.Count){throw 'README P26 PowerShell syntax'}}
Write-Output 'PASS README6.16 syntax2blocks read-only, not executed'
Write-Output ('PASS P26 handoff UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::Now.ToString('o')+' independent offline checks only; no runtime rerun')
