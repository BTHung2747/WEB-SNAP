# Offline only: standalone Compose rendering. No Docker engine or real env file.
param([string]$ComposeExecutable='C:\Program Files\Docker\Docker\resources\cli-plugins\docker-compose.exe',[switch]$PreviewOnly)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$temp=Join-Path $root ('.production-config-check-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$fake=Join-Path $temp 'fake.env'
$text=@'
PUBLIC_HOST=production-fixture.invalid
ACME_EMAIL=acme@example.invalid
CONTACT_EMAIL=operator@example.invalid
APP_IMAGE=fixture.invalid/app:offline
EGRESS_IMAGE=fixture.invalid/egress:offline
WEB_IMAGE=fixture.invalid/static:offline
POSTGRES_PASSWORD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
ADMIN_SESSION_SECRET=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
TIKTOK_EGRESS_CONTROL_SECRET=cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
PRODUCTION_PRIVATE_SUBNET=10.231.47.0/24
'@
function Render([string]$content,[bool]$success=$true){
 [IO.File]::WriteAllText($fake,$content,[Text.UTF8Encoding]::new($false))
 $p=[Diagnostics.Process]::new();$p.StartInfo=[Diagnostics.ProcessStartInfo]::new($ComposeExecutable)
 $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 $p.StartInfo.Environment.Clear()
 foreach($key in @('SystemRoot','WINDIR','TEMP','TMP','PATH')){
  $value=[Environment]::GetEnvironmentVariable($key)
  if($value){$p.StartInfo.Environment[$key]=$value}
 }
 $p.StartInfo.Environment['COMPOSE_DISABLE_ENV_FILE']='1'
 foreach($arg in @('--project-directory',$root,'--env-file',$fake,'-f',(Join-Path $root 'compose.production.yaml'),'--profile','tools','config','--format','json')){$p.StartInfo.ArgumentList.Add($arg)}
 try{
  $watch=[Diagnostics.Stopwatch]::StartNew();if(!$p.Start()){throw 'COMPOSE_START'}
  $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
  if(!$p.WaitForExit(15000)){$p.Kill($true);$p.WaitForExit();throw 'COMPOSE_RENDER_DEADLINE'}
  $watch.Stop();$out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult()
  if($out.Length -gt 131072 -or $err.Length -gt 8192){throw 'COMPOSE_OUTPUT_CAP'}
  if($success -ne ($p.ExitCode -eq 0)){throw 'COMPOSE_EXPECTED_EXIT'}
  if(!$success){return @{actualExit=$p.ExitCode;elapsedMs=$watch.ElapsedMilliseconds}}
  return @{actualExit=$p.ExitCode;elapsedMs=$watch.ElapsedMilliseconds;config=($out|ConvertFrom-Json -Depth 60 -DateKind String)}
 }finally{$p.Dispose()}
}
function Require([bool]$ok,[string]$code){if(!$ok){throw $code}}
function PreviewRoles($config,[string]$expected){
 foreach($role in @('worker','egress')){Require ($config.services.$role.environment.TIKTOK_PREVIEW_ENABLED -ceq $expected) 'PREVIEW_ROLE_FLAG'}
 foreach($role in @('api','maintenance','proxy','postgres','redis')){
  $environment=$config.services.$role.environment
  Require (!$environment -or !$environment.PSObject.Properties['TIKTOK_PREVIEW_ENABLED']) 'PREVIEW_FLAG_WRONG_ROLE'
 }
}
$report=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');scope='offline fake env; no Docker engine/images/network/service actions';cases=@();result='FAIL'}
try{
 $r=Render $text;$c=$r.config
 PreviewRoles $c '0'
 if($PreviewOnly){
  $report.cases+=@{name='preview unset defaults0 only worker+egress';result='PASS';actualExit=$r.actualExit;elapsedMs=$r.elapsedMs}
  foreach($flag in @('0','1')){
   $p=Render ($text+"`nTIKTOK_PREVIEW_ENABLED=$flag`n");PreviewRoles $p.config $flag
   foreach($role in @('api','worker')){foreach($gate in @('TIKTOK_ADAPTER_ENABLED','TIKTOK_PHOTO_ENABLED','TIKTOK_VIDEO_ENABLED','TIKTOK_EGRESS_POLICY_ENABLED')){Require ($p.config.services.$role.environment.$gate -ceq '0') 'PREVIEW_MUST_NOT_ENABLE_PLATFORM'}}
   Require ($p.config.services.egress.environment.TIKTOK_EGRESS_POLICY_ENABLED -ceq '0') 'PREVIEW_MUST_NOT_ENABLE_EGRESS'
   $report.cases+=@{name="preview explicit$flag exact roles; platform gates remain0";result='PASS';actualExit=$p.actualExit;elapsedMs=$p.elapsedMs}
  }
  $example=[IO.File]::ReadAllText((Join-Path $root 'infra/production/production.env.example'))
  Require ([regex]::Matches($example,'(?m)^TIKTOK_PREVIEW_ENABLED=0\r?$').Count -eq 1) 'PREVIEW_EXAMPLE_DEFAULT'
  $ignore=[IO.File]::ReadAllLines((Join-Path $root '.dockerignore'))
  foreach($path in @('lab-runs','labs','design','apps/web/dev','docs/evidence')){Require ($ignore -contains $path) 'RELEASE_CONTEXT_EXCLUDES_FIXTURES'}
  $report.cases+=@{name='example flag0 and lab/fixture build-context exclusions';result='PASS';kind='source inspection only'}
  $report.notRun=@('Docker engine/build/pull/start','historical config suite','real env/settings/source/API/download/preview','commit/push/publish/deploy')
  $report.result='PASS_OFFLINE_CONFIG_ONLY'
  return
 }
 Require ($c.name -eq 'wed-snap-production') 'PROJECT_NOT_SEPARATE'
 Require (($c.services.PSObject.Properties.Name|Sort-Object) -join ',' -eq 'api,egress,maintenance,postgres,proxy,redis,worker') 'EXACT_SERVICES'
 foreach($role in @('api','worker','postgres','redis','egress','maintenance','proxy')){
  $s=$c.services.$role
  Require (!$s.build -and !$s.privileged -and !$s.cap_add -and $s.cap_drop -contains 'ALL' -and $s.read_only -and $s.ipc -eq 'private') 'RUNTIME_GUARDS'
  Require ($s.pull_policy -eq 'never' -and $s.user -notin @('0','root','0:0','')) 'IMAGE_USER'
  Require ($s.mem_limit -gt 0 -and $s.mem_limit -eq $s.memswap_limit) 'MEMORY_CAP'
  if($role -ne 'proxy'){Require (!$s.ports) 'ONLY_PROXY_PUBLIC'}
  foreach($v in $s.volumes){Require ($v.type -eq 'volume') 'NO_HOST_OR_SOURCE_BIND'}
 }
 Require (($c.services.proxy.ports|ForEach-Object published|Sort-Object) -join ',' -eq '443,80') 'TWO_TCP_PORTS'
 Require (($c.services.proxy.ports|Where-Object protocol -ne tcp).Count -eq 0) 'NO_EXTRA_PROTOCOL'
 Require ($c.networks.private.internal -and $c.networks.proxy_api.internal) 'PRIVATE_NETWORKS'
 Require ($c.networks.private.ipam.config[0].subnet -eq '10.231.47.0/24' -and $c.services.egress.environment.TIKTOK_EGRESS_CONTROL_NETWORKS -eq '10.231.47.0/24') 'EXACT_CONTROL_CIDR'
 Require (($c.services.worker.networks.PSObject.Properties.Name -join ',') -eq 'private') 'WORKER_NO_INTERNET'
 Require (($c.services.api.networks.PSObject.Properties.Name|Sort-Object) -join ',' -eq 'private,proxy_api') 'API_NO_INTERNET'
 Require (($c.services.egress.networks.PSObject.Properties.Name|Sort-Object) -join ',' -eq 'outbound,private') 'EGRESS_TOPOLOGY'
 foreach($role in @('api','worker')){
  $e=$c.services.$role.environment
  Require ($e.APP_ORIGIN -eq 'https://production-fixture.invalid' -and $e.COOKIE_SECURE -eq 'true' -and $e.VERIFIED_PLATFORMS -eq 'youtube,tiktok') 'ORIGIN_COOKIE_SCOPE'
  foreach($flag in @('TIKTOK_ADAPTER_ENABLED','TIKTOK_PHOTO_ENABLED','TIKTOK_VIDEO_ENABLED','TIKTOK_EGRESS_POLICY_ENABLED')){Require ($e.$flag -ceq '0') 'DEFAULT_OFF'}
 }
 Require (($c.services.api.command -join ' ') -eq 'node dist/apps/api/src/main.js' -and ($c.services.worker.command -join ' ') -eq 'node dist/apps/worker/src/main.js') 'COMPILED_ENTRYPOINTS'
 Require ($c.services.api.environment.TRUSTED_PROXY_HOSTS -eq 'proxy') 'EXACT_TRUSTED_HOP'
 Require (!$c.services.proxy.environment.ADMIN_SESSION_SECRET -and !$c.services.proxy.environment.TIKTOK_EGRESS_CONTROL_SECRET -and !$c.services.proxy.environment.DATABASE_URL) 'NO_SECRET_ON_PROXY'
 Require ($c.services.api.volumes[0].read_only -and !$c.services.worker.volumes[0].read_only) 'MEDIA_OWNERSHIP'
 $report.cases+=@{name='standalone default-off topology/ports/guards/origin/compiled/secret forwarding';result='PASS';actualExit=$r.actualExit;elapsedMs=$r.elapsedMs}
 $on=Render ($text+"`nTIKTOK_ADAPTER_ENABLED=1`nTIKTOK_PHOTO_ENABLED=1`nTIKTOK_VIDEO_ENABLED=1`nTIKTOK_EGRESS_POLICY_ENABLED=1`n")
 PreviewRoles $on.config '0'
 Require ($on.config.services.api.environment.TIKTOK_VIDEO_ENABLED -ceq '1' -and $on.config.services.worker.environment.TIKTOK_VIDEO_ENABLED -ceq '1' -and $on.config.services.egress.environment.TIKTOK_EGRESS_POLICY_ENABLED -ceq '1') 'ASSIGNED_GATES_FORWARD'
 $report.cases+=@{name='explicit target-stage gate forwarding';result='PASS';actualExit=$on.actualExit;elapsedMs=$on.elapsedMs}
 $missing=Render ($text.Replace('POSTGRES_PASSWORD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','POSTGRES_PASSWORD=')) $false
 $report.cases+=@{name='missing production secret rejects config';result='PASS';actualExit=$missing.actualExit;elapsedMs=$missing.elapsedMs}
 # Check build wiring directly; do not claim a binary/image build when tools are absent.
 $ts=Get-Content -LiteralPath (Join-Path $root 'tsconfig.json')|ConvertFrom-Json
 Require ($ts.compilerOptions.outDir -eq 'dist' -and $ts.compilerOptions.rootDir -eq '.') 'COMPILED_LAYOUT'
 foreach($file in @('apps/api/src/main.ts','apps/worker/src/main.ts','scripts/create-admin.ts','apps/web/index.html','infra/production/Caddyfile')){Require (Test-Path -LiteralPath (Join-Path $root $file)) 'ENTRY_SOURCE_EXISTS'}
 $app=[IO.File]::ReadAllText((Join-Path $root 'Dockerfile'));$web=[IO.File]::ReadAllText((Join-Path $root 'infra/production/Dockerfile.web'))
 Require ($app.Contains('RUN npm run build') -and $web.Contains('FROM caddy:2.11.7-alpine') -and $web.Contains('COPY --from=assets /app/apps/web/dist/ /srv/')) 'STATIC_BUILD_WIRING'
 Require ([IO.File]::ReadAllText((Join-Path $root 'apps/worker/src/main.ts')).Contains('concurrency: 1')) 'CONCURRENCY_ONE'
 $report.cases+=@{name='existing build script/tsconfig/static artifact and concurrency wiring';result='PASS';kind='source inspection only'}
 $report.notRun=@('Docker engine/pull/build/start','real env/secrets/local data','Caddy adapt/validate binary','fresh npm/TypeScript/Vite build: no host project dependencies','TLS/ACME/target resources/P5-P6/source/browser/Range on target')
 $report.result='PASS_OFFLINE_CONFIG_ONLY'
}finally{
 $resolved=[IO.Path]::GetFullPath($temp)
 if([IO.Path]::GetDirectoryName($resolved) -cne $root -or [IO.Path]::GetFileName($resolved) -notmatch '^\.production-config-check-[a-f0-9]{32}$'){throw 'TEMP_OWNERSHIP'}
 Remove-Item -LiteralPath $resolved -Recurse -Force
 $report.fakeEnvRemoved=!(Test-Path -LiteralPath $resolved)
 $report|ConvertTo-Json -Depth 7
}
if($report.result -ne 'PASS_OFFLINE_CONFIG_ONLY'){exit 20}
