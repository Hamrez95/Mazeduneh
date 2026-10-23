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
$rootKey=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($root).ToLowerInvariant()))).Substring(0,12).ToLowerInvariant()
$stateFile = Join-Path $localRoot "processes-$rootKey.json"
$adminBuildMarkerFile = Join-Path $localRoot "admin-build-$rootKey.sha256"
$portsFile = Join-Path $localRoot 'ports.json'
$secretsFile = Join-Path $localRoot 'credentials.json'
$pgRoot = Join-Path $runtime 'postgresql-17.11-5'
$pgBin = Join-Path $pgRoot 'pgsql/bin'
$pgData = Join-Path $localRoot 'postgres-data'
$apiPort = 5080
$webPort = 3000
$adminPort = 8080
$databasePort = 55432
if(Test-Path $portsFile) {
  try {
    $savedPorts=Get-Content $portsFile -Raw | ConvertFrom-Json
    if($savedPorts.api -ge 1024 -and $savedPorts.api -le 65535){$apiPort=[int]$savedPorts.api}
    if($savedPorts.storefront -ge 1024 -and $savedPorts.storefront -le 65535){$webPort=[int]$savedPorts.storefront}
    if($savedPorts.admin -ge 1024 -and $savedPorts.admin -le 65535){$adminPort=[int]$savedPorts.admin}
    if($savedPorts.postgres -ge 1024 -and $savedPorts.postgres -le 65535){$databasePort=[int]$savedPorts.postgres}
  } catch { Write-Warning 'Saved port settings could not be read; using defaults and checking what is available.' }
}
$apiUrl = "http://127.0.0.1:$apiPort"
$webUrl = "http://127.0.0.1:$webPort"
$adminUrl = "http://127.0.0.1:$adminPort"
# Prevent overlapping double-clicks from racing migrations/builds or process state.
$lockName='Local\Mazeduneh-'+[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($localRoot).ToLowerInvariant())))
$launchLock=[Threading.Mutex]::new($false,$lockName)
try {$locked=$launchLock.WaitOne(0)} catch [Threading.AbandonedMutexException] {$locked=$true}
if(-not $locked){$launchLock.Dispose();throw 'Another Mazeduneh startup/stop is still running. Wait for that window to finish.'}
try {
function Read-State { if(Test-Path $stateFile){ @(Get-Content $stateFile -Raw | ConvertFrom-Json) } else {@()} }
function Test-Owned($entry) {
  $p=Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$entry.pid)" -ErrorAction SilentlyContinue
  return $null -ne $p -and $entry.fragment -and ([string]$p.CommandLine).Contains([string]$entry.fragment,[StringComparison]::OrdinalIgnoreCase)
}
function Stop-Apps {
  foreach($entry in (Read-State)) {if(Test-Owned $entry){ & taskkill.exe /PID $entry.pid /T /F 2>$null | Out-Null }}
  $legacyState=Join-Path $localRoot 'processes.json'
  if(Test-Path $legacyState) {
    try {
      $legacyEntries=@(Get-Content $legacyState -Raw | ConvertFrom-Json)
      $sameRoot=$false
      foreach($entry in $legacyEntries) {
        $process=Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$entry.pid)" -ErrorAction SilentlyContinue
        if($process -and ([string]$process.CommandLine).Contains($root,[StringComparison]::OrdinalIgnoreCase)){$sameRoot=$true;break}
      }
      if($sameRoot) {foreach($entry in $legacyEntries){if(Test-Owned $entry){& taskkill.exe /PID $entry.pid /T /F 2>$null | Out-Null}}}
    } catch { Write-Warning 'Legacy process state could not be read; leaving those processes untouched.' }
  }
  Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
}
function Check-Ready([string]$url,[bool]$json=$false) {
  try { $r=Invoke-WebRequest $url -TimeoutSec 4 -SkipHttpErrorCheck
    if($r.StatusCode -ne 200){return $false}
    if($json){return $r.Headers['Content-Type'] -match 'application/json' -and ($r.Content|ConvertFrom-Json).status -eq 'ready'}
    return $true
  } catch {return $false}
}
function Get-AdminSourceFingerprint {
  $adminRoot = Join-Path $root 'apps/admin'
  $files = [Collections.Generic.List[string]]::new()
  foreach($relative in @('pubspec.yaml','pubspec.lock')) {
    $path = Join-Path $adminRoot $relative
    if(Test-Path $path -PathType Leaf){$files.Add($path)}
  }
  foreach($directory in @('lib','web','assets')) {
    $path = Join-Path $adminRoot $directory
    if(Test-Path $path -PathType Container) {
      Get-ChildItem -LiteralPath $path -File -Recurse | ForEach-Object {[void]$files.Add($_.FullName)}
    }
  }
  $entries = [Collections.Generic.List[string]]::new()
  foreach($file in ($files | Sort-Object)) {
    $relative = [IO.Path]::GetRelativePath($adminRoot,$file).Replace('\','/')
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    $entries.Add("$relative`0$hash")
  }
  $payload = [string]::Join("`n",$entries)
  return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($payload))).ToLowerInvariant()
}
function Test-PortAvailable([int]$port) {
  try {if(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction Stop){return $false}} catch {}
  $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$port)
  try {$listener.Start();return $true} catch {return $false} finally {$listener.Stop()}
}
function Test-PortProcessFromRoot([int]$port,[string]$fragment) {
  try {
    $connections=Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction Stop
    foreach($connection in $connections) {
      $processId=[int]$connection.OwningProcess
      for($depth=0;$depth -lt 5 -and $processId -gt 0;$depth++) {
        $process=Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
        if(-not $process){break}
        $processCommand=[string]$process.CommandLine
        $normalizedFragment=$fragment.Replace('/',[IO.Path]::DirectorySeparatorChar)
        if($processCommand.Contains($root,[StringComparison]::OrdinalIgnoreCase) -and $processCommand.Contains($normalizedFragment,[StringComparison]::OrdinalIgnoreCase)){return $true}
        $processId=[int]$process.ParentProcessId
      }
    }
  } catch {}
  return $false
}
function Find-ReadyRootPort([int]$preferred,[int]$count,[string]$fragment) {
  $listeningPorts=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -ge $preferred -and $_.LocalPort -lt [Math]::Min(65536,$preferred+$count) } | Select-Object -ExpandProperty LocalPort -Unique | Sort-Object)
  foreach($candidate in $listeningPorts) {
    if((Test-PortProcessFromRoot $candidate $fragment) -and (Check-Ready "http://127.0.0.1:$candidate")){return $candidate}
  }
  return 0
}
function Find-ReadyApiPort([int]$preferred,[int]$count) {
  $listeningPorts=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -ge $preferred -and $_.LocalPort -lt [Math]::Min(65536,$preferred+$count) } | Select-Object -ExpandProperty LocalPort -Unique | Sort-Object)
  foreach($candidate in $listeningPorts) {
    if(Check-Ready "http://127.0.0.1:$candidate/health/ready" $true){return $candidate}
  }
  return 0
}
function Find-AvailablePort([int]$preferred,[int]$count,[string]$service) {
  for($candidate=$preferred;$candidate -lt [Math]::Min(65536,$preferred+$count);$candidate++) {
    if(Test-PortAvailable $candidate){return $candidate}
  }
  throw "No free local port was found for $service in the range $preferred-$($preferred+$count-1). Close one of those services or retry."
}
function Save-Ports {
  @{api=$apiPort;storefront=$webPort;admin=$adminPort;postgres=$databasePort} | ConvertTo-Json | Set-Content -LiteralPath $portsFile -Encoding utf8NoBOM
}
function Save-DatabasePort {
  $saved=@{}
  if(Test-Path $portsFile){try{$saved=Get-Content $portsFile -Raw|ConvertFrom-Json -AsHashtable}catch{}}
  if(-not $saved){$saved=@{}}
  $saved.postgres=$databasePort
  $saved|ConvertTo-Json|Set-Content -LiteralPath $portsFile -Encoding utf8NoBOM
}
function Set-Urls {
  $script:apiUrl="http://127.0.0.1:$script:apiPort"
  $script:webUrl="http://127.0.0.1:$script:webPort"
  $script:adminUrl="http://127.0.0.1:$script:adminPort"
}
if($Action -eq 'status') {
  [pscustomobject]@{Storefront=(Check-Ready $webUrl);StorefrontUrl=$webUrl;Admin=(Check-Ready $adminUrl);AdminUrl=$adminUrl;ApiDatabase=(Check-Ready "$apiUrl/health/ready" $true);ApiUrl=$apiUrl;PostgresPort=$databasePort;Data=$localRoot}|Format-List
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
$adminSourceFingerprint = $null
$adminBuildCurrent = $false
if(-not $SkipBuild) {
  $adminSourceFingerprint = Get-AdminSourceFingerprint
  if(Test-Path $adminBuildMarkerFile) {
    try {$adminBuildCurrent = (Get-Content $adminBuildMarkerFile -Raw).Trim() -ceq $adminSourceFingerprint} catch {}
  }
}
if($Action -eq 'start') {
  $runningWebPort=Find-ReadyRootPort 3000 100 'apps/storefront'
  $runningAdminPort=Find-ReadyRootPort 8080 100 'serve-admin.cjs'
  $runningApiPort=Find-ReadyApiPort 5080 100
  if($runningWebPort -and $runningAdminPort -and $runningApiPort -and ($SkipBuild -or $adminBuildCurrent)) {
    $webPort=$runningWebPort;$adminPort=$runningAdminPort;$apiPort=$runningApiPort
    Set-Urls
    Save-Ports
    Write-Host "Mazeduneh is already healthy: $webUrl and $adminUrl"
    if(-not $NoBrowser){Start-Process $webUrl;Start-Process $adminUrl}
    exit
  }
  if($runningWebPort -and $runningAdminPort -and $runningApiPort -and -not $SkipBuild) {
    Write-Host 'The running apps are healthy, but the admin build is out of date. Rebuilding from the current source...' -ForegroundColor Cyan
  }
}
if((Check-Ready "$apiUrl/health/ready" $true) -and (Check-Ready $webUrl) -and (Check-Ready $adminUrl) -and (Test-PortProcessFromRoot $webPort 'apps/storefront') -and (Test-PortProcessFromRoot $adminPort 'serve-admin.cjs') -and ($SkipBuild -or $adminBuildCurrent)) {
  Write-Host "Mazeduneh is already healthy: $webUrl and $adminUrl"
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
$pubHostedUrls=[Collections.Generic.List[string]]::new()
if($env:MAZEDUNEH_PUB_HOSTED_URL){$pubHostedUrls.Add($env:MAZEDUNEH_PUB_HOSTED_URL)}
# This is the package source recorded in apps/admin/pubspec.lock. Do not inherit
# a machine-wide PUB_HOSTED_URL: it may point at a throttled mirror.
$pubHostedUrls.Add('https://mirror.sjtu.edu.cn/dart-pub/')
$pubHostedUrls.Add('https://pub.flutter-io.cn')
$pubHostedUrls.Add('https://pub.dev')
$flutterStorageUrl=if($env:MAZEDUNEH_FLUTTER_STORAGE_BASE_URL){$env:MAZEDUNEH_FLUTTER_STORAGE_BASE_URL}elseif($env:FLUTTER_STORAGE_BASE_URL){$env:FLUTTER_STORAGE_BASE_URL}else{'https://storage.googleapis.com'}
if(-not ((& $dotnet --list-sdks) -match '^10\.')){throw '.NET 10 SDK is required: winget install Microsoft.DotNet.SDK.10'}
$apiPort=Find-AvailablePort $apiPort 100 'API'
$webPort=Find-AvailablePort $webPort 100 'storefront'
$adminPort=Find-AvailablePort $adminPort 100 'admin panel'
Set-Urls
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
$databaseRunning=$LASTEXITCODE -eq 0
if($databaseRunning -and (Test-Path "$pgData/postmaster.opts")) {
  $postmasterOptions=Get-Content "$pgData/postmaster.opts" -Raw
  if($postmasterOptions -match '(?i)"-p"\s+"?(\d+)'){ $databasePort=[int]$Matches[1] }
}
if(-not $databaseRunning) {
  $databasePort=Find-AvailablePort $databasePort 100 'PostgreSQL'
  $pgStart=Start-Process -FilePath "$pgBin/pg_ctl.exe" -ArgumentList @('-D',('"'+$pgData+'"'),'-l',('"'+(Join-Path $localRoot 'postgres.log')+'"'),'-o',('"-h 127.0.0.1 -p '+$databasePort+'"'),'-w','start') -RedirectStandardOutput (Join-Path $localRoot 'postgres-start.stdout.log') -RedirectStandardError (Join-Path $localRoot 'postgres-start.stderr.log') -WindowStyle Hidden -PassThru
  # Start-Process -Wait waits for PostgreSQL descendants too, including the server.
  if(-not $pgStart.WaitForExit(60000)){throw 'PostgreSQL startup timed out. See postgres-start.stderr.log.'}
  if($pgStart.ExitCode -ne 0){throw 'PostgreSQL did not start. See postgres.log in the local data folder.'}
}
Save-DatabasePort
$previousPgPassword=$env:PGPASSWORD
try {
  $env:PGPASSWORD=$secrets.databasePassword
  $exists=& "$pgBin/psql.exe" -h 127.0.0.1 -p $databasePort -U mazeduneh -d postgres -tAc "select 1 from pg_database where datname='mazeduneh'"
  if($LASTEXITCODE -ne 0){throw 'Cannot authenticate to the local database.'}
  if($exists -ne '1'){& "$pgBin/createdb.exe" -h 127.0.0.1 -p $databasePort -U mazeduneh mazeduneh;if($LASTEXITCODE -ne 0){throw 'Cannot create the local database.'}}
} finally {$env:PGPASSWORD=$previousPgPassword}
$apiEnv=@{
  ASPNETCORE_ENVIRONMENT='Development';ASPNETCORE_URLS=$apiUrl
  Admin__Email=$secrets.adminEmail
  Admin__PasswordHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($secrets.adminPassword)))
  Admin__TokenSigningKey=$secrets.signingKey;Admin__Mfa__SensitiveActionsRequired='false'
  ConnectionStrings__Catalog="Host=127.0.0.1;Port=$databasePort;Database=mazeduneh;Username=mazeduneh;Password=$($secrets.databasePassword)"
  Payments__SandboxEnabled='true';'Cors__AllowedOrigins__0'=$webUrl;'Cors__AllowedOrigins__1'=$adminUrl
  Media__RootPath=(Join-Path $localRoot 'media')
}
if(-not [string]::IsNullOrWhiteSpace($env:MAZEDUNEH_GOOGLE_CLIENT_ID)){
  $apiEnv.Google__ClientId=$env:MAZEDUNEH_GOOGLE_CLIENT_ID.Trim()
}
$build=Join-Path $root '.local-dev/build/api'
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
  $previousPubHostedUrl=$env:PUB_HOSTED_URL
  $previousFlutterStorageUrl=$env:FLUTTER_STORAGE_BASE_URL
  try {
    # Ignore machine-wide Pub mirrors that may be unavailable or rate-limited.
    # These overrides are scoped to this startup process and can be customized
    # with MAZEDUNEH_PUB_HOSTED_URL / MAZEDUNEH_FLUTTER_STORAGE_BASE_URL.
    $env:FLUTTER_STORAGE_BASE_URL=$flutterStorageUrl
    if(-not(Test-Path .dart_tool/package_config.json)){
      $pubReady=$false
      foreach($pubHostedUrl in $pubHostedUrls){
        $env:PUB_HOSTED_URL=$pubHostedUrl
        for($attempt=1;$attempt -le 3;$attempt++){
          Write-Host "Resolving admin browser dependencies from $pubHostedUrl (attempt $attempt/3)..."
          & $flutter --no-version-check pub get
          if($LASTEXITCODE -eq 0){$pubReady=$true;break}
          if($attempt -lt 3){$delaySeconds=5*$attempt;Write-Warning "Flutter package download failed. Retrying in $delaySeconds seconds...";Start-Sleep -Seconds $delaySeconds}
        }
        if($pubReady){break}
      }
      if(-not $pubReady){throw 'Admin dependency setup failed using the configured Pub mirrors and pub.dev. Check Internet access or set MAZEDUNEH_PUB_HOSTED_URL to a reachable Pub mirror, then retry.'}
    }
    & $flutter --no-version-check build web --no-pub --release --no-web-resources-cdn --target lib/secure_main.dart "--dart-define=MAZEDUNEH_API_BASE_URL=$apiUrl"
    if($LASTEXITCODE -ne 0){throw 'Admin browser build failed.'}
    try {[IO.File]::WriteAllText($adminBuildMarkerFile,$adminSourceFingerprint,[Text.Encoding]::ASCII)} catch {Write-Warning 'The admin build succeeded, but its freshness marker could not be saved; the next start will rebuild it.'}
  } finally {
    $env:PUB_HOSTED_URL=$previousPubHostedUrl
    $env:FLUTTER_STORAGE_BASE_URL=$previousFlutterStorageUrl
    Pop-Location
  }
}
$dll=Join-Path $build 'Mazeduneh.Api.dll'
function Quote-Arg([string]$s){'"'+$s.Replace('"','\"')+'"'}
Run-WithEnv $dotnet @((Quote-Arg $dll),'--migrate','--seed-admin','--seed-demo') $apiEnv
$records=[Collections.Generic.List[object]]::new()
function Start-App([string]$name,[string]$exe,[string[]]$arguments,[hashtable]$environment,[string]$fragment) {
  $out=Join-Path $localRoot "$name.stdout.log";$err=Join-Path $localRoot "$name.stderr.log"
  $p=Start-Process -FilePath $exe -ArgumentList (($arguments|ForEach-Object {Quote-Arg $_}) -join ' ') -WorkingDirectory $root -Environment $environment -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden -PassThru
  $records.Add(@{name=$name;pid=$p.Id;fragment=$fragment;root=$root})
  ConvertTo-Json -InputObject @($records.ToArray()) | Set-Content $stateFile -Encoding utf8NoBOM
}
try {
  Start-App 'api' $dotnet @($dll) $apiEnv $dll
  $next=Join-Path $root 'apps/storefront/node_modules/next/dist/bin/next'
  Start-App 'storefront' $node @($next,'dev','--webpack','--hostname','127.0.0.1','--port',"$webPort", (Join-Path $root 'apps/storefront')) @{NEXT_PUBLIC_MAZEDUNEH_API_URL=$apiUrl;NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL=$apiUrl;NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE='false';NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL=$adminUrl;NEXT_PUBLIC_SITE_URL=$webUrl} $next
  $server=Join-Path $root 'scripts/serve-admin.cjs'
  Start-App 'admin' $node @($server,(Join-Path $root 'apps/admin/build/web'),"$adminPort") @{} $server
  $deadline=[DateTime]::UtcNow.AddMinutes(3)
  do {
    if((Check-Ready "$apiUrl/health/ready" $true) -and (Check-Ready $webUrl) -and (Check-Ready $adminUrl)){break}
    if($records|Where-Object {-not(Test-Owned $_)}){throw "An app stopped early. Check logs in $localRoot."}
    Start-Sleep -Seconds 2
  } while([DateTime]::UtcNow -lt $deadline)
  if(-not(Check-Ready "$apiUrl/health/ready" $true)){throw 'API/database readiness failed. Review api.stdout.log.'}
  if(-not(Check-Ready $webUrl) -or -not(Check-Ready $adminUrl)){throw 'A browser app did not become ready.'}
} catch {Stop-Apps;throw}
Save-Ports
Write-Host "Ready. Storefront: $webUrl    Admin: $adminUrl    API: $apiUrl/health/ready" -ForegroundColor Green
Write-Host "Local login: $($secrets.adminEmail). Password is in $secretsFile" -ForegroundColor Cyan
Write-Host 'Use -Action status, stop or restart. Database survives stops and upgrades.'
if(-not $NoBrowser){Start-Process $webUrl;Start-Process $adminUrl}
} finally {
  $launchLock.ReleaseMutex()
  $launchLock.Dispose()
}
