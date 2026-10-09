param(
  [ValidateSet('menu', 'all', 'storefront', 'storefront-preview', 'api', 'admin')]
  [string]$Component = 'menu',
  [switch]$Stop,
  [switch]$Status,
  [switch]$NoBrowser,
  [switch]$CurrentBranch
)

$ErrorActionPreference = 'Stop'
$SourceRoot = Split-Path -Parent $PSScriptRoot
$StateDirectory = Join-Path $SourceRoot '.local-dev'
$StateFile = Join-Path $StateDirectory 'processes.json'
$AdminPasswordFile = Join-Path $StateDirectory 'admin-password.txt'
$ApiUrl = 'http://127.0.0.1:5080'
$StorefrontUrl = 'http://127.0.0.1:3000'
$AdminUrl = 'http://127.0.0.1:8080'

function Get-GitText([string[]]$Arguments, [string]$WorkingDirectory = $SourceRoot) {
  $result = & git @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $result" }
  return ($result | Out-String).Trim()
}

function Get-RunRoot {
  if ($CurrentBranch) {
    return (Get-GitText @('rev-parse', '--show-toplevel'))
  }

  Get-GitText @('fetch', 'origin', 'main') | Out-Null
  $runDirectory = Join-Path $StateDirectory 'main-worktree'
  if (Test-Path (Join-Path $runDirectory '.git')) {
    $existingStatus = Get-GitText @('-C', $runDirectory, 'status', '--porcelain')
    if ($existingStatus) {
      throw "The managed main worktree has local changes. Review $runDirectory before running again; it was not changed."
    }
    $existingHead = Get-GitText @('-C', $runDirectory, 'rev-parse', 'HEAD')
    $latestMain = Get-GitText @('rev-parse', 'origin/main')
    if ($existingHead -ne $latestMain) {
      Get-GitText @('-C', $runDirectory, 'checkout', '--detach', $latestMain) | Out-Null
    }
  } else {
    New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
    Get-GitText @('worktree', 'add', '--detach', $runDirectory, 'origin/main') | Out-Null
  }
  return $runDirectory
}

function Read-ProcessState {
  if (-not (Test-Path $StateFile)) { return @() }
  try { return @(Get-Content $StateFile -Raw | ConvertFrom-Json) }
  catch { return @() }
}

function Test-OwnedProcess($service) {
  $process = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$service.processId)" -ErrorAction SilentlyContinue
  if ($null -eq $process) { return $false }
  if ([string]::IsNullOrWhiteSpace($service.commandFragment)) { return $false }
  $commandLine = ([string]$process.CommandLine).Replace('\', '/').ToLowerInvariant()
  $commandFragment = ([string]$service.commandFragment).Replace('\', '/').ToLowerInvariant()
  return $commandLine.Contains($commandFragment, [StringComparison]::Ordinal)
}

function Stop-LocalServices {
  foreach ($service in (Read-ProcessState)) {
    $processId = [int]$service.processId
    if (Test-OwnedProcess $service) {
      Write-Host "Stopping $($service.name) (PID $processId)..." -ForegroundColor Yellow
      & taskkill.exe /PID $processId /T /F 2>$null | Out-Null
    } elseif (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
      Write-Warning "Skipped $($service.name): PID $processId is no longer the launcher-owned command."
    }
  }
  Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
  Write-Host 'Local MAZEDUNEH services stopped.' -ForegroundColor Green
}

function Show-Status {
  $services = Read-ProcessState
  if ($services.Count -eq 0) {
    Write-Host 'No MAZEDUNEH local services are recorded as running.' -ForegroundColor Yellow
  } else {
    foreach ($service in $services) {
      $running = Test-OwnedProcess $service
      $state = if ($running) { 'running' } else { 'stopped' }
      Write-Host ("{0}: {1} (PID {2}) — {3}" -f $service.name, $service.url, $service.processId, $state)
      if (Test-Path $service.stderr) {
        $lastError = Get-Content $service.stderr -Tail 4 | Where-Object { $_.Trim() }
        if ($lastError) { $lastError | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow } }
      }
    }
  }
  Write-Host "Storefront: $StorefrontUrl"
  Write-Host "Admin:      $AdminUrl"
  Write-Host "API readiness: $ApiUrl/health/ready"
}

if ($Stop) { Stop-LocalServices; exit 0 }
if ($Status) { Show-Status; exit 0 }

