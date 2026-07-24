. "$PSScriptRoot\common-vcs-paths.bro.ps1"

Get-ChildItem "$PSScriptRoot\common-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "common-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$script:CommonMappingsPath = "$PSScriptRoot\common-vcs-mappings.bro.jsonc"

$script:CommonOverrideMappings = Get-ChildItem (Join-Path (
    Split-Path $script:CommonMappingsPath) "common-vcs-mappings*.jsonc") |
  Where-Object { $_.Name -ne "common-vcs-mappings.bro.jsonc" } |
  Select-Object -First 1

if ($CommonOverrideMappings) {
  $script:CommonMappingsPath = $CommonOverrideMappings.FullName
}
