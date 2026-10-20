# Only an injected test responder, never an executor/process implementation.
function New-FakeNative($Plan,$Options){
 $state=@{calls=[Collections.Generic.List[object]]::new();created=@{};removed=@{};now=0;outcomes=[Collections.Generic.List[object]]::new()}
 $invoke={param($op,$argv,$limit,$cap)
  $state.calls.Add(@{operation=$op;argv=$argv;limit=$limit;cap=$cap})
  $r=[pscustomobject]@{Status='PASS';Created=$true;RootInOwnJob=$true;RootExit=0;RootPID=1234;RootCreationFileTime=100;TerminationRequested=$false;Timeout=$false;ByteCapExceeded=$false;FinalActive=0;BeforeRootRelease=0;AfterRootRelease=0;PipesEOF=$true;CleanupClosed=$true;LiveHandles=0;LiveBuffers=0;BackgroundReaders=0;Events=@();LimitMs=$limit;ByteCap=$cap;ElapsedMs=1;StdoutBytes=0;StderrBytes=0;Phase=$null;Win32Error=$null;Diagnostics=@{Complete=$true;Snapshots=@()};RawOut='';RawErr='SYNTHETIC_RAW_SECRET_NOT_FOR_LOG'}
  $roleName=($op -split '-')[-1];$role=$Plan.roles|Where-Object role -CEQ $roleName;$index=[array]::IndexOf(@('app','proxy','postgres','redis','gateway'),$roleName);$cid=if($index -ge 0){(@('a','b','c','d','e')[$index])*64}else{''}
  if($op -ceq 'images'){$r.RawOut=(@($Plan.roles.image|Sort-Object -Unique)|ForEach-Object{@{id=$_;volumes=$null}|ConvertTo-Json -Compress}) -join "`n"}
  elseif($op -cin @('collision','final-names','final-labels')){}
  elseif($op.StartsWith('create-')){if($state.created.ContainsKey($roleName)){throw 'RECREATE_DENIED'};$state.created[$roleName]=$cid;$r.RawOut=$cid}
  elseif($op.StartsWith('owner-')){
   $g=@{id=$cid;name='/'+$role.name;image=$role.image;run=$Plan.runID;task=$Plan.task}
   if($Options.foreign){$g.run='FOREIGN_SYNTHETIC'};if($Options.missing){$g.Remove('image')};$r.RawOut=$g|ConvertTo-Json -Compress
   if($Options.workExhausted){$state.now=239500};if($Options.allExhausted){$state.now=300001}
  }elseif($op.StartsWith('guard-')){
   $tmp=@{};foreach($v in $role.tmpfs){$x=$v.Split(':',2);$tmp[$x[0]]=$x[1]}
   $g=@{id=$cid;user=$role.user;rootRO=$true;privileged=$false;capAdd=$null;capDrop=@('ALL');security=@('no-new-privileges:true');memory=[long]$role.memoryMiB*1MB;swap=[long]$role.memoryMiB*1MB;pids=[long]$role.pids;nanoCPU=[long]($role.cpu*1e9);ipc='private';cgroupns='private';network='none';portCount=0;networks=@('none');tmpfs=$tmp;mounts=@($role.mounts|ForEach-Object{@{type='bind';target=$_.target;rw=$false}})}
   $r.RawOut=$g|ConvertTo-Json -Depth 32 -Compress;if($Options.guardFail){$r.Status='FAIL';$r.RootExit=20}
  }elseif($op.StartsWith('start-')){
   $pack=@(@{kind='kernel';role=$roleName;ok=$true},@{kind='role';role=$roleName;ok=$true});if($roleName -ceq 'app'){$pack+=@{kind='media-import';role='app';ok=$true}}
   $r.RawOut=($pack|ForEach-Object{$_|ConvertTo-Json -Compress}) -join "`n"
   if($Options.forced){$r.TerminationRequested=$true;$r.Status='FAIL';$r.AfterRootRelease=1}
  }elseif($op.StartsWith('state-')){$r.RawOut=@{id=$cid;running=$false;status=$(if($Options.createdZero){'created'}else{'exited'});exit=0;oom=$false;errorPresent=$false}|ConvertTo-Json -Compress}
  elseif($op.StartsWith('mountTypes-')){$r.RawOut=@{id=$cid;types=@('bind')}|ConvertTo-Json -Compress}
  elseif($op.StartsWith('remove-')){if($argv.Count -ne 3 -or $argv[2] -cne $cid -or $state.created[$roleName] -cne $cid){throw 'FOREIGN_DELETE_DENIED'};$state.removed[$roleName]=$cid}
  elseif($op.StartsWith('absence-')){if($Options.absenceUnknown){$r.RawOut=$cid}}
  else{throw 'UNKNOWN_FAKE_OPERATION'}
  $state.outcomes.Add(@{operation=$op;result=$r;status=$r.Status;exit=$r.RootExit;forced=$r.TerminationRequested});return $r
 }.GetNewClosure()
 $now={$state.now}.GetNewClosure();return @{invoke=$invoke;state=$state;now=$now}
}
