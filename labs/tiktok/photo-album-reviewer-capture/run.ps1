param([ValidateSet('disabled','source')][string]$Mode='disabled')
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
if($Mode -ceq 'disabled'){Write-Output 'WORKFLOW_DISABLED_NO_DOCKER_OR_AUTHORITY';exit 20}
. "$PSScriptRoot/orchestration.ps1"
try{
 $p=WorkflowProposal;$reviewDir=Join-Path (WorkflowBase) "reviewed/proposal-$($p.proposalID)/orchestration"
 $null=PacketSeal $reviewDir;$freeze=SourceRead "$reviewDir/freeze.json"
 if((Canonical (OrchestrationSnapshot))-cne(Canonical $freeze.sources) -or $freeze.codeHash -cne(RowsHash (OrchestrationSnapshot))){throw 'ORCHESTRATION_CODE_HASH'}
 $null=RunWorkflow $p (SHA "$reviewDir/freeze.json")
 Write-Output 'WORKFLOW_COMPLETE_CHECK_CANDIDATE_FILES_AND_VISUAL';exit 0
}catch{Write-Output 'WORKFLOW_REFUSED_OR_FAILED_NO_RETRY';exit 20}
