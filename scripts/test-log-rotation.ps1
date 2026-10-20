param([ValidateSet('Baseline','Source','Probe','Cleanup')][string]$Phase)
$ErrorActionPreference='Stop'
$root33=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $root33 -or $root33 -ne 'D:\WED SNAP'){throw 'Native repository required'}
$stem33='docs/evidence/p33-20261004'
$project33='wed-snap-log-rotation-lab'
$pin33='sha256:f2a71e620a0c6a99261a184ad39352e4bbf26954e34ccb1cddcb25ffefa115f1'
$labArgs33=@('compose','-p',$project33,'--project-directory',$root33,'--env-file','infra/log-rotation-lab.env.example','-f','infra/compose.log-rotation-lab.yaml')
$script:commands33=@();$script:last33=@()
function Need33($ok,$why){if(-not $ok){throw $why}}
function Hash33($path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function Save33($path,$value){Need33 (-not(Test-Path -LiteralPath $path)) ('Never overwrite evidence '+$path);[IO.File]::WriteAllText((Join-Path $root33 $path),($value|ConvertTo-Json -Depth 100)+"`n",(New-Object Text.UTF8Encoding($false)))}
function Raw33($value){Write-Host ('P33_RAW '+($value|ConvertTo-Json -Depth 20 -Compress))}
function Capture33([string[]]$args33,[string]$label33){
 $start33=[DateTime]::UtcNow.ToString('o');Write-Host ('COMMAND docker '+($args33 -join ' '))
 # Windows PowerShell5.1 wraps benign Docker progress stderr in ErrorRecord.
 # Judge native commands by their actual exit code, restoring EAP immediately.
 $savedAction33=$ErrorActionPreference
 try{$ErrorActionPreference='Continue';$script:last33=@(& docker @args33 2>&1);$exit33=$LASTEXITCODE}finally{$ErrorActionPreference=$savedAction33}
 $script:commands33+=@{command=('docker '+($args33 -join ' '));label=$label33;startUTC=$start33;finishUTC=[DateTime]::UtcNow.ToString('o');exitCode=$exit33}
 if($exit33 -ne 0){$script:last33|ForEach-Object{Write-Host $_};throw ('Docker command failed '+$label33+' exit'+$exit33)}
}
function Decode33{ @(($script:last33 -join "`n")|ConvertFrom-Json)[0] }
function Canon33($value33){
 if($null -eq $value33){return 'null'}
 if($value33 -is [System.Collections.IDictionary]){return '{'+((@($value33.Keys|Sort-Object)|ForEach-Object{(ConvertTo-Json -InputObject ([string]$_) -Compress)+':'+(Canon33 $value33[$_])})-join ',')+'}'}
 if($value33 -is [pscustomobject]){return '{'+((@($value33.PSObject.Properties.Name|Sort-Object)|ForEach-Object{(ConvertTo-Json -InputObject ([string]$_) -Compress)+':'+(Canon33 $value33.$_)})-join ',')+'}'}
 if($value33 -is [System.Collections.IList]){return '['+((@($value33)|ForEach-Object{Canon33 $_})-join ',')+']'}
 return (ConvertTo-Json -InputObject $value33 -Compress -Depth 100)
}
function Render33($file33){
 # Explicit envfile and process-variable isolation: never resolve from main .env.
 $names33=@([regex]::Matches((Get-Content -LiteralPath $file33 -Raw),'\$\{([A-Z_][A-Z0-9_]*)')|ForEach-Object{$_.Groups[1].Value})+@('COMPOSE_ENV_FILES','COMPOSE_PROJECT_NAME','COMPOSE_FILE')
 $saved33=@{}
 try{
  foreach($name33 in @($names33|Select-Object -Unique)){$saved33[$name33]=[Environment]::GetEnvironmentVariable($name33,'Process');[Environment]::SetEnvironmentVariable($name33,$null,'Process')}
  Capture33 @('compose','-p','wed-snap-render33','--project-directory',$root33,'--env-file','infra/log-rotation-lab.env.example','-f',$file33,'config','--format','json') 'render-no-main-env'
  return Decode33
 }finally{foreach($name33 in $saved33.Keys){[Environment]::SetEnvironmentVariable($name33,$saved33[$name33],'Process')}}
}
function WithoutPolicy33($doc33){
 $copy33=$doc33|ConvertTo-Json -Depth 100|ConvertFrom-Json
 foreach($svc33 in $copy33.services.PSObject.Properties){$svc33.Value.PSObject.Properties.Remove('logging')}
 $copy33.PSObject.Properties.Remove('x-logging')
 if($copy33.'x-app'){$copy33.'x-app'.PSObject.Properties.Remove('logging')}
 return $copy33
}
function GuardResolved33($cfg33){
 Need33 ($cfg33.name -eq $project33 -and @($cfg33.services.PSObject.Properties).Count -eq 1 -and -not $cfg33.networks -and -not $cfg33.volumes) 'Own one-service/no network/data volumes'
 $s33=$cfg33.services.probe
 Need33 ($s33.image -eq 'wed-snap-p3-test:local' -and $s33.pull_policy -eq 'never' -and -not $s33.build -and -not $s33.entrypoint -and ($s33.command -join ' ') -eq 'node /probe/probe.cjs') 'Cached image/cmd'
 Need33 ($s33.user -eq 'node' -and $s33.working_dir -eq '/tmp' -and $s33.network_mode -eq 'none' -and -not $s33.networks -and -not $s33.pid -and -not $s33.privileged -and $s33.read_only -and $s33.cap_drop -contains 'ALL' -and $s33.security_opt -contains 'no-new-privileges:true') 'Isolation'
 Need33 ([long]$s33.mem_limit -eq 100663296 -and [double]$s33.cpus -eq .25 -and $s33.pids_limit -eq 32 -and $s33.restart -eq 'no' -and -not $s33.environment -and -not $s33.env_file -and -not $s33.ports -and -not $s33.depends_on) 'Resources/no env/ports/deps'
 Need33 (@($s33.volumes).Count -eq 1 -and $s33.volumes[0].type -eq 'bind' -and $s33.volumes[0].read_only -and $s33.volumes[0].target -eq '/probe/probe.cjs' -and $s33.volumes[0].source.Replace('\','/') -eq (Resolve-Path tests/p33/probe.cjs).Path.Replace('\','/')) 'Exact fixtureRO only'
 Need33 (@($s33.tmpfs).Count -eq 1 -and $s33.tmpfs[0] -eq '/tmp:size=8m,uid=1000,gid=1000,nosuid,noexec') 'Bounded private tmpfs'
 Need33 ((Canon33 $s33.logging) -ceq (Canon33 $expected33.probePolicy)) 'Resolved probe64k/3 strings'
 Raw33 @{stage='resolved-guard';utc=[DateTime]::UtcNow.ToString('o');project=$project33;services=1;network='none';sourceRO='tests/p33/probe.cjs only';rootfsRO=$true;privatePID=$true;memoryMiB=96;cpu=.25;pids=32;ports=0;dataVolumes=0;logging=$s33.logging}
}
function Actual33{
 Capture33 ($labArgs33+@('ps','-a','-q')) 'own-id';$ids33=@($script:last33|Where-Object{$_})
 Need33 ($ids33.Count -eq 1 -and $ids33[0] -match '^[a-f0-9]{64}$') 'Exactly one own container'
 Capture33 @('inspect',$ids33[0]) 'actual-inspect';$c33=Decode33
 Need33 ($c33.Config.Labels.'com.docker.compose.project' -eq $project33 -and $c33.Config.Labels.'com.docker.compose.service' -eq 'probe' -and $c33.Image -eq $pin33 -and $c33.Config.Image -eq 'wed-snap-p3-test:local' -and ($c33.Config.Cmd -join ' ') -eq 'node /probe/probe.cjs') 'Actual identity/image/cmd'
 Need33 ($c33.Config.User -eq 'node' -and $c33.Config.WorkingDir -eq '/tmp' -and $c33.HostConfig.PidMode -eq '' -and $c33.HostConfig.NetworkMode -eq 'none' -and -not $c33.HostConfig.Privileged -and $c33.HostConfig.ReadonlyRootfs -and $c33.HostConfig.CapDrop -contains 'ALL' -and $c33.HostConfig.SecurityOpt -contains 'no-new-privileges:true') 'Actual isolation'
 Need33 ($c33.HostConfig.Memory -eq 100663296 -and $c33.HostConfig.NanoCpus -eq 250000000 -and $c33.HostConfig.PidsLimit -eq 32 -and $c33.HostConfig.RestartPolicy.Name -eq 'no' -and @($c33.HostConfig.PortBindings.PSObject.Properties).Count -eq 0 -and -not $c33.HostConfig.VolumesFrom) 'Actual resources/ports/restart'
 Need33 ((Canon33 @{driver=$c33.HostConfig.LogConfig.Type;options=$c33.HostConfig.LogConfig.Config}) -ceq (Canon33 $expected33.probePolicy)) 'Actual LogConfig64k/3'
 $bind33=@($c33.Mounts|Where-Object Type -eq 'bind')
 Need33 ($bind33.Count -eq 1 -and -not $bind33[0].RW -and $bind33[0].Destination -eq '/probe/probe.cjs' -and @($c33.Mounts|Where-Object{$_.Type -notin @('bind','tmpfs') -or ($_.Type -eq 'tmpfs' -and $_.Destination -ne '/tmp')}).Count -eq 0) 'Actual sole fixture mount/private tmpfs only'
 $host33=(Resolve-Path tests/p33/probe.cjs).Path.Replace('\','/');$desktop33='/run/desktop/mnt/host/d/'+$host33.Substring(3)
 Need33 (@($host33,$desktop33) -contains $bind33[0].Source.Replace('\','/')) 'Actual resolved fixture source'
 Need33 (@($c33.HostConfig.Tmpfs.PSObject.Properties).Count -eq 1) 'Actual tmpfs count'
 foreach($option33 in @('size=8m','uid=1000','gid=1000','nosuid','noexec')){Need33 (($c33.HostConfig.Tmpfs.'/tmp' -split ',') -contains $option33) 'Actual tmpfs options'}
 Need33 (@($c33.NetworkSettings.Networks.PSObject.Properties.Name|Where-Object{$_ -and $_ -ne 'none'}).Count -eq 0) 'Actual no foreign networks'
 Need33 ((Canon33 $c33.Config.Entrypoint) -ceq (Canon33 $image33.Config.Entrypoint) -and (Canon33 $c33.Config.Env) -ceq (Canon33 $image33.Config.Env)) 'No foreign entrypoint/env'
 $script:container33=$c33
 Raw33 @{stage='actual-guard';utc=[DateTime]::UtcNow.ToString('o');project=$project33;containerId=$c33.Id;image=$c33.Image;state=$c33.State.Status;exitCode=$c33.State.ExitCode;cmd=$c33.Config.Cmd;envKeys=@($c33.Config.Env|ForEach-Object{($_ -split '=',2)[0]});networkMode=$c33.HostConfig.NetworkMode;privatePID=($c33.HostConfig.PidMode -eq '');sourceRO=$true;rootfsRO=$true;memory=$c33.HostConfig.Memory;nanoCpus=$c33.HostConfig.NanoCpus;pids=$c33.HostConfig.PidsLimit;ports=0;dataVolumes=0;logging=$c33.HostConfig.LogConfig}
}
$expected33=Get-Content tests/p33/expected.json -Raw|ConvertFrom-Json
$created33=$false;$originalError33=$null
try{
 Raw33 @{stage='start';phase=$Phase;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o');shell=$PSVersionTable.PSVersion.ToString();expectedSHA=Hash33 'tests/p33/expected.json';writerSHA=Hash33 'tests/p33/probe.cjs';runnerSHA=Hash33 $PSCommandPath}
 if($Phase -eq 'Baseline'){
  $before33=Render33 'docs/evidence/p33-20261004-source-before/compose.yaml'
  Need33 (@($before33.services.PSObject.Properties).Count -eq 6) 'Six source services'
  foreach($s33 in $expected33.sourceServices){Need33 (-not $before33.services.$s33.logging) 'Baseline only unspecified source logging'}
  Save33 "$stem33-resolved-before.json" $before33
  Raw33 @{stage='baseline';result='EXPECTED_MISSING_SOURCE_POLICY';services=6;daemonPolicy='NOT INSPECTED/no unlimited claim';sourceSHA=Hash33 'docs/evidence/p33-20261004-source-before/compose.yaml'}
 }elseif($Phase -eq 'Source'){
  $before33=Get-Content "$stem33-resolved-before.json" -Raw|ConvertFrom-Json
  $after33=Render33 'compose.yaml'
  foreach($s33 in $expected33.sourceServices){Need33 ((Canon33 $after33.services.$s33.logging) -ceq (Canon33 $expected33.sourcePolicy)) ('Source10m/3 '+$s33);Need33 ($after33.services.$s33.logging.options.'max-file' -is [string] -and $after33.services.$s33.logging.options.'max-size' -is [string]) 'String options'}
  Need33 ((Canon33 (WithoutPolicy33 $before33)) -ceq (Canon33 (WithoutPolicy33 $after33))) 'Canonical nonlogging fields changed'
  Save33 "$stem33-resolved-final.json" $after33
  Save33 "$stem33-canonical.json" @{result='PASS';sixPolicies=$expected33.sourcePolicy;services=$expected33.sourceServices;nonLoggingCanonicalEqual=$true;sourceBeforeSHA=Hash33 'docs/evidence/p33-20261004-source-before/compose.yaml';sourceAfterSHA=Hash33 'compose.yaml';env='Explicit render placeholder file + cleared/restored process interpolation vars; no main.env';excludedOnly=@('services.*.logging','x-logging','x-app.logging');mainApplied=$false}
  Raw33 @{stage='source';result='PASS';services=6;policy=$expected33.sourcePolicy;nonLoggingCanonicalEqual=$true;mainApplied=$false}
 }elseif($Phase -eq 'Cleanup'){
  Capture33 ($labArgs33+@('config','--format','json')) 'cleanup-config';$cfg33=Decode33;GuardResolved33 $cfg33
  Capture33 @('image','inspect','wed-snap-p3-test:local') 'cleanup-image';$image33=Decode33;Need33 ($image33.Id -eq $pin33) 'Cleanup cached image pin'
  Actual33;$created33=$true
  Raw33 @{stage='cleanup-only';state=$container33.State.Status;identityGuarded=$true;emitGranted=$false;runtimePass=$false}
 }elseif($Phase -eq 'Probe'){
  Need33 (-not(Test-Path "$stem33-retained.log")) 'Do not overwrite probe evidence'
  Capture33 ($labArgs33+@('config','--format','json')) 'lab-config';$cfg33=Decode33;GuardResolved33 $cfg33
  Capture33 @('image','inspect','wed-snap-p3-test:local') 'cached-image';$image33=Decode33
  Need33 ($image33.Id -eq $pin33 -and $image33.Os -eq 'linux' -and -not $image33.Config.Volumes) 'Cached pinned image, no implicit volumes'
  Capture33 ($labArgs33+@('ps','-a','-q')) 'own-preflight-empty';Need33 (@($script:last33|Where-Object{$_}).Count -eq 0) 'Own lab already exists; do not recreate/kill it'
  Save33 "$stem33-probe-resolved.json" $cfg33
  Capture33 @('version','--format','{{json .}}') 'versions';$ver33=Decode33
  Raw33 @{stage='versions';client=$ver33.Client.Version;server=$ver33.Server.Version;serverOs=$ver33.Server.Os;kernel=$ver33.Server.KernelVersion}
  Capture33 ($labArgs33+@('create','--no-build')) 'create-own';$created33=$true;Actual33
  Capture33 ($labArgs33+@('start','probe')) 'start-gated';Actual33;Need33 ($container33.State.Status -eq 'running') 'Writer waiting for guarded grant'
  Capture33 ($labArgs33+@('exec','-T','probe','node','--check','/probe/probe.cjs')) 'writer-syntax'
  Raw33 @{stage='pre-emit';actualGuardComplete=$true;state=$container33.State.Status;expectedRecords=512;expectedSequenceBytes=524288;maxPayload=1048576;sourceThreshold='10m';probeThreshold='64k'}
  Capture33 ($labArgs33+@('exec','-T','probe','node','-e',"require('node:fs').writeFileSync('/tmp/p33-emit','p33-granted',{flag:'wx'})")) 'guarded-grant'
  $until33=[DateTime]::UtcNow.AddSeconds(30)
  do{Actual33;if($container33.State.Status -eq 'exited'){break};Start-Sleep -Milliseconds 250}while([DateTime]::UtcNow -lt $until33)
  Need33 ($container33.State.Status -eq 'exited' -and $container33.State.ExitCode -eq 0 -and -not $container33.State.OOMKilled) 'Actual writer exit0 in30s/no OOM'
  Capture33 ($labArgs33+@('logs','--no-color','--no-log-prefix','--tail','all','probe')) 'retained-all'
  $log33=($script:last33 -join "`n")+"`n";Need33 ([Text.Encoding]::UTF8.GetByteCount($log33) -le 1048576) 'Captured all-log bound'
  [IO.File]::WriteAllText((Join-Path $root33 "$stem33-retained.log"),$log33,(New-Object Text.UTF8Encoding($false)))
  $seq33=@();$done33=@();$doneLine33=''
  foreach($line33 in $script:last33){
   if($line33 -match '^P33_SEQ (\d{6}) (x+)$'){Need33 ($line33.Length+1 -eq 1024) 'Actual line bytes/pattern';$seq33+=([int]$Matches[1])}
   elseif($line33.StartsWith('P33_DONE ')){$doneLine33=$line33;$done33+=($line33.Substring(9)|ConvertFrom-Json)}
   else{Need33 ([string]::IsNullOrWhiteSpace($line33)) 'Unexpected retained line/harness error'}
  }
  Need33 ($seq33.Count -gt 0 -and $seq33.Count -lt 512 -and $seq33[0] -gt 1 -and $seq33[-1] -eq 512 -and $seq33 -notcontains 1 -and $done33.Count -eq 1) 'Old records absent/newest suffix/marker from --tail all'
  Need33 (($seq33 -join ',') -eq (($seq33[0]..512) -join ',')) 'Contiguous retained suffix/no gaps/duplicates'
  Need33 ($done33[0].records -eq 512 -and $done33[0].recordBytes -eq 1024 -and $done33[0].sequenceBytes -eq 524288 -and $done33[0].stderrRecords -eq 0) 'Completion counts'
  $emitted33=524288+[Text.Encoding]::UTF8.GetByteCount($doneLine33+"`n")
  Need33 ($emitted33 -le 1048576) 'Actual emitted bounded'
  $result33=@{stage='probe-result';result='PASS';utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o');containerId=$container33.Id;image=$container33.Image;writerActualExit=$container33.State.ExitCode;writer=$done33[0];emittedBytes=$emitted33;retainedRecords=$seq33.Count;firstRetained=$seq33[0];lastRetained=$seq33[-1];retainedSequence=$seq33;capturedBytes=[Text.Encoding]::UTF8.GetByteCount($log33);read='compose logs --tail all/no prefix, no tailN/no daemon logfiles';actualLogConfig=$container33.HostConfig.LogConfig;sourcePolicy=$expected33.sourcePolicy;probePolicy=$expected33.probePolicy;claimsNotMade=@('exact3 physical files','hard diskcap','runtime10m/main','load/SLA/fullR10');completeAfterDrain=$true}
  Save33 "$stem33-probe-result.json" $result33;Raw33 $result33
 }
}catch{$originalError33=$_;Raw33 @{stage='failure';phase=$Phase;message=$_.Exception.Message;utc=[DateTime]::UtcNow.ToString('o')};throw}
finally{
 if($created33){
  Actual33;Capture33 ($labArgs33+@('stop','--timeout','3')) 'stop-own';Actual33;Capture33 ($labArgs33+@('rm','-f')) 'remove-own'
  Capture33 ($labArgs33+@('ps','-a','-q')) 'own-after-cleanup';Need33 (@($script:last33|Where-Object{$_}).Count -eq 0) 'Own container remains'
  Save33 "$stem33-cleanup.json" @{utc=[DateTime]::UtcNow.ToString('o');ownContainerRemoved=$true;services=1;dataVolumes=0;media=0;mainTouched=$false;rawKept=$true;resetFlushPrune=$false}
  Raw33 @{stage='cleanup';ownContainerRemoved=$true;mainTouched=$false;rawKept=$true}
 }
 Save33 "$stem33-$($Phase.ToLowerInvariant())-commands.json" @{phase=$Phase;utc=[DateTime]::UtcNow.ToString('o');commands=$commands33;interpolationEnvRestored=$true;phaseSuccess=($null -eq $originalError33)}
}
Write-Host ('P33_COMMAND_EXIT 0 '+$Phase+' UTC '+[DateTime]::UtcNow.ToString('o'))
