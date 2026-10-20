param([Parameter(Mandatory)][string]$Evidence)
. (Join-Path $PSScriptRoot 'common.ps1')
Initialize-Diagnostic $Evidence
foreach($role in @('node','python','docker')){
 if(!$script:Tools.ContainsKey($role)){Save-NewJSON ($role+'-version.json') @{status='FAIL_TOOL_NOT_FOUND'};continue}
 Register-Query ($role+'-version') $role @('--version')
 $r=Invoke-Query ($role+'-version');$version=$null;$build=$null
 if($r.OK){
  if($role -ceq 'docker' -and $r.Out.Trim() -cmatch '^Docker version ([0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9.+-]*), build ([a-f0-9]+)$'){$version=$Matches[1];$build=$Matches[2]}
  elseif($role -ceq 'node' -and $r.Out.Trim() -cmatch '^v([0-9]+\.[0-9]+\.[0-9]+)$'){$version=$Matches[1]}
  elseif($role -ceq 'python' -and $r.Out.Trim() -cmatch '^Python ([0-9]+\.[0-9]+\.[0-9]+)$'){$version=$Matches[1]}
 }
 Save-NewJSON ($role+'-version.json') @{status=$(if($r.OK -and $version){'OBSERVED_READONLY'}else{'FAIL_OR_UNKNOWN_FORMAT'});version=$version;build=$build;executable=$script:Tools[$role]}
}
Register-Query 'host-plan-path-port' pwsh @('-NoLogo','-NoProfile','-File',(Join-Path $PSScriptRoot 'host.ps1'))
$hostResult=Invoke-Query 'host-plan-path-port'
if($hostResult.OK){$data=$hostResult.Out|ConvertFrom-Json;Save-NewJSON 'host-plan-path-port.json' $data}else{Save-NewJSON 'host-plan-path-port.json' @{status='FAIL_NO_COMPLETE_HOST_OBSERVATION'}}
if($script:Tools.ContainsKey('w32tm')){
 Register-Query 'time-service-status' w32tm @('/query','/status')
 $r=Invoke-Query 'time-service-status';$stratum=$null;$leap=$null
 if($r.OK){if($r.Out -match '(?m)^Stratum:\s*([0-9]+)'){$stratum=[int]$Matches[1]};if($r.Out -match '(?m)^Leap Indicator:\s*([0-9]+)'){$leap=[int]$Matches[1]}}
 Save-NewJSON 'time-service-status.json' @{status=$(if($r.OK){'OBSERVED_READONLY'}else{'FAIL_QUERY'});stratum=$stratum;leapIndicator=$leap;sourceName='OMITTED';trustedHostContainerSkew='UNKNOWN_NO_EXTERNAL_REFERENCE_OR_CONTAINER_QUERY'}
}
Finish-Diagnostic 'INVENTORY_COMPLETE_SOURCE_HOLD'
Write-Output 'INVENTORY_COMPLETE_SOURCE_HOLD';exit 0
