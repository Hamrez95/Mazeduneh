param(
  [ValidateSet('start','restart','status','stop')][string]$Action = 'start',
  [switch]$NoBrowser,
  [switch]$SkipBuild,
  [string]$LocalHome = $env:MAZEDUNEH_LOCAL_HOME,
  [string]$RuntimeHome = $env:MAZEDUNEH_RUNTIME_HOME
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.4') { throw 'PowerShell 7.4+ is required. Install: winget install Microsoft.PowerShell' }
$root = Split-Path -Parent $PSScriptRoot
$localRoot = if($LocalHome) { $LocalHome } else { Join-Path $env:LOCALAPPDATA 'Mazeduneh/local' }
$runtime = if($RuntimeHome) { $RuntimeHome } else { Join-Path $env:LOCALAPPDATA 'Mazeduneh/runtime' }
New-Item -ItemType Directory -Force $localRoot,$runtime,(Join-Path $root '.local-dev') | Out-Null
$stateFile = Join-Path $localRoot 'processes.json'
$secretsFile = Join-Path $localRoot 'credentials.json'
$pgRoot = Join-Path $runtime 'postgresql-17.11-5'
$pgBin = Join-Path $pgRoot 'pgsql/bin'
$pgData = Join-Path $localRoot 'postgres-data'
$apiUrl = 'http://127.0.0.1:5080'
$webUrl = 'http://127.0.0.1:3000'
$adminUrl = 'http://127.0.0.1:8080'
# Prevent overlapping double-clicks from racing migrations/builds or process state.
$lockName='Local\Mazeduneh-'+[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($localRoot).ToLowerInvariant())))
$launchLock=[Threading.Mutex]::new($false,$lockName)
try {$locked=$launchLock.WaitOne(0)} catch [Threading.AbandonedMutexException] {$locked=$true}
if(-not $locked){$launchLock.Dispose();throw 'Another Mazeduneh startup/stop is still running. Wait for that window to finish.'}
trap {if($launchLock){$launchLock.Dispose()};throw $_}
function Read-State { if(Test-Path $stateFile){ @(Get-Content $stateFile -Raw | ConvertFrom-Json) } else {@()} }
function Test-Owned($entry) {
  $p=Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$entry.pid)" -ErrorAction SilentlyContinue
  return $null -ne $p -and $entry.fragment -and ([string]$p.CommandLine).Contains([string]$entry.fragment,[StringComparison]::OrdinalIgnoreCase)
}
function Stop-Apps {
  foreach($entry in (Read-State)) {if(Test-Owned $entry){ & taskkill.exe /PID $entry.pid /T /F 2>$null | Out-Null }}
  Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
}
function Check-Ready([string]$url,[bool]$json=$false) {
  try { $r=Invoke-WebRequest $url -TimeoutSec 4 -SkipHttpErrorCheck
    if($r.StatusCode -ne 200){return $false}
    if($json){return $r.Headers['Content-Type'] -match 'application/json' -and ($r.Content|ConvertFrom-Json).status -eq 'ready'}
    return $true
  } catch {return $false}
}
if($Action -eq 'status') {
  [pscustomobject]@{Storefront=(Check-Ready $webUrl);Admin=(Check-Ready $adminUrl);ApiDatabase=(Check-Ready "$apiUrl/health/ready" $true);Data=$localRoot}|Format-List
  exit
}
if($Action -in @('stop','restart')) {
  Stop-Apps
  if($Action -eq 'stop') {
    if((Test-Path "$pgBin/pg_ctl.exe") -and (Test-Path "$pgData/postmaster.pid")){& "$pgBin/pg_ctl.exe" -D $pgData -m fast -w stop | Out-Null}
    Write-Host 'Local apps stopped. Database files are preserved.'
    exit
  }
}
if((Read-State|Where-Object {Test-Owned $_}) -and (Check-Ready "$apiUrl/health/ready" $true) -and (Check-Ready $webUrl) -and (Check-Ready $adminUrl)) {
  Write-Host "Already running: $webUrl and $adminUrl"
  if(-not $NoBrowser){Start-Process $webUrl;Start-Process $adminUrl}
  exit
}
Stop-Apps
function Resolve-Tool([string]$name,[string[]]$fallbacks=@()) {
  $cmd=Get-Command $name -ErrorAction SilentlyContinue
  if($cmd){return $cmd.Source}
  foreach($f in $fallbacks){if(Test-Path $f){return $f}}
  throw "Missing $name. See docs/BROWSER_FIRST_DELIVERY.md for one-time setup."
}
$dotnet=Resolve-Tool 'dotnet' @("$env:ProgramFiles/dotnet/dotnet.exe")
$node=Resolve-Tool 'node' @("$env:ProgramFiles/nodejs/node.exe")
$npm=Resolve-Tool 'npm.cmd' @("$env:ProgramFiles/nodejs/npm.cmd")
$flutter=Resolve-Tool 'flutter' @("$env:USERPROFILE/develop/flutter/bin/flutter.bat","$env:LOCALAPPDATA/flutter/bin/flutter.bat","$env:LOCALAPPDATA/Mazeduneh/flutter/bin/flutter.bat")
if(-not ((& $dotnet --list-sdks) -match '^10\.')){throw '.NET 10 SDK is required: winget install Microsoft.DotNet.SDK.10'}
foreach($port in @(5080,3000,8080)) {
  $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$port)
  try {$listener.Start()} catch {throw "Port $port belongs to another running app. Close the previous Mazeduneh session before starting this checkout."} finally {$listener.Stop()}
}
function Random-Secret { [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant() }
if(-not(Test-Path $secretsFile)) {
  @{adminEmail='admin@mazeduneh.local';adminPassword=(Random-Secret);databasePassword=(Random-Secret);signingKey=(Random-Secret)} | ConvertTo-Json | Set-Content $secretsFile -Encoding utf8NoBOM
}
$identitySid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $secretsFile /inheritance:r /grant:r "*${identitySid}:(F)" '*S-1-5-18:(F)' | Out-Null
if($LASTEXITCODE -ne 0){throw 'Cannot restrict access to the local credentials file.'}
$secrets=Get-Content $secretsFile -Raw | ConvertFrom-Json
if(-not(Test-Path "$pgRoot/.extract-complete")) {
  $zip=Join-Path $runtime 'postgresql-17.11-5-windows-x64-binaries.zip'
  if(-not(Test-Path $zip)){Write-Host 'First run: downloading PostgreSQL from EDB (no Docker or Windows service)...';Invoke-WebRequest 'https://get.enterprisedb.com/postgresql/postgresql-17.11-5-windows-x64-binaries.zip' -OutFile $zip}
  if((Get-FileHash $zip -Algorithm SHA256).Hash -ne '80379B2C04D51C30225532E0AE04509899141E9957ED096FE749D7FD9DF8F82F'){throw 'PostgreSQL archive checksum mismatch. Remove the incomplete ZIP from the runtime cache and retry.'}
  Write-Host 'Extracting PostgreSQL. This is only needed once...'
  $archive=[IO.Compression.ZipFile]::OpenRead($zip)
  try {
    foreach($entry in $archive.Entries) {
      if($entry.FullName -notmatch '^pgsql/(bin|lib|share)/' -or $entry.FullName.EndsWith('/')){continue}
      $target=[IO.Path]::GetFullPath((Join-Path $pgRoot $entry.FullName))
      if(-not $target.StartsWith([IO.Path]::GetFullPath($pgRoot)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected archive path.'}
      New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
      [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$target,$true)
    }
  } finally {$archive.Dispose()}
  Set-Content "$pgRoot/.extract-complete" '17.11-5' -Encoding ascii
}
if(-not(Test-Path "$pgData/PG_VERSION")) {
  $pwFile=Join-Path $localRoot 'pg-password.tmp'
  try {
    Set-Content $pwFile $secrets.databasePassword -NoNewline -Encoding utf8NoBOM
    & "$pgBin/initdb.exe" -D $pgData -U mazeduneh --encoding=UTF8 --locale=C --auth=scram-sha-256 "--pwfile=$pwFile" | Out-Host
    if($LASTEXITCODE -ne 0){throw 'PostgreSQL initialization failed.'}
  } finally {Remove-Item -LiteralPath $pwFile -Force -ErrorAction SilentlyContinue}
}
& "$pgBin/pg_ctl.exe" -D $pgData status *> $null
if($LASTEXITCODE -ne 0) {
  $pgStart=Start-Process -FilePath "$pgBin/pg_ctl.exe" -ArgumentList @('-D',('"'+$pgData+'"'),'-l',('"'+(Join-Path $localRoot 'postgres.log')+'"'),'-o','"-h 127.0.0.1 -p 55432"','-w','start') -RedirectStandardOutput (Join-Path $localRoot 'postgres-start.stdout.log') -RedirectStandardError (Join-Path $localRoot 'postgres-start.stderr.log') -WindowStyle Hidden -PassThru
  # Start-Process -Wait waits for PostgreSQL descendants too, including the server.
  if(-not $pgStart.WaitForExit(60000)){throw 'PostgreSQL startup timed out. See postgres-start.stderr.log.'}
  if($pgStart.ExitCode -ne 0){throw 'PostgreSQL did not start. See postgres.log in the local data folder.'}
}
$previousPgPassword=$env:PGPASSWORD
try {
  $env:PGPASSWORD=$secrets.databasePassword
  $exists=& "$pgBin/psql.exe" -h 127.0.0.1 -p 55432 -U mazeduneh -d postgres -tAc "select 1 from pg_database where datname='mazeduneh'"
  if($LASTEXITCODE -ne 0){throw 'Cannot authenticate to the local database.'}
  if($exists -ne '1'){& "$pgBin/createdb.exe" -h 127.0.0.1 -p 55432 -U mazeduneh mazeduneh;if($LASTEXITCODE -ne 0){throw 'Cannot create the local database.'}}
} finally {$env:PGPASSWORD=$previousPgPassword}
$apiEnv=@{
  ASPNETCORE_ENVIRONMENT='Development';ASPNETCORE_URLS=$apiUrl
  Admin__Email=$secrets.adminEmail
  Admin__PasswordHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($secrets.adminPassword)))
  Admin__TokenSigningKey=$secrets.signingKey;Admin__Mfa__SensitiveActionsRequired='false'
  ConnectionStrings__Catalog="Host=127.0.0.1;Port=55432;Database=mazeduneh;Username=mazeduneh;Password=$($secrets.databasePassword)"
  Payments__SandboxEnabled='true';'Cors__AllowedOrigins__0'=$webUrl;'Cors__AllowedOrigins__1'=$adminUrl
  Media__RootPath=(Join-Path $localRoot 'media')
}
$build=Join-Path $localRoot 'build/api'
function Run-WithEnv([string]$file,[string[]]$arguments,[hashtable]$environment) {
  $p=Start-Process -FilePath $file -ArgumentList $arguments -WorkingDirectory $root -Environment $environment -NoNewWindow -Wait -PassThru
  if($p.ExitCode -ne 0){throw "Build or database setup failed ($($p.ExitCode))."}
}
if(-not $SkipBuild) {
  & $dotnet build (Join-Path $root 'services/api/Mazeduneh.Api.csproj') -c Release -o $build --nologo
  if($LASTEXITCODE -ne 0){throw 'API build failed.'}
  Push-Location (Join-Path $root 'apps/storefront')
  try {if(-not(Test-Path node_modules/next)){& $npm ci --no-audit --no-fund;if($LASTEXITCODE -ne 0){throw 'Storefront dependency setup failed.'}}} finally {Pop-Location}
  Push-Location (Join-Path $root 'apps/admin')
  try {if(-not(Test-Path .dart_tool/package_config.json)){& $flutter --no-version-check pub get; if($LASTEXITCODE -ne 0){throw 'Admin dependency setup failed.'}}; & $flutter --no-version-check build web --no-pub --release --target lib/secure_main.dart "--dart-define=MAZEDUNEH_API_BASE_URL=$apiUrl";if($LASTEXITCODE -ne 0){throw 'Admin browser build failed.'}} finally {Pop-Location}
}
$dll=Join-Path $build 'Mazeduneh.Api.dll'
function Quote-Arg([string]$s){'"'+$s.Replace('"','\"')+'"'}
Run-WithEnv $dotnet @((Quote-Arg $dll),'--migrate','--seed-admin','--seed-demo') $apiEnv
$records=[Collections.Generic.List[object]]::new()
function Start-App([string]$name,[string]$exe,[string[]]$arguments,[hashtable]$environment,[string]$fragment) {
  $out=Join-Path $localRoot "$name.stdout.log";$err=Join-Path $localRoot "$name.stderr.log"
  $p=Start-Process -FilePath $exe -ArgumentList (($arguments|ForEach-Object {Quote-Arg $_}) -join ' ') -WorkingDirectory $root -Environment $environment -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden -PassThru
  $records.Add(@{name=$name;pid=$p.Id;fragment=$fragment})
  ConvertTo-Json -InputObject @($records.ToArray()) | Set-Content $stateFile -Encoding utf8NoBOM
}
try {
  Start-App 'api' $dotnet @($dll) $apiEnv $dll
  $next=Join-Path $root 'apps/storefront/node_modules/next/dist/bin/next'
  Start-App 'storefront' $node @($next,'dev','--webpack','--hostname','127.0.0.1','--port','3000', (Join-Path $root 'apps/storefront')) @{NEXT_PUBLIC_MAZEDUNEH_API_URL=$apiUrl;NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL=$apiUrl;NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE='false';NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL=$adminUrl;NEXT_PUBLIC_SITE_URL=$webUrl} $next
  $server=Join-Path $root 'scripts/serve-admin.cjs'
  Start-App 'admin' $node @($server,(Join-Path $root 'apps/admin/build/web'),'8080') @{} $server
  $deadline=[DateTime]::UtcNow.AddMinutes(3)
  do {
    if((Check-Ready "$apiUrl/health/ready" $true) -and (Check-Ready $webUrl) -and (Check-Ready $adminUrl)){break}
    if($records|Where-Object {-not(Test-Owned $_)}){throw "An app stopped early. Check logs in $localRoot."}
    Start-Sleep -Seconds 2
  } while([DateTime]::UtcNow -lt $deadline)
  if(-not(Check-Ready "$apiUrl/health/ready" $true)){throw 'API/database readiness failed. Review api.stdout.log.'}
  if(-not(Check-Ready $webUrl) -or -not(Check-Ready $adminUrl)){throw 'A browser app did not become ready.'}
} catch {Stop-Apps;throw}
Write-Host "Ready. Storefront: $webUrl    Admin: $adminUrl" -ForegroundColor Green
Write-Host "Local login: $($secrets.adminEmail). Password is in $secretsFile" -ForegroundColor Cyan
Write-Host 'Use -Action status, stop or restart. Database survives stops and upgrades.'
if(-not $NoBrowser){Start-Process $webUrl;Start-Process $adminUrl}
