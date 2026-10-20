param([string]$Output)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/hash_gate.ps1"
$a=[ordered]@{path='lab/a';sha256=('a'*64)};$b=[ordered]@{path='lab/b';sha256=('b'*64)}
$gold=Convert-TraceSnapshot @($a,$b)
if($gold -cne (Convert-TraceSnapshot @($b,$a))){throw 'Order invariant FAIL'}
$stale=[ordered]@{path='lab/a';sha256=('c'*64)}
if($gold -ceq (Convert-TraceSnapshot @($stale,$b))){throw 'Stale hash FAIL'}
if($gold -ceq (Convert-TraceSnapshot @($a))){throw 'Missing source FAIL'}
$duplicate=$false;try{Convert-TraceSnapshot @($a,$a)|Out-Null}catch{$duplicate=$true}
if(-not $duplicate){throw 'Duplicate source FAIL'}
@{status='PASS';actualExit=0;cases=@('order-invariant','changed-hash-reject','missing-reject','duplicate-reject');sourceCalls=0;PowerShell=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json|Set-Content -LiteralPath $Output

