. "$PSScriptRoot/workflow_contract.ps1"
. "$PSScriptRoot/owned_cleanup.ps1"
function ColdFresh($record,[switch]$Fixture){
 if($record.scope -cne $(if($Fixture){'OFFLINE_COLD_FIXTURE_ONLY'}else{'ALBUM_SOURCE_COLD_ATTESTATION_V1'}) -or $record.status -cne $(if($Fixture){'FIXTURE_COLD_ONLY'}else{'PASS_SOURCE_ONLY_COLD_NETWORK_NONE'}) -or -not(SourceInteger $record.actualExit 0)){throw 'COLD_NATIVE_REQUIRED'}
 $utc=[DateTimeOffset]::Parse($record.utc);$lease=[DateTimeOffset]::Parse($record.bootstrapExpiresUTC);$now=[DateTimeOffset]::UtcNow
 if($utc -gt $now -or $now -ge $lease -or ($now-$utc).TotalSeconds -ge 600 -or ($lease-$utc).TotalSeconds -gt 600){throw 'EXPIRED_FOR_SOURCE'}
 return $lease
}
function SourceRows($p,$cold,$prepSHA,$reviewSHA,[switch]$Fixture){
 $end=ColdFresh $cold -Fixture:$Fixture;$now=[DateTimeOffset]::UtcNow;$candidateEnd=$now.AddSeconds(600);if($candidateEnd -lt $end){$end=$candidateEnd}
 $issued=$now.UtcDateTime.ToString('o');$expires=$end.UtcDateTime.ToString('o')
 $release=@{version=4;scope=$(if($Fixture){'OFFLINE_SOURCE_RELEASE_FIXTURE_ONLY'}else{'ALBUM_SOURCE_RELEASE_V1'});status=$(if($Fixture){'FIXTURE_RELEASE_ONLY'}else{'REVIEWED_BOUND_RELEASE'});sourceGate=([bool](-not $Fixture));preparationSHA=$prepSHA;reviewSHA=$reviewSHA;freshColdSHA=$cold.proofSHA;sourceHash=$p.candidateSourceHash;runtimeHash=$p.candidateRuntimeHash;target=$p.target;expectedID=$p.expectedID;type='photo';selection=$p.selection;validatedN=5;quota=$p.quota;image=$p.image;trustSHA=$p.trustSHA;taskID=$p.draftTaskID;allocationID=$p.draftAllocationID;utc=$issued;expiresUTC=$expires}
 # Use the existing v4 shape validator in fixtures as well. JSON roundtrip is
 # only for the expected typed receipt object; it grants no authority.
 ReleaseShape ($release|ConvertTo-Json -Depth 60|ConvertFrom-Json -DateKind String)
 return $release
}
function NativeWorkflow($phase,[string[]]$arguments,[int]$timeout,$out,$root,$resourceDir,[switch]$Cold){
 $begin=[DateTime]::UtcNow;$psi=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source);$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 foreach($arg in $arguments){$psi.ArgumentList.Add($arg)};$proc=[Diagnostics.Process]::new();$proc.StartInfo=$psi;$null=$proc.Start();$stdout=$proc.StandardOutput.ReadToEndAsync();$stderr=$proc.StandardError.ReadToEndAsync();$expired=-not $proc.WaitForExit($timeout*1000)
 if($expired){$proc.Kill($true);$proc.WaitForExit()};$null=$stdout.GetAwaiter().GetResult();$null=$stderr.GetAwaiter().GetResult();$rc=$proc.ExitCode;$proc.Dispose()
 WorkflowWrite "$out/native-$phase.json" @{phase=$phase;actualExit=$rc;timeout=$timeout;timedOut=$expired;utcStart=$begin.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o')} $root
 if($expired -or $rc -ne 0){
  if($resourceDir){$cleanup=@{status='UNKNOWN';code='FIXED_OWN_CLEANUP_REFUSAL'};try{$cleanup=CleanupRecorded $resourceDir -Cold:$Cold}catch{};WorkflowWrite "$out/cleanup-$phase.json" $cleanup $root}
  throw 'WORKFLOW_NATIVE_FAIL_STOP'
 };return $rc
}
function RealCold($p,$gate,$out,$root){
 $id=[Guid]::NewGuid().ToString('N');SetAlbumExecution $id;$exec=NewAlbumExecution;New-Item -ItemType Directory "$exec/reviewed/input"|Out-Null;$dir="$exec/reviewed/input"
 WorkflowCopy "$(CandidatePacketDirectory)/preparation.json" "$dir/preparation.json" $exec;WorkflowCopy "$(CandidatePacketDirectory)/review.json" "$dir/review.json" $exec
 $issued=[DateTime]::UtcNow;$expires=$issued.AddSeconds(590)
 BootstrapWrite "$dir/bootstrap-control.json" @{stage='bootstrap';sourceGate=$false;coldOnly=$true;bootstrap=@{version=1;scope='ALBUM_COLD_BOOTSTRAP_V1';preparationSHA=$p.preparationSHA;reviewSHA=$p.candidateReviewSHA;sourceHash=$p.candidateSourceHash;runtimeHash=$p.candidateRuntimeHash;image=$p.image;trustSHA=$p.trustSHA;selection=$p.selection;quota=$p.quota;utc=$issued.ToString('o');expiresUTC=$expires.ToString('o')}}
 $null=AssertBootstrap $dir
 $null=NativeWorkflow 'cold' @('-NoProfile','-File',(CandidatePaths).bootstrap,'-ExecutionID',$id) 120 $out $root "$exec/reviewed/cold" -Cold
 $cold=SourceRead "$exec/reviewed/cold/cold.json";$cc=SourceRead "$exec/reviewed/cold/cold-completion.json";$state=SourceRead "$exec/reviewed/cold/cold-state.json"
 if($cc.ownResourcesLeft -ne 0 -or $cc.actualExit -ne 0 -or $state.ExitCode -ne 0 -or $state.OOMKilled -or $state.Running){throw 'COLD_NATIVE_REQUIRED'}
 $record=@{scope=$cold.scope;status=$cold.status;actualExit=$cold.actualExit;utc=$cold.utc;bootstrapExpiresUTC=$expires.ToString('o');proofSHA=SHA "$exec/reviewed/cold/cold.json";storageID=$id;root=$exec;source="$exec/reviewed/cold"}
 $null=ColdFresh $record
 # Proof-only folder, no release grant yet. Reuse full real proof reader BEFORE
 # creating release/auth/allocation; no human wait or review after fresh cold.
 New-Item -ItemType Directory "$exec/release"|Out-Null
 foreach($name in 'preparation.json','review.json','bootstrap-control.json','cold.json','cold-guard.json','cold-mounts.json','cold-completion.json','cold-report.json','cold-state.json','cold-native.json'){WorkflowCopy "$($record.source)/$name" "$exec/release/$name" $exec}
 AssertBootstrapProof "$exec/release" $p.preparationSHA $p.candidateReviewSHA
 return $record
}
function IssueSourceBundle($p,$gate,$freezeSHA,$cold){
 SetAlbumExecution $cold.storageID;$dir="$($cold.root)/release";$release=SourceRows $p $cold $p.preparationSHA $p.candidateReviewSHA
 # Supplemental provenance was verified pre-bootstrap and is checked again
 # against current sealed human packet before issuance and before child consume.
 WorkflowWrite "$dir/release.json" $release $cold.root;$releaseSHA=SHA "$dir/release.json"
 $auth=@{version=4;scope='ALBUM_SOURCE_HUMAN_TASK_V1';status='HUMAN_AUTHORIZED';releaseSHA=$releaseSHA;reviewSHA=$p.candidateReviewSHA;taskID=$p.draftTaskID;allocationID=$p.draftAllocationID;target=$p.target;selection=$p.selection;quota=$p.quota;utc=$release.utc;expiresUTC=$release.expiresUTC}
 WorkflowWrite "$dir/authorization.json" $auth $cold.root
 $allocation=@{version=4;scope='ALBUM_SOURCE_ALLOCATION_V1';releaseSHA=$releaseSHA;authorizationSHA=SHA "$dir/authorization.json";taskID=$p.draftTaskID;allocationID=$p.draftAllocationID;target=$p.target;expectedID=$p.expectedID;type='photo';selection=$p.selection;validatedN=5;quota=$p.quota;utc=$release.utc;expiresUTC=$release.expiresUTC}
 WorkflowWrite "$dir/allocation.json" $allocation $cold.root
 WorkflowWrite "$dir/human-provenance.json" @{version=1;scope='ALL5_RAW_HUMAN_PROVENANCE_V1';proposalSHA=ProposalSHA $p;freezeSHA=$freezeSHA;humanPacketSHA=$gate.humanPacketSHA;questionSHA=$gate.capture.questionSHA;replySHA=$gate.capture.replySHA;nativeRawSHA=$gate.capture.nativeRawSHA;questionItemID=$gate.capture.questionItemID;messageID=$gate.capture.messageID;taskID=$p.draftTaskID;releaseSHA=$releaseSHA;authorizationSHA=SHA "$dir/authorization.json";allocationSHA=SHA "$dir/allocation.json"} $cold.root
 $null=AssertLiveBundle $dir
 return @{directory=$dir;release=$release;provenanceSHA=SHA "$dir/human-provenance.json"}
}
function RunWorkflow($p,$freezeSHA,[switch]$Fixture,$fixtureData,$fixtureRoot){
 if($Fixture){
  ScalarString $fixtureRoot;$expectedBase=Join-Path (WorkflowBase) 'offline';$full=[IO.Path]::GetFullPath($fixtureRoot)
  if((Split-Path $full)-cne $expectedBase -or (Split-Path $full -Leaf)-cnotmatch '^fixture-[a-f0-9]{32}$'){throw 'FIXTURE_NAMESPACE_REQUIRED'}
  if(-not(SameValue $fixtureData.candidatePaths (CandidatePaths))){throw 'FIXTURE_CANDIDATE_PATH_PIN'}
 }
 $gate=WorkflowGates $p $freezeSHA -Fixture:$Fixture -fixtureData $fixtureData
 $root=if($Fixture){$fixtureRoot}else{Join-Path (WorkflowBase) "real/task-$($p.draftTaskID)"};$registry=if($Fixture){Join-Path $fixtureRoot 'fixture-registry'}else{Join-Path (WorkflowBase) 'real/workflow-registry'}
 $null=WorkflowPath $root $(if($Fixture){$fixtureRoot}else{WorkflowBase});$null=WorkflowPath $registry $(if($Fixture){$fixtureRoot}else{WorkflowBase})
 # Preflight duplicates BEFORE cold, and approval reservation prevents a second
 # cold/workflow via another execution ID. Keep reservation on all later FAILs.
 if((Test-Path "$root/workflow-result.json") -or (Test-Path "$root/reservation.json")){throw 'WORKFLOW_OUTPUT_REUSE'}
 if(-not $Fixture){SetAlbumExecution ('0'*32);$taskPath=Join-Path (AlbumRegistryRoot) "task-$($p.draftTaskID)/task-latch.json";if(Test-Path $taskPath){throw 'TASK_ALREADY_CONSUMED'}}
 if(-not(Test-Path $root)){New-Item -ItemType Directory $root|Out-Null};if(-not(Test-Path $registry)){New-Item -ItemType Directory $registry|Out-Null}
 $reservation="$registry/workflow-$($p.draftTaskID).json"
 WorkflowWrite $reservation @{version=1;scope=$(if($Fixture){'OFFLINE_WORKFLOW_RESERVATION_FIXTURE_ONLY'}else{'ALL5_WORKFLOW_RESERVED_BEFORE_BOOTSTRAP'});proposalSHA=ProposalSHA $p;freezeSHA=$freezeSHA;taskID=$p.draftTaskID;allocationID=$p.draftAllocationID;humanPacketSHA=$gate.humanPacketSHA;sourceGate=$false;utc=[DateTime]::UtcNow.ToString('o')} $(if($Fixture){$fixtureRoot}else{WorkflowBase})
 WorkflowCopy $reservation "$root/reservation.json" $(if($Fixture){$fixtureRoot}else{WorkflowBase})
 $trace=@('HUMAN_AND_REVIEW_VALIDATED','WORKFLOW_RESERVED_BEFORE_BOOTSTRAP')
 try{
  if($Fixture){$cold=$fixtureData.cold;$trace+='COLD_FIXTURE_NO_DOCKER';$null=ColdFresh $cold -Fixture;$release=SourceRows $p $cold ('a'*64) ('b'*64) -Fixture;WorkflowWrite "$root/fixture-binding.json" $release $fixtureRoot;$trace+=@('FIXTURE_BINDING_ONLY','FIXTURE_CONSUME_SIMULATED','FIXTURE_SOURCE_SIMULATED_NO_HTTP');$sourceExit=$fixtureData.sourceExit;if(-not(SourceInteger $sourceExit 0)){throw 'WORKFLOW_NATIVE_FAIL_STOP'}}
  else{
   $cold=RealCold $p $gate $root (WorkflowBase);$trace+='REAL_COLD_NATIVE_AND_RAW_VERIFIED'
   $secondGate=WorkflowGates $p $freezeSHA;if($secondGate.humanPacketSHA -cne $gate.humanPacketSHA){throw 'HUMAN_PACKET_CHANGED'}
   $bundle=IssueSourceBundle $p $gate $freezeSHA $cold;$trace+='SOURCE_BUNDLE_AND_PROVENANCE_BOUND'
   $thirdGate=WorkflowGates $p $freezeSHA;$h=SourceRead "$($bundle.directory)/human-provenance.json"
   if($thirdGate.humanPacketSHA -cne $h.humanPacketSHA -or (SHA "$($bundle.directory)/human-provenance.json")-cne $bundle.provenanceSHA -or (SHA "$($bundle.directory)/release.json")-cne $h.releaseSHA -or (SHA "$($bundle.directory)/authorization.json")-cne $h.authorizationSHA -or (SHA "$($bundle.directory)/allocation.json")-cne $h.allocationSHA){throw 'HUMAN_PROVENANCE_CHANGED'}
   $null=ColdFresh $cold;$null=AssertLiveBundle $bundle.directory
   $remaining=([DateTimeOffset]::Parse($bundle.release.expiresUTC)-[DateTimeOffset]::UtcNow).TotalSeconds;if($remaining -lt 1){throw 'EXPIRED_FOR_SOURCE'}
   $timeout=[int][Math]::Min(350,[Math]::Floor($remaining)) # host cap, active source225 remains in candidate.
   $sourceDir=Join-Path (AlbumRegistryRoot) "task-$($p.draftTaskID)"
   $sourceExit=NativeWorkflow 'source' @('-NoProfile','-File',(CandidatePaths).source,'-Stage','source','-ExecutionID',$cold.storageID,'-SourceReleasePath',"$($bundle.directory)/release.json") $timeout $root (WorkflowBase) $sourceDir
   $trace+='CANDIDATE_ATOMIC_CONSUME_SOURCE_NATIVE_EXIT0'
  }
  WorkflowWrite "$root/workflow-result.json" @{status=$(if($Fixture){'PASS_OFFLINE_ORCHESTRATION_FIXTURE_ONLY'}else{'SOURCE_TECHNICAL_RESULT_REQUIRES_FILE_AND_HUMAN_VISUAL_REVIEW'});sourceGate=([bool](-not $Fixture));fixture=[bool]$Fixture;sourceCalls=$(if($Fixture){0}else{'UNKNOWN_USE_CANDIDATE_ACCOUNTING'});realClaims=$(if($Fixture){0}else{1});taskID=$p.draftTaskID;sourceActualExit=$sourceExit;trace=$trace} $(if($Fixture){$fixtureRoot}else{WorkflowBase})
  return $trace
 }catch{
  WorkflowWrite "$root/workflow-failure.json" @{status='FAIL_STOP_NO_RETRY';code='FIXED_WORKFLOW_OPERATION_REFUSAL';trace=$trace;sourceGate=([bool](-not $Fixture));realClaims=$(if($Fixture){0}else{'UNKNOWN_USE_CANDIDATE_LATCH'});utc=[DateTime]::UtcNow.ToString('o')} $(if($Fixture){$fixtureRoot}else{WorkflowBase});throw
 }
}
