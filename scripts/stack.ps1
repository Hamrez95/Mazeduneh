param(
  [ValidateSet('start', 'status', 'stop')]
  [string]$Action = 'start',
  [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$ComposeFile = Join-Path $RepositoryRoot 'compose.yaml'
$LocalDirectory = Join-Path $RepositoryRoot '.local-dev'
$EnvironmentFile = Join-Path $LocalDirectory 'stack.env'
$AdminPasswordFile = Join-Path $LocalDirectory 'admin-password.txt'
$StorefrontUrl = 'http://127.0.0.1:3000'
$ApiUrl = 'http://127.0.0.1:5080'
$AdminUrl = 'http://127.0.0.1:8080'
$ProjectName = 'mazeduneh'

function Resolve-Docker {
  $command = Get-Command docker -CommandType Application -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }

  if ($IsWindows) {
    $candidates = @(@(
      (Join-Path $env:ProgramFiles 'Docker/Docker/resources/bin/docker.exe'),
      (Join-Path $env:LOCALAPPDATA 'Programs/DockerDesktop/resources/bin/docker.exe')
    ) | Where-Object { $_ -and (Test-Path $_) })
    if ($candidates.Count -gt 0) { return $candidates[0] }
  }

  throw 'Docker was not found. Install Docker Desktop (Windows/macOS) or Docker Engine (Linux), then rerun this command.'
}

function Invoke-Compose([string[]]$Arguments, [int]$TimeoutSeconds = 0) {
  $composeArguments = @('compose', '--project-name', $ProjectName, '--file', $ComposeFile)
  if (Test-Path $EnvironmentFile) { $composeArguments += @('--env-file', $EnvironmentFile) }
  $composeArguments += @('--profile', 'full')
  $composeArguments += $Arguments
  if ($TimeoutSeconds -le 0) {
    & $DockerExecutable @composeArguments
    return $LASTEXITCODE
  }

  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $DockerExecutable
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  foreach ($argument in $composeArguments) { [void]$startInfo.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::Start($startInfo)
  $stdout = $process.StandardOutput.ReadToEndAsync()
  $stderr = $process.StandardError.ReadToEndAsync()
  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    try { $process.Kill($true) } catch { }
    [void]$process.WaitForExit(2000)
    Write-Host "Docker Compose $($Arguments[0]) timed out after $TimeoutSeconds seconds." -ForegroundColor Yellow
    return 124
  }
  $process.WaitForExit()
  $output = ($stdout.Result + $stderr.Result).Trim()
  if ($output) { Write-Host $output }
  return $process.ExitCode
}

function New-LocalSecret([int]$ByteCount = 32) {
  $bytes = [byte[]]::new($ByteCount)
  [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-AvailableLoopbackPort([int]$FirstChoice) {
  for ($port = $FirstChoice; $port -lt ($FirstChoice + 100); $port++) {
    $listener = $null
    try {
      $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $port)
      $listener.Start()
      return $port
    } catch {
    } finally {
      if ($null -ne $listener) { $listener.Stop() }
    }
  }
  throw "No free local port was found between $FirstChoice and $($FirstChoice + 99)."
}

function Get-LocalSetting([string]$Name, [string]$DefaultValue) {
  $line = Get-Content $EnvironmentFile | Where-Object { $_.StartsWith("$Name=", [StringComparison]::Ordinal) } | Select-Object -First 1
  if ($line) { return $line.Substring($Name.Length + 1) }
  return $DefaultValue
}

function Ensure-LocalCredentials {
  New-Item -ItemType Directory -Path $LocalDirectory -Force | Out-Null

  if ((Test-Path $EnvironmentFile) -and -not (Test-Path $AdminPasswordFile)) {
    throw "The local stack credentials are incomplete. Restore $AdminPasswordFile from your local backup, or remove .local-dev/stack.env only after understanding that the existing local admin password may no longer match."
  }

  if (-not (Test-Path $EnvironmentFile)) {
    $adminEmail = if ($env:MAZEDUNEH_LOCAL_ADMIN_EMAIL) { $env:MAZEDUNEH_LOCAL_ADMIN_EMAIL.Trim() } else { 'admin@mazeduneh.local' }
    $adminPassword = New-LocalSecret 24
    $passwordHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($adminPassword)))
    $signingKey = New-LocalSecret 48
    $utf8WithoutBom = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($AdminPasswordFile, $adminPassword, $utf8WithoutBom)
    $lines = @(
      "MAZEDUNEH_ADMIN_EMAIL=$adminEmail",
      "MAZEDUNEH_ADMIN_PASSWORD_HASH=$passwordHash",
      "MAZEDUNEH_ADMIN_TOKEN_SIGNING_KEY=$signingKey",
      'MAZEDUNEH_DB_NAME=mazeduneh',
      'MAZEDUNEH_DB_USER=mazeduneh',
      'MAZEDUNEH_DB_PASSWORD=mazeduneh_local_only',
      "MAZEDUNEH_STOREFRONT_PORT=$(Get-AvailableLoopbackPort 3000)",
      "MAZEDUNEH_API_PORT=$(Get-AvailableLoopbackPort 5080)",
      "MAZEDUNEH_ADMIN_PORT=$(Get-AvailableLoopbackPort 8080)",
      "MAZEDUNEH_POSTGRES_PORT=$(Get-AvailableLoopbackPort 5432)"
    )
    [IO.File]::WriteAllLines($EnvironmentFile, $lines, $utf8WithoutBom)
    if (-not $IsWindows) {
      $chmod = Get-Command chmod -ErrorAction SilentlyContinue
      if ($chmod) { & $chmod.Source 600 $AdminPasswordFile $EnvironmentFile }
    }
    Write-Host 'Created local-only Admin credentials in the ignored .local-dev folder.' -ForegroundColor Green
  }

  $existingLines = @(Get-Content $EnvironmentFile)
  $portSettings = @(
    @{ Name = 'MAZEDUNEH_STOREFRONT_PORT'; Preferred = 3000 },
    @{ Name = 'MAZEDUNEH_API_PORT'; Preferred = 5080 },
    @{ Name = 'MAZEDUNEH_ADMIN_PORT'; Preferred = 8080 },
    @{ Name = 'MAZEDUNEH_POSTGRES_PORT'; Preferred = 5432 }
  )
  foreach ($setting in $portSettings) {
    if (-not ($existingLines | Where-Object { $_.StartsWith("$($setting.Name)=", [StringComparison]::Ordinal) })) {
      $existingLines += "$($setting.Name)=$(Get-AvailableLoopbackPort $setting.Preferred)"
    }
  }
  $utf8WithoutBom = [Text.UTF8Encoding]::new($false)
  [IO.File]::WriteAllLines($EnvironmentFile, $existingLines, $utf8WithoutBom)
  if (-not $IsWindows) {
    $chmod = Get-Command chmod -ErrorAction SilentlyContinue
    if ($chmod) { & $chmod.Source 600 $AdminPasswordFile $EnvironmentFile }
  }
  $script:StorefrontUrl = "http://127.0.0.1:$(Get-LocalSetting 'MAZEDUNEH_STOREFRONT_PORT' '3000')"
  $script:ApiUrl = "http://127.0.0.1:$(Get-LocalSetting 'MAZEDUNEH_API_PORT' '5080')"
  $script:AdminUrl = "http://127.0.0.1:$(Get-LocalSetting 'MAZEDUNEH_ADMIN_PORT' '8080')"
}

