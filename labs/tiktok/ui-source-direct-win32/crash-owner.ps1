param([switch]$ExecuteOffline,[string]$Assembly,[string]$AssemblySHA,[string]$Node,[string]$NodeSHA,[string]$FixtureSHA,[string]$Ready)
$ErrorActionPreference='Stop'
if(!$ExecuteOffline -or !$Ready -or !$AssemblySHA -or !$NodeSHA -or !$FixtureSHA){exit 78}
$session=$null
try{
 $fixture=Join-Path $PSScriptRoot 'fixture.cjs'
 foreach($pair in @(@($Assembly,$AssemblySHA),@($Node,$NodeSHA),@($fixture,$FixtureSHA))){if((Get-FileHash -LiteralPath $pair[0]).Hash.ToLowerInvariant() -cne $pair[1]){throw 'PIN_MISMATCH'}}
 $full=[IO.Path]::GetFullPath($Ready);$evidence=[IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'docs/evidence'))
 if(!$full.StartsWith($evidence+[IO.Path]::DirectorySeparatorChar) -or (Test-Path -LiteralPath $full)){throw 'FRESH_READY_REQUIRED'}
 Add-Type -Path $Assembly
 $session=[WedDirectWin32.Poc]::StartCrashOwner($Node,$fixture);$watch=[Diagnostics.Stopwatch]::StartNew();$packet=$null
 while($watch.ElapsedMilliseconds -lt 1500){$session.Pump();try{$packet=$session.Output|ConvertFrom-Json -ErrorAction Stop}catch{};if($packet){break};Start-Sleep -Milliseconds 5}
 if(!$packet -or [uint32]$packet.root -ne $session.RootPID){throw 'FIXTURE_READY_REQUIRED'}
 $ids=@($session.MemberIdentity([uint32]$packet.root),$session.MemberIdentity([uint32]$packet.child))
 $doc=@{mode='OFFLINE_TEST_ONLY';ownerPID=$PID;ownerStartUTC=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o');identities=$ids;observerJobHandle='NONE';utc=[DateTimeOffset]::UtcNow.ToString('o')}
 $f=[IO.FileStream]::new($full,[IO.FileMode]::CreateNew);try{$b=[Text.Encoding]::UTF8.GetBytes(($doc|ConvertTo-Json -Depth 6 -Compress));$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}
 # Safety fallback only: normal test kills this OWNED helper well before expiry.
 while($watch.ElapsedMilliseconds -lt 4500){Start-Sleep -Milliseconds 10}
 Write-Output 'OFFLINE_OWNER_SELF_EXPIRY';exit 20
}catch{Write-Output 'OFFLINE_OWNER_SETUP_FAILED';exit 21}
finally{if($session){$session.Dispose()}}
