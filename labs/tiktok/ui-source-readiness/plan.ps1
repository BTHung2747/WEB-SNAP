# Read-only preparation. This module never invokes a runtime or publishes authority.
function Get-SourceReadinessPlan {
    $map = @()
    function Add-Leaf([string]$Source,[string]$Target,[string[]]$Roles) {
        [pscustomobject]@{source=$Source;target=$Target;roles=$Roles;readOnly=$true;type='file'}
    }
    $sourcePins = @(Get-Content -LiteralPath 'labs/tiktok/photo-source-fixed/source-pins.json' -Raw | ConvertFrom-Json)
    foreach ($p in $sourcePins | Where-Object path -CLike 'apps/media/src/*') {
        $map += Add-Leaf $p.path ('/app/'+$p.path) @('app')
    }
    foreach ($name in @('media_entry.py','media.py','collector.py','worker.ts')) {
        $map += Add-Leaf "labs/tiktok/photo-app-source-executor/common/$name" "/lab/$name" @('app')
    }
    $map += Add-Leaf 'labs/tiktok/photo-app-source-executor/common/media_entry.py' '/app/infra/media_adapter.py' @('app')
    foreach ($name in @('overlay_entry.py','proxy_collect.py')) {
        $map += Add-Leaf "labs/tiktok/photo-dns-diagnostics-fix/$name" "/lab/$name" @('proxy')
    }
    foreach ($name in @('proxy_entry.py','dns_child_environment.py')) {
        $map += Add-Leaf "labs/tiktok/photo-dns-child-offline/common/$name" "/base/$name" @('proxy')
    }
    # Static inventory only; dependency trees remain on the cached images.
    $egressPins = @($sourcePins | Where-Object path -CLike 'apps/egress/*')
    foreach ($p in $egressPins) { $map += Add-Leaf $p.path ('/repo/'+$p.path) @('proxy') }
    foreach ($p in $sourcePins | Where-Object { $_.path -cmatch '^(apps/(api|worker)/src/|packages/shared/src/|prisma/)' }) {
        $map += Add-Leaf $p.path ('/app/'+$p.path) @('app')
    }
    $uiPins=@(Get-Content -LiteralPath 'docs/evidence/ui-final-fixture-20261016/runtime/expected-source.json' -Raw | ConvertFrom-Json)
    $build='docs/evidence/ui-a-app-integration-20261016/build/web/'
    foreach ($p in $uiPins | Where-Object path -CLike "$build*") {
        $map += Add-Leaf $p.path ('/build/'+$p.path.Substring($build.Length)) @('gateway')
    }
    foreach ($name in @('event-writer.cjs','failure-path.cjs','reasons.cjs')) {
        $map += Add-Leaf "labs/tiktok/ui-observation-fix/$name" "/observationfix/$name" @('gateway')
    }
    return [ordered]@{
        schema='wed-ui-source-readiness-plan-v1';sourceGate=$false;launchImplemented=$false
        status='BLOCKED_SOURCE_ADAPTERS_AND_AUTHORIZATION';approvedURL=$null;expectedPostID=$null;selectedIndex=$null
        authorization=$null;sourceClaim=$null;runID=$null
        blockers=@('SOURCE_CONTROLLER_NOT_WIRED','SOURCE_GATEWAY_NOT_WIRED','SOURCE_HANDSHAKE_NOT_WIRED','URL_AND_FRESH_AUTHORIZATION_UNSET')
        mounts=$map
        argv=@{mediaAnalyze=@('python3','-I','/app/infra/media_adapter.py','analyze','<approvedURL>','<ownedJobFolder>');mediaPrepare=@('python3','-I','/app/infra/media_adapter.py','prepare','<approvedURL>','<ownedJobFolder>','<selectedFormatID>');proxy=@('python3','-I','/lab/overlay_entry.py');app=$null;gateway=$null}
        imports=@{media=@('/lab/media.py','/lab/collector.py','/app/apps/media/src/tiktok/photo_core.py','/app/apps/media/src/tiktok/photo_adapter.py');proxy=@('/lab/proxy_collect.py','/base/proxy_entry.py','/base/dns_child_environment.py','/repo/apps/egress/src/egress.py','/repo/apps/egress/src/tiktok_policy/dns_admission.py');gateway=@('/observationfix/event-writer.cjs','/observationfix/failure-path.cjs','/observationfix/reasons.cjs')}
        images=@{app='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e';gateway='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e';proxy='sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10';postgres='sha256:38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74';redis='sha256:a9cc41d6d01da2aa26c219e4f99ecbeead955a7b656c1c499cce8922311b2514'}
        proposal=@{analyzeMetadataGET=2;prepareFreshMetadataGET=2;conditionalJPEGGET=1;redirect=0;retry=0;metadataSeconds=30;prepareSeconds=180;connectSecondsMax=10;readSecondsMax=20;metadataResponseMiB=8;metadataTotalMiB=16;prepareInputMiB=36;prepareOutputMiB=16;imageResponseMiBMax=20;dnsRawMax=256;dnsUniqueMax=64;overallSecondsMax=480;cleanupSeconds=20;sealSeconds=1;memoryMiB=@{app=512;proxy=96;postgres=128;redis=64;gateway=128};runtimeMiB=928}
    }
}

function Assert-SourceReadinessPlan($Plan) {
    if ($Plan.sourceGate -ne $false -or $Plan.launchImplemented -ne $false -or $null -ne $Plan.authorization -or $null -ne $Plan.sourceClaim -or $null -ne $Plan.runID) { throw 'READINESS_AUTHORITY_FORBIDDEN' }
    $seen = @{}
    foreach ($m in $Plan.mounts) {
        if (!$m.readOnly -or $m.type -cne 'file' -or !(Test-Path -LiteralPath $m.source -PathType Leaf)) { throw 'MOUNT_TYPE_OR_SOURCE' }
        if ($m.source -match 'sitecustomize|media_site|generate\.py|expectation|driver\.ts|workflow\.ts' -or $m.target -match '^/(offline|compat)(/|$)') { throw 'FIXTURE_OR_AUTOMATION_FORBIDDEN' }
        foreach ($role in $m.roles) {
            $key=$role+':'+$m.target
            if ($seen.ContainsKey($key)) { throw 'DUPLICATE_MOUNT' };$seen[$key]=$true
        }
    }
    foreach ($role in @('media','proxy','gateway')) {
        $mountRole=if ($role -ceq 'media') {'app'} else {$role}
        foreach ($target in $Plan.imports[$role]) {
            if (!$seen.ContainsKey($mountRole+':'+$target)) { throw 'IMPORT_NOT_MAPPED' }
        }
    }
    if (@($Plan.mounts | Where-Object target -CLike '/app/apps/media/src/*').Count -ne 30) { throw 'MEDIA_LEAF_COVERAGE' }
    if ($null -ne $Plan.argv.app -or $null -ne $Plan.argv.gateway) { throw 'UNREVIEWED_LAUNCH_COMMAND' }
}
