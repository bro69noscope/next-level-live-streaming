# Used to create an editable template from an OBS "scenes.json" file.
# All path substitutions are driven by path-mappings.json

$script:PrettierPath  = Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\prettier.cmd"
$script:ObsBasePath   = Join-Path $env:APPDATA "obs-studio\basic\scenes"
$script:MappingsPath  = Join-Path $PSScriptRoot "path-mappings.json"
$script:DefaultVcsOutPath = Join-Path $PSScriptRoot "scenes"

function Read-PathMappings {
  if (-not (Test-Path $script:MappingsPath)) {
    throw "Mappings file not found: $($script:MappingsPath)"
  }

  $raw = Get-Content $script:MappingsPath -Raw | ConvertFrom-Json

  $mappings = [ordered]@{}
  foreach ($prop in $raw.PSObject.Properties) {
    $token     = $prop.Name
    $localPath = ($prop.Value -replace '\\', '/').TrimEnd('/')
    if (-not (Test-Path $localPath)) {
      Write-Host "Warning: Mapped path does not exist on this machine:
      $localPath (token: $token)" -ForegroundColor Yellow
    }

    $mappings[$token] = $localPath
  }

  return $mappings
}

function Format-JsonWithPrettier {
  param([string]$FilePath)

  if (-not (Test-Path $script:PrettierPath)) {
    Write-Host "Warning: Prettier not found at $script:PrettierPath. Skipping
    formatting." -ForegroundColor Yellow
    return
  }

  & $script:PrettierPath --write $FilePath
}

function ConvertTo-ObsTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath,

    [Parameter(Mandatory=$false)]
    [string]$VcsRelativePath
  )

  $InputFilePath  = (Resolve-Path $InputFilePath).Path
  $inputFileName  = Split-Path $InputFilePath -Leaf
  $inputDirectory = Split-Path $InputFilePath -Parent

  if ($inputDirectory -ne $script:ObsBasePath) {
    throw "This function must target files in: $($script:ObsBasePath)`nCurrent
    target: $inputDirectory"
  }
  if ($InputFilePath -notmatch '\.json$') {
    throw "Input file must be a .json file, got: $inputFileName"
  }

  $mappings = Read-PathMappings

  $templateFileName = $inputFileName -replace "\.json$", ".vcs-template.json"
  if (-not $VcsRelativePath) {
    $collectionName = $inputFileName -replace "\.json$", ""
    $VcsRelativePath = Join-Path "scenes" $collectionName
  }
  Write-Host "Creating vcs template from real config..."
  Write-Host "Input:  $InputFilePath"

  $vcsOutDirPath  = Join-Path $PSScriptRoot $VcsRelativePath
  $vcsOutFilePath = Join-Path $vcsOutDirPath $templateFileName
  Write-Host "Output: $vcsOutFilePath"

  if (-not (Test-Path $vcsOutDirPath)) {
    New-Item -ItemType Directory -Path $vcsOutDirPath -Force | Out-Null
    Write-Host "Created VCS directory: $vcsOutDirPath" -ForegroundColor Yellow
  }

  $backupPath = "$InputFilePath.bak"
  Copy-Item $InputFilePath $backupPath -Force
  Write-Host "Backup saved: $backupPath" -ForegroundColor Magenta

  $symlinkPath = Join-Path $inputDirectory $templateFileName
  if (Test-Path $symlinkPath) {
    Remove-Item $symlinkPath -Force
  }

  $content = Get-Content $InputFilePath -Raw

  # Apply substitutions longest-path-first to prevent a shorter path from
  # matching inside a longer one before it gets a chance to be replaced
  $sortedMappings = $mappings.GetEnumerator() | Sort-Object { $_.Value.Length } `
    -Descending

  foreach ($entry in $sortedMappings) {
    $token     = $entry.Key
    $localPath = $entry.Value
    $variants  = @(
      $localPath,
      ($localPath -replace '/', '\'),
      ($localPath -replace '/', '\\')
    )

    foreach ($variant in $variants) {
      if ($content -match [regex]::Escape($variant)) {
        $content = $content -replace [regex]::Escape($variant), $token
        Write-Host "  Replaced: $variant -> $token" -ForegroundColor DarkCyan
      }
    }
  }

  $content | Set-Content $vcsOutFilePath -Encoding UTF8
  Format-JsonWithPrettier -FilePath $vcsOutFilePath
  Write-Host "Template saved: $vcsOutFilePath" -ForegroundColor Green

  New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $vcsOutFilePath | Out-Null
}

function ConvertFrom-ObsTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath
  )

  $InputFilePath  = (Resolve-Path $InputFilePath).Path
  $inputFileName  = Split-Path $InputFilePath -Leaf
  $inputDirectory = Split-Path $InputFilePath -Parent

  if ($inputDirectory -ne $script:ObsBasePath) {
    throw "This function must target files in: $($script:ObsBasePath)`nCurrent
    target: $inputDirectory"
  }
  if ($InputFilePath -notmatch '\.vcs-template\.json$') {
    throw "Input filename must be like **.vcs-template.json, got: $inputFileName"
  }

  $mappings = Read-PathMappings
  $outPath  = $InputFilePath -replace "\.vcs-template\.json$", ".json"

  Write-Host "Input:  $InputFilePath"
  Write-Host "Output: $outPath"

  if (Test-Path $outPath) {
    $backupPath = "$outPath.bak"
    Copy-Item $outPath $backupPath -Force
    Write-Host "Backup saved: $backupPath" -ForegroundColor Magenta
  }

  $content = Get-Content $InputFilePath -Raw

  foreach ($entry in $mappings.GetEnumerator()) {
    $token     = $entry.Key
    $localPath = $entry.Value
    if ($content -match [regex]::Escape($token)) {
      $content = $content -replace [regex]::Escape($token), $localPath
      Write-Host "  Replaced: $token -> $localPath" -ForegroundColor DarkCyan
    }
  }

  $unresolvedMatches = [regex]::Matches($content, '\{\{[A-Z0-9_]+\}\}') |
    Select-Object -ExpandProperty Value -Unique
  foreach ($unresolved in $unresolvedMatches) {
    Write-Host "Warning: No mapping found for token $unresolved — left as-is" `
      -ForegroundColor Yellow
  }

  $content | Set-Content $outPath -Encoding UTF8
  Format-JsonWithPrettier -FilePath $outPath 
  Write-Host "Real config saved: $outPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "OBS Templater functions loaded!" -ForegroundColor Green
Write-Host "Script location:" -ForegroundColor Cyan
Write-Host "  $PSScriptRoot"

Write-Host "Path Mappings:" -ForegroundColor Cyan
(Read-PathMappings).GetEnumerator() | ForEach-Object {
  Write-Host "  $($_.Key) => $($_.Value)"
}
Write-Host "  All input files must be under: $script:ObsBasePath"
Write-Host "  Default VCS outPath: $script:DefaultVcsOutPath"

Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  ConvertTo-ObsTemplate 'scenes.json'                # Creates
vcs-template.json"

Write-Host "  ConvertTo-ObsTemplate 'scenes.json' 'custom/path'  # Uses custom
out path relative to this script location"

Write-Host "  ConvertFrom-ObsTemplate 'scenes.vcs-template.json' # Creates
scenes.json"

Export-ModuleMember -Function ConvertTo-ObsTemplate, ConvertFrom-ObsTemplate

