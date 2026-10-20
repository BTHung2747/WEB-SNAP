$ErrorActionPreference = 'Stop'
# Explicit SIGKILL only against wed-snap-test, which has separate disposable volumes.
$testArgs = @('compose', '-f', 'compose.yaml', '-f', 'compose.test.yaml')
function Invoke-TestDocker([string[]] $dockerArgs) {
    & docker @testArgs @dockerArgs
    if ($LASTEXITCODE -ne 0) { throw 'Docker crash test command failed' }
}
Invoke-TestDocker @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/crash.integration.ts','worker-start')
Invoke-TestDocker @('kill','-s','SIGKILL','worker')
Invoke-TestDocker @('up','-d','--no-build','worker')
Invoke-TestDocker @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/crash.integration.ts','worker-check')
Invoke-TestDocker @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/crash.integration.ts','api-start')
$holdName = 'wed-snap-test-crash-client'
Invoke-TestDocker @('run','-d','--name',$holdName,'--no-deps','worker','node_modules/.bin/tsx','tests/crash.integration.ts','api-hold')
try {
    $held = $false
    for ($i=0; $i -lt 15; $i++) {
        $logs = & docker logs $holdName 2>&1
        if ($logs -match 'TRANSFER_HELD') { $held = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $held) { throw 'No active transfer; do not kill API' }
    Invoke-TestDocker @('kill','-s','SIGKILL','api')
    Invoke-TestDocker @('up','-d','--no-build','api')
    Invoke-TestDocker @('run','--rm','--no-deps','worker','node_modules/.bin/tsx','tests/crash.integration.ts','api-check')
} finally {
    # Removes only our one-off crash client; main/test data volumes are retained.
    & docker rm -f $holdName | Out-Null
}