function Get-DockerFailureDetails([string]$DockerOutput) {
  Write-Host 'Docker is installed, but its engine did not become ready.' -ForegroundColor Yellow
  if (-not [string]::IsNullOrWhiteSpace($DockerOutput)) { Write-Host $DockerOutput -ForegroundColor DarkYellow }
  if ($DockerOutput -match 'Docker is using .+ containers') {
    Write-Host 'Switch Docker Desktop to Linux containers, then rerun this command.' -ForegroundColor Yellow
    return
  }

  if ($IsWindows) {
    $virtualization = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue |
      Where-Object { $null -ne $_.VirtualizationFirmwareEnabled } |
      Select-Object -First 1 -ExpandProperty VirtualizationFirmwareEnabled
    if ($virtualization -eq $false) {
      Write-Host 'This computer reports firmware virtualization as disabled. Enable Intel VT-x/Intel Virtualization Technology (or AMD-V/SVM) in BIOS/UEFI, then enable Windows Subsystem for Linux and Virtual Machine Platform and restart Windows.' -ForegroundColor Yellow
    } else {
      Write-Host 'On Windows, open Docker Desktop and wait for “Engine running”. If it reports a WSL problem, install/enable WSL 2 and Virtual Machine Platform, then restart Windows.' -ForegroundColor Yellow
    }

    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($wsl) {
      $wslStatus = ((& $wsl.Source --status 2>&1 | Out-String).Replace([string][char]0, '')).Trim()
      if ($wslStatus) { Write-Host "WSL status: $wslStatus" -ForegroundColor DarkYellow }
    }
  } else {
    Write-Host 'Start the Docker Engine service and rerun this command.' -ForegroundColor Yellow
  }
}

