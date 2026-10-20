# AGPL-3.0 non-source bootstrap reader/producer glue, using v4 primitives.
. "$PSScriptRoot/live_contract.ps1"
function BootstrapWrite($path,$value){
 $parent=Split-Path $path;FixedPath $parent $parent
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject $value -Depth 60 -Compress))
 if($bytes.Length -gt 2MB){throw 'BOOTSTRAP_OUTPUT_CAP'}
 $f=[IO.FileStream]::new($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$f.Write($bytes);$f.Flush($true)}finally{$f.Dispose()}
}
function AssertBootstrap($dir,[switch]$SelfTest,[switch]$Proof){
 if($SelfTest -and $Proof){throw 'BOOTSTRAP_SCOPE'}
 $expected=Join-Path (AlbumRoot) $(if($Proof){'release'}elseif($SelfTest){'self-test/input'}else{'reviewed/input'})
 FixedPath $dir $expected
 $c=BundleRow $dir 'bootstrap-control.json';ExactKeys $c @('stage','sourceGate','coldOnly','bootstrap')
 if($c.stage -cne 'bootstrap' -or $c.sourceGate -isnot [bool] -or $c.sourceGate -or $c.coldOnly -isnot [bool] -or -not $c.coldOnly){throw 'BOOTSTRAP_CONTROL'}
 $a=$c.bootstrap;ExactKeys $a @('version','scope','preparationSHA','reviewSHA','sourceHash','runtimeHash','image','trustSHA','selection','quota','utc','expiresUTC')
 if(-not(SourceInteger $a.version 1) -or $a.scope -cne $(if($SelfTest){'OFFLINE_BOOTSTRAP_SELF_TEST_V1'}else{'ALBUM_COLD_BOOTSTRAP_V1'})){throw 'BOOTSTRAP_SCOPE'}
 HashFields $a @('preparationSHA','reviewSHA','sourceHash','runtimeHash','trustSHA');FreshExpiry $a.utc $a.expiresUTC;AlbumSelection $a.selection;AssertAlbumQuota $a.quota 5
 $p=BundleRow $dir 'preparation.json';ExactKeys $p @('version','scope','sourceGate','sources','runtime','sourceHash','runtimeHash','image','trustSHA','selection','quota')
 if(-not(SourceInteger $p.version 4) -or $p.scope -cne 'ALBUM_BRIDGE_OFFLINE_PREPARATION_V1' -or $p.sourceGate -isnot [bool] -or $p.sourceGate){throw 'BOOTSTRAP_PREPARATION'}
 if($a.preparationSHA -cne (SourceSHA "$dir/preparation.json") -or $a.sourceHash -cne (RowsHash (SourceSnapshot)) -or $a.runtimeHash -cne (RowsHash (RuntimeExpected -Source)) -or (Canonical $p.sources) -cne (Canonical (SourceSnapshot)) -or (Canonical $p.runtime) -cne (Canonical (RuntimeExpected -Source)) -or $a.image -cne (SourceImage) -or $a.trustSHA -cne (SourceTrust)){throw 'BOOTSTRAP_HASH'}
 foreach($k in 'sourceHash','runtimeHash','image','trustSHA','selection','quota'){if(-not(SameValue $a.$k $p.$k)){throw 'BOOTSTRAP_BINDING'}}
 $r=BundleRow $dir 'review.json';ExactKeys $r @('version','scope','status','sourceGate','sourceCalls','actualExit','preparationSHA','sourceHash','runtimeHash','selection','quota','utc')
 if(-not(SourceInteger $r.version 4) -or $r.scope -cne $(if($SelfTest){'OFFLINE_REVIEW_FIXTURE_ONLY'}else{'ALBUM_BRIDGE_INDEPENDENT_REVIEW_V1'}) -or $r.status -cne $(if($SelfTest){'FIXTURE_REVIEW_ONLY'}else{'PASS_INDEPENDENT_ALBUM_BRIDGE_REVIEW'}) -or $r.sourceGate -isnot [bool] -or $r.sourceGate -or -not(SourceInteger $r.sourceCalls 0) -or -not(SourceInteger $r.actualExit 0) -or $a.reviewSHA -cne (SourceSHA "$dir/review.json")){throw 'BOOTSTRAP_REVIEW'}
 foreach($k in 'preparationSHA','sourceHash','runtimeHash','selection','quota'){if(-not(SameValue $a.$k $r.$k)){throw 'BOOTSTRAP_REVIEW_BINDING'}}
 return $a
}
function BootstrapGuard($g){
 $h=$g.HostConfig;ColdGuardCollections $h
 if($g.Image -cne (SourceImage) -or $g.Config.User -cne '65534:65534' -or $h.NetworkMode -cne 'none' -or -not(SourceInteger $h.Memory 96MB) -or -not(SourceInteger $h.MemorySwap 96MB) -or -not(SourceInteger $h.NanoCpus 250000000) -or -not(SourceInteger $h.PidsLimit 64) -or $h.ReadonlyRootfs -isnot [bool] -or -not $h.ReadonlyRootfs -or $h.Privileged -isnot [bool] -or $h.Privileged -or $h.IpcMode -cne 'private' -or @($h.PortBindings.psobject.Properties).Count -or @($h.Devices).Count -or $h.PidMode){throw 'BOOTSTRAP_GUARD'}
 if(($g.Config.Cmd -join '|') -cne '/usr/bin/timeout|--signal=KILL|30s|python3|/integration/bootstrap_probe.py'){throw 'BOOTSTRAP_COMMAND'}
 $dest=@('/integration','/poc','/vendor','/trace_lab','/stock','/app/apps/media/src/tiktok/source_photo','/authority','/control','/out')
 if($g.Mounts -isnot [array] -or $g.Mounts.Count -ne $dest.Count -or (Compare-Object $dest @($g.Mounts.Destination) -CaseSensitive)){throw 'BOOTSTRAP_MOUNTS'}
 foreach($m in $g.Mounts){if($m.Type -cne 'bind' -or $m.RW -isnot [bool] -or $m.RW -cne ($m.Destination -ceq '/out')){throw 'BOOTSTRAP_MOUNTS'}}
}
function AssertBootstrapProof($dir,$preparationSHA,$reviewSHA){
 # Real source only; self-test scopes cannot be promoted by relabelling cold.
 $null=AssertBootstrap $dir -Proof
 $c=BundleRow $dir 'cold-completion.json';ExactKeys $c @('actualExit','sourceCalls','ownResourcesLeft','producerScope','controlSHA','reportSHA','stateSHA','mountsSHA','nativeSHA','utc')
 $control=BundleRow $dir 'bootstrap-control.json';$a=$control.bootstrap
 if($c.producerScope -cne 'ALBUM_COLD_BOOTSTRAP_V1' -or $a.scope -cne 'ALBUM_COLD_BOOTSTRAP_V1' -or $a.preparationSHA -cne $preparationSHA -or $a.reviewSHA -cne $reviewSHA){throw 'BOOTSTRAP_NOT_SOURCE_PROOF'}
 foreach($pair in @(@('controlSHA','bootstrap-control.json'),@('reportSHA','cold-report.json'),@('stateSHA','cold-state.json'),@('mountsSHA','cold-mounts.json'),@('nativeSHA','cold-native.json'))){if($c.($pair[0]) -cne (SourceSHA (Join-Path $dir $pair[1]))){throw 'BOOTSTRAP_PROOF_LINK'}}
 $native=BundleRow $dir 'cold-native.json';if(-not(SourceInteger $native.actualExit 0) -or $native.step -cne 'start'){throw 'BOOTSTRAP_NATIVE'}
 FreshExpiry $a.utc $a.expiresUTC
 $g=BundleRow $dir 'cold-guard.json';BootstrapGuard $g
 if(-not(SameValue (BundleRow $dir 'cold-mounts.json') $g.Mounts)){throw 'BOOTSTRAP_MOUNTS'}
 $s=BundleRow $dir 'cold-state.json';$r=BundleRow $dir 'cold-report.json'
 if($s.Running -isnot [bool] -or $s.Running -or $s.OOMKilled -isnot [bool] -or $s.OOMKilled -or -not(SourceInteger $s.ExitCode 0) -or ([DateTimeOffset]::Parse($s.FinishedAt)-[DateTimeOffset]::Parse($s.StartedAt)).TotalSeconds -gt 30){throw 'BOOTSTRAP_STATE'}
 foreach($k in 'sourceCalls','dnsCalls','httpCalls','networkCalls','fdDelta'){if(-not(SourceInteger $r.$k 0)){throw 'BOOTSTRAP_REPORT'}}
 if($r.scope -cne $a.scope -or $r.controlSHA -cne $c.controlSHA -or -not(SourceInteger $r.uid 65534) -or -not(SourceInteger $r.threadsBefore 1) -or -not(SourceInteger $r.threadsAfter 1) -or $r.sourceMainInvoked -isnot [bool] -or $r.sourceMainInvoked -or $r.fixtureModules -isnot [array] -or $r.fixtureModules.Count -or (Canonical $r.sources) -cne (Canonical (RuntimeExpected -Source)) -or $r.trustSHA -cne (SourceTrust)){throw 'BOOTSTRAP_REPORT'}
 AssertVersions $r
}
