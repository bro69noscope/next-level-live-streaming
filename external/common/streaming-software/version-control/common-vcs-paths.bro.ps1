$script:PrettierPath = Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\prettier.cmd"
$script:repoPath = $env:STREAMING_REPO_PATH
$script:CommonMappingsPath = "$PSScriptRoot\common-vcs-mappings.bro.jsonc"
$script:HelpersModulePath = "$PSScriptRoot\helpers.psm1"
