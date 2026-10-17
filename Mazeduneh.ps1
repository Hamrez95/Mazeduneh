param(
  [ValidateSet('start','restart','status','stop')][string]$Action = 'start',
  [switch]$NoBrowser,
  [switch]$SkipBuild,
  [string]$LocalHome = $env:MAZEDUNEH_LOCAL_HOME,
  [string]$RuntimeHome = $env:MAZEDUNEH_RUNTIME_HOME
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath
$bootstrap = Join-Path $root 'scripts/setup-local.ps1'
$launcher = Join-Path $root 'scripts/local.ps1'

$localArgs = @{ Action = $Action }
if ($NoBrowser) { $localArgs.NoBrowser = $true }
if ($SkipBuild) { $localArgs.SkipBuild = $true }
if ($LocalHome) { $localArgs.LocalHome = $LocalHome }
if ($RuntimeHome) { $localArgs.RuntimeHome = $RuntimeHome }

if ($Action -in @('start', 'restart')) {
  Write-Host 'Checking Windows prerequisites...'
  & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $bootstrap
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($PSVersionTable.PSVersion -lt [version]'7.4') {
  $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
  if ($pwsh) { $pwshPath = $pwsh.Source }
  else {
    $pwshPath = "$env:ProgramFiles/PowerShell/7/pwsh.exe"
    if (-not (Test-Path $pwshPath)) { $pwshPath = "$env:LOCALAPPDATA/Programs/PowerShell/7/pwsh.exe" }
  }
  if (-not (Test-Path $pwshPath)) { throw 'PowerShell 7.4+ was installed but could not be found. Run Mazeduneh.ps1 again.' }
  & $pwshPath -NoLogo -NoProfile -ExecutionPolicy Bypass -File $launcher @localArgs
  exit $LASTEXITCODE
}

& $launcher @localArgs
exit $LASTEXITCODE
