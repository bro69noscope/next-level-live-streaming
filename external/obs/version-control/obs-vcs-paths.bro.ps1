$script:PrettierPath = Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\prettier.cmd"
$script:ObsBasePath = Join-Path $env:APPDATA "obs-studio\basic\scenes"
$script:MappingsPath = Join-Path $PSScriptRoot "obs-vcs-mappings.bro.jsonc"

$UserMappings = Get-ChildItem "$PSScriptRoot\obs-vcs-mappings*.jsonc" |
  Where-Object { $_.Name -ne "obs-vcs-mappings.bro.jsonc" } |
  Select-Object -First 1

if ($UserMappings) {
  $script:MappingsPath = $UserMappings.FullName
}
