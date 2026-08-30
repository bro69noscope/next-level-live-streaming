# Used to create an editable template from an OBS "scenes.json" file.
if (-not $Global:RepoPath) {
  $Global:RepoPath = Find-RepoRoot
}

. "$RepoPath\external\common\streaming-software\version-control\init.ps1"

try {
  . "$PSScriptRoot\dotsource-obs-paths.ps1"
} catch {
  Write-Host "Failed to load OBS paths: $($_.Exception.Message)" -ForegroundColor Red
  throw
}

$obsRoots = @(
  @{
    Path = $script:ObsVcamPath
    Name = "vcam"
  },
  @{
    Path = $script:ObsFtpPath
    Name = "ftp"
  },
  @{
    Path = $script:ObsProductionPath
    Name = "production"
  }
)

$mappings = Read-ReplacementMappings `
  -CommonMappingsPath $script:CommonUserMappingsPath `
  -MappingsPath $script:ObsMappingsPath `
  -ScopedMappingsPaths @($script:ObsPortsPath)

$script:ObsMarkers = @("scenes", "plugin_config")
$script:ObsPluginAllowlist = @("obs-websocket")
$script:ObsSceneAllowlist = @(
  "collection_aoe2",
  "collection_dota2",
  "ftp_collection_main",
  "vcam_collection_main"
)
# also allow any scene name that ends with these suffixes, for testing purposes
$script:ObsSceneTestSuffixPattern = '_(fake|test)$'

function Test-ObsMarkerPath {
  param([Parameter(Mandatory=$true)] [string]$Path)

  $parts = $Path -split '\\'

  for ($i = 0; $i -lt $parts.Count; $i++) {
    $marker = $parts[$i]
    $nextPart = if ($i + 1 -lt $parts.Count) {
      $parts[$i + 1]
    } else {
      $null
    }

    if ($marker -eq "plugin_config") {
      if ($script:ObsPluginAllowlist -contains $nextPart) {
        return $true
      }
      continue
    }

    if ($marker -eq "scenes") {
      $sceneName = if ($nextPart) {
        $nextPart -replace '\.vcs-template\.json$', '' -replace '\.json$', ''
      } else {
        $null
      }
      if (
        $script:ObsSceneAllowlist -contains $sceneName -or
        ($sceneName -and $sceneName -match $script:ObsSceneTestSuffixPattern)
      ) {
        return $true
      }
      continue
    }
  }

  return $false
}

function ConvertTo-ObsTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath
  )

  $InputFilePath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath $InputFilePath -Roots $obsRoots

  if (Test-Path $InputFilePath -PathType Container) {
    $candidates = Get-ChildItem $InputFilePath -Recurse -File -Filter "*.json" |
      Where-Object {
        $_.Name -notmatch '\.vcs-template\.json$' -and
        (Test-ObsMarkerPath -Path $_.FullName)
      }

    if (-not $candidates) {
      Write-Host "No matching .json files found under: $InputFilePath" -ForegroundColor Yellow
      Write-Host "  (must live under one of: $($script:ObsMarkers -join ', '))" -ForegroundColor Yellow
      return
    }

    Write-Host "Found $($candidates.Count) matching .json file(s) under: $InputFilePath"
    foreach ($candidate in $candidates) {
      Write-Host ""
      try {
        ConvertTo-ObsTemplate -InputFilePath $candidate.FullName
      } catch {
        Write-Host "  Failed: $($candidate.FullName)" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
      }
    }
    return
  }

  $VcsRelativePath = Get-VcsRelativePath `
    -InputFilePath $InputFilePath `
    -Roots $obsRoots `
    -Markers $script:ObsMarkers `
    -AppName "OBS"

  $vcsOutDirPath = Join-Path $PSScriptRoot "vcdata"
  $vcsOutDirPath = Join-Path $vcsOutDirPath $VcsRelativePath

  ConvertTo-VcsTemplateFile `
    -InputFilePath $InputFilePath `
    -VcsOutDirPath $vcsOutDirPath `
    -Rules $mappings
}

function ConvertFrom-ObsTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath,
    [Parameter(Mandatory=$false)]
    [switch]$Backup
  )

  $InputFilePath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath $InputFilePath -Roots $obsRoots

  if (Test-Path $InputFilePath -PathType Container) {
    $templates = Get-ChildItem $InputFilePath -Recurse -File -Filter "*.vcs-template.json" |
      Where-Object { Test-ObsMarkerPath -Path $_.FullName }

    if (-not $templates) {
      Write-Host "No matching *.vcs-template.json files found under: $InputFilePath" -ForegroundColor Yellow
      return
    }

    Write-Host "Found $($templates.Count) matching *.vcs-template.json file(s) under: $InputFilePath"
    foreach ($template in $templates) {
      Write-Host ""
      try {
        ConvertFrom-ObsTemplate `
          -InputFilePath $template.FullName `
          -Backup:$Backup
      } catch {
        Write-Host "  Failed: $($template.FullName)" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
      }
    }
    return
  }

  ConvertFrom-VcsTemplateFile `
    -InputFilePath $InputFilePath `
    -Rules $mappings `
    -Backup:$Backup
}

Write-Host ""
Write-Host "OBS Templater: " -ForegroundColor Yellow

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
Write-Host "  All input files must be under:`n$($obsRoots.Path -join "`n")"
Write-Host "  ConvertTo-ObsTemplate 'scenes.json'                # Creates vcs-template.json"
Write-Host "  ConvertFrom-ObsTemplate 'scenes.vcs-template.json' # Creates scenes.json"

Export-ModuleMember -Function ConvertTo-ObsTemplate, ConvertFrom-ObsTemplate
Write-Host "OBS Templater functions loaded!" -ForegroundColor Green

