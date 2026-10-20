. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path (Get-Location).Path 'labs/tiktok/ui-source-prelaunch/wiring.ps1')
$plan=Get-PrelaunchPlan;$specs=@(New-Specs $plan.resources.roles);$cases=[Collections.Generic.List[object]]::new()
function Check([bool]$OK,[string]$Code){if(!$OK){throw $Code};$cases.Add(@{case=$Code;status='PASS_FIXTURE_ONLY'})}
function Reject($Action,[string]$Code){$denied=$false;try{&$Action|Out-Null}catch{$denied=$true};Check $denied $Code}
$good=@{Status='PASS';Created=$true;RootInOwnJob=$true;RootExit=0;TerminationRequested=$false;Timeout=$false;ByteCapExceeded=$false;FinalActive=0;PipesEOF=$true;CleanupClosed=$true;LiveHandles=0;LiveBuffers=0;BackgroundReaders=0}
Check (Test-NativeOperation ([pscustomobject]$good)) 'NATIVE_ALL_CONDITIONS'
foreach($patch in @(@{key='Status';value='FAIL'},@{key='RootExit';value=20},@{key='RootExit';value=$null},@{key='TerminationRequested';value=$true},@{key='FinalActive';value=$null},@{key='PipesEOF';value=$false},@{key='CleanupClosed';value=$false},@{key='ByteCapExceeded';value=$true})){$v=$good.Clone();$v[$patch.key]=$patch.value;Check (!(Test-NativeOperation ([pscustomobject]$v))) ('REJECT_'+$patch.key+'_'+$cases.Count)}
Check ($specs.Count -eq 7 -and @($specs|Where-Object image|Select-Object image -Unique).Count -eq 4) 'SEVEN_FIXED_FOUR_IMAGES'
$image=$specs[1];$fake=@{id=$image.image;os='linux';architecture='amd64';sizeBytes=12345}
$data=Read-Projection $image ($fake|ConvertTo-Json -Compress)
Check ($data.roles.Count -eq 2) 'IMAGE_ROLE_ASSOCIATION'
$fake.id='sha256:'+('0'*64);Reject {Read-Projection $image ($fake|ConvertTo-Json -Compress)} 'REJECT_IMAGE_ID'
foreach($name in @('containers','networks')){Check ((Read-Projection @($specs|Where-Object key -CEQ $name)[0] '').count -eq 0) ('EMPTY_SCOPED_'+$name)}
$fake=@{id='a'*64;name='outside';state='running';run='b'*32};Reject {Read-Projection $specs[5] ($fake|ConvertTo-Json -Compress)} 'REJECT_FOREIGN_CONTAINER_SCOPE'
$fake.name='wed-source-'+('b'*32)+'-app';Check ((Read-Projection $specs[5] ($fake|ConvertTo-Json -Compress)).count -eq 1) 'VALID_SCOPED_CONTAINER'
$fake.run='c'*32;Reject {Read-Projection $specs[5] ($fake|ConvertTo-Json -Compress)} 'REJECT_NAME_LABEL_MISMATCH'
$fake=@{id='a'*64;name='wed-source-'+('b'*32)+'-internal';driver='bridge';scope='local'};Check ((Read-Projection $specs[6] ($fake|ConvertTo-Json -Compress)).count -eq 1) 'VALID_SCOPED_NETWORK'
$fake=@{serverVersion='29.8.1';os='linux';architecture='x86_64';kernel='6.6';operatingSystem='Docker Desktop';cpus=4;memoryBytes=2000000000;cgroupVersion='2';cgroupDriver='cgroupfs';securityOptions=@('name=seccomp,profile=builtin','name=cgroupns')}
$safe=Read-Projection $specs[0] ($fake|ConvertTo-Json -Compress)
Check ($safe.fields.seccompAdvertised -and $safe.fields.cgroupnsAdvertised -and !$safe.fields.ContainsKey('securityOptions')) 'INFO_ADVERTISEMENT_PROJECTION'
$fake.extra='OFFLINE_DUMMY_ONLY';Reject {Read-Projection $specs[0] ($fake|ConvertTo-Json -Compress)} 'REJECT_EXTRA_FIELDS'
Write-New (Join-Path $script:Root 'offline-contract-tests-2.json') @{status='PASS_PURE_FIXTURES_NOT_ENVIRONMENT';caseCount=$cases.Count;cases=$cases.ToArray();nativeQueries=0;daemonQueries=0;sourceCalls=0}
Write-Output ('PASS_PURE_CONTRACT_FIXTURES_'+$cases.Count);exit 0
