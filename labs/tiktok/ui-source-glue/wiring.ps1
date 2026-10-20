# Inventory/argv delta only. No Docker, namespace, grant or claim creation.
function Get-SourceGlueDelta {
    $leaf=@()
    foreach($name in @('entry.py','start.sh','controller.ts','gateway.cjs','contract.cjs','policy.cjs','handshake.py','budget-policy.json')){
        $roles=if($name -in @('entry.py','start.sh','controller.ts')){@('app')}elseif($name -ceq 'gateway.cjs'){@('gateway')}else{@('app','gateway')}
        $leaf+=[pscustomobject]@{source="labs/tiktok/ui-source-glue/$name";target="/labs/tiktok/ui-source-glue/$name";roles=$roles;readOnly=$true}
    }
    foreach($name in @('event-writer.cjs','failure-path.cjs','reasons.cjs')){
        $leaf+=[pscustomobject]@{source="labs/tiktok/ui-observation-fix/$name";target="/labs/tiktok/ui-observation-fix/$name";roles=@('app','gateway');readOnly=$true}
    }
    $leaf+=[pscustomobject]@{source='labs/tiktok/ui-combined-offline/handshake.py';target='/labs/tiktok/ui-combined-offline/handshake.py';roles=@('app');readOnly=$true}
    $leaf+=[pscustomobject]@{source='labs/tiktok/photo-app-source-executor/common/supervisor.py';target='/lab/supervisor.py';roles=@('app');readOnly=$true}
    [pscustomobject]@{
        sourceGate=$false;launcherImplemented=$false;mounts=$leaf
        app=@('/usr/bin/timeout','--signal=KILL','340s','python3','-I','/labs/tiktok/ui-source-glue/entry.py')
        gateway=@('/app/node_modules/.bin/tsx','/labs/tiktok/ui-source-glue/gateway.cjs')
        proxy=@('python3','-I','/lab/overlay_entry.py')
        replaceReadinessHelperTargets=@('/observationfix/event-writer.cjs','/observationfix/failure-path.cjs','/observationfix/reasons.cjs')
        ownerInputs=@('/control/browser-contract.json','/control/source-decision.json','/control/source-budget.json')
    }
}
