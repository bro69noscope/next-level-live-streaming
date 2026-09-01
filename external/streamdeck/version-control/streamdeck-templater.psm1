# Used to create an editable template from an StreamDeck "scenes.json" file.
if (-not $Global:RepoPath) {
  $Global:RepoPath = Find-RepoRoot -StartPath $PSScriptRoot
}

. "$RepoPath\external\common\streaming-software\version-control\init.ps1"

try {
  . "$PSScriptRoot\dotsource-streamdeck-paths.ps1"
} catch {
  Write-Host "Failed to load StreamDeck paths: $($_.Exception.Message)" -ForegroundColor Red
  throw
}

$script:DefaultVcsOutPath = Join-Path $PSScriptRoot "vcdata"

$streamDeckRoots = @(
  @{
    Path = $script:SdeckBasePath;
    Name = "StreamDeck"
  }
)

$mappings = Read-ReplacementMappings `
  -CommonMappingsPath $script:CommonUserMappingsPath `
  -MappingsPath $script:SdeckMappingsPath `
  -ScopedMappingsPaths @($script:PortsPath)

$Script:manifestStr = "manifest.json"
$Script:jsonMarkerStr = "*-marker.json"

function Initialize-StreamDeckMarkerFile {
  param([Parameter(Mandatory=$true)][string]$InputFilePath)

  $emptyMarkerPath = (Resolve-Path $InputFilePath).Path
  $rawContent = Get-Content $emptyMarkerPath -Raw

  if (-not [string]::IsNullOrWhiteSpace($rawContent)) {
    return $false
  }

  $template = [ordered]@{
    "vcs-flag" = ""
    "name"     = ""
    "desc"     = ""
    "type"     = "dir|profile|home"
  }

  $template | ConvertTo-Json -Depth 5 | Set-Content $emptyMarkerPath -Encoding UTF8
  Write-Host "  Seeded empty marker template: $emptyMarkerPath" -ForegroundColor Cyan
  return $true
}


function Get-StreamDeckVcsOutDirPath {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath,
    [Parameter(Mandatory=$false)] [string]$RelativeOutPath
  )

  $inputDirectory = Split-Path $InputFilePath -Parent
  $relativeDeckPath = $inputDirectory.Substring($script:SdeckBasePath.Length).TrimStart('\')

  if ($RelativeOutPath) {
    return Join-Path $PSScriptRoot (Join-Path $RelativeOutPath $relativeDeckPath)
  }
  return Join-Path $script:DefaultVcsOutPath $relativeDeckPath
}

function ConvertTo-StreamDeckTemplate {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath,
    [Parameter(Mandatory=$false)] [string]$RelativeOutPath
  )

  $InputPath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath -Path $InputPath -Roots $streamDeckRoots

  if (Test-Path $InputPath -PathType Container) {
    $manifests = Get-ChildItem $InputPath -Recurse -File -Filter $manifestStr
    $jsonMarkerFiles = Get-ChildItem $InputPath -Recurse -File -Filter $jsonMarkerStr

    if (-not $manifests -and -not $jsonMarkerFiles) {
      Write-Host "No $manifestStr or $jsonMarkerStr files found under: $InputPath" `
        -ForegroundColor Yellow
      return
    }

    if ($manifests) {
      Write-Host "Found $($manifests.Count) $manifestStr file(s) under: $InputPath" `
        -ForegroundColor Cyan
      foreach ($manifest in $manifests) {
        Write-Host ""
        try {
          ConvertTo-StreamDeckTemplate -InputFilePath $manifest.FullName `
            -RelativeOutPath $RelativeOutPath
        } catch {
          Write-Host "  Failed: $($manifest.FullName)" -ForegroundColor Red
          Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        }
      }
    }

    $seededPaths = @()

    if ($jsonMarkerFiles) {
      Write-Host "Found $($jsonMarkerFiles.Count) $jsonMarkerStr file(s) under: $InputPath" -ForegroundColor Cyan
      foreach ($mdMarkerFile in $jsonMarkerFiles) {
        Write-Host ""
        try {
          $wasSeeded = Initialize-StreamDeckMarkerFile -InputFilePath $mdMarkerFile.FullName
          if ($wasSeeded) {
            $seededPaths += $mdMarkerFile.FullName
            continue
          }
          Copy-StreamDeckMarkerFile -InputFilePath $mdMarkerFile.FullName -RelativeOutPath $RelativeOutPath
        } catch {
          Write-Host "  Failed: $($mdMarkerFile.FullName)" -ForegroundColor Red
          Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        }
      }
    }

    if ($seededPaths.Count -gt 0) {
      Write-Host ""
      Write-Host "Seeded $($seededPaths.Count) new marker template(s) — fill in name/desc/type, then rerun." -ForegroundColor Yellow
      $seededPaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    }

    return
  }

  $vcsOutDirPath = Get-StreamDeckVcsOutDirPath -InputFilePath $InputPath `
    -RelativeOutPath $RelativeOutPath

  ConvertTo-VcsTemplateFile -InputFilePath $InputPath -VcsOutDirPath $vcsOutDirPath `
    -Rules $mappings
}

