param(
  [ValidateSet('all', 'storefront', 'api', 'admin')]
  [string]$Component = 'all',
  [switch]$Stop,
  [switch]$Status,
  [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$StateDirectory = Join-Path $Root '.local-dev'
$StateFile = Join-Path $StateDirectory 'processes.json'
$AdminPasswordFile = Join-Path $StateDirectory 'admin-password.txt'
$ApiUrl = 'http://127.0.0.1:5080'
$StorefrontUrl = 'http://127.0.0.1:3000'
$AdminUrl = 'http://127.0.0.1:8080'

function Read-ProcessState {
  if (-not (Test-Path $StateFile)) { return @() }
  try { return @(Get-Content $StateFile -Raw | ConvertFrom-Json) }
  catch { return @() }
}

function Stop-LocalServices {
  foreach ($service in (Read-ProcessState)) {
    $processId = [int]$service.processId
    if (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
      Write-Host "Stopping $($service.name) (PID $processId)..." -ForegroundColor Yellow
      & taskkill.exe /PID $processId /T /F 2>$null | Out-Null
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
      $running = [bool](Get-Process -Id ([int]$service.processId) -ErrorAction SilentlyContinue)
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
  Write-Host "API health: $ApiUrl/health"
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
  [string]$Url
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
    name = $Name; processId = $process.Id; url = $Url; stdout = $stdout; stderr = $stderr
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

$startApi = $Component -in @('all', 'api', 'admin', 'storefront')
$startStorefront = $Component -in @('all', 'storefront')
$startAdmin = $Component -in @('all', 'admin')
$requiredCommands = @()
if ($startApi) { $requiredCommands += 'dotnet' }
if ($startStorefront) { $requiredCommands += @('node', 'npm') }
if ($startAdmin) { $requiredCommands += @('flutter', 'dart') }
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

if (Read-ProcessState | Where-Object { Get-Process -Id ([int]$_.processId) -ErrorAction SilentlyContinue }) {
  Write-Host 'A local demo session is already running. Use ./scripts/dev.ps1 -Status or -Stop first.' -ForegroundColor Yellow
  Show-Status
  exit 1
}

New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null

if ($startStorefront) {
  $storefrontPath = Join-Path $Root 'apps/storefront'
  if (-not (Test-Path (Join-Path $storefrontPath 'node_modules/next/dist/bin/next'))) {
    Write-Host 'Installing storefront dependencies (first run only)...' -ForegroundColor Cyan
    Push-Location $storefrontPath
    try { & npm ci; if ($LASTEXITCODE -ne 0) { throw 'npm ci failed.' } }
    finally { Pop-Location }
  }
}

if ($startAdmin) {
  $adminPath = Join-Path $Root 'apps/admin'
  if (-not (Test-Path (Join-Path $adminPath '.dart_tool/package_config.json'))) {
    Write-Host 'Installing admin dependencies (first run only)...' -ForegroundColor Cyan
    Push-Location $adminPath
    try { & flutter pub get; if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' } }
    finally { Pop-Location }
  }
}

if ($startApi -and (Test-Path $StateFile)) { Stop-LocalServices }

$services = [System.Collections.Generic.List[object]]::new()
$adminEmail = 'Hamidrezapakpour95@gmail.com'
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
  }
  $services.Add((Start-LocalService 'api' $dotnetExecutable @(
    'run', '--project', (Join-Path $Root 'services/api/Mazeduneh.Api.csproj'), '--no-launch-profile', '--urls', $ApiUrl
  ) (Join-Path $Root 'services/api') $apiEnvironment "$ApiUrl/health"))
}

if ($startStorefront) {
  $storefrontPath = Join-Path $Root 'apps/storefront'
  $storefrontEnvironment = @{
    NEXT_PUBLIC_MAZEDUNEH_API_URL = $ApiUrl
    NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL = $ApiUrl
    NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE = 'false'
    NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL = $AdminUrl
    NEXT_PUBLIC_SITE_URL = $StorefrontUrl
  }
  $services.Add((Start-LocalService 'storefront' (Get-Command node).Source @(
    (Join-Path $storefrontPath 'node_modules/next/dist/bin/next'), 'dev', '--hostname', '127.0.0.1', '--port', '3000'
  ) $storefrontPath $storefrontEnvironment $StorefrontUrl))
}

if ($startAdmin) {
  $adminPath = Join-Path $Root 'apps/admin'
  $flutterBin = Split-Path -Parent (Get-Command flutter).Source
  $dartExecutable = Join-Path $flutterBin 'cache/dart-sdk/bin/dart.exe'
  $flutterSnapshot = Join-Path $flutterBin 'cache/flutter_tools.snapshot'
  $adminEnvironment = @{ DART_SUPPRESS_ANALYTICS = 'true' }
  $services.Add((Start-LocalService 'admin' $dartExecutable @(
    '--disable-dart-dev', $flutterSnapshot, 'run', '-d', 'web-server', '--web-hostname', '127.0.0.1', '--web-port', '8080',
    '--target', 'lib/main.dart', '--dart-define=MAZEDUNEH_API_BASE_URL=http://127.0.0.1:5080'
  ) $adminPath $adminEnvironment $AdminUrl))
}

$services | ConvertTo-Json | Set-Content -Path $StateFile -Encoding utf8NoBOM
Write-Host 'Starting the local demo. Services are bound to this computer only.' -ForegroundColor Cyan

$ready = $true
if ($startApi) { $ready = (Wait-ForUrl 'api' "$ApiUrl/health") -and $ready }
if ($startStorefront) { $ready = (Wait-ForUrl 'storefront' $StorefrontUrl) -and $ready }
if ($startAdmin) { $ready = (Wait-ForUrl 'admin' $AdminUrl) -and $ready }

Write-Host ''
if ($startStorefront) { Write-Host "Storefront: $StorefrontUrl" -ForegroundColor Cyan }
if ($startAdmin) { Write-Host "Admin:      $AdminUrl" -ForegroundColor Cyan }
if ($startApi) {
  Write-Host "API health: $ApiUrl/health" -ForegroundColor Cyan
  Write-Host "Admin login: $adminEmail" -ForegroundColor Yellow
  Write-Host "Admin password: $adminPassword" -ForegroundColor Yellow
  Write-Host 'This password is local-demo-only and is saved in the ignored .local-dev folder.' -ForegroundColor DarkGray
}
Write-Host 'Stop everything with: ./scripts/dev.ps1 -Stop' -ForegroundColor Gray
Write-Host 'Show status with:      ./scripts/dev.ps1 -Status' -ForegroundColor Gray

if ($startStorefront -and -not $NoBrowser) { Start-Process $StorefrontUrl }
if ($startAdmin -and -not $NoBrowser) { Start-Process $AdminUrl }
if (-not $ready) { exit 1 }
