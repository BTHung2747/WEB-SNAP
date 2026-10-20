# AGPL-3.0 WED SNAP wiring only. Readers and canonical claims remain unchanged.
function NewAuthorityMountTree($releaseDir,$stagedDir){
 ScalarString $releaseDir;ScalarString $stagedDir
 FixedPath $releaseDir $releaseDir
 $parent=Split-Path $stagedDir;FixedPath $parent $parent
 if((Split-Path $stagedDir -Leaf) -cne 'authority-mount' -or (Test-Path -LiteralPath $stagedDir)){throw 'AUTHORITY_MOUNT_REUSE_OR_PATH'}
 $entries=@(Get-ChildItem -LiteralPath $releaseDir -Force)
 if(-not $entries.Count -or $entries.Count -gt 64){throw 'AUTHORITY_MOUNT_INVENTORY'}
 foreach($entry in $entries){
  FixedPath $entry.FullName $entry.FullName
  if($entry.PSIsContainer -or $entry.Name -cnotmatch '^[a-z][a-z0-9-]*\.json$' -or $entry.Name -cin @('source-claim.json','task-latch.json') -or $entry.Length -gt 2MB){throw 'AUTHORITY_MOUNT_INPUT'}
 }
 New-Item -ItemType Directory -Path $stagedDir|Out-Null;FixedPath $stagedDir $stagedDir
 $rows=@()
 foreach($entry in $entries){
  $before=SourceSHA $entry.FullName;$target=Join-Path $stagedDir $entry.Name
  Copy-Item -LiteralPath $entry.FullName -Destination $target
  if((SourceSHA $target) -cne $before -or (SourceSHA $entry.FullName) -cne $before){throw 'AUTHORITY_MOUNT_COPY_HASH'}
  $rows+=@{name=$entry.Name;sha256=$before}
 }
 foreach($name in 'source-claim.json','task-latch.json'){
  $f=[IO.File]::Open((Join-Path $stagedDir $name),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);$f.Dispose()
 }
 return @{directory=(Resolve-Path -LiteralPath $stagedDir).Path;releaseDirectory=(Resolve-Path -LiteralPath $releaseDir).Path;copies=$rows;placeholders=@('source-claim.json','task-latch.json');canonicalChildBindsRequired=$true}
}
