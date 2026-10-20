# One bind-mount map, validated before the runner's first Docker command.
function Get-CombinedMountMap([string]$Control){
 $rows=[Collections.Generic.List[object]]::new()
 function Add-Bind([string]$Source,[string]$Target,[string]$Type,[string[]]$Roles,[bool]$ReadOnly=$true){
  $rows.Add([pscustomobject]@{source=[IO.Path]::GetFullPath($Source);target=$Target;type=$Type;roles=$Roles;readOnly=$ReadOnly})
 }
 $all=@('generate','proxy','app');$application=@('generate','app')
 Add-Bind 'labs/tiktok/photo-app-source-executor/common' '/lab' 'directory' $all
 Add-Bind 'labs/tiktok/photo-app-source-executor/offline' '/offline' 'directory' $all
 Add-Bind 'labs/tiktok/ui-combined-offline' '/newlab' 'directory' @('generate','proxy','app','gateway')
 Add-Bind 'labs/tiktok/ui-backend-offline' '/compat' 'directory' $all
 Add-Bind 'labs/tiktok/ui-combined-mountfix' '/mountfix' 'directory' $all
 Add-Bind 'labs/tiktok/photo-dns-diagnostics-fix/proxy_collect.py' '/lab/proxy_collect.py' 'file' $all
 Add-Bind $Control '/control' 'directory' @('generate','proxy','app','gateway') $false
 foreach($root in @('apps/egress','apps/web','apps/media/src','apps/worker/src','apps/api/src','packages/shared/src','prisma','labs/tiktok/photo-app-source-executor','labs/tiktok/ui-backend-offline','labs/tiktok/ui-combined-offline','labs/tiktok/ui-combined-mountfix')){Add-Bind $root "/repo/$root" 'directory' $all}
 foreach($file in @('package.json','package-lock.json','tsconfig.json','labs/tiktok/photo-dns-diagnostics-fix/proxy_collect.py')){Add-Bind $file "/repo/$file" 'file' $all}
 foreach($name in @('index.html','assets/index-UOIc8eun.js','assets/index-DCfw3VbE.css')){$path="docs/evidence/ui-a-app-integration-20261016/build/web/$name";Add-Bind $path "/repo/$path" 'file' $all}
 foreach($root in @('apps/web','apps/media/src','apps/worker/src','apps/api/src','packages/shared/src','prisma')){Add-Bind $root "/app/$root" 'directory' $application}
 Add-Bind 'labs/tiktok/photo-app-source-executor/offline/media_entry.py' '/app/infra/media_adapter.py' 'file' $application
 Add-Bind 'docs/evidence/ui-a-app-integration-20261016/build/web' '/build' 'directory' @('generate','app','gateway')
 return $rows.ToArray()
}
function Resolve-CombinedTarget($Map,[string]$Role,[string]$Target){
 $matches=@($Map|Where-Object{ $_.roles -contains $Role -and ($_.target -ceq $Target -or ($_.type -ceq 'directory' -and $Target.StartsWith($_.target+'/',[StringComparison]::Ordinal)))}|Sort-Object {$_.target.Length} -Descending)
 if(!$matches.Count){throw 'TARGET_UNMAPPED'};$m=$matches[0]
 $suffix=$Target.Substring($m.target.Length).TrimStart('/')
 return $(if($suffix){[IO.Path]::Combine($m.source,$suffix.Replace('/',[IO.Path]::DirectorySeparatorChar))}else{$m.source})
}
function Assert-CombinedMountMap($Map){
 foreach($m in $Map){
  $source=Get-Item -LiteralPath $m.source -ErrorAction Stop
  if(($m.type -ceq 'directory') -ne [bool]$source.PSIsContainer -or $m.type -notin @('file','directory') -or $m.source.Contains(',') -or !$m.target.StartsWith('/') -or $m.target.Contains('..')){throw 'MOUNT_SOURCE_TYPE'}
  if(!$m.readOnly -and $m.target -cne '/control'){throw 'MOUNT_WRITE_SCOPE'}
 }
 foreach($role in @('generate','proxy','app','gateway')){
  $rows=@($Map|Where-Object{$_.roles -contains $role});$seen=@{}
  foreach($m in $rows){if($seen.ContainsKey($m.target)){throw 'DUPLICATE_TARGET'};$seen[$m.target]=$true
   foreach($parent in $rows|Where-Object{$_.readOnly -and $_.type -ceq 'directory' -and $m.target.StartsWith($_.target+'/',[StringComparison]::Ordinal)}){
    $target=[IO.Path]::Combine($parent.source,$m.target.Substring($parent.target.Length+1).Replace('/',[IO.Path]::DirectorySeparatorChar))
    if(!(Test-Path -LiteralPath $target)){throw 'MISSING_NESTED_TARGET'}
    if((Get-Item -LiteralPath $target).PSIsContainer -ne ($m.type -ceq 'directory')){throw 'NESTED_TARGET_TYPE'}
   }
  }
 }
 $required=@{
  generate=@('/offline/generate.py','/compat/check.cjs','/newlab/controller.ts','/newlab/gateway.cjs','/build/index.html')
  proxy=@('/offline/proxy.py','/compat/sitecustomize.py','/lab/proxy_collect.py','/repo/apps/egress/src/egress.py','/repo/apps/egress/src/tiktok_policy/runtime.py','/repo/apps/egress/vendor/aiohappyeyeballs/__init__.py')
  app=@('/mountfix/entry.py','/lab/supervisor.py','/compat/start.sh','/newlab/controller.ts','/lab/worker.ts','/lab/selection.ts','/lab/media.py','/offline/media_entry.py','/offline/media_site.py','/app/infra/media_adapter.py','/app/apps/media/src/tiktok/photo_adapter.py','/app/apps/media/src/tiktok/connection_boundaries.py','/app/apps/api/src/main.ts','/app/apps/worker/src/processor.ts','/app/packages/shared/src/core.ts','/app/prisma/schema.prisma')
  gateway=@('/newlab/gateway.cjs','/build/index.html','/build/assets/index-UOIc8eun.js','/build/assets/index-DCfw3VbE.css')
 }
 $proof=@(foreach($role in $required.Keys){foreach($target in $required[$role]){$path=Resolve-CombinedTarget $Map $role $target;if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw 'ENTRY_IMPORT_TARGET'};[pscustomobject]@{role=$role;target=$target;source=$path;sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}}})
 $start=[IO.File]::ReadAllText((Resolve-CombinedTarget $Map 'app' '/compat/start.sh'))
 $entry=[IO.File]::ReadAllText((Resolve-CombinedTarget $Map 'app' '/mountfix/entry.py'))
 if(!$start.Contains('/newlab/controller.ts') -or !$entry.Contains("['bash','/compat/start.sh']")){throw 'ENTRY_LINK'}
 return $proof
}
function Get-CombinedBindArgs($Map,[string]$Role){
 foreach($m in $Map|Where-Object{$_.roles -contains $Role}){'--mount';"type=bind,source=$($m.source),target=$($m.target)$(if($m.readOnly){',readonly'})"}
}
