# Used to create an editable template from an StreamDeck "scenes.json" file.
. "$PSScriptRoot\StreamDeck-vcs-paths.bro.ps1"

Get-ChildItem "$PSScriptRoot\streamdeck-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "streamdeck-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$script:DefaultVcsOutPath = Join-Path $PSScriptRoot "vcdata"

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

function Assert-StreamDeckPath {
  param([Parameter(Mandatory=$true)][string]$Path)

  if (-not $Path.StartsWith($script:StreamDeckBasePath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "This function must target files under: $($script:StreamDeckBasePath)`nCurrent target: $Path"
  }
}

function ConvertTo-StreamDeckTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,

    [Parameter(Mandatory=$false)]
    [string]$RelativeOutPath
  )

  $InputPath = (Resolve-Path $InputPath).Path
  Assert-StreamDeckPath -Path $InputPath
  if (Test-Path $InputPath -PathType Container) {
    $manifests = Get-ChildItem $InputPath -Recurse -File -Filter "manifest.json"

    if (-not $manifests) {
      Write-Host "No manifest.json files found under: $InputPath" -ForegroundColor Yellow
      return
    }

    Write-Host "Found $($manifests.Count) manifest.json file(s) under: $InputPath" -ForegroundColor Cyan

    foreach ($manifest in $manifests) {
      Write-Host ""
      try {
        ConvertTo-StreamDeckTemplate -InputPath $manifest.FullName -RelativeOutPath $RelativeOutPath
      } catch {
        Write-Host "  Failed: $($manifest.FullName)" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
      }
    }
    return
  }

  $inputFileName  = Split-Path $InputPath -Leaf
  $inputDirectory = Split-Path $InputPath -Parent

  if ([string]::IsNullOrWhiteSpace($script:StreamDeckBasePath)) {
    throw "StreamDeckBasePath is not set. Check StreamDeck-vcs-paths.bro.ps1 / overrides."
  }

  Assert-StreamDeckPath -Path $inputDirectory

  if ($InputPath -notmatch '\.json$') {
    throw "Input file must be a .json file, got: $inputFileName"
  }

  $mappings = Read-ReplacementMappings

  # Calculate relative path from StreamDeck base to input file
  $relativeDeckPath = $inputDirectory.Substring(
    $script:StreamDeckBasePath.Length
  ).TrimStart('\')

  $templateFileName = $inputFileName -replace "\.json$", ".vcs-template.json"
  Write-Host "Creating vcs template from real config..."
  Write-Host "Input:  $InputPath"

  if ($RelativeOutPath) {
    $finalRelativePath = Join-Path $RelativeOutPath $relativeDeckPath
    $vcsOutDirPath = Join-Path $PSScriptRoot $finalRelativePath
  } else {
    $vcsOutDirPath = Join-Path $script:DefaultVcsOutPath $relativeDeckPath
  }
  $vcsOutFilePath = Join-Path $vcsOutDirPath $templateFileName
  Write-Host "Output: $vcsOutFilePath"

  if (-not (Test-Path $vcsOutDirPath)) {
    New-Item -ItemType Directory -Path $vcsOutDirPath -Force | Out-Null
    Write-Host "Created VCS directory: $vcsOutDirPath" -ForegroundColor Yellow
  }

  $backupPath = "$InputPath.bak"
  Copy-Item $InputPath $backupPath -Force
  Write-Host "Backup saved: $backupPath" -ForegroundColor Magenta

  $symlinkPath = Join-Path $inputDirectory $templateFileName
  if (Test-Path $symlinkPath) {
    Remove-Item $symlinkPath -Force
  }

  $content = Get-Content $InputPath -Raw

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

function ConvertFrom-StreamDeckTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath
  )

  $InputFilePath  = (Resolve-Path $InputFilePath).Path
  $inputFileName  = Split-Path $InputFilePath -Leaf
  $inputDirectory = Split-Path $InputFilePath -Parent

  if ($inputDirectory -ne $script:StreamDeckBasePath) {
    throw "This function must target files in: $($script:StreamDeckBasePath)`nCurrent
    target: $inputDirectory"
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
Write-Host "StreamDeck Templater functions loaded!" -ForegroundColor Green

Write-Host "Mappings:" -ForegroundColor Cyan
(Read-ReplacementMappings).GetEnumerator() | ForEach-Object {
  Write-Host "  $($_.Key) => $($_.Value)"
}

Write-Host "Script location:" -ForegroundColor Cyan
Write-Host "  $PSScriptRoot"

Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  All input files must be under: $script:StreamDeckBasePath"
Write-Host "  Default VCS outPath: $script:DefaultVcsOutPath"
Write-Host "  ConvertTo-StreamDeckTemplate 'manifest.json'                # Creates vcs-template.json"
Write-Host "  ConvertTo-StreamDeckTemplate 'manifest.json' 'custom/path'  # Uses custom out path relative to this script location"
Write-Host "  ConvertFrom-StreamDeckTemplate 'manifest.vcs-template.json' # Creates manifest.json"

Export-ModuleMember -Function ConvertTo-StreamDeckTemplate, ConvertFrom-StreamDeckTemplate

