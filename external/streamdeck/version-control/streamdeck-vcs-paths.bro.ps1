. (Join-Path $env:STREAMING_REPO_PATH `
    "external\common\streaming-software\version-control\dotsource-paths.ps1")

$script:SdeckBasePath = Join-Path $env:APPDATA "Elgato\StreamDeck\ProfilesV3"

$script:PortsPath = Join-Path $env:STREAMING_REPO_PATH `
  "config\ports_generated.streamdeck.json"

$script:SdeckMappingsPath = Join-Path $PSScriptRoot "streamdeck-vcs-mappings.bro.json5"

$SdeckOverrideMappings = Get-ChildItem "$PSScriptRoot\streamdeck-vcs-mappings*.json5" |
  Where-Object { $_.Name -ne "streamdeck-vcs-mappings.bro.json5" } |
  Select-Object -First 1

if ($SdeckOverrideMappings) {
  $script:SdeckMappingsPath = $SdeckOverrideMappings.FullName
}
