# Used to create an editable template from an OBS "scenes.json" file

$script:DataPath = $env:STREAMING_DATA_PATH
$script:RepoPath = $env:STREAMING_REPO_PATH
$script:PrettierPath = Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\prettier.cmd"


# Validate environment setup
if (-not $script:RepoPath) {
  throw "STREAMING_REPO_PATH environment variable is not set. Please set it
    before running this script."
}

if (-not (Test-Path -Path $script:RepoPath -PathType Container)) {
  throw "STREAMING_REPO_PATH points to a directory that does not exist: $script:RepoPath"
}

if (-not $script:DataPath) {
  throw "Warning: STREAMING_DATA_PATH environment variable is not set. Please
    set it before running this script."
}

if (-not (Test-Path -Path $script:DataPath -PathType Container)) {
  throw "STREAMING_DATA_PATH points to a directory that does not exist: $script:DataPath"
}

# Normalize paths to use forward slashes and trim trailing slashes
$script:DataPath = if ($script:DataPath) {
  ($script:DataPath -replace '\\', '/').TrimEnd('/')
} else {
  $null
}

$script:RepoPath = if ($script:RepoPath) {
  ($script:RepoPath -replace '\\', '/').TrimEnd('/')
} else {
  $null
}

$script:DefaultVcsPath = "external/obs/version-control/scenes"
$script:ObsBasePath = Join-Path $env:APPDATA "obs-studio\basic\scenes"

function Format-JsonWithPrettier {
  param([string]$FilePath)

  if (-not (Test-Path $script:PrettierPath)) {
    Write-Host "Warning: Prettier not found at $script:PrettierPath.
    Skipping formatting." -ForegroundColor Yellow
    return
  }

  Write-Host "Formatting with Prettier..." -ForegroundColor Cyan
  & $script:PrettierPath --write $FilePath
}

function ConvertTo-ObsTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [Parameter(Mandatory=$false)]
    [string]$VcsRelativePath = $script:DefaultVcsPath
  )
  $InputFile = (Resolve-Path $InputFile).Path
  $inputFileName = Split-Path $InputFile -Leaf
  $inputDirectory = Split-Path $InputFile -Parent
  $expectedPath = $script:ObsBasePath

  if ($inputDirectory -ne $expectedPath) {
    throw "This function must target files in: $expectedPath`nCurrent target: $inputDirectory"
  }
  if ($InputFile -notmatch '\.json$') {
    throw "Input file must be a .json file, got: $inputFileName"
  }

  $templateFileName = $inputFileName -replace "\.json$", ".vcs-template.json"
  Write-Host "Creating template from real config..." -ForegroundColor Green
  Write-Host "Input:  $InputFile"

  # Setup paths
  $vcsFullPath = Join-Path ($script:RepoPath -replace '/', '\') $VcsRelativePath
  $vcsTemplatePath = Join-Path $vcsFullPath $templateFileName

  Write-Host "Output: $vcsTemplatePath"

  # Ensure the VCS directory exists
  if (-not (Test-Path $vcsFullPath)) {
    New-Item -ItemType Directory -Path $vcsFullPath -Force | Out-Null
    Write-Host "Created VCS directory: $vcsFullPath" -ForegroundColor Cyan
  }

  # CREATE BACKUP FIRST
  $backupFileName = $inputFileName -replace "\.json$", ".backup.json"
  $backupPath = Join-Path $vcsFullPath $backupFileName
  Copy-Item $InputFile $backupPath -Force
  Write-Host "Backup saved: $backupPath" -ForegroundColor Magenta

  # Remove existing symlink before reading/writing anything
  $symlinkPath = Join-Path $inputDirectory $templateFileName
  if (Test-Path $symlinkPath) {
    Remove-Item $symlinkPath -Force
    Write-Host "Removed existing template/symlink"
  }

  # Read and process content
  $content = Get-Content $InputFile -Raw

  # Replace actual paths with placeholders
  $content = $content -replace [regex]::Escape($script:RepoPath), "{{STREAMING_REPO_PATH}}"
  $content = $content -replace [regex]::Escape($script:DataPath), "{{STREAMING_DATA_PATH}}"
  $content | Set-Content $vcsTemplatePath -Encoding UTF8
  Format-JsonWithPrettier -FilePath $vcsTemplatePath
  Write-Host "Template saved: $vcsTemplatePath" -ForegroundColor Yellow

  # Create symlink in OBS scenes folder pointing to VCS location
  New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $vcsTemplatePath | Out-Null
  Write-Host "Created symlink: $symlinkPath -> $vcsTemplatePath" -ForegroundColor Green
}

function ConvertFrom-ObsTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile
  )

  $InputFile = (Resolve-Path $InputFile).Path
  $inputFileName = Split-Path $InputFile -Leaf
  $inputDirectory = Split-Path $InputFile -Parent
  $expectedPath = $script:ObsBasePath

  if ($inputDirectory -ne $expectedPath) {
    throw "This function must target files in: $expectedPath`nCurrent target: $inputDirectory"
  }
  if ($InputFile -notmatch '\.vcs-template\.json$') {
    throw "Input file must be a .vcs-template.json file, got: $inputFileName"
  }

  $OutputFile = $InputFile -replace "\.vcs-template\.json$", ".json"

  Write-Host "Creating real config from template..." -ForegroundColor Green
  Write-Host "Input:  $InputFile"
  Write-Host "Output: $OutputFile"

  $content = Get-Content $InputFile -Raw

  # Replace placeholders
  $content = $content -replace "{{STREAMING_REPO_PATH}}", $script:RepoPath
  $content = $content -replace "{{STREAMING_DATA_PATH}}", $script:DataPath

  $content | Set-Content $OutputFile -Encoding UTF8
  Format-JsonWithPrettier -FilePath $OutputFile
  Write-Host "Real config saved: $OutputFile" -ForegroundColor Yellow
}

Write-Host "OBS Templater functions loaded!" -ForegroundColor Green
Write-Host "  Data Path: $($script:DataPath ?? 'Not set')"
Write-Host "  Repo Path: $($script:RepoPath ?? 'Not set')"
Write-Host "  Input files must be under: $script:ObsBasePath"
Write-Host "  Default VCS Path: $script:DefaultVcsPath"
Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  ConvertTo-ObsTemplate 'scenes.json'                # Creates vcs-template.json"
Write-Host "  ConvertTo-ObsTemplate 'scenes.json' 'custom/path'  # Uses custom VCS relative path in repo"
Write-Host "  ConvertFrom-ObsTemplate 'scenes.vcs-template.json' # Creates scenes.json"
Export-ModuleMember -Function ConvertTo-ObsTemplate, ConvertFrom-ObsTemplate

