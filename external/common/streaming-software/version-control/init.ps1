if (-not $Global:RepoPath) {
  $Global:RepoPath = Find-RepoRoot
}

$Global:Ps1HelpersModulePath = "$RepoPath\external\common\helpers\ps1\helpers.psm1"
if (-not (Test-Path $Ps1HelpersModulePath)) {
  Get-PSCallStack | Out-String | Write-Host -ForegroundColor Red
  throw "PS1 helpers module not found at: $Ps1HelpersModulePath"
}

try {
  Import-Module $Ps1HelpersModulePath -Force -ErrorAction Stop
} catch {
  Write-Host "Failed to load PS1 helpers module: $($_.Exception.Message)" -ForegroundColor Red
  throw
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
