# Used to create an editable template from a StreamDeck "manifest.json" profile file

$script:RepoPath = $env:STREAMING_REPO_PATH
$script:PrettierPath = Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\prettier.cmd"

if (-not $script:RepoPath) {
  throw "STREAMING_REPO_PATH environment variable is not set. Please set it
    before running this script."
}

if (-not (Test-Path -Path $script:RepoPath -PathType Container)) {
  throw "STREAMING_REPO_PATH points to a directory that does not exist: $script:RepoPath"
}

$script:RepoPath = if ($script:RepoPath) {
  ($script:RepoPath -replace '\\', '/').TrimEnd('/')
} else {
  $null
}

$script:DefaultVcsPath = "external/streamdeck/version-control"
$script:StreamDeckBasePath = "$env:APPDATA\Elgato\StreamDeck\ProfilesV2"

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

function ConvertTo-StreamDeckTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [Parameter(Mandatory=$false)]
    [string]$VcsRelativePath = $script:DefaultVcsPath
  )
  $InputFile = (Resolve-Path $InputFile).Path
  $inputFileName = Split-Path $InputFile -Leaf
  $inputDirectory = Split-Path $InputFile -Parent
  $expectedPath = $script:StreamDeckBasePath

  if ($inputDirectory -notmatch [regex]::Escape($expectedPath)) {
    throw "This function must target files in: $expectedPath`nCurrent target: $inputDirectory"
  }
  if ($InputFile -notmatch '\.json$') {
    throw "Input file must be a .json file, got: $inputFileName"
  }

  $templateFileName = $inputFileName -replace "\.json$", ".vcs-template.json"
  Write-Host "Creating StreamDeck template from real config..." -ForegroundColor Green
  Write-Host "Input:  $InputFile"

  # Calculate relative path from StreamDeck base to input file
  $relativePath = $inputDirectory -replace [regex]::Escape($script:StreamDeckBasePath), ""
  $relativePath = $relativePath.TrimStart('\')

  # Setup paths
  $vcsFullPath = Join-Path ($script:RepoPath -replace '/', '\') $VcsRelativePath
  $vcsMirroredPath = Join-Path $vcsFullPath $relativePath
  $vcsTemplatePath = Join-Path $vcsMirroredPath $templateFileName

  Write-Host "Output: $vcsTemplatePath"

  $forwardSlashPath = $script:RepoPath
  $backslashPath = $script:RepoPath -replace '/', '\\'
  $escapedForward = [regex]::Escape($forwardSlashPath)
  $escapedBackslash = [regex]::Escape($backslashPath)

  # Ensure the VCS mirrored directory exists
  if (-not (Test-Path $vcsMirroredPath)) {
    New-Item -ItemType Directory -Path $vcsMirroredPath -Force | Out-Null
    Write-Host "Created VCs directory: $vcsMirroredPath" -ForegroundColor Cyan
  }

  # CREATE BACKUP FIRST
  $backupFileName = $inputFileName -replace "\.json$", ".backup.json"
  $backupPath = Join-Path $vcsMirroredPath $backupFileName
  Copy-Item $InputFile $backupPath -Force
  Write-Host "Backup saved: $backupPath" -ForegroundColor Magenta

  # Remove existing template file or symlink in input directory
  $symlinkPath = Join-Path $inputDirectory $templateFileName
  if (Test-Path $symlinkPath) {
    Remove-Item $symlinkPath -Force
    Write-Host "Removed existing symlink"
  }

  # Read and process content
  $content = Get-Content $InputFile -Raw

  # Replace both versions with the placeholder
  $content = $content -replace $escapedForward, "{{STREAMING_REPO_PATH}}"
  $content = $content -replace $escapedBackslash, "{{STREAMING_REPO_PATH}}"
  $content | Set-Content $vcsTemplatePath -Encoding UTF8
  Format-JsonWithPrettier -FilePath $vcsTemplatePath
  Write-Host "Template saved: $vcsTemplatePath" -ForegroundColor Yellow

  # Create symlink in mirrored VCS directory pointing to template
  New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $vcsTemplatePath | Out-Null
  Write-Host "Created symlink: $symlinkPath -> $vcsTemplatePath" -ForegroundColor Green
}

function ConvertFrom-StreamDeckTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile
  )
  $InputFile = (Resolve-Path $InputFile).Path
  $inputFileName = Split-Path $InputFile -Leaf
  $inputDirectory = Split-Path $InputFile -Parent
  $expectedPath = $script:StreamDeckBasePath

  if ($inputDirectory -notmatch [regex]::Escape($expectedPath)) {
    throw "This function must target files in: $expectedPath`nCurrent target: $inputDirectory"
  }
  if ($InputFile -notmatch '\.vcs-template\.json$') {
    throw "Input file must be a .vcs-template.json file, got: $inputFileName"
  }

  $OutputFile = $InputFile -replace "\.vcs-template\.json$", ".json"

  Write-Host "Creating real StreamDeck config from template..." -ForegroundColor Green
  Write-Host "Input:  $InputFile"
  Write-Host "Output: $OutputFile"

  $content = Get-Content $InputFile -Raw

  # Replace with backslash version for Windows paths
  $windowsPath = $script:RepoPath -replace '/', '\\'
  $content = $content -replace "{{STREAMING_REPO_PATH}}", $windowsPath

  $content | Set-Content $OutputFile -Encoding UTF8
  Format-JsonWithPrettier -FilePath $OutputFile
  Write-Host "Real config saved: $OutputFile" -ForegroundColor Yellow
}

Write-Host "StreamDeck Templater functions loaded!" -ForegroundColor Green
Write-Host "  Repo Path: $($script:RepoPath ?? 'Not set')"
Write-Host "  Input files must be under: $script:StreamDeckBasePath"
Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  ConvertTo-StreamDeckTemplate 'manifest.json'                # Creates vcs-template.json"
Write-Host "  ConvertTo-ObsTemplate 'manifest.json' 'custom/path'         # Uses custom VCS relative path in repo"
Write-Host "  ConvertFrom-StreamDeckTemplate 'manifest.vcs-template.json' # Creates manifest.json"
Export-ModuleMember -Function ConvertTo-StreamDeckTemplate, ConvertFrom-StreamDeckTemplate

