. "$PSScriptRoot\obs-vcs-paths.bro.ps1"

Get-ChildItem "$PSScriptRoot\obs-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "obs-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$ObsOverrideMappings = Get-ChildItem "$PSScriptRoot\obs-vcs-mappings*.jsonc" |
  Where-Object { $_.Name -ne "obs-vcs-mappings.bro.jsonc" } |
  Select-Object -First 1

if ($ObsOverrideMappings) {
  $script:ObsMappingsPath = $ObsOverrideMappings.FullName
}
