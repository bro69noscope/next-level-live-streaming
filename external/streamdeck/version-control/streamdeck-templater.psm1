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
$Script:mdMarkerStr = "*-marker.md"

function ConvertTo-StreamDeckTemplate {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath,
    [Parameter(Mandatory=$false)] [string]$RelativeOutPath
  )

  $InputPath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath -Path $InputPath -Roots $streamDeckRoots

  if (Test-Path $InputPath -PathType Container) {
    $manifests = Get-ChildItem $InputPath -Recurse -File -Filter $manifestStr
    $mdMarkerFiles = Get-ChildItem $InputPath -Recurse -File -Filter $mdMarkerStr

    if (-not $manifests -and -not $mdMarkerFiles) {
      Write-Host "No $manifestStr or $mdMarkerStr files found under: $InputPath" -ForegroundColor Yellow
      return
    }

    if ($manifests) {
      Write-Host "Found $($manifests.Count) $manifestStr file(s) under: $InputPath" -ForegroundColor Cyan
      foreach ($manifest in $manifests) {
        Write-Host ""
        try {
          ConvertTo-StreamDeckTemplate -InputFilePath $manifest.FullName -RelativeOutPath $RelativeOutPath
        } catch {
          Write-Host "  Failed: $($manifest.FullName)" -ForegroundColor Red
          Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        }
      }
    }

    if ($mdMarkerFiles) {
      Write-Host "Found $($mdMarkerFiles.Count) $mdMarkerStr file(s) under: $InputPath" -ForegroundColor Cyan
      foreach ($mdMarkerFile in $mdMarkerFiles) {
        Write-Host ""
        try {
          Copy-StreamDeckMarkerFile -InputFilePath $mdMarkerFile.FullName -RelativeOutPath $RelativeOutPath
        } catch {
          Write-Host "  Failed: $($mdMarkerFile.FullName)" -ForegroundColor Red
          Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        }
      }
    }

    return
  }

  $inputDirectory = Split-Path $InputPath -Parent
  $relativeDeckPath = $inputDirectory.Substring($script:SdeckBasePath.Length).TrimStart('\')

  $vcsOutDirPath = if ($RelativeOutPath) {
    Join-Path $PSScriptRoot (Join-Path $RelativeOutPath $relativeDeckPath)
  } else {
    Join-Path $script:DefaultVcsOutPath $relativeDeckPath
  }

  ConvertTo-VcsTemplateFile -InputFilePath $InputPath -VcsOutDirPath $vcsOutDirPath -Rules $mappings
}

function Copy-StreamDeckMarkerFile {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath,
    [Parameter(Mandatory=$false)] [string]$RelativeOutPath
  )

  $InputPath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath -Path $InputPath -Roots $streamDeckRoots

  $inputDirectory = Split-Path $InputPath -Parent
  $relativeDeckPath = $inputDirectory.Substring($script:SdeckBasePath.Length).TrimStart('\')

  $vcsOutDirPath = if ($RelativeOutPath) {
    Join-Path $PSScriptRoot (Join-Path $RelativeOutPath $relativeDeckPath)
  } else {
    Join-Path $script:DefaultVcsOutPath $relativeDeckPath
  }

  if (-not (Test-Path $vcsOutDirPath)) {
    New-Item -ItemType Directory -Path $vcsOutDirPath -Force | Out-Null
  }

  $fileName = Split-Path $InputPath -Leaf
  $destPath = Join-Path $vcsOutDirPath $fileName

  $content = Get-Content $InputPath -Raw
  if ($null -eq $content) {
    $content = "" # cannot use -match on null
  }

  $randomHash = [guid]::NewGuid().ToString("N").Substring(0, 8)
  $bumpPattern = '(?m)^vcs-flag-hash:\S+\s*$'

  if ($content -match $bumpPattern) {
    $content = [regex]::Replace($content, $bumpPattern, "vcs-flag-hash:$randomHash")
  } else {
    $content = $content.TrimEnd() + "`nvcs-flag-hash:$randomHash`n"
  }

  $content | Set-Content $destPath -Encoding UTF8 -NoNewline
  Write-Host "  Marker copied (vcs-flag-hash:$randomHash): $destPath" -ForegroundColor Green
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
    Write-Host "Found $($templates.Count) *.vcs-template.json file(s) under: $InputPath" -ForegroundColor Cyan
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

