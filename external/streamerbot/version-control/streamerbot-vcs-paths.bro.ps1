. (Join-Path $env:STREAMING_REPO_PATH `
    "external\common\streaming-software\version-control\dotsource-paths.ps1")

$script:SbotMappingsPath = "$PSScriptRoot\streamerbot-vcs-mappings.bro.json5"

$Script:SbotProductionPath = Join-Path $env:MYFILES_PATH `
  "streaming-programs\streamerbot-portable-production\Streamer.bot"

$Script:SbotFtpPath = Join-Path $env:MYFILES_PATH `
  "streaming-programs\streamerbot-portable-ftp\Streamer.bot"

$script:SbotPortsPath = Join-Path $env:STREAMING_REPO_PATH `
  "config\ports_generated.streamerbot.json"

$SbotOverrideMappings = Get-ChildItem "$PSScriptRoot\streamerbot-vcs-mappings*.json5" |
  Where-Object { $_.Name -ne "streamerbot-vcs-mappings.bro.json5" } |
  Select-Object -First 1

if ($SbotOverrideMappings) {
  $script:SbotMappingsPath = $SbotOverrideMappings.FullName
}

