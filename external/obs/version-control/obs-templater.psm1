# Used to create an editable template from an OBS "scenes.json" file.
. "$PSScriptRoot\obs-vcs-paths.bro.ps1"

Get-ChildItem "$PSScriptRoot\obs-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "obs-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$script:DefaultVcsOutPath = Join-Path $PSScriptRoot "scenes"

function Read-MappingsFile {
  param([Parameter(Mandatory=$true)][string]$Path)

  if (-not (Test-Path $Path)) {
    throw "Mappings file not found: $Path"
  }

  $content = Get-Content $Path -Raw
  $content = $content -replace '(?m)^\s*//.*$', ''
  $raw = $content | ConvertFrom-Json

  $mappings = [ordered]@{}
  foreach ($category in $raw.PSObject.Properties) {
    foreach ($prop in $category.Value.PSObject.Properties) {
      $token = $prop.Name
      $value = if ($prop.Value -is [string]) {
        $prop.Value
      } else {
        $prop.Value.value
      }
      $mappings[$token] = $value
    }
  }
  return $mappings
}

function Read-ReplacementMappings {
  $merged = [ordered]@{}

  if ($script:CommonMappingsPath -and (Test-Path $script:CommonMappingsPath)) {
    (Read-MappingsFile $script:CommonMappingsPath).GetEnumerator() | ForEach-Object {
      $merged[$_.Key] = $_.Value
    }
  }

  (Read-MappingsFile $script:MappingsPath).GetEnumerator() | ForEach-Object {
    if ($merged.Contains($_.Key)) {
      Write-Host "  Note: '$($_.Key)' overrides common mapping" -ForegroundColor DarkYellow
    }
    $merged[$_.Key] = $_.Value
  }

  return $merged
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

function Get-VcsRelativePath {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath
  )

  $relative = $InputFilePath.Substring(
    $script:ObsBasePath.Length
  ).TrimStart('\')

  $parts = $relative -split '\\'

  if ($parts[0] -eq "scenes") {
    return "scenes"
  }

  if ($parts[0] -eq "profiles" -and $parts.Count -ge 3) {
    return Join-Path "profiles" $parts[1]
  }

  throw "Unknown OBS config location: $relative"
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

  if ($inputDirectory -notlike "$($script:ObsBasePath)*") {
    throw "This function must target files in: $($script:ObsBasePath)`n
    Current target: $inputDirectory"
  }

  if ($InputFilePath -notmatch '\.json$') {
    throw "Input file must be a .json file, got: $inputFileName"
  }

  Write-Host "Creating vcs template from real config..."
  Write-Host "Input:  $InputFilePath"

  $mappings = Read-ReplacementMappings

  $templateFileName = $inputFileName -replace "\.json$", ".vcs-template.json"
  if (-not $VcsRelativePath) {
    $VcsRelativePath = get-VcsRelativePath $InputFilePath
  }

  $vcsOutDirPath = Join-Path $PSScriptRoot "vcdata"
  $vcsOutDirPath = Join-Path $vcsOutDirPath $VcsRelativePath

  $vcsOutFilePath = Join-Path $vcsOutDirPath $templateFileName
  Write-Host "Output: $vcsOutFilePath"

  if (-not (Test-Path $vcsOutDirPath)) {
    New-Item -ItemType Directory -Path $vcsOutDirPath -Force | Out-Null
    Write-Host "Created VCS directory: $vcsOutDirPath" -ForegroundColor Yellow
  }

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

  if ($inputDirectory -notlike "$($script:ObsBasePath)*") {
    throw "This function must target files in: $($script:ObsBasePath)`n
    Current target: $inputDirectory"
  }

  if ($InputFilePath -notmatch '\.vcs-template\.json$') {
    throw "Input filename must be like **.vcs-template.json, got: $inputFileName"
  }

  $mappings = Read-ReplacementMappings
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

Write-Host "Mappings:" -ForegroundColor Cyan
(Read-ReplacementMappings).GetEnumerator() | ForEach-Object {
  Write-Host "  $($_.Key) => $($_.Value)"
}

Write-Host "Script location:" -ForegroundColor Cyan
Write-Host "  $PSScriptRoot"

Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  All input files must be under: $script:ObsBasePath"
Write-Host "  Default VCS outPath: $script:DefaultVcsOutPath"
Write-Host "  ConvertTo-ObsTemplate 'scenes.json'                # Creates vcs-template.json"
Write-Host "  ConvertTo-ObsTemplate 'scenes.json' 'custom/path'  # Uses custom out path relative to this script location"
Write-Host "  ConvertFrom-ObsTemplate 'scenes.vcs-template.json' # Creates scenes.json"

Export-ModuleMember -Function ConvertTo-ObsTemplate, ConvertFrom-ObsTemplate

