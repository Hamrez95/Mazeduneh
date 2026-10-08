param(
  [ValidateSet('all', 'storefront', 'api', 'admin')]
  [string]$Component = 'all',
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
  return $process.CommandLine -like "*$($service.commandFragment)*"
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
    try {
      $response = Invoke-WebRequest -Uri $Url -TimeoutSec 4 -SkipHttpErrorCheck
      if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
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

$RunRoot = Get-RunRoot
$RunSha = Get-GitText @('-C', $RunRoot, 'rev-parse', 'HEAD')
Write-Host "Running source: $RunRoot" -ForegroundColor DarkCyan
Write-Host "Running SHA:    $RunSha" -ForegroundColor DarkCyan

$startApi = $Component -in @('all', 'api', 'admin', 'storefront')
$startStorefront = $Component -in @('all', 'storefront')
$startAdmin = $Component -in @('all', 'admin')
$requiredCommands = @()
if ($startApi) { $requiredCommands += 'dotnet' }
if ($startStorefront) { $requiredCommands += @('node', 'npm') }
if ($startAdmin) { $requiredCommands += @('flutter', 'dart') }
if ($startApi) { $requiredCommands += 'docker' }
foreach ($commandName in $requiredCommands | Select-Object -Unique) { Assert-Command $commandName }

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

New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null

if ($startApi) {
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
    NEXT_PUBLIC_MAZEDUNEH_API_URL = $ApiUrl
    NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL = $ApiUrl
    NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE = 'false'
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
if (-not $ready) { exit 1 }

