. (Join-Path $env:STREAMING_REPO_PATH `
    "external\common\streaming-software\version-control\dotsource-common-paths.ps1")

$script:SbotMappingsPath = "$PSScriptRoot\streamerbot-vcs-mappings.bro.json5"

$Script:SbotProductionPath = Join-Path $env:MYFILES_PATH `
  "streaming-programs\streamerbot-portable-production\Streamer.bot"

$Script:SbotFtpPath = Join-Path $env:MYFILES_PATH `
  "streaming-programs\streamerbot-portable-ftp\Streamer.bot"

$script:SbotPortsPath = Join-Path $env:STREAMING_REPO_PATH `
  "config\ports_generated.streamerbot.json"

