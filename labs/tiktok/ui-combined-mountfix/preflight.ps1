$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
. (Join-Path $PSScriptRoot 'mounts.ps1')
$ev='docs/evidence/ui-combined-mountfix-20261016';if(Test-Path "$ev/preflight.json"){throw 'REFUSE_PREFLIGHT_REUSE'}
New-Item -ItemType Directory -Path "$ev/filesystem-control"|Out-Null
$map=@(Get-CombinedMountMap (Resolve-Path "$ev/filesystem-control").Path);$proof=@(Assert-CombinedMountMap $map)
$cases=@([pscustomobject]@{case='CORRECT_LAYOUT';status='PASS'})
foreach($name in @('sitecustomize.py','start.sh')){
 $broken=@($map)+@([pscustomobject]@{source=(Resolve-Path "labs/tiktok/ui-backend-offline/$name").Path;target="/newlab/$name";type='file';roles=@('generate');readOnly=$true})
 $rejected=$false;try{Assert-CombinedMountMap $broken|Out-Null}catch{if($_.Exception.Message -cne 'MISSING_NESTED_TARGET'){throw};$rejected=$true};if(!$rejected){throw 'MISSING_TARGET_ACCEPTED'}
 $cases+=[pscustomobject]@{case="MISSING_NESTED_$name";status='REJECTED_BEFORE_DOCKER'}
}
$badEntry=@($map|Where-Object target -CNE '/mountfix');$rejected=$false
try{Assert-CombinedMountMap $badEntry|Out-Null}catch{if($_.Exception.Message -cne 'TARGET_UNMAPPED'){throw};$rejected=$true};if(!$rejected){throw 'MISSING_ENTRY_ACCEPTED'}
$cases+=[pscustomobject]@{case='MISSING_ENTRY_MAP';status='REJECTED_BEFORE_DOCKER'}
$old=Get-Content docs/evidence/ui-combined-offline-20261016/manifest.json -Raw|ConvertFrom-Json
foreach($pin in $old.implementation){if((Get-FileHash -LiteralPath $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'REUSED_HASH'}}
$tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseFile((Resolve-Path labs/tiktok/ui-combined-mountfix/run.ps1),[ref]$tokens,[ref]$errors)|Out-Null;if($errors.Count){throw 'RUNNER_SYNTAX'}
$pins=@(Get-ChildItem labs/tiktok/ui-combined-mountfix -File|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})+@($old.implementation)
@{status='PASS_MOUNT_FILESYSTEM_ONLY';cases=$cases;caseCount=$cases.Count;pins=$pins;requiredPaths=$proof;mounts=$map;dockerCalls=0;browserCalls=0;sourceCalls=0;nativeActualExit=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 8|Set-Content "$ev/preflight.json"
Write-Output 'PASS_MOUNT_FILESYSTEM_ONLY'
