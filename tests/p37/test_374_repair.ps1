# Narrow real-branch fixtures: native bundled PowerShell executes summary/analyze missing-input only.
# Synthetic reports contain no source URLs, cookies, network receipts or real metadata.
param([Parameter(Mandatory=$true)][ValidateSet('before','after')][string]$Phase,
      [string]$Runner='tests/p37/run-374.ps1', [ValidateRange(1,2)][int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP'
$ev="docs/evidence/p37-4-r-20261007/fixtures-$Phase"
if($Attempt -gt 1){$ev+="-$Attempt"}
if(Test-Path -LiteralPath $ev){throw 'Refuse reused fixture evidence'}
New-Item -ItemType Directory -Path $ev | Out-Null
$nativeLog=Join-Path $ev 'native.jsonl'
$psExe=(Get-Process -Id $PID).Path
$passed=0;$failed=0
function Assert($condition,[string]$message){if(-not $condition){throw $message}}
function Case([string]$name,[scriptblock]$body){
    try{& $body;$script:passed++;Write-Output "PASS $name"}
    catch{$script:failed++;Write-Output "FAIL $name : $($_.Exception.Message)"}
}
function InvokeRunner([string[]]$argsRepair){
    $start=[DateTime]::UtcNow
    $pi=[Diagnostics.ProcessStartInfo]::new();$pi.FileName=$psExe;$pi.WorkingDirectory=$root
    $pi.UseShellExecute=$false;$pi.RedirectStandardOutput=$true;$pi.RedirectStandardError=$true
    foreach($arg in (@('-NoProfile','-File',$Runner)+$argsRepair)){$pi.ArgumentList.Add($arg)}
    $proc=[Diagnostics.Process]::Start($pi)
    $stdout=$proc.StandardOutput.ReadToEndAsync();$stderr=$proc.StandardError.ReadToEndAsync()
    if(-not $proc.WaitForExit(20000)){$proc.Kill($true);throw 'Fixture command timeout'}
    $out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult();$code=$proc.ExitCode;$proc.Dispose()
    @{args=$argsRepair;runner=$Runner;startUTC=$start.ToString('o');endUTC=[DateTime]::UtcNow.ToString('o');
      endVN=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');actualExit=$code;stdout=$out;stderr=$err;
      sourceRequests=0;fixtureOnly=$true} | ConvertTo-Json -Depth 8 -Compress | Add-Content $nativeLog -Encoding utf8
    return @{out=$out;err=$err;code=$code}
}
function Report([string]$metadata){
    $r=@{fixture_only=$true;harness_status='COMPLETED';metadata_status=$metadata;
         configuration_sha256=('a'*64);diagnostic_bytes_consistent=$true;
         response_bytes_sum=64;total_decoded_bytes=64;
         requests=@(@{method='GET';actual_handler='curl_cffi';effective_target='chrome-136:macos-15';
                      prepared_headers_safe=@{'User-Agent'='fixture-fixed-UA'};decoded_bytes=64})}
    if($metadata -eq 'PASS'){$r.result=@{id='fixture-only-id';formats=@(@{format_id='fixture-play'})}}
    return $r
}
function Summary([string]$name,$current,$alternate,[switch]$Malformed){
    $caseDir="$ev/$name"
    foreach($slot in @('current','alternate')){
        $data=if($slot -eq 'current'){$current}else{$alternate}
        if($null -ne $data -or ($Malformed -and $slot -eq 'alternate')){
            New-Item -ItemType Directory -Path "$caseDir/$slot" -Force | Out-Null
            if($Malformed -and $slot -eq 'alternate'){'{broken JSON' | Set-Content "$caseDir/$slot/ab-attempt-B.json" -Encoding utf8}
            else{$data | ConvertTo-Json -Depth 15 | Set-Content "$caseDir/$slot/ab-attempt-B.json" -Encoding utf8}
        }
    }
    $res=InvokeRunner @('-Stage','summary','-CaseDir',$caseDir)
    Assert ($res.code -eq 0) "summary process exit=$($res.code)"
    return ($res.out | ConvertFrom-Json)
}
function Limited($summary){
    Assert ($summary.status -ne 'MEASURED_TWO_NETWORKS') 'confounded reports marked fully measured'
    Assert (@($summary.comparability_limits).Count -gt 0) 'missing comparability limit'
    Assert ($summary.conclusion -notmatch 'network-condition sensitivity') 'causal network conclusion survived limits'
    Assert (($summary.metadata -join ',') -eq 'FAIL,PASS') 'observed metadata values were lost'
}
Case 'configuration mismatch preserves unknown cause' {
    $a=Report 'FAIL';$b=Report 'PASS';$b.configuration_sha256='b'*64
    Limited (Summary 'config-mismatch' $a $b)
}
Case 'prepared header mismatch preserves unknown cause' {
    $a=Report 'FAIL';$b=Report 'PASS';$b.requests[0].prepared_headers_safe['User-Agent']='fixture-other-UA'
    Limited (Summary 'header-mismatch' $a $b)
}
Case 'actual target mismatch preserves unknown cause' {
    $a=Report 'FAIL';$b=Report 'PASS';$b.requests[0].effective_target='chrome-146:macos-26'
    Limited (Summary 'target-mismatch' $a $b)
}
Case 'byte aggregate mismatch preserves unknown cause' {
    $a=Report 'FAIL';$b=Report 'PASS';$b.diagnostic_bytes_consistent=$false;$b.response_bytes_sum=63
    Limited (Summary 'byte-mismatch' $a $b)
}
Case 'NOT_COMPLETED report remains partial' {
    $a=Report 'FAIL';$b=Report 'PASS';$b.harness_status='NOT_COMPLETED'
    $sum=Summary 'not-completed' $a $b
    Assert ($sum.status -like 'PARTIAL*') 'incomplete harness reported fully measured'
    Assert ($sum.conclusion -notmatch 'network-condition sensitivity') 'incomplete report inferred network cause'
}
Case 'malformed report becomes partial instead of accepting complete pair' {
    $sum=Summary 'malformed' (Report 'FAIL') $null -Malformed
    Assert ($sum.status -like 'PARTIAL*') 'malformed report not partial'
}
Case 'malformed PASS formats schema is not a complete report' {
    $a=Report 'FAIL';$b=Report 'PASS';$b.result.formats='not-an-array'
    $sum=Summary 'malformed-formats' $a $b
    Assert ($sum.status -like 'PARTIAL*') 'malformed formats reported complete'
    Assert ($sum.conclusion -notmatch 'network-condition sensitivity') 'malformed schema inferred network cause'
}
Case 'missing alternate remains partial' {
    $sum=Summary 'missing-report' (Report 'FAIL') $null
    Assert ($sum.status -like 'PARTIAL*') 'missing report marked complete'
}
Case 'comparable complete reports keep metadata separate' {
    $sum=Summary 'comparable' (Report 'FAIL') (Report 'PASS')
    Assert ($sum.status -eq 'MEASURED_TWO_NETWORKS') 'comparable completed pair lost measured state'
    Assert (@($sum.comparability_limits).Count -eq 0) 'valid identical controls got limits'
    Assert (($sum.metadata -join ',') -eq 'FAIL,PASS') 'metadata/harness conflated'
}
Case 'comparable both FAIL keeps cause unproven' {
    $sum=Summary 'both-fail' (Report 'FAIL') (Report 'FAIL')
    Assert (($sum.metadata -join ',') -eq 'FAIL,FAIL') 'both FAIL metadata lost'
    Assert ($sum.conclusion -match 'unproven|undetermined|unknown') 'both FAIL cause no longer unknown'
}
Case 'default case has correct five source pins and config pin' {
    $tokens=$null;$parseErrors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $Runner),[ref]$tokens,[ref]$parseErrors)
    Assert ($parseErrors.Count -eq 0) 'runner parse error'
    $paramAst=@($ast.ParamBlock.Parameters | Where-Object {$_.Name.VariablePath.UserPath -eq 'CaseDir'})[0]
    $defaultCase=$paramAst.DefaultValue.Value
    $pins=@(Get-Content "$defaultCase/source-pin.json" -Raw | ConvertFrom-Json)
    Assert ($pins.Count -eq 5) 'wrong pin count'
    foreach($p in $pins){Assert ((Get-FileHash -LiteralPath $p.file -Algorithm SHA256).Hash.ToLower() -ceq $p.sha256) "stale source pin $($p.file)"}
    $cp=Get-Content "$defaultCase/config-pin.json" -Raw | ConvertFrom-Json
    Assert ((Get-FileHash "$defaultCase/fixed-configuration.json" -Algorithm SHA256).Hash.ToLower() -ceq $cp.file_sha256) 'config file pin mismatch'
    Assert ($cp.configuration_sha256 -ceq '6c2c655ffc39af3c658c6b58c26da013b504092fb4f32f4d39bf4d05a7bc6121') 'configuration changed'
}
Case 'missing network input stays at zero source' {
    $res=InvokeRunner @('-Stage','analyze')
    Assert ($res.code -eq 40 -and $res.out -match 'NOT_RUN') 'missing-input branch did not stop before runtime'
}
@{phase=$Phase;utc=[DateTime]::UtcNow.ToString('o');ps=$PSVersionTable.PSVersion.ToString();runner=$Runner;
  passed=$passed;failed=$failed;actualExit=$(if($failed){1}else{0});sourceRequests=0;dockerInvoked=$false;
  scope='actual summary branch/native PowerShell; synthetic report files; no metadata extraction'} | ConvertTo-Json | Set-Content "$ev/result.json" -Encoding utf8
Write-Output "RESULT $passed PASS/$failed FAIL; fixtures only; 0 source/0 Docker"
if($failed){exit 1}
exit 0
