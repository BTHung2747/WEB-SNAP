$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
. (Join-Path $PSScriptRoot 'wiring.ps1')
$ev='docs/evidence/ui-combined-wired-20261016';if(Test-Path "$ev/preflight.json"){throw 'REFUSE_REUSE'}
New-Item -ItemType Directory -Path "$ev/filesystem-control"|Out-Null
$map=@(Get-WiredMountMap (Resolve-Path "$ev/filesystem-control").Path);$commands=Get-WiredCommands;$proof=@(Assert-WiredPlan $map $commands)
$cases=@([pscustomobject]@{case='CORRECT_REVIEWED_MAP_COMMANDS';status='PASS'})
$bad=[pscustomobject]@{generator=$commands.generator;app=$commands.app;gateway=@('node','/newlab/gateway.cjs')};$rejected=$false
try{Assert-WiredPlan $map $bad|Out-Null}catch{if($_.Exception.Message -cne 'COMMAND_WIRING'){throw};$rejected=$true};if(!$rejected){throw 'STALE_COMMAND_ACCEPTED'}
$cases+=[pscustomobject]@{case='REJECT_STALE_GATEWAY_COMMAND';status='PASS'}
$badMap=@($map|Where-Object target -CNE '/gatewayfix');$rejected=$false
try{Assert-WiredPlan $badMap $commands|Out-Null}catch{if($_.Exception.Message -cne 'TARGET_UNMAPPED'){throw};$rejected=$true};if(!$rejected){throw 'MISSING_GATEWAY_MOUNT_ACCEPTED'}
$cases+=[pscustomobject]@{case='REJECT_MISSING_GATEWAY_ROLE_MOUNT';status='PASS'}
$pins=@();foreach($path in @('docs/evidence/ui-gateway-failurefix-20261016/manifest.json','docs/evidence/ui-combined-mountfix-20261016/manifest.json')){$old=Get-Content $path -Raw|ConvertFrom-Json;foreach($p in (@($old.implementation)+@($old.reusedImplementation)|Where-Object {$_ -and $_.path})){if((Get-FileHash -LiteralPath $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'REVIEWED_SOURCE_CHANGED'};$pins+=$p}}
$pins+=@(Get-ChildItem $PSScriptRoot -File|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
foreach($file in Get-ChildItem $PSScriptRoot -Filter *.ps1){$tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)|Out-Null;if($errors.Count){throw 'POWERSHELL_SYNTAX'}}
@{status='PASS_WIRING_FILESYSTEM_ONLY';cases=$cases;caseCount=$cases.Count;pins=$pins;commands=$commands;mounts=$map;requiredPaths=$proof;dockerCalls=0;browserCalls=0;sourceCalls=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 8|Set-Content "$ev/preflight.json"
Write-Output 'PASS_WIRING_FILESYSTEM_ONLY';exit 0
