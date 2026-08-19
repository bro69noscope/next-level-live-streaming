. "$PSScriptRoot\common-vcs-paths.bro.ps1"
Import-Module "$repoPath\external\common\helpers\ps1\helpers.psm1"

Get-ChildItem "$PSScriptRoot\common-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "common-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$script:CommonOverrideMappings = Get-ChildItem (Join-Path (
    Split-Path $script:CommonMappingsPath) "common-vcs-mappings*.json5") |
  Where-Object { $_.Name -ne "common-vcs-mappings.bro.json5" } |
  Select-Object -First 1

if ($CommonOverrideMappings) {
  $script:CommonMappingsPath = $CommonOverrideMappings.FullName
}
