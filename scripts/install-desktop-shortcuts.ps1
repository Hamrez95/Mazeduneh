param([string]$LocalHome=$env:MAZEDUNEH_LOCAL_HOME,[string]$RuntimeHome=$env:MAZEDUNEH_RUNTIME_HOME)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$shell=New-Object -ComObject WScript.Shell
$desktop=[Environment]::GetFolderPath('Desktop')
$pwsh=(Get-Process -Id $PID).Path
if($PSVersionTable.PSVersion.Major -lt 7){throw 'Run this installer in PowerShell 7.4+.'}
foreach($action in @('start','stop','status')) {
  $link=$shell.CreateShortcut((Join-Path $desktop "Mazeduneh $action.lnk"))
  $link.TargetPath=$pwsh
  $link.WorkingDirectory=$root
  $link.Arguments="-NoLogo -NoProfile -NoExit -ExecutionPolicy Bypass -File `"$PSScriptRoot/local.ps1`" -Action $action"
  if($LocalHome){$link.Arguments+=" -LocalHome `"$LocalHome`""}
  if($RuntimeHome){$link.Arguments+=" -RuntimeHome `"$RuntimeHome`""}
  $link.Description="Mazeduneh browser apps: $action"
  $link.Save()
}
Write-Host 'Mazeduneh start, stop and status shortcuts are ready on your desktop.'
