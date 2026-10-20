param([ValidateSet('capability','unit')][string]$Mode='capability',[ValidateRange(1,20)][int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev="docs/evidence/tiktok-photo-egress-step3-20261015/$Mode-$Attempt"
if(Test-Path $ev){throw 'Refuse evidence reuse'}
New-Item -ItemType Directory -Path $ev|Out-Null
$image='sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10'
$run=[Guid]::NewGuid().ToString('N');$id=$null
function Native([string]$step,[string[]]$argv){$begin=[DateTimeOffset]::UtcNow;$out=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE;@{step=$step;arguments=$argv;actualExit=$exit;utcStart=$begin.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');output=$out}|ConvertTo-Json -Depth 8 -Compress|Add-Content "$ev/native.jsonl";if($exit){throw "Native $step exit$exit"};return $out.Trim()}
$source=@(Get-ChildItem apps/egress -File -Recurse|Where-Object{$_.FullName -notmatch '[\\/]__pycache__[\\/]'})
$hashes=@($source|Sort-Object FullName|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Resolve-Path apps/egress).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})
$hashes|ConvertTo-Json|Set-Content "$ev/expected-source.json"
try{
 $id=Native 'create' @('create','--pull=never','--label',"com.wed-snap.run=$run",'--network','none','--ipc','private','--read-only','--user','65534:65534','--memory','96m','--memory-swap','96m','--cpus','0.25','--pids-limit','64','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=16m,uid=65534,gid=65534,nosuid,noexec','-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONPATH=/code/src:/code/vendor:/fixture','-e','EGRESS_STEP3_FIXTURE=1','--mount',"type=bind,source=$((Resolve-Path apps/egress).Path),target=/code,readonly",'--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo-egress-step3).Path),target=/fixture,readonly",'--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/out",$image,'/usr/bin/timeout','--signal=KILL','150s','python','/fixture/check.py',$Mode)
 $guard=@((Native 'guard' @('inspect',$id)|ConvertFrom-Json))[0];$guard|ConvertTo-Json -Depth 40|Set-Content "$ev/guard.json"
 if($guard.Config.User -cne '65534:65534' -or !$guard.HostConfig.ReadonlyRootfs -or $guard.HostConfig.Memory -ne 96MB -or $guard.HostConfig.MemorySwap -ne 96MB -or $guard.HostConfig.NanoCpus -ne 250000000 -or $guard.HostConfig.NetworkMode -cne 'none' -or $guard.HostConfig.CapDrop -notcontains 'ALL' -or $guard.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true'){throw 'Guard mismatch'}
 Native 'test' @('start','-a',$id)|Out-Null
 $state=@((Native 'state' @('inspect',$id)|ConvertFrom-Json))[0];if($state.State.ExitCode -ne 0 -or $state.State.OOMKilled){throw 'Actual state failed'}
 foreach($r in $hashes){if((Get-FileHash "apps/egress/$($r.path)").Hash.ToLowerInvariant() -cne $r.sha256){throw 'Source drift'}}
 @{status='PASS_OFFLINE';actualExit=0;sourceCalls=0;image=$image;utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}finally{if($id){$owner=@((Native 'owner' @('inspect',$id)|ConvertFrom-Json))[0];if($owner.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong owner'};Native 'remove-own' @('rm','-f',$id)|Out-Null;$left=Native 'verify-absent' @('ps','-aq','--filter',"label=com.wed-snap.run=$run");if($left){throw 'Owned resources remain'};@{container=$id;run=$run;ownResourcesLeft=0;networksCreated=0;volumesCreated=0}|ConvertTo-Json|Set-Content "$ev/cleanup.json"}}
