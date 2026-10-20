# P37.4: one B analyze on each owner-provided network; never changes host networking.
param(
    [Parameter(Mandatory=$true)][ValidateSet('prepare','offline','analyze','summary')][string]$Stage,
    [ValidateSet('current','alternate')][string]$NetworkSlot='current',
    [string]$NetworkPlanFile='', [string]$NetworkProofFile='',
    [string]$CaseDir='docs/evidence/p37-4-r-20261007/case-current-final',
    [string]$EvidenceDir='docs/evidence/p37-4-20261007/offline'
)
Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
$ROOT='D:\WED SNAP'; Set-Location $ROOT
$casePath=[IO.Path]::GetFullPath((Join-Path $ROOT $CaseDir))
$evidenceRoot=[IO.Path]::GetFullPath("$ROOT\docs\evidence\")
if(-not $casePath.StartsWith($evidenceRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Case must be inside docs/evidence'}
$core=@('tests/p37/guard_374.ps1','tests/p37/run-374.ps1','tests/p37/probe_374.py',
    'tests/p37/lab372.py','infra/compose.tiktok-lab-374.yaml')
function SHA([string]$f){(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower()}
if($Stage -eq 'prepare'){
    if(Test-Path -LiteralPath $casePath){throw 'Refuse reused case'}
    $proof=Get-Content (Join-Path $ROOT "$EvidenceDir/offline-config-proof.json") -Raw | ConvertFrom-Json
    if(-not $proof.no_request_made -or $proof.network -ne 'none'){throw 'Missing validated offline configuration proof'}
    New-Item -ItemType Directory -Path $casePath | Out-Null
    $proof.configuration | ConvertTo-Json -Depth 15 | Set-Content "$casePath/fixed-configuration.json" -Encoding utf8
    @{configuration_sha256=$proof.configuration_sha256;file_sha256=(SHA "$casePath/fixed-configuration.json")} | ConvertTo-Json | Set-Content "$casePath/config-pin.json" -Encoding utf8
    @(foreach($f in $core){@{file=$f;sha256=(SHA $f)}}) | ConvertTo-Json | Set-Content "$casePath/source-pin.json" -Encoding utf8
    @{utc=[DateTime]::UtcNow.ToString('o');status='PREPARED_WAITING_NETWORK';analyzeAttempts=0;
        missing=@('owner-provided alternate network and permission','approved outbound verification method and active own-egress proof');
        sourceRequestsMade=0;runtimeMetadata='NOT_RUN'} | ConvertTo-Json -Depth 5 | Set-Content "$casePath/preparation.json" -Encoding utf8
    Write-Output 'PREPARED; 0 analyze; owner network plan/proof required before either source call'
    exit 0
}
if($Stage -eq 'summary'){
    # Interpret existing reports only. Completeness and comparability are separate from metadata outcome.
    function ReportValue($obj,[string]$key){
        if($null -ne $obj){$p=$obj.PSObject.Properties[$key];if($null -ne $p){return ,$p.Value}}
        return $null
    }
    function ByteCount($value){return ($value -is [long] -or $value -is [int]) -and $value -ge 0}
    $entries=@();$errors=@();$complete=@();$fileCount=0;$parsedCount=0
    foreach($slot in @('current','alternate')){
        $file="$casePath/$slot/ab-attempt-B.json"
        $present=Test-Path -LiteralPath $file
        $r=$null;$valid=$false;$metadata='UNKNOWN';$harness='UNKNOWN'
        if($present){
            $fileCount++
            try{$r=Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -ErrorAction Stop;$parsedCount++}
            catch{$errors+="$slot : malformed or unreadable report JSON"}
            $flag=ReportValue $r 'metadata_status'
            if($flag -in @('PASS','FAIL')){$metadata=$flag}
            $flag=ReportValue $r 'harness_status'
            if($flag -in @('COMPLETED','NOT_COMPLETED','FAILED')){$harness=$flag}
            $requests=ReportValue $r 'requests'
            $valid=($r -is [pscustomobject]) -and $harness -eq 'COMPLETED' -and $metadata -in @('PASS','FAIL') -and
                ((ReportValue $r 'configuration_sha256') -match '^[a-f0-9]{64}$') -and ($requests -is [array]) -and
                ((ReportValue $r 'diagnostic_bytes_consistent') -is [bool]) -and
                (ByteCount (ReportValue $r 'response_bytes_sum')) -and (ByteCount (ReportValue $r 'total_decoded_bytes'))
            if($valid -and $metadata -eq 'PASS'){
                $info=ReportValue $r 'result';$formats=ReportValue $info 'formats'
                $valid=([bool](ReportValue $info 'id')) -and ($formats -is [array]) -and @($formats).Count -gt 0
            }
            if($valid){$complete+=$r}else{$errors+="$slot : report incomplete or input harness outcome unknown"}
        }
        $entries+=@{slot=$slot;report_present=$present;report_complete=$valid;metadata_status=$metadata;harness_status=$harness}
    }
    $result=@{analyze_reports=$parsedCount;report_files=$fileCount;complete_reports=$complete.Count;status='NOT_RUN';
        input_harness_status='UNKNOWN';metadata=@($entries | Where-Object {$_.report_present} | ForEach-Object {$_.metadata_status});
        observed_outcomes=$entries;comparability_limits=@();report_errors=$errors;cause='UNKNOWN';
        conclusion='No source reports; metadata NOT_RUN.'}
    if($complete.Count -eq 2 -and $errors.Count -eq 0){
        $limits=@();$signatures=@()
        if($complete[0].configuration_sha256 -cne $complete[1].configuration_sha256){$limits+='fixed configuration mismatch'}
        foreach($r in $complete){
            $sum=0;$signature=@()
            if(-not $r.diagnostic_bytes_consistent -or $r.response_bytes_sum -ne $r.total_decoded_bytes){$limits+='response byte/aggregate mismatch'}
            if(@($r.requests).Count -eq 0){$limits+='actual target/header/request evidence unavailable'}
            foreach($request in $r.requests){
                $n=ReportValue $request 'decoded_bytes'
                if(ByteCount $n){$sum+=$n}elseif($null -ne $n){$limits+='response byte evidence malformed'}
                $target=ReportValue $request 'effective_target';$handler=ReportValue $request 'actual_handler';$method=ReportValue $request 'method'
                $headers=ReportValue $request 'prepared_headers_safe'
                if(-not $target -or $target -eq 'unknown' -or -not $handler -or -not $method -or
                   $headers -isnot [pscustomobject] -or @($headers.PSObject.Properties).Count -eq 0){$limits+='actual target/header/request evidence unavailable'}
                $sortedHeaders=[ordered]@{}
                if($headers -is [pscustomobject]){foreach($p in ($headers.PSObject.Properties | Sort-Object Name)){$sortedHeaders[$p.Name.ToLowerInvariant()]=$p.Value}}
                $signature+=[ordered]@{method=$method;handler=$handler;target=$target;prepared_headers=$sortedHeaders}
            }
            if($sum -ne $r.total_decoded_bytes){$limits+='final response bytes do not sum to aggregate'}
            $signatures+=ConvertTo-Json -InputObject $signature -Depth 10 -Compress
        }
        if($signatures[0] -cne $signatures[1]){$limits+='actual target/header/request-sequence differs or unavailable'}
        $result.comparability_limits=@($limits | Select-Object -Unique)
        $result.input_harness_status='COMPLETED'
        if($result.comparability_limits.Count -gt 0){
            $result.status='OBSERVED_TWO_REPORTS'
            $result.conclusion='Observed metadata outcomes at two times only; recorded controls are not comparable and cause remains unknown.'
        }else{
            $result.status='MEASURED_TWO_NETWORKS'
            $result.conclusion=if($result.metadata[0] -eq 'FAIL' -and $result.metadata[1] -eq 'PASS'){
                'Metadata differed at two observation times with comparable recorded controls; compatible with network-condition sensitivity at those times, not proof of a specific cause, all IPs or stable availability.'
            }elseif(@($result.metadata | Where-Object {$_ -eq 'PASS'}).Count -eq 0){
                'Both metadata FAIL; observed causes only, IP/captcha/maintenance cause remains unproven.'
            }else{'Report each observed metadata outcome with comparable recorded controls; cause remains unknown; no download/watermark acceptance.'}
        }
    }elseif($fileCount -gt 0){
        $result.status='PARTIAL'
        $result.conclusion='Available metadata flags only; reports or input harness outcomes are incomplete/unknown. Cause remains unknown.'
    }
    $result | ConvertTo-Json -Depth 10
    exit 0
}
# Validate both network availability/authorization and active own-egress proof before Docker or source calls.
$caseLock=$null; $receipt=$null
if($Stage -eq 'analyze'){
    if(-not $NetworkPlanFile -or -not $NetworkProofFile){Write-Output 'NOT_RUN: missing owner-provided alternate network/permission and outbound proof';exit 40}
    $plan=Get-Content -LiteralPath $NetworkPlanFile -Raw | ConvertFrom-Json
    $receipt=Get-Content -LiteralPath $NetworkProofFile -Raw | ConvertFrom-Json
    if($plan.schema -ne 'wed-snap-374-network-plan-v1' -or -not $plan.ownerProvidedAlternative -or -not $plan.useAuthorized){throw 'Network condition/authorization missing; NOT_RUN'}
    foreach($label in @($plan.currentLabel,$plan.alternateLabel)){if($label -notmatch '^[A-Za-z0-9_-]{1,40}$'){throw 'Use a non-sensitive opaque network label'}}
    if($plan.currentLabel -ceq $plan.alternateLabel -or $plan.verificationMethod -notmatch '^[A-Za-z0-9_-]{1,80}$'){throw 'Network labels/method insufficient; use a non-sensitive method reference'}
    $expectedLabel=if($NetworkSlot -eq 'current'){$plan.currentLabel}else{$plan.alternateLabel}
    if($receipt.schema -ne 'wed-snap-374-network-proof-v1' -or $receipt.slot -cne $NetworkSlot -or $receipt.label -cne $expectedLabel -or -not $receipt.ownLabEgressVerified){throw 'Active lab outbound proof missing'}
    if($receipt.verificationMethod -cne $plan.verificationMethod -or $receipt.routeToken -notmatch '^[A-Za-z0-9_-]{24,80}$' -or $receipt.evidenceSHA256 -notmatch '^[a-f0-9]{64}$'){throw 'External network proof insufficient'}
    $observed=[DateTimeOffset]::Parse($receipt.observedUtc)
    $age=([DateTimeOffset]::UtcNow-$observed).TotalMinutes
    if($age -lt 0 -or $age -gt 10){throw 'Active outbound proof must be current (<=10 minutes)'}
    foreach($r in (Get-Content "$casePath/source-pin.json" -Raw | ConvertFrom-Json)){if((SHA $r.file) -cne $r.sha256){throw 'Frozen runtime source changed'}}
    $configPin=Get-Content "$casePath/config-pin.json" -Raw | ConvertFrom-Json
    if((SHA "$casePath/fixed-configuration.json") -cne $configPin.file_sha256){throw 'Frozen configuration changed'}
    if(Test-Path "$casePath/$NetworkSlot"){throw 'Refuse repeated network slot'}
    if($NetworkSlot -eq 'alternate'){
        $first=Get-Content "$casePath/current/network-observation.json" -Raw | ConvertFrom-Json
        if($first.routeToken -ceq $receipt.routeToken){throw 'Outbound not shown to differ; Wi-Fi name alone is insufficient'}
    }elseif(Test-Path "$casePath/alternate"){throw 'Current network must run first'}
    # Receipt is external operator-reviewed evidence, not an automatic network measurement by this runner.
    # No IP, receipt file body, private routing evidence or network switching command is logged.
    $caseLock=[IO.File]::Open("$casePath/run.lock",[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $outputPath=Join-Path $casePath $NetworkSlot
}else{
    $outputPath=[IO.Path]::GetFullPath((Join-Path $ROOT $EvidenceDir))
}
if(-not $outputPath.StartsWith($evidenceRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Output must be inside docs/evidence'}
if(Test-Path -LiteralPath $outputPath){if($caseLock){$caseLock.Dispose()};throw 'Refuse reused evidence'}
New-Item -ItemType Directory -Path $outputPath | Out-Null
$EV=$outputPath.Substring($ROOT.Length+1)
$LOG=Join-Path $outputPath "runner-$Stage.jsonl"
$RUN_ID=[Guid]::NewGuid().ToString('N');$RUN_LABEL="com.wed-snap.run=$RUN_ID";$LABEL='com.wed-snap.lab=tiktok-374'
$mediaID='sha256:c66f52eace47d01e59a54c4b37f2d4d3db8b65326abff670b3673cb7d8900d8f'
$egressID='sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10'
$PIN=@{};$PIN[$mediaID]=$mediaID;$PIN[$egressID]=$egressID
. "$PSScriptRoot/guard_374.ps1"
$exitCode=0;$nativeEnv=@{}
foreach($key in @('LAB374_RUN_ID','LAB374_OUTPUT_DIR')){$nativeEnv[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
try{
    Add-Content $LOG ((@{step='begin';stage=$Stage;start=(Stamp);networkSlot=$NetworkSlot;ps=$PSVersionTable.PSVersion.ToString()} | ConvertTo-Json -Compress)) -Encoding utf8
    if(@(Own-Containers).Count -or @(Own-Networks).Count){$global:preflightFailedPreExisting=$true;throw 'Preexisting lab374 resources; preserve them'}
    foreach($img in $PIN.Keys){Check (((Native 'image-pin' @('image','inspect',$img,'--format','{{.Id}}')).out).Trim() -ceq $PIN[$img]) 'actual image pin'}
    $ro=@("$ROOT\tests\p37|/p37|False","$outputPath|/out|True")
    $allowed=@('PATH','NODE_VERSION','YARN_VERSION','HOME','PYTHONDONTWRITEBYTECODE','PYTHONUNBUFFERED','MEDIA_PROXY','AB_ARM','AB_TARGET')
    if($Stage -eq 'offline'){
        $name='wed-snap-tiktok-374-offline';$cmd=@('python3','/p37/test_374_offline.py')
        $args374=@('create','--name',$name,'--label',$LABEL,'--label',$RUN_LABEL,'--network','none','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','256m','--memory-swap','256m','--pids-limit','64','--cpus','0.5','--tmpfs','/tmp:size=64m,noexec,nosuid','-v',"$ROOT\tests\p37:/p37:ro",'-v',"$outputPath`:/out",'-e','HOME=/tmp','-e','PYTHONDONTWRITEBYTECODE=1','--pull','never',$mediaID)+$cmd
        try{Native 'create-offline' $args374 | Out-Null}finally{Track-RunResources}
        $c=Guard $name $mediaID '1000:1000' 256MB 'none' @('none') $ro $allowed $cmd @('/usr/bin/tini','-g','--')
        $r=Native 'offline-fixture' @('start','-a',$c.Id) -AllowFail -TimeoutSec 60
        $state=(Inspect1 $c.Id).State
        Check (-not $state.Running -and -not $state.OOMKilled -and $state.ExitCode -eq $r.code) 'offline native/container outcome'
        $exitCode=$r.code
    }else{
        $empty=Join-Path $outputPath 'compose.empty.env';[IO.File]::WriteAllText($empty,'')
        $env:LAB374_RUN_ID=$RUN_ID;$env:LAB374_OUTPUT_DIR=$outputPath
        $dc=@('compose','--env-file',$empty,'--project-directory',$ROOT,'-f',"$ROOT\infra\compose.tiktok-lab-374.yaml")
        (Native 'compose-config' ($dc+@('config'))).out | Set-Content "$outputPath/compose-resolved.yaml" -Encoding utf8
        Create-ComposeResources $dc
        $e=Guard 'wed-snap-tiktok-374-egress' $egressID '65534:65534' 96MB 'wed-snap-tiktok-lab-374_outbound' @('wed-snap-tiktok-lab-374_outbound','wed-snap-tiktok-lab-374_private') @() @('PATH','LANG','PYTHON_VERSION','PYTHON_SHA256','GPG_KEY') @('python','egress.py')
        $p=Guard 'wed-snap-tiktok-374-probe' $mediaID '1000:1000' 384MB 'wed-snap-tiktok-lab-374_private' @('wed-snap-tiktok-lab-374_private') $ro $allowed @('python3','/p37/probe_374.py') @('/usr/bin/tini','-g','--')
        Check (-not $e.Config.Entrypoint -and ($e.HostConfig.Memory+$p.HostConfig.Memory) -eq 480MB) 'two-service memory/entrypoint'
        Check (@($p.Config.Env) -contains 'AB_ARM=B' -and @($p.Config.Env) -contains 'AB_TARGET=chrome-136:macos-15' -and @($p.Config.Env) -contains 'MEDIA_PROXY=http://egress:8888') 'fixed B env'
        $nets=(Native 'network-actual' @('network','inspect','wed-snap-tiktok-lab-374_private','wed-snap-tiktok-lab-374_outbound')).out | ConvertFrom-Json
        foreach($n in $nets){Check ($n.Id -in $global:createdNetworkIds -and $n.Labels.'com.wed-snap.run' -eq $RUN_ID -and $n.Labels.'com.wed-snap.lab' -eq 'tiktok-374' -and $n.Driver -eq 'bridge') 'network ownership/driver'}
        Check (@($nets | Where-Object {$_.Name -eq 'wed-snap-tiktok-lab-374_private' -and $_.Internal}).Count -eq 1) 'internal-only probe'
        Check (@($nets | Where-Object {$_.Name -eq 'wed-snap-tiktok-lab-374_outbound' -and -not $_.Internal}).Count -eq 1) 'outbound egress'
        Native 'start-egress' @('start',$e.Id) | Out-Null
        Start-Sleep 2
        Check ((Inspect1 $e.Id).State.Running) 'egress running'
        # Reserve the slot once, immediately before the single analyze start. No external retry.
        @{slot=$NetworkSlot;label=$receipt.label;observedUtc=$receipt.observedUtc;routeToken=$receipt.routeToken;
            evidenceSHA256=$receipt.evidenceSHA256;verificationMethod=$receipt.verificationMethod;
            verificationOrigin='owner-supplied operator-reviewed private own-egress proof; not measured by runner';
            reservedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content "$outputPath/network-observation.json" -Encoding utf8
        $r=Native 'single-B-analyze' @('start','-a',$p.Id) -AllowFail -TimeoutSec 45
        $state=(Inspect1 $p.Id).State
        Check (-not $state.Running -and -not $state.OOMKilled -and $state.ExitCode -eq $r.code) 'actual native/container result'
        Check ($r.code -in @(0,20)) 'harness failure'
        $report=Get-Content "$outputPath/ab-attempt-B.json" -Raw | ConvertFrom-Json
        Check ($report.configuration_sha256 -ceq $configPin.configuration_sha256) 'effective frozen configuration'
        Check ($report.diagnostic_bytes_consistent -and $report.response_bytes_sum -eq $report.total_decoded_bytes) 'final response bytes/aggregate'
        Check ($report.seconds -le 30 -and $report.harness_status -eq 'COMPLETED') 'analyze deadline/completion'
        Check (($r.code -eq 0 -and $report.metadata_status -eq 'PASS') -or ($r.code -eq 20 -and $report.metadata_status -eq 'FAIL')) 'metadata/native exit match'
        $exitCode=$r.code
        Native 'egress-logs' @('logs',$e.Id,'--tail','30') | Out-Null
    }
}catch{
    Add-Content $LOG ((@{step='ABORT';end=(Stamp);error=(Clean $_.Exception.Message)} | ConvertTo-Json -Compress)) -Encoding utf8
    Write-Output ('ABORT: '+(Clean $_.Exception.Message));$exitCode=30
}finally{
    foreach($key in $nativeEnv.Keys){[Environment]::SetEnvironmentVariable($key,$nativeEnv[$key],'Process')}
    try{$left=Cleanup;if($left -ne 0){$exitCode=31}}
    finally{if($caseLock){$caseLock.Dispose()};Add-Content $LOG ((@{step='end';end=(Stamp);exit=$exitCode} | ConvertTo-Json -Compress)) -Encoding utf8}
}
exit $exitCode
