# Windows PowerShell 5.1 compatible, so a fresh Windows PC can bootstrap PowerShell 7.
param()
$ErrorActionPreference='Stop'
function Refresh-Path {
  $env:PATH=[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')+';'+$env:PATH
}
function Ensure-Package([string]$id,[scriptblock]$available) {
  if(& $available){return}
  if(-not(Get-Command winget.exe -ErrorAction SilentlyContinue)){throw 'Install Microsoft App Installer (winget) from Microsoft Store, then run setup-local.cmd again.'}
  Write-Host "Installing $id from winget..."
  & winget.exe install --id $id --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity
  if($LASTEXITCODE -ne 0){throw "Installation failed: $id. Complete the installer and retry setup-local.cmd."}
  Refresh-Path
  if(-not(& $available)){throw "Installed $id but it is not available in this shell yet. Open setup-local.cmd again."}
}
Ensure-Package 'Microsoft.PowerShell' { (Get-Command pwsh.exe -ErrorAction SilentlyContinue) -or (Test-Path "$env:ProgramFiles/PowerShell/7/pwsh.exe") }
Ensure-Package 'Microsoft.DotNet.SDK.10' { $d=Get-Command dotnet.exe -ErrorAction SilentlyContinue; $d -and ((& $d.Source --list-sdks) -match '^10\.') }
Ensure-Package 'OpenJS.NodeJS.LTS' { $n=Get-Command node.exe -ErrorAction SilentlyContinue; $n -and ([int]((& $n.Source --version).TrimStart('v').Split('.')[0]) -ge 22) }
Ensure-Package 'Git.Git' {Get-Command git.exe -ErrorAction SilentlyContinue}
$flutter=Get-Command flutter -ErrorAction SilentlyContinue
$fallbacks=@("$env:USERPROFILE/develop/flutter/bin/flutter.bat","$env:LOCALAPPDATA/flutter/bin/flutter.bat","$env:LOCALAPPDATA/Mazeduneh/flutter/bin/flutter.bat")
if(-not $flutter -and -not($fallbacks | Where-Object {Test-Path $_})) {
  $sdk=Join-Path $env:LOCALAPPDATA 'Mazeduneh/flutter'
  if(Test-Path $sdk){throw "Incomplete Flutter directory: $sdk. Complete the SDK setup there before retrying."}
  Write-Host 'Installing the pinned Flutter SDK for the admin browser build...'
  & git.exe clone --depth 1 --branch 3.44.7 https://github.com/flutter/flutter.git $sdk
  if($LASTEXITCODE -ne 0){throw 'Flutter download failed. Check the Internet connection and retry.'}
  $previousPubHostedUrl=$env:PUB_HOSTED_URL
  $previousFlutterStorageUrl=$env:FLUTTER_STORAGE_BASE_URL
  try {
    # Preserve an explicitly configured storage mirror for regions where the
    # official Flutter artifact host is unavailable.
    if($env:MAZEDUNEH_PUB_HOSTED_URL){$env:PUB_HOSTED_URL=$env:MAZEDUNEH_PUB_HOSTED_URL}
    if($env:MAZEDUNEH_FLUTTER_STORAGE_BASE_URL){$env:FLUTTER_STORAGE_BASE_URL=$env:MAZEDUNEH_FLUTTER_STORAGE_BASE_URL}
    elseif(-not $env:FLUTTER_STORAGE_BASE_URL){$env:FLUTTER_STORAGE_BASE_URL='https://storage.googleapis.com'}
    $precacheReady=$false
    for($attempt=1;$attempt -le 3;$attempt++){
      & "$sdk/bin/flutter.bat" --no-version-check precache --web
      if($LASTEXITCODE -eq 0){$precacheReady=$true;break}
      if($attempt -lt 3){$delaySeconds=5*$attempt;Write-Warning "Flutter browser tools download failed. Retrying in $delaySeconds seconds...";Start-Sleep -Seconds $delaySeconds}
    }
    if(-not $precacheReady){throw 'Flutter browser tools download failed after 3 attempts. Check Internet access or set MAZEDUNEH_FLUTTER_STORAGE_BASE_URL to a reachable Flutter mirror.'}
  } finally {
    $env:PUB_HOSTED_URL=$previousPubHostedUrl
    $env:FLUTTER_STORAGE_BASE_URL=$previousFlutterStorageUrl
  }
}
Write-Host 'Local prerequisites are ready. No SQL Server or Docker installation is required.' -ForegroundColor Green