function Show-LauncherMenu {
  Write-Host ''
  Write-Host 'MAZEDUNEH — Local development' -ForegroundColor Green
  Write-Host 'Choose what to start:' -ForegroundColor Cyan
  Write-Host '  1) Full system: PostgreSQL + API + Storefront + Admin'
  Write-Host '  2) Storefront with local API and PostgreSQL'
  Write-Host '  3) Admin with local API and PostgreSQL'
  Write-Host '  4) API + PostgreSQL'
  Write-Host '  5) Storefront preview (sample catalog, no Docker/API)'
  Write-Host '  6) Show service status'
  Write-Host '  7) Stop launcher-owned app processes'
  Write-Host '  8) Install or start Docker Desktop'
  Write-Host '  0) Exit'
}

function Start-OrExplainDocker {
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if (-not $docker) {
    Write-Host 'Docker CLI was not found. Full system, API, and Admin modes need Docker Desktop for PostgreSQL.' -ForegroundColor Yellow
    Write-Host 'Install Docker Desktop from https://www.docker.com/products/docker-desktop/ (or `winget install --id Docker.DockerDesktop --exact`), then reopen PowerShell.' -ForegroundColor Yellow
    Write-Host 'You can still choose Storefront preview to browse the sample catalog without Docker.' -ForegroundColor DarkGray
    return $false
  }

  try { & $docker.Source info --format '{{.ServerVersion}}' 2>$null | Out-Null }
  catch { }
  if ($LASTEXITCODE -ne 0) {
    $desktop = Join-Path $env:ProgramFiles 'Docker/Docker/Docker Desktop.exe'
    if (Test-Path $desktop) {
      Write-Host 'Starting Docker Desktop; waiting for its engine...' -ForegroundColor Cyan
      Start-Process -FilePath $desktop -WindowStyle Hidden
      $deadline = [DateTime]::UtcNow.AddMinutes(2)
      $engineReady = $false
      do {
        Start-Sleep -Seconds 3
        & $docker.Source info --format '{{.ServerVersion}}' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $engineReady = $true; break }
      } while ([DateTime]::UtcNow -lt $deadline)
      if (-not $engineReady) {
        Write-Host 'Docker Desktop is installed but its engine is not ready yet. Finish its first-run setup, wait for “Engine running”, then choose this option again.' -ForegroundColor Yellow
        return $false
      }
    } else {
      Write-Host 'Docker is installed but its engine is unavailable. Start Docker Desktop and wait for “Engine running”, then choose this option again.' -ForegroundColor Yellow
      Write-Host 'If Docker Desktop is not installed, use its official installer: https://www.docker.com/products/docker-desktop/' -ForegroundColor Yellow
    }
    return $false
  }
  & $docker.Source compose version 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'Docker is running, but the Compose plugin is unavailable. Install or update Docker Desktop from https://www.docker.com/products/docker-desktop/, then reopen PowerShell.' -ForegroundColor Yellow
    return $false
  }
  return $true
}

function Install-OrStartDocker {
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if ($docker) {
    $desktop = Join-Path $env:ProgramFiles 'Docker/Docker/Docker Desktop.exe'
    if (Test-Path $desktop) {
      [void](Start-OrExplainDocker)
      return
    }
    try { & $docker.Source info --format '{{.ServerVersion}}' 2>$null | Out-Null }
    catch { }
    if ($LASTEXITCODE -eq 0) {
      [void](Start-OrExplainDocker)
      return
    }
  }

  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if (-not $winget) {
    Write-Host 'Windows Package Manager (winget) is not available. Install Docker Desktop from https://www.docker.com/products/docker-desktop/, then rerun this launcher.' -ForegroundColor Yellow
    return
  }

  Write-Host 'Installing Docker Desktop from the official winget package. Windows may ask for Administrator approval; follow Docker Desktop first-run setup if prompted.' -ForegroundColor Cyan
  & $winget.Source install --id Docker.DockerDesktop --exact --source winget --accept-source-agreements --accept-package-agreements
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'Docker Desktop installation did not complete. Check the installer output above; if Windows requested a restart, restart before running this option again.' -ForegroundColor Yellow
    return
  }
  Write-Host 'Docker Desktop is installed. If the installer requested a restart, restart Windows. Then rerun this option and wait for “Engine running”.' -ForegroundColor Green
}

