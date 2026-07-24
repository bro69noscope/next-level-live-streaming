. (Join-Path $env:STREAMING_REPO_PATH `
    "external\common\streaming-software\version-control\dotsource-paths.ps1")

$script:ObsProductionPath = Join-Path $env:APPDATA "obs-studio\"

$script:ObsVcamPath = Join-Path $env:MYFILES_PATH `
  "streaming-programs\obs-studio-portable-vcam\obs-studio\config\obs-studio"

$script:ObsFtpPath = Join-Path $env:MYFILES_PATH `
  "streaming-programs\obs-studio-portable-ftp\obs-studio\config\obs-studio"

$script:ObsPortsPath = Join-Path $env:STREAMING_REPO_PATH `
  "\config\ports_generated.obs.json"

$script:ObsMappingsPath = Join-Path $PSScriptRoot "obs-vcs-mappings.bro.jsonc"

$ObsOverrideMappings = Get-ChildItem "$PSScriptRoot\obs-vcs-mappings*.jsonc" |
  Where-Object { $_.Name -ne "obs-vcs-mappings.bro.jsonc" } |
  Select-Object -First 1

if ($ObsOverrideMappings) {
  $script:ObsMappingsPath = $ObsOverrideMappings.FullName
}
