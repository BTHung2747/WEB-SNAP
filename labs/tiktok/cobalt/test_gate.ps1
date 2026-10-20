$ErrorActionPreference='Stop'
. "$PSScriptRoot/hash_gate.ps1"
. "$PSScriptRoot/redact.ps1"
function MustReject($receipt,$current,$image){
    try{Assert-CobaltHashGate $receipt $current $image}catch{return}
    throw 'Stale/missing offline receipt accepted'
}
$files=@([ordered]@{path='src/main.mjs';bytes=1;sha256='source-a'},[ordered]@{path='package-lock.json';bytes=2;sha256='deps-a'})
$receipt=@{schema=1;actualExit=0;ownResourcesLeft=0;imageID='image-a';hostHashes=$files}
Assert-CobaltHashGate $receipt $files 'image-a'
MustReject $receipt @([ordered]@{path='src/main.mjs';bytes=1;sha256='source-b'},$files[1]) 'image-a'
MustReject $receipt @($files[0],[ordered]@{path='package-lock.json';bytes=2;sha256='deps-b'}) 'image-a'
MustReject $receipt $files 'image-b'
MustReject @{actualExit=0;ownResourcesLeft=0} $files 'image-a'
$redacted=Clean 'https://FAKEUSER:FAKEPASS@host.invalid/FAKEPATH/token/FAKEPATH2?token=FAKEQUERY#FAKEFRAGMENT Cookie: FAKECOOKIE'
if($redacted -match 'FAKE' -or $redacted -notmatch '\[url-redacted\]'){throw 'Path/query/header redaction failed'}
Write-Output 'PASS host hash gate: match; stale source/lock/image/missing receipt denied; pathname/query/userinfo/cookie redacted (fake only)'
