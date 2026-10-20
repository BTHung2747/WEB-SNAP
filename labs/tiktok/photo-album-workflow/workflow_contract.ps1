# AGPL-3.0 workflow/human binding glue; candidate readers/libraries remain owners.
. 'D:/WED SNAP/labs/tiktok/photo-album-execution-namespace/bootstrap_contract.ps1'
function WorkflowBase{[IO.Path]::GetFullPath('D:\WED SNAP\lab-runs\tiktok-photo-album-workflow-v1')}
function OrchestrationSnapshot{@(rg --files $PSScriptRoot|ForEach-Object {[pscustomobject][ordered]@{path=$_.Replace('\','/');sha256=SHA $_}}|Sort-Object path)}
function WorkflowProposal{
 $p=SourceRead "$PSScriptRoot/proposal.json"
 ExactKeys $p @('version','scope','status','proposalID','draftTaskID','draftAllocationID','target','expectedID','type','selection','quota','preparationSHA','candidateReviewSHA','candidateSourceHash','candidateRuntimeHash','image','trustSHA','workflowCount','sourceGate','downloadGrant')
 if(-not(SourceInteger $p.version 1) -or $p.scope -cne 'DRAFT_NO_AUTHORITY' -or $p.sourceGate -isnot [bool] -or $p.sourceGate -or $p.downloadGrant -isnot [bool] -or $p.downloadGrant -or -not(SourceInteger $p.workflowCount 1) -or $p.proposalID -cnotmatch '^[a-f0-9]{32}$' -or $p.target -cne(SourceTarget) -or $p.expectedID -cne '7678209751167110421' -or $p.type -cne 'photo'){throw 'DRAFT_PROPOSAL_SCHEMA'}
 AlbumIDs $p.draftTaskID $p.draftAllocationID;AlbumSelection $p.selection;AssertAlbumQuota $p.quota 5
 $prep=SourceRead "$PSScriptRoot/inputs/preparation.json";$rv=SourceRead "$PSScriptRoot/inputs/candidate-review.json"
 if($p.preparationSHA -cne(SHA "$PSScriptRoot/inputs/preparation.json") -or $p.candidateReviewSHA -cne(SHA "$PSScriptRoot/inputs/candidate-review.json") -or $p.candidateSourceHash -cne(RowsHash (SourceSnapshot)) -or $p.candidateRuntimeHash -cne(RowsHash (RuntimeExpected -Source)) -or $p.image -cne(SourceImage) -or $p.trustSHA -cne(SourceTrust) -or -not(SameValue $p.selection $prep.selection) -or -not(SameValue $p.quota $prep.quota) -or $rv.preparationSHA -cne $p.preparationSHA -or $rv.scope -cne 'ALBUM_BRIDGE_INDEPENDENT_REVIEW_V1' -or $rv.status -cne 'PASS_INDEPENDENT_ALBUM_BRIDGE_REVIEW'){throw 'CANDIDATE_PROPOSAL_BINDING'}
 return $p
}
function WorkflowQuestion($p,$freezeSHA){
 "Bạn có giao đúng MỘT workflow nguồn all5 proposal=$($p.proposalID), proposalSHA=$(SHA "$PSScriptRoot/proposal.json"), orchestrationFreezeSHA=$freezeSHA, taskID=$($p.draftTaskID), target=$($p.target), indices=1,2,3,4,5, count=5, snapshotKey=$($p.selection.snapshotKey), quotaSHA=$(ObjectSHA $p.quota), retry=0/HEAD=0/redirect=0, cold590s rồi binding/consume/source; không main/gallery/deploy?"
}
function GrantAnswer($p){"Tôi giao MỘT workflow nguồn all5 proposal=$($p.proposalID) taskID=$($p.draftTaskID), đúng đề bài và hạn mức đã review; không retry hoặc deploy."}
function ObjectSHA($v){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($v|ConvertTo-Json -Depth 60 -Compress)))).ToLowerInvariant()}
function NativeReplyContent($text,$question,$reply){
 # Adapter for the public user question-reply envelope observed in this chat.
 # Only JSON is parsed by existing .NET/PowerShell readers; origin authentication
 # remains a separate independent capture review of the trusted native channel.
 if($text -isnot [string] -or [Text.Encoding]::UTF8.GetByteCount($text) -gt 64KB -or $text -match 'codex_delegation|send_message_to_thread'){throw 'HUMAN_NATIVE_RAW_CONTENT'}
 $match=[regex]::Match($text,'\A\s*<send_user_message_question_reply>\s*(?<json>[\s\S]*?)\s*</send_user_message_question_reply>\s*\z')
 if(-not $match.Success){throw 'HUMAN_NATIVE_RAW_CONTENT'}
 $doc=[Text.Json.JsonDocument]::Parse($match.Groups['json'].Value);try{AssertJsonKeys $doc.RootElement}finally{$doc.Dispose()}
 $rows=$match.Groups['json'].Value|ConvertFrom-Json -DateKind String -NoEnumerate
 if($rows -isnot [array] -or $rows.Count -ne 1){throw 'HUMAN_NATIVE_RAW_CONTENT'}
 $row=$rows[0];ExactKeys $row @('questionItemId','question','answer')
 if($row.questionItemId -cne $question.questionItemID -or $row.question -cne $question.title -or $row.answer -cne $reply.answer){throw 'HUMAN_NATIVE_RAW_CONTENT'}
 return $true
}
function WorkflowPath($path,$root){
 ScalarString $path;ScalarString $root;$full=[IO.Path]::GetFullPath($path);$root=[IO.Path]::GetFullPath($root)
 if($full -cne $root -and -not $full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::Ordinal)){throw 'WORKFLOW_PATH_CROSSING'}
 $anchor=$full;while(-not(Test-Path -LiteralPath $anchor)){$anchor=Split-Path $anchor;if(-not $anchor){throw 'WORKFLOW_PATH_MISSING'}};FixedPath $anchor $anchor;return $full
}
function WorkflowWrite($path,$value,$root){
 $full=WorkflowPath $path $root;FixedPath (Split-Path $full) (Split-Path $full)
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($value|ConvertTo-Json -Depth 60 -Compress));if($bytes.Length -gt 2MB){throw 'WORKFLOW_OUTPUT_CAP'}
 $f=[IO.FileStream]::new($full,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$f.Write($bytes);$f.Flush($true)}finally{$f.Dispose()}
}
function WorkflowCopy($src,$dest,$root){
 $dest=WorkflowPath $dest $root;FixedPath (Split-Path $dest) (Split-Path $dest);$bytes=[IO.File]::ReadAllBytes((Resolve-Path $src));if($bytes.Length -gt 2MB){throw 'WORKFLOW_COPY_CAP'}
 $f=[IO.FileStream]::new($dest,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$f.Write($bytes);$f.Flush($true)}finally{$f.Dispose()};if((SHA $src)-cne(SHA $dest)){throw 'WORKFLOW_COPY_HASH'}
}
function HumanBinding($p,$freezeSHA,$question,$reply,$attestation,[switch]$Fixture){
 # Raw role labels alone are NOT authentication: an independent capture review
 # of direct native human input, already sealed, is mandatory before bootstrap.
 ExactKeys $question @('version','scope','tool','callID','questionItemID','threadID','title','utc')
 ExactKeys $reply @('version','scope','origin','actor','role','threadID','messageID','questionItemID','answer','utc')
 ExactKeys $attestation @('version','scope','status','reviewerThreadID','sourceGate','questionSHA','replySHA','nativeRawSHA','proposalSHA','freezeSHA','taskID','target','selection','quota','questionItemID','messageID','utc')
 $qScope=if($Fixture){'OFFLINE_QUESTION_FIXTURE_ONLY'}else{'NATIVE_REQUEST_USER_INPUT_QUESTION_V1'};$aScope=if($Fixture){'OFFLINE_CAPTURE_REVIEW_FIXTURE_ONLY'}else{'ALL5_INDEPENDENT_DIRECT_HUMAN_CAPTURE_REVIEW_V1'}
 if(-not(SourceInteger $question.version 1) -or $question.scope -cne $qScope -or $question.tool -cne 'request_user_input_async' -or $question.callID -isnot [string] -or $question.callID -cnotmatch '^call_[a-zA-Z0-9]+$' -or $question.questionItemID -cne ('["request_user_input_async","'+$question.callID+'",0]') -or $question.threadID -cne '01a11517-a7fc-7e02-ae6c-80cfe5436ba0' -or $question.title -cne (WorkflowQuestion $p $freezeSHA)){throw 'HUMAN_QUESTION_BINDING'}
 if(-not(SourceInteger $reply.version 1) -or $reply.scope -cne $(if($Fixture){'OFFLINE_HUMAN_REPLY_FIXTURE_ONLY'}else{'NATIVE_DIRECT_HUMAN_QUESTION_REPLY_V1'}) -or $reply.origin -cne 'direct_user_input' -or $reply.actor -cne 'human' -or $reply.role -cne 'user' -or $reply.threadID -cne $question.threadID -or $reply.questionItemID -cne $question.questionItemID -or $reply.messageID -isnot [string] -or $reply.messageID.Length -lt 1 -or $reply.answer -cne (GrantAnswer $p) -or $reply.answer -match 'codex_delegation|send_message_to_thread|Hình đúng|watermark TikTok'){throw 'DIRECT_HUMAN_EXACT_TASK_REQUIRED'}
 if(-not(SourceInteger $attestation.version 1) -or $attestation.scope -cne $aScope -or $attestation.status -cne $(if($Fixture){'FIXTURE_CAPTURE_REVIEW_ONLY'}else{'VERIFIED_DIRECT_HUMAN_INPUT_NO_AGENT_OR_CODE_TASK'}) -or $attestation.reviewerThreadID -cne '01a0f38a-e8ce-7872-8415-242b74b560f5' -or $attestation.sourceGate -isnot [bool] -or $attestation.sourceGate -or $attestation.freezeSHA -cne $freezeSHA -or $attestation.proposalSHA -cne(SHA "$PSScriptRoot/proposal.json") -or $attestation.taskID -cne $p.draftTaskID -or $attestation.target -cne $p.target -or -not(SameValue $attestation.selection $p.selection) -or -not(SameValue $attestation.quota $p.quota) -or $attestation.questionItemID -cne $question.questionItemID -or $attestation.messageID -cne $reply.messageID){throw 'INDEPENDENT_HUMAN_CAPTURE_REVIEW_REQUIRED'}
 foreach($v in @($question.utc,$reply.utc,$attestation.utc)){if($v -isnot [string] -or -not $v.EndsWith('Z')){throw 'HUMAN_TIMESTAMP'}}
 if([DateTimeOffset]::Parse($reply.utc) -lt [DateTimeOffset]::Parse($question.utc) -or [DateTimeOffset]::Parse($attestation.utc) -lt [DateTimeOffset]::Parse($reply.utc) -or [DateTimeOffset]::Parse($attestation.utc) -gt [DateTimeOffset]::UtcNow){throw 'HUMAN_TIMESTAMP'}
 return $true
}
function PacketSeal($dir){
 FixedPath $dir $dir;$m=SourceRead "$dir/manifest.json"
 if($m.files -isnot [array] -or $m.files.Count -lt 1 -or $m.files.Count -gt 8){throw 'PACKET_FILE_CAP'}
 if((SHA "$dir/manifest.json") -cne (Get-Content "$dir/manifest.sha256" -Raw).Trim()){throw 'PACKET_MANIFEST_HASH'}
 $names=@();foreach($row in $m.files){ExactKeys $row @('name','sha256');if($row.name -isnot [string] -or $row.name -match '[\\/:]' -or $row.name -in @('.','..') -or $row.name -in $names){throw 'PACKET_FILE_SCHEMA'};$names+=$row.name;FixedPath "$dir/$($row.name)" "$dir/$($row.name)";if((Get-Item "$dir/$($row.name)").Length -gt $(if($row.name -ceq 'native-raw.txt'){64KB}else{2MB})){throw 'PACKET_RAW_CAP'};if((SHA "$dir/$($row.name)")-cne $row.sha256){throw 'PACKET_FILE_HASH'}}
 $files=@(Get-ChildItem -LiteralPath $dir -File|Where-Object Name -NotIn @('manifest.json','manifest.sha256','verification-seal.json','verification-readonly.json')|Select-Object -ExpandProperty Name)
 if(Compare-Object $names $files -CaseSensitive){throw 'PACKET_FULL_COVERAGE'}
 foreach($n in 'verification-seal.json','verification-readonly.json'){$r=SourceRead "$dir/$n";if($r.status -cne 'PASS_INDEPENDENT_WORKFLOW_PACKET' -or -not(SourceInteger $r.actualExit 0) -or $r.manifestSHA -cne(SHA "$dir/manifest.json")){throw 'INDEPENDENT_PACKET_NOT_SEALED'}}
 return SHA "$dir/manifest.json"
}
function WorkflowGates($p,$freezeSHA,[switch]$Fixture,$fixtureData){
 if(-not(SameValue $p (WorkflowProposal))){throw 'PROPOSAL_CHANGED'}
 if($Fixture){$question=$fixtureData.question;$reply=$fixtureData.reply;$att=$fixtureData.attestation;$review=$fixtureData.review;$humanSHA='f'*64;$nativeRaw=$fixtureData.nativeRaw;if($att.questionSHA -cne(ObjectSHA $question) -or $att.replySHA -cne(ObjectSHA $reply) -or $att.nativeRawSHA -cne(ObjectSHA $nativeRaw)){throw 'HUMAN_RAW_SHA'}}
 else{
  $base=Join-Path (WorkflowBase) "reviewed/proposal-$($p.proposalID)";$reviewDir="$base/orchestration";$humanDir="$base/human"
  FixedPath $reviewDir $reviewDir;FixedPath $humanDir $humanDir;$null=PacketSeal $reviewDir;$humanSHA=PacketSeal $humanDir
  $review=SourceRead "$reviewDir/review.json";$question=SourceRead "$humanDir/question.json";$reply=SourceRead "$humanDir/reply.json";$att=SourceRead "$humanDir/capture-review.json"
  foreach($pair in @(@('questionSHA','question.json'),@('replySHA','reply.json'),@('nativeRawSHA','native-raw.txt'))){if($att.($pair[0]) -cne(SHA "$humanDir/$($pair[1])")){throw 'HUMAN_RAW_SHA'}}
  if((Get-Item "$humanDir/native-raw.txt").Length -gt 64KB){throw 'HUMAN_RAW_CAP'}
  $nativeRaw=[IO.File]::ReadAllText((Resolve-Path "$humanDir/native-raw.txt"))
 }
 $null=NativeReplyContent $nativeRaw $question $reply
 ExactKeys $review @('version','scope','status','sourceGate','freezeSHA','proposalSHA','candidateSourceHash','candidateRuntimeHash','reviewerThreadID')
 if(-not(SourceInteger $review.version 1) -or $review.scope -cne $(if($Fixture){'OFFLINE_ORCHESTRATION_REVIEW_FIXTURE_ONLY'}else{'ALL5_INDEPENDENT_ORCHESTRATION_REVIEW_V1'}) -or $review.status -cne $(if($Fixture){'FIXTURE_REVIEW_ONLY'}else{'PASS_INDEPENDENT_WORKFLOW_PROCEDURE'}) -or $review.sourceGate -isnot [bool] -or $review.sourceGate -or $review.freezeSHA -cne $freezeSHA -or $review.proposalSHA -cne(SHA "$PSScriptRoot/proposal.json") -or $review.candidateSourceHash -cne $p.candidateSourceHash -or $review.candidateRuntimeHash -cne $p.candidateRuntimeHash -or $review.reviewerThreadID -cne '01a0f38a-e8ce-7872-8415-242b74b560f5'){throw 'ORCHESTRATION_REVIEW_REQUIRED'}
 $null=HumanBinding $p $freezeSHA $question $reply $att -Fixture:$Fixture
 return @{humanPacketSHA=$humanSHA;taskID=$p.draftTaskID;allocationID=$p.draftAllocationID;capture=$att;question=$question;reply=$reply}
}
