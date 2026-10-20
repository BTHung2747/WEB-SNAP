param([Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference='Stop'
$ev=(Resolve-Path -LiteralPath $Evidence).Path
function NewJSON([string]$Name,$Value){$path=Join-Path $ev $Name;$f=[IO.FileStream]::new($path,[IO.FileMode]::CreateNew);try{$b=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 16));$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}}
function Check([bool]$Condition,[string]$Code){if(!$Condition){throw $Code}}
function Pins { @(Get-ChildItem -LiteralPath $PSScriptRoot -File|Sort-Object Name|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}}) }
$pins=Pins;NewJSON 'poc-pins-before.json' $pins
$dll=Join-Path $ev 'Win32Poc.dll';$compile=[Diagnostics.Stopwatch]::StartNew();Add-Type -Path (Join-Path $PSScriptRoot 'Win32Poc.cs') -OutputAssembly $dll -ErrorAction Stop
if(!('WedDirectWin32.Poc' -as [type])){Add-Type -Path $dll}
$binarySHA=(Get-FileHash $dll).Hash.ToLowerInvariant();NewJSON 'compile.json' @{status='PASS_LOCAL_ADD_TYPE';elapsedMs=$compile.ElapsedMilliseconds;binarySHA=$binarySHA;sourceSHA=(Get-FileHash (Join-Path $PSScriptRoot 'Win32Poc.cs')).Hash.ToLowerInvariant();powershell=$PSVersionTable.PSVersion.ToString();dotnet=[Environment]::Version.ToString()}
NewJSON 'layout.json' ([WedDirectWin32.Poc]::Layout())
$node=@(Get-Command node -CommandType Application)[0].Source;$nodeSHA=(Get-FileHash $node).Hash.ToLowerInvariant();$fixture=(Resolve-Path (Join-Path $PSScriptRoot 'fixture.cjs')).Path;$fixtureSHA=(Get-FileHash $fixture).Hash.ToLowerInvariant()
NewJSON 'tools.json' @{node=$node;nodeSHA=$nodeSHA;nodeFileVersion=(Get-Item $node).VersionInfo.ProductVersion;pwsh=(Get-Process -Id $PID).Path;fixtureSHA=$fixtureSHA;noExternalPackages=$true}
$cases=[Collections.Generic.List[object]]::new()
foreach($mode in @('pass','exit20','argv','stderr','orphan','grandparent','latepipe','timeout','flood','attribute-failure','create-failure')){
 $argsVector=@();if($mode -ceq 'argv'){$argsVector=@('','two words','a"b','endslash\','slash\"quote','Việt 😺','semi; & | $ literal')}
 $cap=if($mode -ceq 'flood'){2048}else{8192};$limit=if($mode -ceq 'timeout'){1200}else{1800}
 foreach($p in $pins){Check ((Get-FileHash -LiteralPath $p.path).Hash.ToLowerInvariant() -ceq $p.sha256) 'POC_PIN_DRIFT'}
 Check ((Get-FileHash $node).Hash.ToLowerInvariant() -ceq $nodeSHA) 'NODE_PIN_DRIFT'
 $r=[WedDirectWin32.Poc]::Run($node,$fixture,$mode,$argsVector,$limit,$cap)
 $receipt=$r|Select-Object * -ExcludeProperty RawOut,RawErr;NewJSON ('case-'+$mode+'.json') $receipt
 Check ($r.CleanupClosed -and $r.FinalActive -eq 0 -and $r.LiveHandles -eq 0 -and $r.LiveBuffers -eq 0 -and $r.CloseErrors -eq 0 -and $r.BackgroundReaders -eq 0) 'CLEANUP_UNKNOWN'
 Check ($r.ElapsedMs -lt $limit+100 -and $r.MemoryLimitBytes -eq 268435456 -and $r.ActiveLimitActual -eq 4 -and $r.LimitsVerified) 'LIMIT_OR_DEADLINE'
 if($mode -cin @('pass','argv','stderr')){Check ($r.Status -ceq 'PASS' -and $r.RootExit -eq 0 -and $r.Created -and $r.RootInOwnJob -and $r.PipesEOF -and !$r.TerminationRequested) 'POSITIVE_NATIVE_CONTRACT'}
 if($mode -ceq 'exit20'){Check ($r.Status -ceq 'FAIL' -and $r.RootExit -eq 20 -and $r.RawOut.Contains('PASS')) 'PACKET_OVERRULED_EXIT'}
 if($mode -ceq 'argv'){$actual=@($r.RawOut|ConvertFrom-Json);Check ($actual.Count -eq $argsVector.Count) 'ARGV_COUNT';for($i=0;$i -lt $actual.Count;$i++){Check ($actual[$i] -ceq $argsVector[$i]) 'ARGV_MISMATCH'}}
 if($mode -cin @('orphan','grandparent','latepipe')){Check ($r.RootExit -eq 0 -and $r.Status -ceq 'FAIL' -and $r.AfterRootRelease -gt 0 -and $r.TerminationRequested -and $r.TreeClosed -and $r.PipesEOF) 'ORPHAN_NOT_CONTAINED';if($mode -ceq 'grandparent'){Check ($r.AfterRootRelease -ge 2) 'GRANDCHILD_NOT_OBSERVED'}}
 if($mode -ceq 'timeout'){Check ($r.Status -ceq 'FAIL' -and $r.Timeout -and $r.TerminationRequested -and $null -ne $r.RootExit) 'TIMEOUT_NOT_ENFORCED'}
 if($mode -ceq 'flood'){Check ($r.Status -ceq 'FAIL' -and $r.ByteCapExceeded -and $r.RetainedBytes -le 2048 -and $r.TerminationRequested) 'CAP_NOT_DURING_READ'}
 if($mode -ceq 'attribute-failure'){Check (!$r.Created -and $r.Phase -ceq 'ATTRIBUTE_JOB_LIST' -and $r.Win32Error -gt 0 -and $r.Status -ceq 'FAIL') 'ATTRIBUTE_FAILURE_NOT_OBSERVED'}
 if($mode -ceq 'create-failure'){Check (!$r.Created -and $r.Phase -ceq 'CREATE_PROCESS' -and $r.Win32Error -gt 0 -and $r.Status -ceq 'FAIL') 'CREATE_FAILURE_NOT_OBSERVED'}
 $text=$receipt|ConvertTo-Json -Depth 9 -Compress;foreach($s in @('OFFLINE_TEST_ONLY_SECRET','TOKEN_PATH','TOKEN_QUERY','https://')){Check (!$text.Contains($s)) 'RAW_OUTPUT_IN_RECEIPT'}
 $cases.Add(@{case=$mode;expectedTest='PASS_ASSERTIONS';observed=$r.Status;actualRootExit=$r.RootExit;cleanupClosed=$r.CleanupClosed;elapsedMs=$r.ElapsedMs;win32Error=$r.Win32Error})
}
# Warmed same-process repeated cycles; ownership counters are stronger than total-host counts.
$before=[WedDirectWin32.Poc]::HandleCount();$cycleReceipts=@()
for($i=0;$i -lt 6;$i++){$r=[WedDirectWin32.Poc]::Run($node,$fixture,'pass',@(),1800,8192);Check ($r.Status -ceq 'PASS' -and $r.CleanupClosed -and $r.LiveHandles -eq 0 -and $r.LiveBuffers -eq 0) 'CYCLE_NOT_CLOSED';$cycleReceipts+=@($r|Select-Object * -ExcludeProperty RawOut,RawErr)}
$after=[WedDirectWin32.Poc]::HandleCount();NewJSON 'cycles.json' @{count=6;hostHandlesBefore=$before;hostHandlesAfter=$after;delta=([long]$after-$before);receipts=$cycleReceipts;scope='WARM_SAME_PROCESS_OBSERVATION_NOT_UNIVERSAL_LEAK_PROOF'};Check ($after -le $before+2) 'HOST_HANDLE_GROWTH'
$cases.Add(@{case='six-warm-cycles';expectedTest='PASS_ASSERTIONS';nativeTreeAndHandles='CLOSED_EACH';hostHandleDelta=([long]$after-$before)})
# Owner-crash fixture: no duplicate job handle in observer; only observed process handles.
$ready=Join-Path $ev 'crash-ready.json';$psi=[Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path);$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
foreach($a in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'crash-owner.ps1'),'-ExecuteOffline','-Assembly',$dll,'-AssemblySHA',$binarySHA,'-Node',$node,'-NodeSHA',$nodeSHA,'-FixtureSHA',$fixtureSHA,'-Ready',$ready)){$psi.ArgumentList.Add($a)}
$p=[Diagnostics.Process]::new();$p.StartInfo=$psi;$watch=[Diagnostics.Stopwatch]::StartNew();$observers=[Collections.Generic.List[object]]::new()
try{
 $null=$p.Start();$ownerID=$p.Id;$ownerStart=$p.StartTime.ToUniversalTime().ToString('o');$out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync()
 while(!(Test-Path $ready)){Check (!$p.HasExited -and $watch.ElapsedMilliseconds -lt 4000) 'CRASH_READY_NOT_AVAILABLE';Start-Sleep -Milliseconds 5}
 $doc=Get-Content $ready -Raw|ConvertFrom-Json -DateKind String;Check ($doc.mode -ceq 'OFFLINE_TEST_ONLY' -and $doc.ownerPID -eq $ownerID -and $doc.ownerStartUTC -ceq $ownerStart -and $doc.observerJobHandle -ceq 'NONE' -and $doc.identities.Count -eq 2) 'OWNER_IDENTITY'
 foreach($id in $doc.identities){$identity=[WedDirectWin32.Identity]::new();$identity.PID=$id.PID;$identity.CreationFileTime=$id.CreationFileTime;$identity.VerifiedInOwnedJob=$id.VerifiedInOwnedJob;$o=[WedDirectWin32.Poc]::Observe($identity);Check (!$o.Wait(0)) 'FIXTURE_NOT_ALIVE_BEFORE_OWNER_KILL';$observers.Add($o)}
 $killClock=[Diagnostics.Stopwatch]::StartNew();$p.Kill();Check ($p.WaitForExit(1000)) 'OWNER_KILL_NOT_CLOSED'
 $observed=@();foreach($o in $observers){Check ($o.Wait([Math]::Max(0,1500-$killClock.ElapsedMilliseconds))) 'KILL_ON_LAST_CLOSE_NOT_OBSERVED';$observed+=@{PID=$o.PID;actualExit=$o.Exit;signaled=$true}}
 NewJSON 'owner-crash.json' @{mode='OFFLINE_TEST_ONLY';ownerPID=$ownerID;ownerActualExit=$p.ExitCode;ownerKilledBy='EXACT_OWNED_PROCESS_HANDLE_SINGLE_PROCESS_KILL';descendants=$observed;elapsedAfterKillMs=$killClock.ElapsedMilliseconds;elapsedWholeCaseMs=$watch.ElapsedMilliseconds;observerJobHandles=0;identity='EXACT_CREATION_FILETIME_AND_OWNER_ISPROCESSINJOB';selfExpiryMs=4500;stdout=$out.GetAwaiter().GetResult();stderr=$err.GetAwaiter().GetResult();nativeSourceSuccess='NOT_CLAIMED_AFTER_OWNER_CRASH'}
 $cases.Add(@{case='owner-crash-last-job-handle';expectedTest='PASS_ASSERTIONS';actualOwnerExit=$p.ExitCode;fixtureProcesses=$observed.Count;closure='OWNED_PROCESS_HANDLES_SIGNALED_NOT_JOB_QUERY_AFTER_DESTRUCTION'})
}finally{foreach($o in $observers){$o.Dispose()};if(!$p.HasExited){$p.Kill();$p.WaitForExit(1000)|Out-Null};$p.Dispose()}
$ownership=[WedDirectWin32.Poc]::Ownership();NewJSON 'final-ownership.json' $ownership
Check ($ownership.liveHandles -eq 0 -and $ownership.liveBuffers -eq 0 -and $ownership.closeErrors -eq 0 -and $ownership.backgroundReaders -eq 0) 'FINAL_OBSERVER_OR_RESOURCE_NOT_CLOSED'
$afterPins=Pins;Check (($pins|ConvertTo-Json -Depth 4 -Compress) -ceq ($afterPins|ConvertTo-Json -Depth 4 -Compress)) 'FINAL_POC_CODE_DRIFT';NewJSON 'poc-pins-after.json' $afterPins
NewJSON 'summary.json' @{status='PASS_DIRECT_WIN32_OFFLINE_POC_NOT_INTEGRATED';caseCount=$cases.Count;cases=$cases.ToArray();caps=@{jobMiB=256;activeProcesses=4;maxCaseWatchdogMs=15000;captureCap=8192;floodCaptureCap=2048};explicitRestrictedNesting='NOT_RUN_NO_HOST_JOB_CHANGES';hostNesting='ACTUAL_HOST_IN_JOB_AND_OWN_JOB_CREATION_OBSERVED';preciseCrashDuringKernelCall='NOT_RUN';runtimeOwnerChanges=0;dockerCalls=0;sourceCalls=0;authorityCreated=0;utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow,'SE Asia Standard Time').ToString('o')}
Write-Output "PASS_DIRECT_WIN32_POC_$($cases.Count)_NOT_INTEGRATED"
exit 0
