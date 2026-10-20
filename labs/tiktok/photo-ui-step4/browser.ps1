param([Parameter(Mandatory=$true)][string]$Build,[ValidateRange(1,20)][int]$Attempt=1,[switch]$Before)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev="docs/evidence/tiktok-photo-ui-step4-20261015/browser-$Attempt";if(Test-Path $ev){throw 'Refuse reuse'};New-Item -ItemType Directory $ev|Out-Null
$buildPath=(Resolve-Path "$Build/web").Path;$fixture=(Resolve-Path docs/evidence/tiktok-photo-egress-step3b-20261015/worker-3/prepared-image.jpg).Path
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@();$j=[IntPtr]::Zero;$process=$null
function SHA([string]$p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
$c=Get-Content "$Build/completion.json" -Raw|ConvertFrom-Json;if($c.actualExit -ne 0){throw 'Build gate failed'}
$source=@(Get-Content "$Build/expected-source.json" -Raw|ConvertFrom-Json)
foreach($r in $source){if((SHA $r.path) -cne $r.sha256){throw 'Build source no longer final'}}
$source|ConvertTo-Json|Set-Content "$ev/expected-source.json"
$compiled=@(Get-ChildItem $buildPath -File -Recurse|ForEach-Object{@{path=[IO.Path]::GetRelativePath($buildPath,$_.FullName).Replace('\','/');sha256=(SHA $_.FullName)}})
$compiled|ConvertTo-Json|Set-Content "$ev/compiled-source.json"
$testSource=@(foreach($p in @('browser.ps1','browser.cjs','static.cjs')){@{path=$p;sha256=(SHA "labs/tiktok/photo-ui-step4/$p")}});$testSource|ConvertTo-Json|Set-Content "$ev/test-source.json"
New-Item -ItemType Directory "$ev/tested-tools"|Out-Null;foreach($r in $testSource){Copy-Item "labs/tiktok/photo-ui-step4/$($r.path)" "$ev/tested-tools/$($r.path)"}
function Native([string]$step,[string[]]$argv){$at=[DateTimeOffset]::UtcNow;$s=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE;@{step=$step;arguments=$argv;actualExit=$exit;output=$s;utcStart=$at.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 8 -Compress|Add-Content "$ev/native.jsonl";if($exit){throw "Native $step exit$exit"};$s.Trim()}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class UiJob {
 [StructLayout(LayoutKind.Sequential)] public struct Basic {public long p,j;public uint flags;public UIntPtr min,max;public uint active;public UIntPtr affinity;public uint priority,scheduling;}
 [StructLayout(LayoutKind.Sequential)] public struct IO {public ulong a,b,c,d,e,f;}
 [StructLayout(LayoutKind.Sequential)] public struct Limits {public Basic basic;public IO io;public UIntPtr processMemory,jobMemory,peakProcess,peakJob;}
 [StructLayout(LayoutKind.Sequential)] public struct Accounting {public long a,b,c,d;public uint faults,total,active,terminated;}
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] public static extern IntPtr CreateJobObject(IntPtr a,string n);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool SetInformationJobObject(IntPtr j,int c,ref Limits l,int n);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool QueryInformationJobObject(IntPtr j,int c,ref Accounting l,int n,IntPtr o);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool AssignProcessToJobObject(IntPtr j,IntPtr p);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool TerminateJobObject(IntPtr j,uint c);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr p);
}
'@
try{
 $j=[UiJob]::CreateJobObject([IntPtr]::Zero,"photo-ui-$run");if($j -eq [IntPtr]::Zero){throw 'JOB_CREATE'}
 $limits=[UiJob+Limits]::new();$limits.basic.flags=0x2208;$limits.basic.active=48;$limits.jobMemory=[UIntPtr]::new(768MB)
 if(![UiJob]::SetInformationJobObject($j,9,[ref]$limits,[Runtime.InteropServices.Marshal]::SizeOf($limits))){throw 'JOB_LIMIT'}
 $node='C:/Users/LENOVO/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe';$script=(Resolve-Path labs/tiktok/photo-ui-step4/browser.cjs).Path;$out=(Resolve-Path $ev).Path;$mode=if($Before){'before'}else{'after'}
 $start=[DateTimeOffset]::UtcNow
 $process=Start-Process -FilePath $node -ArgumentList @('--max-old-space-size=128',('"'+$script+'"'),('"'+$out+'"'),$mode,('"'+$buildPath+'"'),('"'+$fixture+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput "$out/stdout.log" -RedirectStandardError "$out/stderr.log"
 if(![UiJob]::AssignProcessToJobObject($j,$process.Handle)){throw 'JOB_ASSIGN'}
 @{memoryCommittedLimit=768MB;activeProcessLimit=48;killOnClose=$true;assignedBeforeBrowserSpawn=$true;nodePID=$process.Id;browserSandboxRequested=$true;staticMemoryLimit=0;totalConfiguredBounds=768MB;cpuHardCapBrowser='NOT_CONFIGURED_WINDOWS_JOB';sourceCalls=0}|ConvertTo-Json|Set-Content "$ev/browser-guard.json"
 [IO.File]::WriteAllText((Join-Path $out 'release'),'assigned')
 if(!$process.WaitForExit(180000)){throw 'BROWSER_WATCHDOG'};$process.WaitForExit();$actual=$process.ExitCode
 @{step='browser';actualExit=$actual;utcStart=$start.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');arguments=@($node,$script,$out,$mode,$buildPath,$fixture)}|ConvertTo-Json -Compress|Add-Content "$ev/native.jsonl"
 if($actual -ne 0){throw 'BROWSER_TEST_FAILED'}
 $account=[UiJob+Accounting]::new();$end=[DateTimeOffset]::UtcNow.AddSeconds(5)
 do{if(![UiJob]::QueryInformationJobObject($j,1,[ref]$account,[Runtime.InteropServices.Marshal]::SizeOf($account),[IntPtr]::Zero)){throw 'JOB_QUERY'};if($account.active -eq 0){break};Start-Sleep -Milliseconds 50}while([DateTimeOffset]::UtcNow -lt $end)
 if($account.active -ne 0){throw 'BROWSER_CHILDREN_REMAIN'}
 foreach($r in $source){if((SHA $r.path) -cne $r.sha256){throw 'Source changed during browser test'}}
 foreach($r in $compiled){if((SHA "$buildPath/$($r.path)") -cne $r.sha256){throw 'Compiled bundle changed'}}
 foreach($r in $testSource){if((SHA "labs/tiktok/photo-ui-step4/$($r.path)") -cne $r.sha256){throw 'Browser tool changed'}}
 @{status='PASS_BROWSER_OWN_JOB_CLOSED';actualExit=$actual;activeProcesses=0;totalProcesses=$account.total;utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[DateTimeOffset]::Now.ToString('o');sourceCalls=0}|ConvertTo-Json|Set-Content "$ev/completion.json"
}finally{
 $windowsActive=$null
 if($j -ne [IntPtr]::Zero){
  [UiJob]::TerminateJobObject($j,91)|Out-Null;$end=[DateTimeOffset]::UtcNow.AddSeconds(5);$a=[UiJob+Accounting]::new()
  do{$queried=[UiJob]::QueryInformationJobObject($j,1,[ref]$a,[Runtime.InteropServices.Marshal]::SizeOf($a),[IntPtr]::Zero);if($queried -and $a.active -eq 0){break};Start-Sleep -Milliseconds 50}while([DateTimeOffset]::UtcNow -lt $end)
  if($queried){$windowsActive=$a.active};[UiJob]::CloseHandle($j)|Out-Null
 }
 foreach($id in $ids){$g=@((Native 'cleanup-owner' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Owner mismatch'};Native 'remove-own' @('rm','-f',$id)|Out-Null}
 foreach($id in $nets){Native 'remove-network' @('network','rm',$id)|Out-Null}

 @{containers=$ids;networks=$nets;run=$run;windowsOwnedJobHandleClosed=$true;windowsActiveProcesses=$windowsActive;ownResourcesLeft=0;volumesCreated=0}|ConvertTo-Json|Set-Content "$ev/cleanup.json"
}
