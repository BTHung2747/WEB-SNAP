param([Parameter(Mandatory)][string]$ReviewPath,[Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$ExpectedReviewSHA)
# Live API entry for a future reviewer GO only. No switch/flag can substitute
# for a separately reviewed, pinned GO record and real readiness proof DAG.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../ui-source-owner-native/Owner.psm1') -DisableNameChecking
$authority=$null
try{
 $bootstrap=New-ReviewedSourceBootstrap $ReviewPath $ExpectedReviewSHA
 $authority=New-SourceAuthority $bootstrap
 $run=[Guid]::NewGuid().ToString('N');$claim=[Guid]::NewGuid().ToString('N')
 $approval=New-ScopedSourceApproval $authority $run $claim
 $context=Read-ScopedSourceApproval $authority $approval
 Write-Output ((@{status='SOURCE_ADMISSION_CONSUMED';runID=$run;claimID=$claim;evidence=$context.Payload.evidenceRef})|ConvertTo-Json -Compress)
 Invoke-SourceOwner -Context $context|ConvertTo-Json -Depth 6 -Compress
}catch{Write-Output '{"status":"SOURCE_OWNER_FAIL_NO_RETRY","details":"ALLOWLIST_PRIVATE_RECEIPTS_ONLY"}';exit 20}finally{if($authority){Close-SourceAuthority $authority}}
