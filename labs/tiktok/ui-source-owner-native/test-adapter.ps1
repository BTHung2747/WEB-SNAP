param([Parameter(Mandatory)][string]$Evidence,[ValidateSet('runtime','security')][string]$Group='runtime')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Owner.psm1') -Force -DisableNameChecking
$ev=(Resolve-Path $Evidence).Path;$module=Get-Module Owner;$ctx=New-OfflineNativeTestContext $ev
Initialize-OfflineNativeAdapter $ctx|Out-Null
$rows=[Collections.Generic.List[object]]::new()
function Check([bool]$OK,[string]$Code){if(!$OK){throw $Code}}
function Reject($Action){$denied=$false;try{&$Action|Out-Null}catch{$denied=$true};Check $denied 'EXPECTED_REJECTION'}
function Save([string]$Name,$Value){$f=[IO.FileStream]::new((Join-Path $ev $Name),[IO.FileMode]::CreateNew);try{$b=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 15));$f.Write($b,0,$b.Length)}finally{$f.Dispose()}}
function Fixture([string]$Case,[int]$Limit=1600,[int]$Cap=8192){Invoke-OfflineNativeCommand $ctx node @('--max-old-space-size=32',(Join-Path $PSScriptRoot 'child.cjs'),$Case) $Limit $Cap}
if($Group -ceq 'runtime'){
 $vector=@('','space value','q"uote','trail\','slash\"quote','Việt 😺','semi; & | $ literal')
 $previous=[Environment]::GetEnvironmentVariable('WED_NATIVE_OFFLINE_TEST');[Environment]::SetEnvironmentVariable('WED_NATIVE_OFFLINE_TEST','OFFLINE_Unicode_ệ_😺')
 try{foreach($role in @('node','python','pwsh')){
  $argv=switch($role){node{@('--max-old-space-size=32',(Join-Path $PSScriptRoot 'child.cjs'),'argv')+$vector}python{@('-I','-B',(Join-Path $PSScriptRoot 'generic-fixture.py'))+$vector}pwsh{@('-NoLogo','-NoProfile','-File',(Join-Path $PSScriptRoot 'generic-fixture.ps1'))+$vector}}
  $r=Invoke-OfflineNativeCommand $ctx $role $argv 2400 8192;Save ('adapter-argv-'+$role+'.json') $r.Receipt;$data=Read-NativeJSON $r
  Check ($data.args.Count -eq $vector.Count) ('ARGV_COUNT_'+$role);for($i=0;$i -lt $vector.Count;$i++){Check ($data.args[$i] -ceq $vector[$i]) ('ARGV_VALUE_'+$role)}
  Check ([IO.Path]::GetFullPath($data.cwd) -ceq (Get-Location).Path -and $data.env -ceq 'OFFLINE_Unicode_ệ_😺') ('ENV_CWD_'+$role)
  Check ($r.Receipt.additionalJobMemoryLimit -eq 0 -and $r.Receipt.additionalActiveLimit -eq 0 -and $r.Receipt.jobFlags -eq 8192) 'POC_QUOTAS_LEAKED'
  $rows.Add(@{case='ARGV_ENV_CWD_'+$role;status='PASS_ACTUAL_EXECUTABLE';receipt=$r.Receipt})
 }}finally{[Environment]::SetEnvironmentVariable('WED_NATIVE_OFFLINE_TEST',$previous)}
 foreach($case in @('stdin','cross','pipeclosed','grandparent','natural')){
  $cap=if($case -ceq 'cross'){1024}else{8192};$r=Fixture $case 1600 $cap;Save ('adapter-'+$case+'.json') $r.Receipt
  if($case -cin @('stdin','natural')){$data=Read-NativeJSON $r;if($case -ceq 'stdin'){Check ($data.eof -and $data.n -eq 0) 'STDIN_EOF'}}else{Reject {Assert-NativeSuccess $r}}
  if($case -ceq 'cross'){Check ($r.Receipt.stdoutBytes+$r.Receipt.stderrBytes -eq 1400 -and $r.Receipt.retainedBytes -eq 1024 -and $r.Receipt.byteCapExceeded) 'COMBINED_CAP'}
  if($case -ceq 'pipeclosed'){Check ($r.Receipt.timedOut -and $r.Receipt.killTreeRequested -and $r.Receipt.pipesClosed) 'EOF_WAS_NOT_ROOT_EXIT'}
  if($case -ceq 'grandparent'){Check ($r.Receipt.jobAfterRootRelease -ge 2 -and $r.Receipt.jobFinalActive -eq 0) 'GRANDCHILD_OWN_JOB'}
  Check ($r.Receipt.treeClosure -ceq 'CLOSED' -and $r.Receipt.liveHandles -eq 0 -and $r.Receipt.backgroundReaders -eq 0) 'NATIVE_CLEANUP'
  $rows.Add(@{case=$case;status='PASS_ASSERTIONS';receipt=$r.Receipt})
 }
 foreach($fault in @('ATTRIBUTE_SIZE','MISSING_EXE')){
  &$module {param($c,$f)(Get-NativeContext $c).Fault=$f} $ctx $fault
  try{$r=Fixture pass;Save ('adapter-fault-'+$fault+'.json') $r.Receipt;Reject {Assert-NativeSuccess $r};Check (!$r.Receipt.created -and $r.Receipt.win32Error -gt 0 -and $r.Receipt.treeClosure -ceq 'CLOSED') 'PARTIAL_CREATE_PROOF';$rows.Add(@{case=$fault;status='PASS_ACTUAL_INVALID_INPUT_API_RETURN';receipt=$r.Receipt})}finally{&$module {param($c)(Get-NativeContext $c).Fault='None'} $ctx}
 }
 $r=Fixture pass 600;Assert-NativeSuccess $r;Check ($r.Receipt.waitLimitMs -eq 600 -and $r.Receipt.elapsedMs -le 700) 'LOWER_NATIVE_LIMIT';$rows.Add(@{case='LOWER_LIMIT_600';status='PASS';receipt=$r.Receipt})
 $before=&$module {param($c)$e=Get-NativeEngine $c;$e.Type::HandleCount()} $ctx
 for($i=0;$i -lt 4;$i++){$r=Fixture pass;Assert-NativeSuccess $r}
 $counts=&$module {param($c)$e=Get-NativeEngine $c;@{host=$e.Type::HandleCount();owned=$e.Type::Ownership()}} $ctx
 Check ($counts.host -le $before+2 -and $counts.owned.liveHandles -eq 0 -and $counts.owned.liveBuffers -eq 0 -and $counts.owned.backgroundReaders -eq 0) 'REPEATED_CLOSURE'
 $rows.Add(@{case='FOUR_CYCLES';status='PASS';before=$before;after=$counts})
}else{
 $good=Fixture pass;Assert-NativeSuccess $good
 $copy=[pscustomobject]@{Receipt=$good.Receipt;RawOut=$good.RawOut;RawErr=$good.RawErr};Reject {Assert-NativeSuccess $copy};$rows.Add(@{case='COPIED_RESULT_REF';status='PASS_REJECT'})
 $bad=Fixture exit20;$bad.Receipt.actualExit=0;Reject {Assert-NativeSuccess $bad};$rows.Add(@{case='MUTATED_EXIT20_RECEIPT';status='PASS_REJECT'})
 $r=Fixture pass;$r.Receipt.treeClosure='UNKNOWN';Reject {Assert-NativeSuccess $r};$rows.Add(@{case='MUTATED_UNKNOWN_TREE';status='PASS_REJECT'})
 $r=Fixture pass;$r.RawOut='{"status":"FAKE"}';Reject {Read-NativeJSON $r};$rows.Add(@{case='MUTATED_RAW_OUTPUT';status='PASS_REJECT'})
 $other=New-OfflineNativeTestContext $ev;Reject {Read-OfflineRootJSON $other $good};$rows.Add(@{case='FOREIGN_CONTEXT_RESULT';status='PASS_REJECT'})
 $fake=[pscustomobject]@{Mode=$ctx.Mode;Seal=$ctx.Seal;Root=$ctx.Root;NativeChildren=$ctx.NativeChildren;NativeReceipts=$ctx.NativeReceipts}
 Reject {Initialize-OfflineNativeAdapter $fake};Reject {Invoke-OfflineNativeCommand $fake node @('--version')};$rows.Add(@{case='COPIED_SEAL_FAKE_CONTEXT';status='PASS_REJECT_NO_CHILD'})
 $c=New-OfflineNativeTestContext $ev;$r=Invoke-OfflineNativeChild $c pass;$c.NativeChildren[0].TreeClosure='UNKNOWN'
 Reject {Assert-NativeSuccess $r};Check (!(&$module {param($c)Test-NativeContextClosed $c} $c)) 'DISPOSED_UNKNOWN_ACCEPTED';$rows.Add(@{case='DISPOSED_RECORD_MUTATION';status='PASS_REJECT'})
 $c=New-OfflineNativeTestContext $ev;$r=Invoke-OfflineNativeChild $c pass;$c.NativeChildren.Add([pscustomobject]@{Disposed=$true;TreeClosure='CLOSED'})
 Check (!(&$module {param($c)Test-NativeContextClosed $c} $c)) 'FORGED_CLOSED_RECORD_ACCEPTED';$rows.Add(@{case='FORGED_DISPOSED_CLOSED_RECORD';status='PASS_REJECT'})
 $c=New-OfflineNativeTestContext $ev;$r=Invoke-OfflineNativeChild $c pass;$c.NativeChildren.Clear();Check (!(&$module {param($c)Test-NativeContextClosed $c} $c)) 'REMOVED_RECORD_ACCEPTED';$rows.Add(@{case='REMOVED_REGISTERED_RECORD';status='PASS_REJECT'})
 foreach($n in @(599,30001)){Reject {Invoke-OfflineNativeCommand $ctx node @() $n 8192}};foreach($n in @(255,1048577)){Reject {Invoke-OfflineNativeCommand $ctx node @() 1600 $n}};$rows.Add(@{case='LIMITS_UNCHANGED_REJECT_OUTSIDE';status='PASS_REJECT'})
 $c=New-OfflineNativeTestContext $ev;$state=&$module {param($c)Get-NativeContext $c} $c;$key=@($state.Tools.Keys|Where-Object{$state.Tools[$_].role -ceq 'node'})[0];$state.Tools[$key].sha='0'*64
 Reject {Invoke-OfflineNativeCommand $c node @('--version')};Check ($c.NativeChildren.Count -eq 0) 'EXE_MISMATCH_CREATED_CHILD';$rows.Add(@{case='EXE_PIN_MISMATCH_PRIVATE_EXPECTATION_TEST';status='PASS_REJECT_NO_CHILD'})
}
Save ('adapter-'+$Group+'-summary.json') @{status='PASS_INTEGRATED_ADAPTER_TESTS';caseCount=$rows.Count;cases=$rows.ToArray();dockerCalls=0;sourceCalls=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}
Write-Output "PASS_ADAPTER_${Group}_$($rows.Count)"
exit 0
