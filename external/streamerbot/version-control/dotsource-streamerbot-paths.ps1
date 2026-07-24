. "$PSScriptRoot\streamerbot-vcs-paths.bro.ps1"

Get-ChildItem "$PSScriptRoot\streamerbot-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "streamerbot-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$SbotOverrideMappings = Get-ChildItem "$PSScriptRoot\streamerbot-vcs-mappings*.json5" |
  Where-Object { $_.Name -ne "streamerbot-vcs-mappings.bro.json5" } |
  Select-Object -First 1

if ($SbotOverrideMappings) {
  $script:SbotMappingsPath = $SbotOverrideMappings.FullName
}
