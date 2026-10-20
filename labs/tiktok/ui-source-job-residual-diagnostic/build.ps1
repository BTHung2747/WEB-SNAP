param([ValidateSet('development','final')][string]$Epoch='development')
. (Join-Path (Get-Location).Path 'labs/tiktok/ui-source-runtime-probe-fix/core.ps1')
. (Join-Path (Get-Location).Path 'labs/tiktok/ui-source-runtime-probe-fix/native.ps1')
$ErrorActionPreference='Stop'
$root=Join-Path (Get-Location).Path 'docs/evidence/ui-source-job-residual-diagnostic-20261019/backend'
$original=(Resolve-Path labs/tiktok/ui-source-owner-native/Win32Adapter.cs).Path
if((Get-FileHash $original).Hash.ToLowerInvariant() -cne '5ed79b96326b56535077c6a97b7b0b30fee1031379f74dc845cfc6fcebbf7f19'){throw 'BASE_DRIFT'}
$text=[IO.File]::ReadAllText($original)
$changes=@(
 @('namespace WedOwnerWin32 {','namespace WedJobDiagnostic {'),
 @('public string RawOut,RawErr; public List<Event> Events=new List<Event>();','public Diagnostic Diagnostics=new Diagnostic(); public bool DiagnosticFault; public string RawOut,RawErr; public List<Event> Events=new List<Event>();'),
 @('private void Stop(){if(!r.TerminationRequested){','private void ObserveDiagnostic(string point,IntPtr borrowedRoot){try{Collector.Capture(job.P,borrowedRoot,r,clock,point);}catch{r.Diagnostics.Complete=false;r.Diagnostics.Code="COLLECTOR_ERROR_NO_MESSAGE";}} private void Stop(){if(!r.TerminationRequested){ObserveDiagnostic("BEFORE_STOP",IntPtr.Zero);'),
 @('Mark("ROOT_EXIT_CAPTURED",r.BeforeRootRelease);root.Dispose();','Mark("ROOT_EXIT_CAPTURED",r.BeforeRootRelease);ObserveDiagnostic("ROOT_EXIT_CAPTURED",root.P);root.Dispose();'),
 @('r.AfterRootRelease=Active();}','r.AfterRootRelease=Active();ObserveDiagnostic("AFTER_ROOT_RELEASE",IntPtr.Zero);}'),
 @('Case="NATIVE",ByteCap=cap,LimitMs=limitMs,HandleCountBefore=HandleCount()','Case="NATIVE",ByteCap=cap,LimitMs=limitMs,HandleCountBefore=HandleCount(),DiagnosticFault=fault=="DIAG_THROW"')
)
foreach($change in $changes){if(([regex]::Matches($text,[regex]::Escape($change[0]))).Count -ne 1){throw 'CLONE_ANCHOR_MISMATCH'};$text=$text.Replace($change[0],$change[1])}
$clone=Join-Path $PSScriptRoot 'DiagnosticAdapter.cs'
if(Test-Path $clone){if([IO.File]::ReadAllText($clone) -cne $text){throw 'CLONE_DRIFT'}}else{[IO.File]::WriteAllText($clone,$text,[Text.UTF8Encoding]::new($false))}
$restored=$text;for($i=$changes.Count-1;$i -ge 0;$i--){$restored=$restored.Replace($changes[$i][1],$changes[$i][0])}
if($restored -cne [IO.File]::ReadAllText($original)){throw 'SEMANTIC_RESTORATION_FAILED'}
$dir=Join-Path $root ('compiled-'+$Epoch);New-Item -ItemType Directory -Path $dir|Out-Null
$dll=Join-Path $dir 'JobDiagnostic.dll';$watch=[Diagnostics.Stopwatch]::StartNew()
Add-Type -Path @($clone,(Join-Path $PSScriptRoot 'Diagnostic.cs')) -OutputAssembly $dll
Add-Type -Path $dll
$engine='WedJobDiagnostic.Engine' -as [type]
Save-New (Join-Path $root ('compile-'+$Epoch+'.json')) @{baseSHA=(Get-FileHash $original).Hash.ToLowerInvariant();cloneSHA=(Get-FileHash $clone).Hash.ToLowerInvariant();collectorSHA=(Get-FileHash (Join-Path $PSScriptRoot 'Diagnostic.cs')).Hash.ToLowerInvariant();dll=$dll;dllSHA=(Get-FileHash $dll).Hash.ToLowerInvariant();MVID=$engine.Module.ModuleVersionId.ToString();layout=$engine::Layout();diagnosticLayout=[WedJobDiagnostic.Collector]::Layout();elapsedMs=$watch.ElapsedMilliseconds;compilerHardCancel='NOT_CLAIMED';anchors=$changes;restoredBaseTextEqual=$true;utc=[DateTimeOffset]::UtcNow.ToString('o')}
Write-Output 'DIAGNOSTIC_CLONE_COMPILED_NO_NATIVE_CHILD'
