$packagesDir = $PSScriptRoot
$destRoot    = Join-Path (Split-Path $PROFILE) "Modules"

Get-ChildItem $packagesDir -Directory | ForEach-Object {
  $moduleName = $_.Name
  $destDir    = Join-Path $destRoot $moduleName

  if (Test-Path $destDir) {
    Remove-Item $destDir -Recurse -Force
  }
  Copy-Item $_.FullName $destDir -Recurse -Force
  Write-Host "Installed $moduleName -> $destDir" -ForegroundColor Green
}
