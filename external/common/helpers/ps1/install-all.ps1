$sourceRoot = $PSScriptRoot
$destRoot    = Join-Path (Split-Path $PROFILE) "Modules"
$markerFile  = "bro-pwsh-module.md"

$sourceModuleNames = (Get-ChildItem $sourceRoot -Directory).Name

# Remove any installed module carrying our marker that no longer has a
# matching source folder, so renames/deletions don't leave stale copies
Get-ChildItem $destRoot -Directory | Where-Object {
  (Test-Path (Join-Path $_.FullName $markerFile)) -and ($_.Name -notin $sourceModuleNames)
} | ForEach-Object {
  Write-Host "Removing stale module: $($_.Name)" -ForegroundColor Yellow
  Remove-Item $_.FullName -Recurse -Force
}

Get-ChildItem $sourceRoot -Directory | ForEach-Object {
  $moduleName = $_.Name
  $destDir    = Join-Path $destRoot $moduleName

  if (Test-Path $destDir) {
    Remove-Item $destDir -Recurse -Force
  }
  Copy-Item $_.FullName $destDir -Recurse -Force
  Write-Host "Installed $moduleName -> $destDir" -ForegroundColor Green
}
