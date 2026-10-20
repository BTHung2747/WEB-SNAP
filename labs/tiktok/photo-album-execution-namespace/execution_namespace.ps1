# AGPL-3.0 fixed execution namespaces; storage ID is not task/source authority.
function AlbumEvidenceRoot{[IO.Path]::GetFullPath('D:\WED SNAP\docs\evidence\tiktok-photo-album-execution-namespace-20261014')}
function AlbumExecutionBase{[IO.Path]::GetFullPath('D:\WED SNAP\lab-runs\tiktok-photo-album-namespace-v1')}
function SetAlbumExecution($id,[switch]$Offline){
 ScalarString $id
 if($id -cnotmatch '^[a-f0-9]{32}$'){throw 'EXECUTION_ID_SCHEMA'}
 $script:AlbumExecutionID=$id;$script:AlbumExecutionMode=$(if($Offline){'offline'}else{'real'})
}
function RequireAlbumExecution($mode){
 if($mode -cnotin @('offline','real') -or $script:AlbumExecutionMode -cne $mode -or $script:AlbumExecutionID -isnot [string] -or $script:AlbumExecutionID -cnotmatch '^[a-f0-9]{32}$'){throw 'EXECUTION_SCOPE_REQUIRED'}
}
function AlbumRoot{
 if($script:AlbumExecutionMode -cnotin @('offline','real')){throw 'EXECUTION_REQUIRED'}
 RequireAlbumExecution $script:AlbumExecutionMode
 Join-Path (AlbumExecutionBase) "$($script:AlbumExecutionMode)/execution-$($script:AlbumExecutionID)"
}
function AlbumRegistryRoot{RequireAlbumExecution 'real';Join-Path (AlbumExecutionBase) 'real/task-registry'}
function AlbumExecutionPath($path){
 ScalarString $path;$full=[IO.Path]::GetFullPath($path);$root=AlbumRoot
 if($full -cne $root -and -not $full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::Ordinal)){throw 'EXECUTION_PATH_CROSSING'}
 # Reuse FixedPath on the nearest existing ancestor before mkdir/write, and
 # every existing child. Missing paths do not bypass junction checks.
 $anchor=$full;while(-not(Test-Path -LiteralPath $anchor)){$anchor=Split-Path $anchor;if(-not $anchor){throw 'EXECUTION_PATH_MISSING'}}
 FixedPath $anchor $anchor
 return $full
}
function NewAlbumExecution{
 $root=AlbumExecutionPath (AlbumRoot)
 if(Test-Path -LiteralPath $root){throw 'EXECUTION_REUSE'}
 New-Item -ItemType Directory -Path $root|Out-Null;FixedPath $root $root
 return $root
}
