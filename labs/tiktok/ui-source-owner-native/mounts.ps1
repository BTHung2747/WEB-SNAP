function Get-CanonicalMountHost([string]$Path){
 if([string]::IsNullOrWhiteSpace($Path) -or $Path -match '[<>]'){throw 'MOUNT_SOURCE_UNBOUND'}
 $full=if([IO.Path]::IsPathRooted($Path)){[IO.Path]::GetFullPath($Path)}else{Resolve-WorkspaceFile $Path}
 $relative=[IO.Path]::GetRelativePath((Get-Location).Path,$full)
 $checked=Resolve-WorkspaceFile $relative # Reject every existing ancestor reparse.
 if(!(Test-Path -LiteralPath $checked)){throw 'MOUNT_SOURCE_MISSING'}
 return $checked.TrimEnd([IO.Path]::DirectorySeparatorChar)
}
function Test-HostSubtree([string]$Path,[string]$Parent){
 $Path.Equals($Parent,[StringComparison]::OrdinalIgnoreCase) -or $Path.StartsWith($Parent+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
}
function Assert-NoPrivateMountSource($Context,[string]$HostPath){
 $private=[Collections.Generic.List[string]]::new()
 if($Context.Root){$private.Add([IO.Path]::GetFullPath((Join-Path $Context.Root 'owner-private')))}
 foreach($name in @('ClaimPath','RunPath','LedgerPath','ApprovalPath')){if($Context.$name){$private.Add([IO.Path]::GetFullPath($Context.$name))}}
 $private.Add([IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'trust-anchor.json')))
 $isDirectory=(Get-Item -LiteralPath $HostPath).PSIsContainer
 foreach($p in $private){if((Test-HostSubtree $HostPath $p) -or ($isDirectory -and (Test-HostSubtree $p $HostPath))){throw 'PRIVATE_SOURCE_EXPOSURE'}}
 if($isDirectory -and (!$Context.Control -or !([IO.Path]::GetFullPath($Context.Control).TrimEnd([IO.Path]::DirectorySeparatorChar)).Equals($HostPath,[StringComparison]::OrdinalIgnoreCase))){throw 'UNPLANNED_DIRECTORY_SOURCE'}
}
function Assert-ObservedMountSource($Context,[string]$Expected,[string]$Observed){
 # Native Windows source spelling is verified through public filesystem APIs.
 # Linux Docker Desktop strings are NEVER inferred by prefix substitution.
 if($Observed -match '^[A-Za-z]:[\\/]'){
  $host=Get-CanonicalMountHost $Observed;Assert-NoPrivateMountSource $Context $host
  if(!$host.Equals($Expected,[StringComparison]::OrdinalIgnoreCase)){throw 'MOUNT_SOURCE_MISMATCH'};return
 }
 if(!$Observed.StartsWith('/') -or $Observed -match '//|/\.\.?(/|$)|[\x00-\x1f]'){throw 'MOUNT_SOURCE_FORM_UNKNOWN'}
 $maps=@($Context.EnvironmentProof.mountSourceMap|Where-Object{ $_.hostSource -ceq $Expected -and $_.observedSource -ceq $Observed })
 if($maps.Count -ne 1){throw 'DOCKER_HOST_SOURCE_MAPPING_UNKNOWN'}
 $map=$maps[0];$offline=$Context.Mode -ceq 'OFFLINE_TEST_ONLY'
 if($Context.EnvironmentProof.mode -cne $(if($offline){'OFFLINE_TEST_ONLY'}else{'SOURCE_OWNER_ENVIRONMENT'}) -or $map.status -cne $(if($offline){'OFFLINE_TEST_ONLY'}else{'PASS_OBSERVED'})){throw 'DOCKER_HOST_SOURCE_MAPPING_UNOBSERVED'}
 $proof=Resolve-WorkspaceFile $map.proof.ref
 if((Get-FileHash -LiteralPath $proof).Hash.ToLowerInvariant() -cne $map.proof.sha256){throw 'DOCKER_HOST_MAPPING_PROOF_CHANGED'}
}
function Assert-PlannedMount($Context,$Expected,$Observed){
 if($Observed.Type -cne 'bind' -or $Observed.Destination -cne $Expected.target -or $Expected.readOnly -isnot [bool] -or $Observed.RW -isnot [bool] -or $Observed.RW -ne !$Expected.readOnly){throw 'MOUNT_TYPE_TARGET_RW'}
 $raw=[string]$Expected.source
 if($raw.Contains('<')){if(!$Context.Control){throw 'OWN_CONTROL_NOT_BOUND'};$raw=Expand-OwnerArg $raw @{OWN_CONTROL=$Context.Control}}
 $host=Get-CanonicalMountHost $raw;Assert-NoPrivateMountSource $Context $host
 Assert-ObservedMountSource $Context $host ([string]$Observed.Source)
}
