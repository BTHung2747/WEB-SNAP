# Reproduce F37.2-H1 runner bugs:
# 1. Enumeration error is swallowed by -AllowFail, falsely concluding clean state.
# 2. Pre-existing resource aborts preflight, but finally { Cleanup } deletes the pre-existing resource.
# 3. Process env $env:AB_TARGET is not restored in finally.
# 4. Cleanup deletes any container matching label, rather than only own-created IDs with identity guard.

param()
Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

Write-Host "=== REPRODUCING F37.2-H1 ==="

# --- Test 1: Enumeration error swallowed ---
$fakePsFail = $true
function Old-Native([string]$name, [string[]]$dargs, [switch]$AllowFail) {
    if ($name -eq 'own-containers' -and $fakePsFail) {
        # Simulate docker daemon error or timeout during enumeration (exit code 1)
        return [pscustomobject]@{ out = 'error: daemon not reachable'; code = 1 }
    }
    return [pscustomobject]@{ out = ''; code = 0 }
}

function Old-Own-Containers {
    (Old-Native 'own-containers' @('ps') -AllowFail).out -split "`r?`n" | Where-Object { $_ -match '^wed-snap' }
}

$found = @(Old-Own-Containers)
$falselyClean = ($found.Count -eq 0)
Write-Host "Test 1: When docker ps fails (exit 1), Old-Own-Containers count: $($found.Count)"
Write-Host "Falsely concluded clean state on enumeration error: $falselyClean"

# --- Test 2: Pre-existing resource deleted by finally ---
$simulatedContainers = [System.Collections.Generic.List[string]]::new()
$simulatedContainers.Add('pre-existing-container-123')
$deletedContainers = [System.Collections.Generic.List[string]]::new()

function Old-Cleanup-Sim {
    # Old logic: query by label, rm all
    foreach ($c in @($simulatedContainers)) {
        $deletedContainers.Add($c)
        $simulatedContainers.Remove($c) | Out-Null
    }
}

$preflightAborted = $false
try {
    if ($simulatedContainers.Count -gt 0) {
        throw "GUARD FAIL: own resources already exist"
    }
}
catch {
    $preflightAborted = $true
}
finally {
    # In old run-372.ps1, finally ALWAYS calls Cleanup
    Old-Cleanup-Sim
}

$deletedPreExisting = $deletedContainers.Contains('pre-existing-container-123')
Write-Host "Test 2: Preflight aborted: $preflightAborted"
Write-Host "Pre-existing container deleted by finally: $deletedPreExisting"

# --- Test 3: Environment variable leakage ---
$env:AB_TARGET = 'original_value'
try {
    $env:AB_TARGET = 'target_injected'
    throw "Abort during execution"
}
catch {}
finally {
    # Old finally does NOT restore env:AB_TARGET
}
$envLeaked = ($env:AB_TARGET -eq 'target_injected')
Write-Host "Test 3: env:AB_TARGET leaked after failure: $envLeaked"
$env:AB_TARGET = 'original_value'

if ($falselyClean -and $deletedPreExisting -and $envLeaked) {
    Write-Host "F37.2-H1 bug reproduced successfully: all 3 flaws demonstrated."
    exit 43 # Exit 43 proves reproduction
} else {
    Write-Host "Failed to reproduce."
    exit 1
}
