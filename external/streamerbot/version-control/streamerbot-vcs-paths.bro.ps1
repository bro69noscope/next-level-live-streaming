$script:PrettierPath = Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\prettier.cmd"
$script:StreamerbotBasePath = Join-Path $env:MYFILES_PATH "programs\Streamer.bot\data"
$script:MappingsPath = Join-Path $PSScriptRoot "streamerbot-vcs-mappings.bro.jsonc"

$UserMappings = Get-ChildItem "$PSScriptRoot\streamerbot-vcs-mappings*.jsonc" |
  Where-Object { $_.Name -ne "streamerbot-vcs-mappings.bro.jsonc" } |
  Select-Object -First 1

if ($UserMappings) {
  $script:MappingsPath = $UserMappings.FullName
}

