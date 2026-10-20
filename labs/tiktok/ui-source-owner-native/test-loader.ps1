param([Parameter(Mandatory)][string]$Evidence,[ValidateSet('fake-context','source-pin','missing-source','compile-fault','preloaded-type','binary-pin')][string]$Case)
$ErrorActionPreference='Stop';Import-Module (Join-Path $PSScriptRoot 'Owner.psm1') -Force -DisableNameChecking
$module=Get-Module Owner;$ev=(Resolve-Path $Evidence).Path;$ctx=New-OfflineNativeTestContext $ev;$rejected=$false;$injection='NONE'
switch($Case){
 'fake-context'{$fake=[pscustomobject]@{Mode=$ctx.Mode;Seal=$ctx.Seal;Root=$ctx.Root;NativeChildren=$ctx.NativeChildren;NativeReceipts=$ctx.NativeReceipts};$action={Initialize-OfflineNativeAdapter $fake}}
 'source-pin'{&$module {$script:NativeHelperSHA='0'*64};$injection='OFFLINE_EXPECTED_HASH_ONLY';$action={Initialize-OfflineNativeAdapter $ctx}}
 'missing-source'{&$module {param($p)$script:NativeImportPins+=@{path=$p;sha='0'*64}} (Join-Path $ev 'OFFLINE_MISSING_HELPER.cs');$injection='OFFLINE_IMPORT_PIN_ADDS_NONEXISTENT_FILE';$action={Initialize-OfflineNativeAdapter $ctx}}
 'compile-fault'{&$module {function script:Add-Type {throw 'OFFLINE_TEST_ONLY_INJECTED_COMPILER_FAILURE'}};$injection='MOCKED_ADD_TYPE_EXCEPTION_NOT_ROSLYN_FAILURE';$action={Initialize-OfflineNativeAdapter $ctx}}
 'preloaded-type'{Add-Type -TypeDefinition 'namespace WedOwnerWin32 { public static class Engine {} }';$injection='ACTUAL_UNOWNED_PRELOADED_TYPE';$action={Initialize-OfflineNativeAdapter $ctx}}
 'binary-pin'{Initialize-OfflineNativeAdapter $ctx|Out-Null;&$module {$script:NativeEngine.SHA='0'*64};$injection='OFFLINE_CACHED_EXPECTATION_HASH_ONLY';$action={Initialize-OfflineNativeAdapter $ctx}}
}
try{&$action|Out-Null}catch{$rejected=$true}
if(!$rejected -or $ctx.NativeChildren.Count -ne 0){throw 'LOADER_NEGATIVE_FAILED'}
$doc=@{case=$Case;status='PASS_REJECT_BEFORE_CHILD';injection=$injection;compilerAlreadyPrepared=($Case -ceq 'binary-pin');registeredChildren=$ctx.NativeChildren.Count;dockerCalls=0;sourceCalls=0}
$file=Join-Path $ev ('loader-'+$Case+'.json');$f=[IO.FileStream]::new($file,[IO.FileMode]::CreateNew);try{$b=[Text.Encoding]::UTF8.GetBytes(($doc|ConvertTo-Json));$f.Write($b,0,$b.Length)}finally{$f.Dispose()}
Write-Output "PASS_LOADER_$Case";exit 0
