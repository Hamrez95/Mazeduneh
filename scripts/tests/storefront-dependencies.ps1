$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'storefront-dependencies.ps1')
$testParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $testParent ('mazeduneh-dependency-contract-' + [Guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'node_modules/next') -Force | Out-Null
  $marker = Join-Path $fixtureRoot 'dependencies.sha256'
  Set-Content -LiteralPath (Join-Path $fixtureRoot 'package.json') -Value '{"dependencies":{"next":"16.4.3"}}'
  Set-Content -LiteralPath (Join-Path $fixtureRoot 'package-lock.json') -Value '{"packages":{"node_modules/next":{"version":"16.4.3"}}}'
  Set-Content -LiteralPath (Join-Path $fixtureRoot 'node_modules/next/package.json') -Value '{"version":"16.2.11"}'
  if(Test-StorefrontDependenciesCurrent $fixtureRoot $marker){throw 'A missing marker must require installation.'}
  $original = Get-StorefrontDependencyFingerprint $fixtureRoot
  Set-Content -LiteralPath $marker -Value $original
  if(Test-StorefrontDependenciesCurrent $fixtureRoot $marker){throw 'An installed old Next version must not be accepted.'}
  Set-Content -LiteralPath (Join-Path $fixtureRoot 'node_modules/next/package.json') -Value '{"version":"16.4.3"}'
  if(-not(Test-StorefrontDependenciesCurrent $fixtureRoot $marker)){throw 'Matching installation must be reused.'}
  Add-Content -LiteralPath (Join-Path $fixtureRoot 'package-lock.json') -Value ' '
  if(Test-StorefrontDependenciesCurrent $fixtureRoot $marker){throw 'A changed dependency lock must require installation.'}
  if((Get-StorefrontDependencyFingerprint $fixtureRoot) -ceq $original){throw 'Lock edits must change the fingerprint.'}
  Write-Host 'PowerShell dependency cache: missing marker, stale installed version, reuse and changed lock passed.'
} finally {
  $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
  if(-not $resolvedFixture.StartsWith($testParent, [StringComparison]::OrdinalIgnoreCase) -or
    -not ([IO.Path]::GetFileName($resolvedFixture)).StartsWith('mazeduneh-dependency-contract-')) {throw 'Unexpected fixture cleanup path.'}
  if(Test-Path -LiteralPath $resolvedFixture){Remove-Item -LiteralPath $resolvedFixture -Recurse -Force}
}
