. (Join-Path $PSScriptRoot 'common.ps1')
$script:Plan=[pscustomobject]@{runID='a'*32};$role=[pscustomobject]@{name='wed-source-'+('a'*32)+'-offline-app';image='sha256:'+('b'*64)}
$good=@{id='c'*64;name='/'+$role.name;image=$role.image;run='a'*32;task=$script:TaskMarker}
$rows=[Collections.Generic.List[object]]::new()
function Check([bool]$Value,[string]$Code){if(!$Value){throw $Code};$rows.Add(@{case=$Code;status='PASS_PURE_FIXTURE'})}
Assert-Owner $role ([pscustomobject]$good) ('c'*64);Check $true 'EXACT_OWNER_FULL_CID'
foreach($field in @('id','name','image','run','task')){$changed=$good.Clone();$changed[$field]='OFFLINE_INVALID';$rejected=$false;try{Assert-Owner $role ([pscustomobject]$changed) ('c'*64)}catch{$rejected=$true};Check $rejected ('DENY_'+$field)}
$rejected=$false;try{Assert-Owner $role ([pscustomobject]$good) ('d'*64)}catch{$rejected=$true};Check $rejected 'DENY_CID_SUBSTITUTION'
$native=@{Status='PASS';Created=$true;RootInOwnJob=$true;RootExit=0;TerminationRequested=$false;Timeout=$false;ByteCapExceeded=$false;FinalActive=0;PipesEOF=$true;CleanupClosed=$true}
Check (Native-OK ([pscustomobject]$native)) 'NATIVE_ALL_CONDITIONS'
foreach($patch in @(@{k='Status';v='FAIL'},@{k='RootExit';v=20},@{k='RootExit';v=$null},@{k='TerminationRequested';v=$true},@{k='FinalActive';v=$null},@{k='PipesEOF';v=$false},@{k='CleanupClosed';v=$false})){$n=$native.Clone();$n[$patch.k]=$patch.v;Check (!(Native-OK ([pscustomobject]$n))) ('DENY_NATIVE_'+$patch.k+'_'+$rows.Count)}
$errors=@();Get-ChildItem $PSScriptRoot -Filter '*.ps1'|ForEach-Object{$tokens=$null;$e=$null;$null=[Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$e);$errors+=@($e)};Check ($errors.Count -eq 0) 'PS_PARSE'
Save (Join-Path $script:Root 'offline-guard-fixtures.json') @{status='PASS_FIXTURE_NOT_RUNTIME';caseCount=$rows.Count;cases=$rows.ToArray();daemonCalls=0;resourcesCreated=0}
Write-Output ('PASS_OFFLINE_GUARD_FIXTURES_'+$rows.Count);exit 0
