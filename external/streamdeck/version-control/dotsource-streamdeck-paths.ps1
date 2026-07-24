. "$PSScriptRoot\streamdeck-vcs-paths.bro.ps1"

Get-ChildItem "$PSScriptRoot\streamdeck-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "streamdeck-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$SdeckOverrideMappings = Get-ChildItem "$PSScriptRoot\streamdeck-vcs-mappings*.json5" |
  Where-Object { $_.Name -ne "streamdeck-vcs-mappings.bro.json5" } |
  Select-Object -First 1

if ($SdeckOverrideMappings) {
  $script:SdeckMappingsPath = $SdeckOverrideMappings.FullName
}