function Test-DockerEngine {
  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $DockerExecutable
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  [void]$startInfo.ArgumentList.Add('info')
  [void]$startInfo.ArgumentList.Add('--format')
  [void]$startInfo.ArgumentList.Add('{{.OSType}}')

  $process = [Diagnostics.Process]::Start($startInfo)
  $stdout = $process.StandardOutput.ReadToEndAsync()
  $stderr = $process.StandardError.ReadToEndAsync()
  if (-not $process.WaitForExit(8000)) {
    try { $process.Kill($true) } catch { }
    [void]$process.WaitForExit(2000)
    return [pscustomobject]@{ Ready = $false; Output = 'The Docker engine check timed out after 8 seconds.' }
  }
  $process.WaitForExit()
  if ($process.ExitCode -eq 0 -and $stdout.Result.Trim() -ne 'linux') {
    return [pscustomobject]@{ Ready = $false; Output = "Docker is using $($stdout.Result.Trim()) containers." }
  }
  return [pscustomobject]@{
    Ready = ($process.ExitCode -eq 0)
    Output = (($stdout.Result + $stderr.Result).Trim())
  }
}

function Ensure-DockerEngine {
  $check = Test-DockerEngine
  if ($check.Ready) { return $true }
  $output = $check.Output

  if ($IsWindows) {
    $virtualization = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue |
      Where-Object { $null -ne $_.VirtualizationFirmwareEnabled } |
      Select-Object -First 1 -ExpandProperty VirtualizationFirmwareEnabled
    if ($virtualization -eq $false) {
      Get-DockerFailureDetails $output
      return $false
    }

    $desktopCandidates = @(@(
      (Join-Path $env:ProgramFiles 'Docker/Docker/Docker Desktop.exe'),
      (Join-Path $env:LOCALAPPDATA 'Programs/DockerDesktop/Docker Desktop.exe')
    ) | Where-Object { $_ -and (Test-Path $_) })
    if ($desktopCandidates.Count -gt 0) {
      Write-Host 'Opening Docker Desktop and waiting up to 90 seconds for its engine...' -ForegroundColor Cyan
      Start-Process -FilePath $desktopCandidates[0] -WindowStyle Hidden
      $deadline = [DateTime]::UtcNow.AddSeconds(90)
      do {
        Start-Sleep -Seconds 3
        $check = Test-DockerEngine
        if ($check.Ready) { return $true }
        $output = $check.Output
      } while ([DateTime]::UtcNow -lt $deadline)
    }
  }

  Get-DockerFailureDetails ($output | Out-String)
  return $false
}

