# Used to create an editable template from an StreamDeck "scenes.json" file.
. "$PSScriptRoot\StreamDeck-vcs-paths.bro.ps1"
Import-Module $HelpersModulePath -Force

Get-ChildItem "$PSScriptRoot\streamdeck-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "streamdeck-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$script:DefaultVcsOutPath = Join-Path $PSScriptRoot "vcdata"

$mappings = Read-ReplacementMappings `
  -CommonMappingsPath $script:CommonMappingsPath `
  -MappingsPath $script:MappingsPath

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
    $variants = @(
      $localPath,
      ($localPath | ConvertTo-Json -Compress).Trim('"')
    )

    foreach ($variant in $variants) {
      if ($content.Contains($variant)) {
        $content = $content.Replace($variant, $token)
        Write-Host "  Replaced: $variant -> $token" `
          -ForegroundColor DarkCyan
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

  $InputFilePath = (Resolve-Path $InputFilePath).Path
  Assert-StreamDeckPath -Path $InputFilePath

  if (Test-Path $InputFilePath -PathType Container) {
    $templates = Get-ChildItem $InputFilePath -Recurse -File -Filter "*.vcs-template.json"

    if (-not $templates) {
      Write-Host "No *.vcs-template.json files found under: $InputFilePath" -ForegroundColor Yellow
      return
    }

    Write-Host "Found $($templates.Count) *.vcs-template.json file(s) under: $InputFilePath" -ForegroundColor Cyan

    foreach ($template in $templates) {
      Write-Host ""
      try {
        ConvertFrom-StreamDeckTemplate -InputFilePath $template.FullName
      } catch {
        Write-Host "  Failed: $($template.FullName)" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
      }
    }
    return
  }

  $inputFileName  = Split-Path $InputFilePath -Leaf
  $inputDirectory = Split-Path $InputFilePath -Parent

  Assert-StreamDeckPath -Path $inputDirectory

  if ($InputFilePath -notmatch '\.vcs-template\.json$') {
    throw "Input filename must be like **.vcs-template.json, got: $inputFileName"
  }

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
$mappings.GetEnumerator() | ForEach-Object {
  Write-Host "  $($_.Key) => $($_.Value)"
}

Write-Host "Script location:" -ForegroundColor Cyan
Write-Host "  $PSScriptRoot"

Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  All input files must be under: $script:StreamDeckBasePath"
Write-Host "  Default VCS outPath: $script:DefaultVcsOutPath"
Write-Host "  ConvertTo-StreamDeckTemplate 'manifest.json'                     # Creates vcs-template.json"
Write-Host "  ConvertTo-StreamDeckTemplate 'manifest.json' 'custom/path'       # Uses custom out path relative to this script location"
Write-Host "  ConvertTo-StreamDeckTemplate 'folder'                            # Recursively creates vcs-template.json for every manifest.json under folder"
Write-Host "  ConvertFrom-StreamDeckTemplate 'manifest.vcs-template.json'      # Creates manifest.json"
Write-Host "  ConvertFrom-StreamDeckTemplate 'folder'                          # Recursively restores every *.vcs-template.json under folder"

Export-ModuleMember -Function ConvertTo-StreamDeckTemplate, ConvertFrom-StreamDeckTemplate

