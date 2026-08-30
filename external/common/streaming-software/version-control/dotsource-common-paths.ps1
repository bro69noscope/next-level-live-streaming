$script:CommonVcsPaths = "$PSScriptRoot\common-vcs-paths.bro.ps1"

$Script:CommonVcsPathsOverride = Get-ChildItem "$PSScriptRoot\common-vcs-paths.*.ps1" |
  Where-Object { $_.Name -ne "common-vcs-paths.bro.ps1" } |
  Select-Object -First 1

if ($CommonVcsPathsOverride) {
  $CommonVcsPaths = $CommonVcsPathsOverride.FullName
}

if (-not (Test-Path $CommonVcsPaths)) {
  Write-ThrowContext
  throw "Common VCS paths file not found at: $CommonVcsPaths"
}

. $CommonVcsPaths

$script:CommonUserMappingsPath = "$PSScriptRoot\common-vcs-mappings.bro.json5"

$script:CommonUserMappingsOverride = Get-ChildItem (Join-Path (
    Split-Path $CommonUserMappingsPath) "common-vcs-mappings*.json5") |
  Where-Object { $_.Name -ne "common-vcs-mappings.bro.json5" } |
  Select-Object -First 1

if ($CommonUserMappingsOverride) {
  $CommonUserMappingsPath = $CommonUserMappingsOverride.FullName
}