function Wait-ForEndpoint([string]$Name, [string]$Url, [int]$TimeoutSeconds = 180) {
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    try {
      $response = Invoke-WebRequest -Uri $Url -TimeoutSec 4 -UseBasicParsing
      if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
        Write-Host "$Name is ready: $Url" -ForegroundColor Green
        return $true
      }
    } catch { }
    Start-Sleep -Seconds 3
  } while ([DateTime]::UtcNow -lt $deadline)

  Write-Host "$Name did not become ready at $Url within $TimeoutSeconds seconds." -ForegroundColor Red
  return $false
}

function Open-LocalUrl([string]$Url) {
  if ($NoBrowser) { return }
  if ($IsWindows) { Start-Process $Url; return }
  if ($IsMacOS) { Start-Process open -ArgumentList $Url; return }
  $browser = Get-Command xdg-open -ErrorAction SilentlyContinue
  if ($browser) { Start-Process -FilePath $browser.Source -ArgumentList $Url }
}

try { $DockerExecutable = Resolve-Docker }
catch {
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit 2
}

if ($Action -eq 'status') {
  $engine = Test-DockerEngine
  if (-not $engine.Ready) { Get-DockerFailureDetails $engine.Output; exit 2 }
  $exitCode = Invoke-Compose @('ps') 12
  exit $exitCode
}

if ($Action -eq 'stop') {
  $engine = Test-DockerEngine
  if (-not $engine.Ready) { Get-DockerFailureDetails $engine.Output; exit 2 }
  Write-Host 'Stopping the app containers. PostgreSQL and uploaded media volumes will be preserved.' -ForegroundColor Cyan
  $exitCode = Invoke-Compose @('down') 45
  exit $exitCode
}

Ensure-LocalCredentials
Write-Host 'Checking Docker Engine...' -ForegroundColor Cyan
if (-not (Ensure-DockerEngine)) { exit 2 }

& $DockerExecutable compose version | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'Docker Compose is unavailable. Update or reinstall Docker Desktop / Docker Compose, then rerun.' -ForegroundColor Red
  exit 2
}

Write-Host 'Building and starting PostgreSQL, API, Storefront, and Admin...' -ForegroundColor Cyan
$exitCode = Invoke-Compose @('up', '--detach', '--build')
if ($exitCode -ne 0) {
  Write-Host 'The stack did not start. Recent container logs:' -ForegroundColor Red
  [void](Invoke-Compose @('logs', '--tail', '80'))
  exit $exitCode
}

$apiReady = Wait-ForEndpoint 'API' "$ApiUrl/health/ready"
$storefrontReady = Wait-ForEndpoint 'Storefront' $StorefrontUrl
$adminReady = Wait-ForEndpoint 'Admin' "$AdminUrl/health"

Write-Host ''
Write-Host "Storefront: $StorefrontUrl"
Write-Host "Admin:      $AdminUrl"
Write-Host "API:        $ApiUrl"
Write-Host "Admin login: $((Get-Content $EnvironmentFile | Where-Object { $_ -like 'MAZEDUNEH_ADMIN_EMAIL=*' }) -replace '^MAZEDUNEH_ADMIN_EMAIL=', '')"
Write-Host "Admin password: $((Get-Content $AdminPasswordFile -Raw).Trim())" -ForegroundColor Yellow
Write-Host 'Stop while preserving local data: pwsh -File ./scripts/stack.ps1 -Action stop' -ForegroundColor Gray
Write-Host 'Show status:                       pwsh -File ./scripts/stack.ps1 -Action status' -ForegroundColor Gray

if ($apiReady -and $storefrontReady -and $adminReady) {
  Open-LocalUrl $StorefrontUrl
  Open-LocalUrl $AdminUrl
} else {
  Write-Host 'Some apps are still unavailable. Their recent logs are shown below.' -ForegroundColor Yellow
  [void](Invoke-Compose @('logs', '--tail', '80'))
  exit 1
}
