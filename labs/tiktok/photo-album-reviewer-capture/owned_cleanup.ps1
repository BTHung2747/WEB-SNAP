# Timeout fallback for reviewed child runners only. Never scan/prune globally.
# IDs and ownership nonce come from their bounded saved guard/native receipts.
function CleanupRecorded($resourceDir,[switch]$Cold){
 $records=@();$roles=if($Cold){@('cold-guard.json')}else{@('guard-proxy.json','guard-worker.json','guard-validate.json')};$nonce=$null
 foreach($name in $roles){$path=Join-Path $resourceDir $name;if(-not(Test-Path $path)){continue};$g=SourceRead $path
  $key=if($Cold){'com.wed-snap.album-bootstrap'}else{'com.wed-snap.run'};$value=$g.Config.Labels.$key
  if($g.Id -isnot [string] -or $g.Id -cnotmatch '^[a-f0-9]{64}$' -or $value -isnot [string] -or $value -cnotmatch '^[a-f0-9]{32}$' -or $g.Image -cne(SourceImage)){throw 'OWN_RESOURCE_RECEIPT_INVALID'}
  if($nonce -and $nonce -cne $value){throw 'OWN_RESOURCE_NONCE_MISMATCH'};$nonce=$value;$records+=@{kind='container';id=$g.Id;key=$key;nonce=$value}
 }
 if(-not $Cold -and $nonce -and (Test-Path "$resourceDir/native.jsonl")){
  if((Get-Item "$resourceDir/native.jsonl").Length -gt 2MB){throw 'OWN_NATIVE_CAP'}
  foreach($line in Get-Content -LiteralPath "$resourceDir/native.jsonl"){$row=$line|ConvertFrom-Json -DateKind String;if($row.step -in @('private','secondary') -and $row.actualExit -eq 0){$id=$row.stdout.Trim();if($id -cnotmatch '^[a-f0-9]{64}$'){throw 'OWN_NETWORK_RECEIPT_INVALID'};$records+=@{kind='network';id=$id;key='com.wed-snap.run';nonce=$nonce}}}
 }
 $closed=@();foreach($row in $records){
  $text=& docker $row.kind inspect $row.id 2>$null|Out-String;$rc=$LASTEXITCODE
  if($rc -ne 0){$ids=if($row.kind -ceq 'container'){& docker ps -aq --no-trunc 2>$null}else{& docker network ls --no-trunc --format '{{.ID}}' 2>$null};if($LASTEXITCODE -ne 0 -or $row.id -in $ids){throw 'OWN_RESOURCE_STATE_UNKNOWN'};$closed+=$row.id;continue}
  $g=@($text|ConvertFrom-Json -DateKind String)[0];$labels=if($row.kind -ceq 'container'){$g.Config.Labels}else{$g.Labels}
  if($labels.($row.key) -cne $row.nonce -or $g.Id -cne $row.id){throw 'OWN_LIVE_LABEL_MISMATCH'}
  if($row.kind -ceq 'container'){$null=& docker rm -f $row.id 2>$null}else{$null=& docker network rm $row.id 2>$null};if($LASTEXITCODE -ne 0){throw 'OWN_RESOURCE_CLEANUP_UNKNOWN'};$closed+=$row.id
 }
 # Missing registration is not proof there were no resources. Preserve raw and
 # stop; an operator may inspect only own recorded IDs in a separately reviewed task.
 return @{status=$(if($records.Count){'RECORDED_OWN_IDS_CLOSED'}else{'UNKNOWN_NO_GUARD_REGISTRATION'});recorded=$records.Count;closedIDs=$closed;unregistered='UNKNOWN';globalPrune=0}
}
