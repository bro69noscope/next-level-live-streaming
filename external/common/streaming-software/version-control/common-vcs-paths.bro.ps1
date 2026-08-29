$script:PrettierPath = Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\prettier.cmd"
$script:RepoPath = $env:STREAMING_REPO_PATH
$script:CommonUserMappingsPath = "$PSScriptRoot\common-vcs-mappings.bro.json5"
$script:VcsHelpersModulePath = "$PSScriptRoot\vcs-helpers.psm1"
