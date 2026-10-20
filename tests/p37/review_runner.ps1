# Runs actual functions extracted from the runner AST; only Docker I/O is doubled.
# No invocation of the runner top-level, Docker, network or datastore.
param([string]$Runner = "$PSScriptRoot/run-372.ps1")
$ErrorActionPreference = 'Stop'
$tokens=$null; $parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($Runner,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) { throw 'Runner parser errors' }
foreach($fn in $ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst]},$true)) {
    if ($fn.Name -in @('Clean','Check','Norm','Guard','Own-Containers','Own-Networks','Cleanup','Create-ComposeResources','Track-RunResources')) {
        . ([scriptblock]::Create($fn.Extent.Text))
    }
}
$script:failed=0; $script:passed=0
function Assert($condition,$message) { if(-not $condition){throw $message} }
function Case($name,[scriptblock]$body) {
    try { & $body; $script:passed++; Write-Output "PASS $name" }
    catch { $script:failed++; Write-Output "FAIL $name : $($_.Exception.Message)" }
}
function Stamp { 'fixture-clock' }
# Suppress runner log writes in these in-memory unit tests.
function Add-Content { param($Path,$Value,$Encoding) }
$LOG='in-memory'; $LABEL='com.wed-snap.lab=tiktok-372'; $RUN_ID='review-run'
$RUN_LABEL="com.wed-snap.run=$RUN_ID"
$script:containers=@(); $script:networks=@(); $script:removed=@(); $script:enumFail=$false
function Native($name,$dargs,[switch]$AllowFail) {
    $out=''; $code=0
    if($name -eq 'compose-create') {
        $script:containers=@('aaaaaaaaaaaa'); $script:networks=@('bbbbbbbbbbbb')
        throw 'fixture: compose created resources then failed'
    }
    elseif($name -match 'containers|compose-cids') { $out=$script:containers -join "`n"; if($script:enumFail){throw 'fixture: enumeration unavailable'} }
    elseif($name -match 'networks|compose-nids') { $out=$script:networks -join "`n"; if($script:enumFail){throw 'fixture: enumeration unavailable'} }
    elseif($name -match '^inspect-before-rm-(lbl|netlbl)') { $out='{"com.wed-snap.lab":"tiktok-372","com.wed-snap.run":"review-run"}' }
    elseif($name -match '^inspect-before-rm-') { $out=$dargs[1]; if($dargs[0] -eq 'network'){$out=$dargs[2]} }
    elseif($name -match '^rm-') { $script:removed+= $dargs[2]; $script:containers=@() }
    elseif($name -match '^netrm-') { $script:removed+= $dargs[2]; $script:networks=@() }
    else { throw "Unexpected native double: $name" }
    [pscustomobject]@{out=$out;code=$code}
}
Case 'sanitize URL credentials and query' {
    $s=Clean 'https://FAKEUSER:FAKEPASS@example.invalid/p?token=FAKEQUERY'
    Assert ($s -notmatch 'FAKEUSER|FAKEPASS|FAKEQUERY') 'credential survived Clean()'
}
Case 'sanitize inline authorization header' {
    Assert ((Clean 'request failed Authorization: Bearer FAKEAUTH') -notmatch 'FAKEAUTH') 'header survived Clean()'
}
Case 'enumeration fails closed' {
    $script:enumFail=$true; $threw=$false
    try { Own-Containers | Out-Null } catch { $threw=$true } finally {$script:enumFail=$false}
    Assert $threw 'enumeration accepted error'
}
Case 'preexisting resources preserved by actual cleanup' {
    $global:preflightFailedPreExisting=$true; $script:removed=@()
    $global:createdContainerIds=[System.Collections.Generic.List[string]]::new()
    $global:createdNetworkIds=[System.Collections.Generic.List[string]]::new()
    try { $left=Cleanup; Assert ($left -eq 0 -and $script:removed.Count -eq 0) 'preexisting resource removed' }
    finally {$global:preflightFailedPreExisting=$false}
}
Case 'partial compose failure is tracked and cleaned' {
    $script:containers=@(); $script:networks=@(); $script:removed=@()
    $global:createdContainerIds=[System.Collections.Generic.List[string]]::new()
    $global:createdNetworkIds=[System.Collections.Generic.List[string]]::new()
    $dc=@('compose'); $creationFailed=$false
    try {
        if(Get-Command Create-ComposeResources -ErrorAction SilentlyContinue) { Create-ComposeResources $dc }
        else {
            # Execute the original creation/tracking statements verbatim for baseline.
            $source=[IO.File]::ReadAllText($Runner)
            $match=[regex]::Match($source,"(?s)        Native 'compose-create'.*?(?=        \`$ab =)")
            if(-not $match.Success){throw 'Baseline creation statements not found'}
            . ([scriptblock]::Create($match.Value))
        }
    } catch { $creationFailed=$true }
    $left=Cleanup
    Assert $creationFailed 'fixture creation must fail'
    Assert ($left -eq 0 -and $script:removed.Count -eq 2) "partial resources leaked: left=$left removed=$($script:removed.Count)"
}
Case 'output mount follows selected evidence directory' {
    $compose=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../infra/compose.tiktok-lab-372.yaml'))
    Assert ($compose.Contains('${LAB372_OUTPUT_DIR:?')) 'compose output remains hardcoded'
    Assert ($ast.Extent.Text.Contains('$env:LAB372_OUTPUT_DIR =')) 'runner does not supply output directory'
}
Write-Output "RESULT actual-runner-functions=$($script:passed)PASS/$($script:failed)FAIL; Docker double; no live Docker"
if($script:failed){exit 1}
