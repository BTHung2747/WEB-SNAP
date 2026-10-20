param([Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$PlanSHA)
. (Join-Path $PSScriptRoot 'readiness.ps1')
$path=Join-Path $script:LiveARoot 'readiness-plan.json';$p=Get-Content $path -Raw|ConvertFrom-Json -AsHashtable;$p.planSHA=(Get-FileHash $path).Hash.ToLowerInvariant()
if($p.planSHA -cne $PlanSHA){throw 'REVIEWED_PLAN_HASH_REQUIRED'}
if($p.sourceGate -ne $false -or $p.taskMarker -cne 'live-readiness-20261019' -or $p.workMs -ne 60000 -or $p.hardMs -ne 80000 -or $p.nativeMs -ne 15000 -or $p.captureBytes -ne 65536 -or $p.maxRunning -ne 1 -or $p.customNetworks -ne 0 -or $p.publishPorts -ne 0){throw 'READINESS_SCOPE'}
$null=Read-LiveHuman;Assert-Pins (@($p.sourcePins)+@($p.baselinePins));No-DockerOverrides
$native=New-NativeDelegate $p
Save-New (Join-Path $script:LiveARoot 'readiness-once.json') @{planSHA=$p.planSHA;runID=$p.runID;sourceCalls=0;liveGrants=0;sourceClaims=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}
$sink={param($name,$value) $null=Write-CappedReceipt (Join-Path $script:LiveARoot ('readiness-'+$name+'.json')) $value $null}
$port={
 $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,5206)
 try{$listener.ExclusiveAddressUse=$true;$listener.Start(1);& $sink 'port' @{ip='127.0.0.1';port=5206;exclusiveBind='OBSERVED_THEN_RELEASED';reservation=$false;HTTPRequests=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}}catch{throw 'PORT_UNAVAILABLE'}finally{$listener.Stop()}
}
$watch=[Diagnostics.Stopwatch]::StartNew();$now={$watch.ElapsedMilliseconds}.GetNewClosure()
$r=Invoke-ReadinessBatch $p $native $sink $now $port
Write-Output ('READINESS_'+$(if($r.readinessPASS){'PASS'}else{'FAIL'})+' cleanup='+$r.cleanupClosed+' cause='+$r.cause)
if(!$r.readinessPASS){exit 20}
