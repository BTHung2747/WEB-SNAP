$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/tiktok-app-integration-20261009/api-2'
if(Test-Path $ev){throw 'Refuse evidence reuse'};New-Item -ItemType Directory -Path $ev|Out-Null
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@()
$image=(docker image inspect wed-snap-tiktok-app-integration:20261009 --format '{{.Id}}')
if($LASTEXITCODE){throw 'Require cached integration lab image'}
$env:TIKTOK_APP_RUN=$run;$env:TIKTOK_APP_IMAGE=$image;$env:TIKTOK_APP_OUTPUT=(Resolve-Path $ev).Path
$empty="$env:TIKTOK_APP_OUTPUT/compose.empty.env";[IO.File]::WriteAllText($empty,'')
$dc=@('compose','--project-directory','D:\WED SNAP','--env-file',$empty,'-f','labs/tiktok/app-integration/compose.yaml')
function Native([string]$step,[string[]]$argv,[switch]$AllowFail){
 $start=[DateTime]::UtcNow;$text=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE
 @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$text}|ConvertTo-Json -Compress|Add-Content "$ev/native.jsonl"
 if($exit -ne 0 -and -not $AllowFail){throw "Native $step exit$exit"};return @{text=$text.Trim();code=$exit}
}
try{
 Native 'config' ($dc+@('config'))|Out-Null
 try{Native 'create' ($dc+@('up','--no-start','--pull','never'))|Out-Null}
 finally{
  $ids=@((Native 'own-containers' @('ps','-a','--no-trunc','--filter',"label=com.wed-snap.run=$run",'--format','{{.ID}}')).text -split '\r?\n'|Where-Object {$_})
  $nets=@((Native 'own-networks' @('network','ls','--no-trunc','--filter',"label=com.wed-snap.run=$run",'--format','{{.ID}}')).text -split '\r?\n'|Where-Object {$_})
 }
 if($ids.Count -ne 3 -or $nets.Count -ne 1){throw 'Require own3containers/internalnetwork'}
 $memory=0
 foreach($id in $ids){
  $c=@((Native 'inspect' @('inspect',$id)).text|ConvertFrom-Json)[0]
  if($c.Config.Labels.'com.wed-snap.run' -cne $run -or $c.Config.Labels.'com.wed-snap.lab' -cne 'tiktok-app-integration' -or -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.Privileged -or $c.HostConfig.CapAdd -or $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or $c.HostConfig.MemorySwap -ne $c.HostConfig.Memory -or $c.HostConfig.IpcMode -cne 'private' -or $c.HostConfig.PidMode -or @($c.HostConfig.PortBindings.PSObject.Properties).Count){throw 'Isolation guard failed'}
  $memory+=$c.HostConfig.Memory
  if($c.Config.Labels.'com.docker.compose.service' -ceq 'app' -and ($c.Image -cne $image -or $c.Config.User -cne '1000:1000' -or $c.HostConfig.Memory -ne 768MB -or $c.Config.Env -notcontains 'TIKTOK_APP_FIXTURE=1' -or $c.Config.Env -notcontains 'APP_ORIGIN=http://tiktok-app-fixture.invalid')){throw 'App identity failed'}
  $c|ConvertTo-Json -Depth 35|Set-Content "$ev/guard-$id.json"
 }
 if($memory -ne 960MB){throw 'Require total lab960MiB'}
 $network=@((Native 'network' @('network','inspect',$nets[0])).text|ConvertFrom-Json)[0]
 if(-not $network.Internal -or $network.Labels.'com.wed-snap.run' -cne $run){throw 'Internal network guard failed'}
 Native 'start' ($dc+@('start','postgres','redis'))|Out-Null
 $appId=@($ids|Where-Object {@((docker inspect $_|ConvertFrom-Json))[0].Config.Labels.'com.docker.compose.service' -ceq 'app'})[0]
 Native 'app-start-only' @('start',$appId)|Out-Null
 $wait=Native 'app-wait' @('wait',$appId)
 Native 'app-logs' @('logs',$appId)|Out-Null
 $actual=@((Native 'app-final-state' @('inspect',$appId)).text|ConvertFrom-Json)[0]
 if($wait.text -cne '0' -or $actual.State.ExitCode -ne 0 -or $actual.State.OOMKilled -or $actual.State.Running){throw 'App actual test failed'}
}finally{
 foreach($id in $ids){
  $c=@((docker inspect $id|ConvertFrom-Json))[0]
  if($c.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong container owner'}
  Native 'remove' @('rm','-f',$id)|Out-Null
 }
 foreach($id in $nets){
  $n=@((docker network inspect $id|ConvertFrom-Json))[0]
  if($n.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong network owner'}
  Native 'remove-network' @('network','rm',$id)|Out-Null
 }
 foreach($key in @('TIKTOK_APP_RUN','TIKTOK_APP_IMAGE','TIKTOK_APP_OUTPUT')){[Environment]::SetEnvironmentVariable($key,$null,'Process')}
}
@{actualExit=0;ownResourcesLeft=0;image=$image;sourceCalls=0;utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
