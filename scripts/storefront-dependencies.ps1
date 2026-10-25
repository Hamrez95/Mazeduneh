function Get-StorefrontDependencyFingerprint([string]$StorefrontRoot) {
  $entries = foreach($name in @('package.json','package-lock.json')) {
    $file = Join-Path $StorefrontRoot $name
    "$name`0$((Get-FileHash -LiteralPath $file -Algorithm SHA256 -ErrorAction Stop).Hash)"
  }
  $bytes = [Text.Encoding]::UTF8.GetBytes(($entries -join "`n"))
  [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Test-StorefrontDependenciesCurrent([string]$StorefrontRoot, [string]$MarkerFile) {
  $installedFile = Join-Path $StorefrontRoot 'node_modules/next/package.json'
  if(-not(Test-Path -LiteralPath $MarkerFile -PathType Leaf) -or -not(Test-Path -LiteralPath $installedFile -PathType Leaf)){return $false}
  try {
    $expected = Get-StorefrontDependencyFingerprint $StorefrontRoot
    if((Get-Content -LiteralPath $MarkerFile -Raw).Trim() -cne $expected){return $false}
    $lock = Get-Content -LiteralPath (Join-Path $StorefrontRoot 'package-lock.json') -Raw | ConvertFrom-Json
    $installed = Get-Content -LiteralPath $installedFile -Raw | ConvertFrom-Json
    return $installed.version -and $installed.version -ceq $lock.packages.'node_modules/next'.version
  } catch {return $false}
}
