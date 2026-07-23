$script:PrettierPath = Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\prettier.cmd"
$script:StreamDeckBasePath = Join-Path $env:APPDATA "Elgato\StreamDeck\ProfilesV3"
$script:MappingsPath = Join-Path $PSScriptRoot "streamdeck-vcs-mappings.bro.jsonc"
$script:CommonMappingsPath = Join-Path $PSScriptRoot `
  "..\..\common\streaming-software\version-control\common-vcs-mappings.bro.jsonc"

$script:HelpersModulePath = Join-Path $env:STREAMING_REPO_PATH `
  "external\common\streaming-software\version-control\helpers.psm1"

$script:PortsPath = Join-Path $env:STREAMING_REPO_PATH `
  "config\ports_generated.streamdeck.json"

$CommonUserMappings = Get-ChildItem (Join-Path (
    Split-Path $script:CommonMappingsPath) "common-vcs-mappings*.jsonc") |
  Where-Object { $_.Name -ne "common-vcs-mappings.bro.jsonc" } |
  Select-Object -First 1

if ($CommonUserMappings) {
  $script:CommonMappingsPath = $CommonUserMappings.FullName
}


$UserMappings = Get-ChildItem "$PSScriptRoot\streamdeck-vcs-mappings*.jsonc" |
  Where-Object { $_.Name -ne "streamdeck-vcs-mappings.bro.jsonc" } |
  Select-Object -First 1

if ($UserMappings) {
  $script:MappingsPath = $UserMappings.FullName
}
