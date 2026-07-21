$script:PrettierPath = Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\prettier.cmd"
$script:MappingsPath = Join-Path $PSScriptRoot "streamerbot-vcs-mappings.bro.jsonc"
$script:CommonMappingsPath = Join-Path $PSScriptRoot `
  "..\..\common\streaming-software\version-control\common-vcs-mappings.bro.jsonc"

$script:HelpersModulePath = Join-Path $env:STREAMING_REPO_PATH `
  "external\common\streaming-software\version-control\helpers.psm1"

$script:PortsPath = Join-Path $env:STREAMING_REPO_PATH "config\ports.json5"

$script:StreamerbotBasePaths = @(
  Join-Path $env:MYFILES_PATH `
    "streaming-programs\streamerbot-portable-production"

  Join-Path $env:MYFILES_PATH `
    "streaming-programs\streamerbot-portable-ftp"
)

$CommonUserMappings = Get-ChildItem (Join-Path (
    Split-Path $script:CommonMappingsPath) "common-vcs-mappings*.jsonc") |
  Where-Object { $_.Name -ne "common-vcs-mappings.bro.jsonc" } |
  Select-Object -First 1

if ($CommonUserMappings) {
  $script:CommonMappingsPath = $CommonUserMappings.FullName
}

$UserMappings = Get-ChildItem "$PSScriptRoot\streamerbot-vcs-mappings*.jsonc" |
  Where-Object { $_.Name -ne "streamerbot-vcs-mappings.bro.jsonc" } |
  Select-Object -First 1

if ($UserMappings) {
  $script:MappingsPath = $UserMappings.FullName
}