function Copy-StreamDeckMarkerFile {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath,
    [Parameter(Mandatory=$false)] [string]$RelativeOutPath
  )

  $InputPath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath -Path $InputPath -Roots $streamDeckRoots

  $rawContent = Get-Content $InputPath -Raw
  if ($null -eq $rawContent){
    Write-Warning "Marker file is empty: $InputPath"
    $rawContent = ""
  }

  try {
    $marker = $rawContent | ConvertFrom-Json -AsHashtable
  } catch {
    Write-ThrowContext
    throw "Marker file is not valid JSON: $InputPath`n$($_.Exception.Message)"
  }

  foreach ($field in @("name", "type")) {
    if (-not $marker.ContainsKey($field) -or -not $marker[$field]) {
      throw "Marker file has missing/empty required '$field' field: $InputPath"
    }
  }

  $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
  foreach ($field in @("name", "type")) {
    $value = [string]$marker[$field]
    $badChars = $value.ToCharArray() | Where-Object { $invalidChars -contains $_ }
    if ($badChars) {
      Write-ThrowContext
      throw "Marker field '$field' contains invalid filename character(s) " +
      "('$($badChars -join "', '")'): $InputPath"
    }
  }

  $marker["vcs-flag"] = [guid]::NewGuid().ToString("N").Substring(0, 8)

  $vcsOutDirPath = Get-StreamDeckVcsOutDirPath -InputFilePath $InputPath `
    -RelativeOutPath $RelativeOutPath

  if (-not (Test-Path $vcsOutDirPath)) {
    New-Item -ItemType Directory -Path $vcsOutDirPath -Force | Out-Null
  }

  $destFileName = "$($marker['name'])--$($marker['type'])-marker.json"
  $destPath = Join-Path $vcsOutDirPath $destFileName

  $marker | ConvertTo-Json -Depth 5 | Set-Content $destPath -Encoding UTF8
  Write-Host "  Marker copied (vcs-flag:$($marker['vcs-flag'])): $destPath" -ForegroundColor Green
}

function ConvertFrom-StreamDeckTemplate {
  param(
    [Parameter(Mandatory=$true)] [string]$InputFilePath,
    [Parameter(Mandatory=$false)] [switch]$Backup
  )

  $InputPath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath -Path $InputPath -Roots $streamDeckRoots

  if (Test-Path $InputPath -PathType Container) {
    $templates = Get-ChildItem $InputPath -Recurse -File -Filter "*.vcs-template.json"
    if (-not $templates) {
      Write-Host "No *.vcs-template.json files found under: $InputPath" -ForegroundColor Yellow
      return
    }
    Write-Host "Found $($templates.Count) *.vcs-template.json file(s) under: $InputPath" `
      -ForegroundColor Cyan
    foreach ($template in $templates) {
      Write-Host ""
      try {
        ConvertFrom-StreamDeckTemplate `
          -InputFilePath $template.FullName `
          -Backup:$Backup
      } catch {
        Write-Host "  Failed: $($template.FullName)" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
      }
    }
    return
  }

  Assert-StreamDeckPath -Path (Split-Path $InputPath -Parent)
  ConvertFrom-VcsTemplateFile `
    -InputFilePath $InputPath `
    -Rules $mappings `
    -Backup:$Backup
}

Write-Host ""
Write-Host "StreamDeck Templater:" -ForegroundColor Yellow

Write-Verbose "Mappings:"
$mappings | ForEach-Object {
  $scope = if ($_.Key) {
    "[$($_.Key)] "
  } else {
    ""
  }
  Write-Verbose "  $scope$($_.Token) => $($_.Value)"
}

Write-Host "Script location:" -ForegroundColor Cyan
Write-Host "  $PSScriptRoot"

Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  All input files must be under: $script:SdeckBasePath"
Write-Host "  Default VCS outPath: $script:DefaultVcsOutPath"
Write-Host "  ConvertTo-StreamDeckTemplate 'manifest.json'                     # Creates vcs-template.json"
Write-Host "  ConvertTo-StreamDeckTemplate 'manifest.json' 'custom/path'       # Uses custom out path relative to this script location"
Write-Host "  ConvertTo-StreamDeckTemplate 'folder'                            # Recursively creates vcs-template.json for every manifest.json under folder"
Write-Host "  ConvertFrom-StreamDeckTemplate 'manifest.vcs-template.json'      # Creates manifest.json"
Write-Host "  ConvertFrom-StreamDeckTemplate 'folder'                          # Recursively restores every *.vcs-template.json under folder"

Export-ModuleMember -Function ConvertTo-StreamDeckTemplate, ConvertFrom-StreamDeckTemplate
Write-Host "StreamDeck Templater functions loaded!" -ForegroundColor Green

