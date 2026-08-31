if (-not $Global:RepoPath) {
  $Global:RepoPath = Find-RepoRoot -StartPath $PSScriptRoot
}

$Script:VcsHelpersModulePath = "$PSScriptRoot\vcs-helpers.psm1"
if (-not (Test-Path $VcsHelpersModulePath)) {
  Write-ThrowContext
  throw "VCS helpers module not found at: $VcsHelpersModulePath"
}

try {
  Import-Module $VcsHelpersModulePath -Force -ErrorAction Stop
} catch {
  Write-Host "Failed to load VCS helpers module: $($_.Exception.Message)" -ForegroundColor Red
  throw
}