if ($Component -eq 'menu') {
  Show-LauncherMenu
  $choice = Read-Host 'Enter 0-8'
  switch ($choice.Trim()) {
    '1' { $Component = 'all' }
    '2' { $Component = 'storefront' }
    '3' { $Component = 'admin' }
    '4' { $Component = 'api' }
    '5' { $Component = 'storefront-preview' }
    '6' { Show-Status; exit 0 }
    '7' { Stop-LocalServices; exit 0 }
    '8' { Install-OrStartDocker; exit 0 }
    '0' { exit 0 }
    default { Write-Host 'Choose one of the listed numbers, then run the launcher again.' -ForegroundColor Yellow; exit 2 }
  }
}

function Assert-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' is not installed or not available in PATH."
  }
}

function New-LocalAdminPassword {
  $randomBytes = [byte[]]::new(24)
  [Security.Cryptography.RandomNumberGenerator]::Fill($randomBytes)
  return [Convert]::ToBase64String($randomBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Start-LocalService(
  [string]$Name,
  [string]$Executable,
  [string[]]$Arguments,
  [string]$WorkingDirectory,
  [hashtable]$Environment,
  [string]$Url,
  [string]$CommandFragment
) {
  $stdout = Join-Path $StateDirectory "$Name.stdout.log"
  $stderr = Join-Path $StateDirectory "$Name.stderr.log"
  Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue
  $quotedArguments = $Arguments | ForEach-Object {
    $argument = [string]$_
    if ($argument -match '[\s"]') { '"' + $argument.Replace('"', '\"') + '"' }
    else { $argument }
  }
  $process = Start-Process -FilePath $Executable -ArgumentList ($quotedArguments -join ' ') `
    -WorkingDirectory $WorkingDirectory -Environment $Environment `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr `
    -WindowStyle Hidden -PassThru
  return [pscustomobject]@{
    name = $Name; processId = $process.Id; url = $Url; stdout = $stdout; stderr = $stderr; commandFragment = $CommandFragment
  }
}

function Wait-ForUrl([string]$Name, [string]$Url, [int]$TimeoutSeconds = 180) {
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    $ownedService = Read-ProcessState | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if ($ownedService -and -not (Test-OwnedProcess $ownedService)) { break }
    try {
      $response = Invoke-WebRequest -Uri $Url -TimeoutSec 4 -SkipHttpErrorCheck
      if ($response.StatusCode -eq 200) {
        Write-Host "$Name is ready: $Url" -ForegroundColor Green
        return $true
      }
    } catch { }
    Start-Sleep -Seconds 2
  }
  Write-Host "$Name did not respond in time. Recent error log:" -ForegroundColor Red
  $log = Join-Path $StateDirectory "$Name.stderr.log"
  if (Test-Path $log) { Get-Content $log -Tail 25 | ForEach-Object { Write-Host $_ } }
  return $false
}

if ($PSVersionTable.PSVersion -lt [version]'7.4') {
  throw 'Run this script with PowerShell 7.4 or later (pwsh).'
}

function Assert-PortAvailable([int]$Port, [string]$ServiceName) {
  $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
  $available = $true
  try { $listener.Start() }
  catch {
    $available = $false
    Write-Host "$ServiceName needs local port $Port, but it is already in use. Stop that app, then run this launcher again." -ForegroundColor Yellow
  }
  finally { $listener.Stop() }
  return $available
}

$RunRoot = Get-RunRoot
$RunSha = Get-GitText @('-C', $RunRoot, 'rev-parse', 'HEAD')
Write-Host "Running source: $RunRoot" -ForegroundColor DarkCyan
Write-Host "Running SHA:    $RunSha" -ForegroundColor DarkCyan

$startApi = $Component -in @('all', 'api', 'admin', 'storefront')
$startStorefront = $Component -in @('all', 'storefront', 'storefront-preview')
$startAdmin = $Component -in @('all', 'admin')
$requiredCommands = @()
if ($startApi) { $requiredCommands += 'dotnet' }
if ($startStorefront) { $requiredCommands += @('node', 'npm') }
if ($startAdmin) { $requiredCommands += @('flutter', 'dart') }
if ($startApi) { $requiredCommands += 'docker' }
foreach ($commandName in $requiredCommands | Select-Object -Unique) {
  if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
    if ($commandName -eq 'docker') {
      [void](Start-OrExplainDocker)
      exit 2
    }
    Write-Host "Required tool '$commandName' was not found. Install the version listed in README.md and reopen PowerShell." -ForegroundColor Yellow
    exit 2
  }
}

$dotnetExecutable = $null
if ($startApi) {
  $machineDotnet = (Get-Command dotnet).Source
  $userDotnet = Join-Path $env:USERPROFILE '.dotnet/dotnet.exe'
  foreach ($candidate in @($userDotnet, $machineDotnet)) {
    if (-not (Test-Path $candidate)) { continue }
    $installedSdks = & $candidate --list-sdks 2>$null
    if ($installedSdks -match '^10\.') {
      $dotnetExecutable = $candidate
      break
    }
  }
  if (-not $dotnetExecutable) {
    throw 'The API targets .NET 10. Install the .NET 10 SDK, then run this launcher again. The admin app needs the API.'
  }
}

if (Read-ProcessState | Where-Object { Test-OwnedProcess $_ }) {
  Write-Host 'A local demo session is already running. Use ./scripts/dev.ps1 -Status or -Stop first.' -ForegroundColor Yellow
  Show-Status
  exit 1
}

if ($startApi -and -not (Assert-PortAvailable 5080 'API')) { exit 2 }
if ($startStorefront -and -not (Assert-PortAvailable 3000 'Storefront')) { exit 2 }
if ($startAdmin -and -not (Assert-PortAvailable 8080 'Admin')) { exit 2 }

New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null

if ($startApi) {
  if (-not (Start-OrExplainDocker)) { exit 2 }
  $composeFile = Join-Path $RunRoot 'compose.yaml'
  if (-not (Test-Path $composeFile)) { throw "compose.yaml is missing from $RunRoot." }
  Write-Host 'Starting the persistent local PostgreSQL service...' -ForegroundColor Cyan
  & docker compose -f $composeFile up -d postgres
  if ($LASTEXITCODE -ne 0) { throw 'Docker Compose could not start PostgreSQL. Start Docker Desktop, then rerun this command.' }
  $deadline = [DateTime]::UtcNow.AddSeconds(90)
  do {
    $databaseState = (& docker compose -f $composeFile ps --format json postgres 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue).Health
    if ($databaseState -eq 'healthy') { break }
    Start-Sleep -Seconds 2
  } while ([DateTime]::UtcNow -lt $deadline)
  if ($databaseState -ne 'healthy') { throw 'PostgreSQL did not become healthy within 90 seconds. Run docker compose ps from the run worktree for details.' }
}

if ($startStorefront) {
  $storefrontPath = Join-Path $RunRoot 'apps/storefront'
  Write-Host 'Synchronizing storefront dependencies with package-lock.json...' -ForegroundColor Cyan
  Push-Location $storefrontPath
  try { & npm ci --prefer-offline --no-audit --no-fund; if ($LASTEXITCODE -ne 0) { throw 'npm ci failed.' } }
  finally { Pop-Location }
}

if ($startAdmin) {
  $adminPath = Join-Path $RunRoot 'apps/admin'
  Write-Host 'Synchronizing admin dependencies with pubspec.lock...' -ForegroundColor Cyan
  Push-Location $adminPath
  try { & flutter pub get; if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' } }
  finally { Pop-Location }
}

if ($startApi -and (Test-Path $StateFile)) { Stop-LocalServices }

$services = [System.Collections.Generic.List[object]]::new()
$adminEmail = if ($env:MAZEDUNEH_LOCAL_ADMIN_EMAIL) { $env:MAZEDUNEH_LOCAL_ADMIN_EMAIL } else { 'admin@mazeduneh.local' }
$adminPassword = $null
if ($startApi) {
  if (-not (Test-Path $AdminPasswordFile)) {
    $adminPassword = New-LocalAdminPassword
    Set-Content -Path $AdminPasswordFile -Value $adminPassword -NoNewline -Encoding utf8NoBOM
  } else {
    $adminPassword = (Get-Content $AdminPasswordFile -Raw).Trim()
  }

  $passwordHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($adminPassword)))
  $signingBytes = [byte[]]::new(48)
  [Security.Cryptography.RandomNumberGenerator]::Fill($signingBytes)
  $signingKey = [Convert]::ToBase64String($signingBytes)
  $apiEnvironment = @{
    ASPNETCORE_ENVIRONMENT = 'Development'
    ASPNETCORE_URLS = $ApiUrl
    Admin__Email = $adminEmail
    Admin__PasswordHash = $passwordHash
    Admin__TokenSigningKey = $signingKey
    'Cors__AllowedOrigins__0' = 'http://127.0.0.1:3000'
    'Cors__AllowedOrigins__1' = 'http://localhost:3000'
    'Cors__AllowedOrigins__2' = 'http://127.0.0.1:8080'
    'Cors__AllowedOrigins__3' = 'http://localhost:8080'
    Payments__SandboxEnabled = 'true'
    ConnectionStrings__Catalog = 'Host=127.0.0.1;Port=5432;Database=mazeduneh;Username=mazeduneh;Password=mazeduneh_local_only'
  }
  $services.Add((Start-LocalService 'api' $dotnetExecutable @(
    'run', '--project', (Join-Path $RunRoot 'services/api/Mazeduneh.Api.csproj'), '--no-launch-profile', '--urls', $ApiUrl
  ) (Join-Path $RunRoot 'services/api') $apiEnvironment "$ApiUrl/health/ready" 'Mazeduneh.Api.csproj'))
}

if ($startStorefront) {
  $storefrontPath = Join-Path $RunRoot 'apps/storefront'
  $storefrontEnvironment = @{
    NEXT_PUBLIC_MAZEDUNEH_API_URL = $(if ($Component -eq 'storefront-preview') { '' } else { $ApiUrl })
    NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL = $(if ($Component -eq 'storefront-preview') { '' } else { $ApiUrl })
    NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE = $(if ($Component -eq 'storefront-preview') { 'true' } else { 'false' })
    NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL = $AdminUrl
    NEXT_PUBLIC_SITE_URL = $StorefrontUrl
  }
  $services.Add((Start-LocalService 'storefront' (Get-Command node).Source @(
    (Join-Path $storefrontPath 'node_modules/next/dist/bin/next'), 'dev', '--hostname', '127.0.0.1', '--port', '3000'
  ) $storefrontPath $storefrontEnvironment $StorefrontUrl 'next/dist/bin/next'))
}

if ($startAdmin) {
  $adminPath = Join-Path $RunRoot 'apps/admin'
  $flutterBin = Split-Path -Parent (Get-Command flutter).Source
  $dartExecutable = Join-Path $flutterBin 'cache/dart-sdk/bin/dart.exe'
  $flutterSnapshot = Join-Path $flutterBin 'cache/flutter_tools.snapshot'
  $adminEnvironment = @{ DART_SUPPRESS_ANALYTICS = 'true' }
  $services.Add((Start-LocalService 'admin' $dartExecutable @(
    '--disable-dart-dev', $flutterSnapshot, 'run', '-d', 'web-server', '--web-hostname', '127.0.0.1', '--web-port', '8080',
    '--target', 'lib/secure_main.dart', '--dart-define=MAZEDUNEH_API_BASE_URL=http://127.0.0.1:5080'
  ) $adminPath $adminEnvironment $AdminUrl 'flutter_tools.snapshot'))
}

$services | ConvertTo-Json | Set-Content -Path $StateFile -Encoding utf8NoBOM
Write-Host 'Starting the local demo. Services are bound to this computer only.' -ForegroundColor Cyan

$ready = $true
if ($startApi) { $ready = (Wait-ForUrl 'api' "$ApiUrl/health/ready") -and $ready }
if ($startStorefront) { $ready = (Wait-ForUrl 'storefront' $StorefrontUrl) -and $ready }
if ($startAdmin) { $ready = (Wait-ForUrl 'admin' $AdminUrl) -and $ready }

Write-Host ''
if ($startStorefront) { Write-Host "Storefront: $StorefrontUrl" -ForegroundColor Cyan }
if ($startAdmin) { Write-Host "Admin:      $AdminUrl" -ForegroundColor Cyan }
if ($startApi) {
  Write-Host "API readiness: $ApiUrl/health/ready" -ForegroundColor Cyan
  Write-Host "Admin login: $adminEmail" -ForegroundColor Yellow
  Write-Host "Admin password: $adminPassword" -ForegroundColor Yellow
  Write-Host 'This password is local-demo-only and is saved in the ignored .local-dev folder.' -ForegroundColor DarkGray
}
Write-Host 'Stop everything with: ./scripts/dev.ps1 -Stop' -ForegroundColor Gray
Write-Host 'Show status with:      ./scripts/dev.ps1 -Status' -ForegroundColor Gray

if ($startStorefront -and -not $NoBrowser) { Start-Process $StorefrontUrl }
if ($startAdmin -and -not $NoBrowser) { Start-Process $AdminUrl }
if (-not $ready) {
  Write-Host 'Startup did not pass readiness checks. Stopping only processes launched by this run.' -ForegroundColor Red
  Stop-LocalServices
  exit 1
}

