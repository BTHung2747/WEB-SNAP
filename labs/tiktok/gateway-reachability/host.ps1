param([string]$RunID,[string]$Evidence)
$ErrorActionPreference='Stop'
if($RunID -cnotmatch '^[a-f0-9]{32}$'){exit 20}
$begin=[DateTimeOffset]::UtcNow
$result=@{status='FAIL';code='UNKNOWN';httpStatus=$null;markerMatch=$false;timeoutSeconds=5;socket='UNKNOWN';retry=0;redirect=0;noProxy=$true;powerShell=$PSVersionTable.PSVersion.ToString()}
try{
 $response=Invoke-WebRequest -Uri 'http://127.0.0.1:5206/reachability' -Method Get -NoProxy -ConnectionTimeoutSeconds 4 -OperationTimeoutSeconds 4 -MaximumRetryCount 0 -MaximumRedirection 0 -Headers @{'x-wed-probe-point'='host'}
 $result.httpStatus=[int]$response.StatusCode;$result.markerMatch=([string]$response.Content -ceq "WED_SNAP_REACHABILITY_$RunID`n")
 $result.status=if($result.httpStatus -eq 200 -and $result.markerMatch){'PASS'}else{'FAIL'};$result.code=if($result.status -eq 'PASS'){'OK'}else{'MARKER_OR_HTTP'}
}catch{
 $errorItem=$_.Exception;$classes=@()
 for($i=0;$errorItem -and $i -lt 8;$i++){
  $type=$errorItem.GetType().FullName
  if($type -in @('System.Net.Http.HttpRequestException','System.Net.Sockets.SocketException','System.Threading.Tasks.TaskCanceledException','System.OperationCanceledException','Microsoft.PowerShell.Commands.HttpResponseException')){$classes+=,$type}
  if($errorItem -is [Net.Sockets.SocketException]){$result.socketError=[int]$errorItem.SocketErrorCode;$result.code=if($errorItem.SocketErrorCode -eq [Net.Sockets.SocketError]::ConnectionRefused){'CONNECTION_REFUSED'}else{'SOCKET_ERROR'}}
  elseif($errorItem -is [OperationCanceledException]){$result.code='TIMEOUT'}
  $errorItem=$errorItem.InnerException
 };$result.classes=$classes
}
$result.elapsedSeconds=([DateTimeOffset]::UtcNow-$begin).TotalSeconds;$result.utc=[DateTimeOffset]::UtcNow.ToString('o');$result.vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')
$result|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $Evidence 'host.json') -Encoding utf8
exit 0
