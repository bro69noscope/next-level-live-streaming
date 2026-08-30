# Used to create an editable template from an StreamDeck "scenes.json" file.
if (-not $Global:RepoPath) {
  $Global:RepoPath = Find-RepoRoot
}

. "$RepoPath\external\common\streaming-software\version-control\init.ps1"

try {
  . "$PSScriptRoot\dotsource-streamdeck-paths.ps1"
} catch {
  Write-Host "Failed to load StreamDeck paths: $($_.Exception.Message)" -ForegroundColor Red
  throw
}

$script:DefaultVcsOutPath = Join-Path $PSScriptRoot "vcdata"

$mappings = Read-ReplacementMappings `
  -CommonMappingsPath $script:CommonUserMappingsPath `
  -MappingsPath $script:SdeckMappingsPath `
  -ScopedMappingsPaths @($script:PortsPath)

function Assert-StreamDeckPath {
  param([Parameter(Mandatory=$true)][string]$Path)

  if (-not $Path.StartsWith($script:SdeckBasePath, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-ThrowContext
    throw "This function must target files under: $($script:SdeckBasePath)`nCurrent target: $Path"
  }
}

function ConvertTo-StreamDeckTemplate {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath,
    [Parameter(Mandatory=$false)] [string]$RelativeOutPath
  )

  $InputPath = (Resolve-Path $InputFilePath).Path
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
        ConvertTo-StreamDeckTemplate -InputFilePath $manifest.FullName -RelativeOutPath $RelativeOutPath
      } catch {
        Write-Host "  Failed: $($manifest.FullName)" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
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

function ConvertFrom-StreamDeckTemplate {
  param(
    [Parameter(Mandatory=$true)] [string]$InputFilePath,
    [Parameter(Mandatory=$false)] [switch]$Backup
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

  Assert-StreamDeckPath -Path (Split-Path $InputFilePath -Parent)
  ConvertFrom-VcsTemplateFile `
    -InputFilePath $InputFilePath `
    -Rules $mappings `
    -Backup:$Backup
}

Write-Host ""
Write-Host "StreamDeck Templater:" -ForegroundColor Yellow

Write-Host "Mappings:" -ForegroundColor Cyan
$mappings | ForEach-Object {
  $scope = if ($_.Key) {
    "[$($_.Key)] "
  } else {
    ""
  }
  Write-Host "  $scope$($_.Token) => $($_.Value)"
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

