$ErrorActionPreference='Stop'
. (Join-Path (Get-Location).Path 'labs/tiktok/ui-source-diagnostic-runtime/wiring.ps1')
$script:LiveARoot=Join-Path (Get-Location).Path 'docs/evidence/ui-source-live-attempt-20261019/backend'
$script:HumanPath='docs/permissions/human-source/UI_TIKTOK_SINGLE_PHOTO_20261019.json'
$script:LiveTask='docs/tasks/UI_TIKTOK_SINGLE_PHOTO_NEW_LAUNCH_20261019.md'
function Live-Ref([string]$Path){@{ref=[IO.Path]::GetRelativePath((Get-Location).Path,[IO.Path]::GetFullPath($Path)).Replace('\','/');sha256=(Get-FileHash $Path).Hash.ToLowerInvariant()}}
function Check-LiveBaseline {
 $d=Verify-Dependencies
 $refs=@(@{root='docs/evidence/ui-source-diagnostic-runtime-20261019/backend';sha='81f5263f32908e54155918a5ce0b385df7867bc134d97b2d163e0d721d7e01c8'},@{root='docs/evidence/ui-source-diagnostic-runtime-attempt-20261019/backend';sha='1c1f9ff573e7f99fa1f5fe5a13f4b39ec17eeb946079257760c2da3025d8d8f5'})
 $pins=@($d.pins)
 foreach($r in $refs){$f=Join-Path $r.root 'manifest.json';if((Get-FileHash $f).Hash.ToLowerInvariant() -cne $r.sha){throw 'LIVE_BASELINE_DRIFT'};$m=Get-Content $f -Raw|ConvertFrom-Json;Assert-Pins $m.implementation;$pins+=@($m.implementation)+@{path=(Resolve-Path $f).Path;sha256=$r.sha};foreach($a in $m.artifacts){$x=@{path=(Resolve-Path (Join-Path $r.root $a.path)).Path;sha256=$a.sha256};Assert-Pins @($x);$pins+=$x};if($m.externalArtifacts){Assert-Pins $m.externalArtifacts;$pins+=@($m.externalArtifacts)}}
 return @{pins=$pins;frozen=$d.frozen}
}
function Read-LiveHuman {
 $h=Get-Content $script:HumanPath -Raw|ConvertFrom-Json
 if($h.directHumanReply -cne 'làm đi' -or $h.maximumSourceAdmissions -ne 1 -or $h.isRuntimeGrant -ne $false -or $h.canonicalURL -cne 'https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421' -or $h.expectedPostID -cne '7678209751167110421' -or $h.selectedIndex -ne 2 -or !$h.labOnly -or $h.mainActivation -or $h.galleryActivation -or $h.deployment -or $h.reuseOldGrantOrClaim){throw 'HUMAN_SCOPE_MISMATCH'}
 return $h
}
function Check-ClockPair($HostBefore,$HostAfter,$Linux){
 if($HostBefore.unixMs -gt $HostAfter.unixMs -or $HostBefore.qpc -ge $HostAfter.qpc -or $HostBefore.frequency -ne $HostAfter.frequency -or $HostAfter.unixMs-$HostBefore.unixMs -gt 2000){throw 'CLOCK_PAIR_UNBOUNDED'}
 if($Linux.unixMs -isnot [long] -and $Linux.unixMs -isnot [int]){throw 'CLOCK_PACKET_TYPE'}
 $lo=$Linux.unixMs-$HostAfter.unixMs;$hi=$Linux.unixMs-$HostBefore.unixMs
 if($lo -lt -1000 -or $hi -gt 1000){throw 'CLOCK_SKEW_NOT_BOUNDED'}
 return @{offsetLowerMs=$lo;offsetUpperMs=$hi;roundTripMs=$HostAfter.unixMs-$HostBefore.unixMs;clockDomains='HOST_QPC_AND_LINUX_MONOTONIC_DISTINCT_UTC_BRACKET_ONLY';status='OBSERVED_WITHIN_BRACKET_NOT_FUTURE_GUARANTEE'}
}
