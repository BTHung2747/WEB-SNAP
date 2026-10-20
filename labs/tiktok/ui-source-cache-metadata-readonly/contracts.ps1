$ErrorActionPreference='Stop'
function New-Specs($Roles){
 $expected=@{app='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e';gateway='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e';proxy='sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10';postgres='sha256:38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74';redis='sha256:a9cc41d6d01da2aa26c219e4f99ecbeead955a7b656c1c499cce8922311b2514'}
 if(@($Roles).Count -ne 5){throw 'EXACT_PLANNED_ROLES'}
 foreach($name in $expected.Keys){$one=@($Roles|Where-Object role -CEQ $name);if($one.Count -ne 1 -or $one[0].image -cne $expected[$name]){throw 'IMMUTABLE_SCOPE_ID_MISMATCH'}}
 $info='{"serverVersion":{{json .ServerVersion}},"os":{{json .OSType}},"architecture":{{json .Architecture}},"kernel":{{json .KernelVersion}},"operatingSystem":{{json .OperatingSystem}},"cpus":{{json .NCPU}},"memoryBytes":{{json .MemTotal}},"cgroupVersion":{{json .CgroupVersion}},"cgroupDriver":{{json .CgroupDriver}},"securityOptions":{{json .SecurityOptions}}}'
 $image='{"id":{{json .ID}},"os":{{json .Os}},"architecture":{{json .Architecture}},"sizeBytes":{{json .Size}}}'
 $result=@([pscustomobject]@{key='info';argv=@('info','--format',$info);roles=@();image=$null})
 foreach($map in @(@{key='image-app-gateway';role='app';roles=@('app','gateway')},@{key='image-proxy';role='proxy';roles=@('proxy')},@{key='image-postgres';role='postgres';roles=@('postgres')},@{key='image-redis';role='redis';roles=@('redis')})){
  $id=@($Roles|Where-Object role -CEQ $map.role)[0].image
  if($id -cnotmatch '^sha256:[a-f0-9]{64}$'){throw 'INVALID_PLANNED_IMAGE'}
  $result+= [pscustomobject]@{key=$map.key;argv=@('image','inspect',$id,'--format',$image);roles=$map.roles;image=$id}
 }
 if(@($Roles|Where-Object role -CEQ gateway)[0].image -cne $result[1].image -or @($result|Where-Object image|Select-Object -ExpandProperty image -Unique).Count -ne 4){throw 'FOUR_IMAGE_FIVE_ROLE_CONTRACT'}
 $ps='{"id":{{json .ID}},"name":{{json .Names}},"state":{{json .State}},"run":{{json (.Label "com.wed-snap.run")}}}'
 $network='{"id":{{json .ID}},"name":{{json .Name}},"driver":{{json .Driver}},"scope":{{json .Scope}}}'
 $result+=[pscustomobject]@{key='containers';argv=@('ps','--all','--no-trunc','--filter','label=com.wed-snap.run','--filter','name=wed-source-','--format',$ps);roles=@();image=$null}
 $result+=[pscustomobject]@{key='networks';argv=@('network','ls','--no-trunc','--filter','label=com.wed-snap.run','--filter','name=wed-source-','--format',$network);roles=@();image=$null}
 return $result
}
function Test-NativeOperation($R){return $R.Status -ceq 'PASS' -and $R.Created -and $R.RootInOwnJob -and $R.RootExit -eq 0 -and $null -ne $R.RootExit -and !$R.TerminationRequested -and !$R.Timeout -and !$R.ByteCapExceeded -and $R.FinalActive -eq 0 -and $null -ne $R.FinalActive -and $R.PipesEOF -and $R.CleanupClosed -and $R.LiveHandles -eq 0 -and $R.LiveBuffers -eq 0 -and $R.BackgroundReaders -eq 0}
function Keys($Data,[string[]]$Expected){if(!$Data -or (($Data.PSObject.Properties.Name|Sort-Object) -join '|') -cne (($Expected|Sort-Object) -join '|')){throw 'PROJECTION_KEYS'}}
function Integer($Value){return ($Value -is [int] -or $Value -is [long]) -and $Value -ge 0}
function Read-Projection($Spec,[string]$Text){
 if($Spec.key -cin @('containers','networks')){
  $rows=@(foreach($line in @($Text -split '\r?\n'|Where-Object{![string]::IsNullOrWhiteSpace($_)})){
   $d=$line|ConvertFrom-Json -ErrorAction Stop
   if($Spec.key -ceq 'containers'){
    Keys $d @('id','name','state','run')
    if($d.id -cnotmatch '^[a-f0-9]{64}$' -or $d.name -cnotmatch '^wed-source-([a-f0-9]{32})-[a-z-]+$'){throw 'CONTAINER_SCOPE_FIELDS'}
    $nameRun=$Matches[1]
    if($d.run -cne $nameRun -or $d.state -cnotin @('created','restarting','running','removing','paused','exited','dead')){throw 'CONTAINER_STATE_LABEL'}
   }else{
    Keys $d @('id','name','driver','scope')
    if($d.id -cnotmatch '^[a-f0-9]{64}$' -or $d.name -cnotmatch '^wed-source-[a-f0-9]{32}-[a-z-]+$' -or $d.driver -cnotin @('bridge','host','null','overlay','macvlan','ipvlan','nat') -or $d.scope -cnotin @('local','swarm','global')){throw 'NETWORK_SCOPE_FIELDS'}
   };$d
  })
  return @{status='OBSERVED_READONLY_SCOPED_SNAPSHOT';rows=$rows;count=$rows.Count;labelFilter='com.wed-snap.run';nameFilter='wed-source-';globalAbsence='NOT_CLAIMED';resourceOwnershipOrCleanup='NOT_INFERRED_NO_MUTATION'}
 }
 $d=$Text|ConvertFrom-Json -ErrorAction Stop
 if($Spec.image){
  Keys $d @('id','os','architecture','sizeBytes')
  if($d.id -cne $Spec.image -or $d.os -cne 'linux' -or $d.architecture -cne 'amd64' -or !(Integer $d.sizeBytes)){throw 'IMAGE_ID_PLATFORM_SIZE'}
  return @{status='OBSERVED_READONLY_IMMUTABLE_CACHE_METADATA';fields=$d;roles=@($Spec.roles);runtimeImports='NOT_RUN';mapping='NOT_RUN'}
 }
 Keys $d @('serverVersion','os','architecture','kernel','operatingSystem','cpus','memoryBytes','cgroupVersion','cgroupDriver','securityOptions')
 if($d.serverVersion -cne '29.8.1' -or $d.os -cne 'linux' -or $d.architecture -cnotin @('x86_64','amd64') -or !(Integer $d.cpus) -or $d.cpus -lt 1 -or !(Integer $d.memoryBytes) -or $d.memoryBytes -lt 1){throw 'INFO_IDENTITY_NUMERIC_FIELDS'}
 foreach($key in @('kernel','operatingSystem','cgroupVersion','cgroupDriver')){if([string]$d.$key -cnotmatch '^[A-Za-z0-9._+ ()-]{0,128}$'){throw 'INFO_TEXT_FIELDS'}}
 $safe=@{};foreach($key in @('serverVersion','os','architecture','kernel','operatingSystem','cpus','memoryBytes','cgroupVersion','cgroupDriver')){$safe[$key]=$d.$key}
 $safe.seccompAdvertised=@($d.securityOptions|Where-Object{$_ -match '^name=seccomp(,|$)'}).Count -gt 0
 $safe.cgroupnsAdvertised=@($d.securityOptions|Where-Object{$_ -ceq 'name=cgroupns'}).Count -gt 0
 return @{status='OBSERVED_READONLY_ENGINE_ADVERTISEMENT';fields=$safe;roleEnforcement='NOT_RUN_NOT_INFERRED'}
}
