$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='docs/evidence/tiktok-photo-trace-integration-20261010/preflight';if(Test-Path $root){throw 'Refuse preflight reuse'};New-Item -ItemType Directory $root|Out-Null
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e';$run=[Guid]::NewGuid().ToString('N');$id=$null
function Native($step,[string[]]$argv){$txt=& docker @argv 2>&1|Out-String;$rc=$LASTEXITCODE;@{step=$step;actualExit=$rc;output=$txt;utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Compress|Add-Content "$root/native.jsonl";if($rc){throw ('Preflight:{0}:{1}' -f $step,$rc)};return $txt.Trim()}
try{
 $id=Native 'create' @('create','--label','com.wed-snap.lab=tiktok-photo-trace','--label',"com.wed-snap.run=$run",'--network','none','--read-only','--user','65534:65534','--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','96m','--memory-swap','96m','--cpus','0.25','--pids-limit','64','--ipc','private','--tmpfs','/tmp:size=32m,uid=65534,gid=65534,noexec,nosuid','--mount',"type=bind,source=$((Resolve-Path labs/tiktok/photo-trace).Path),target=/integration,readonly",'-e','PYTHONDONTWRITEBYTECODE=1',$image,'python3','/integration/probe.py')
 $guard=@((Native 'inspect' @('inspect',$id))|ConvertFrom-Json)[0]
 $guard|ConvertTo-Json -Depth 30|Set-Content "$root/guard.json"
 $text=Native 'runtime' @('start','-a',$id);$r=$text|ConvertFrom-Json
 if($r.python -cne '3.11.2' -or $guard.Image -cne $image -or $guard.HostConfig.Memory -ne 96MB){throw 'Proxy cache pin/guard'}
 foreach($f in $r.core){if((Get-FileHash "apps/media/src/tiktok/$($f.path)").Hash.ToLower() -cne $f.sha256){throw 'Runtime core mismatch'}}
 $text|Set-Content "$root/runtime.json"
 Native 'main' @('image','inspect','wed-snap-app:local','--format','{{.Id}}')|Set-Content "$root/main-image.txt"
}finally{
 if($id){$owner=@((docker inspect $id|ConvertFrom-Json))[0];if($owner.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Owner'};Native 'remove' @('rm','-f',$id)|Out-Null}
}
Write-Output 'PASS cache actual proxy Python3.11.2 at96MiB; core/runtime pins'

