# Used to create an editable template from a Streamer.bot "actions/settings.json" file.
if (-not $Global:RepoPath) {
  $Global:RepoPath = Find-RepoRoot
}

. "$RepoPath\external\common\streaming-software\version-control\init.ps1"

try {
  . "$PSScriptRoot\dotsource-streamerbot-paths.ps1"
} catch {
  Write-Host "Failed to load Streamer.bot paths: $($_.Exception.Message)" -ForegroundColor Red
  throw
}

Import-Module "$PSScriptRoot\healthcheck.psm1" -Force

$script:streamerbotRoots = @(
  @{
    Path = $script:SbotFtpPath
    Name = "ftp"
  },
  @{
    Path = $script:SbotProductionPath
    Name = "production"
  }
)

$mappings = Read-ReplacementMappings `
  -CommonMappingsPath $script:CommonUserMappingsPath `
  -MappingsPath $script:SbotMappingsPath `
  -ScopedMappingsPaths @($script:SbotPortsPath)

$script:SbotMarkers = @("data")
$script:SbotFileAllowlist = @("obs.json", "settings.json", "actions.json")
$script:SbotTestSuffixPattern = '_(fake|test)\.json$'

function Test-StreamerbotMarkerPath {
  param([Parameter(Mandatory=$true)] [string]$Path)

  $parts = $Path -split '\\'
  if ([array]::IndexOf($parts, "data") -lt 0) {
    return $false
  }

  $baseFileName = $parts[-1] -replace '\.vcs-template\.json$', '' -replace '\.json$', ''

  return (
    $script:SbotFileAllowlist -contains "$baseFileName.json" -or
    "$baseFileName.json" -match $script:SbotTestSuffixPattern
  )
}

function ConvertTo-StreamerbotTemplate {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath
  )

  $InputFilePath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath $InputFilePath -Roots $streamerbotRoots

  if (Test-Path $InputFilePath -PathType Container) {
    $candidates = Get-ChildItem $InputFilePath -Recurse -File -Filter "*.json" |
      Where-Object {
        $_.Name -notmatch '\.vcs-template\.json$' -and
        (Test-StreamerbotMarkerPath -Path $_.FullName)
      }

    if (-not $candidates) {
      Write-Host "No matching .json files found under: $InputFilePath" -ForegroundColor Yellow
      Write-Host "  (must live under one of: $($script:SbotMarkers -join ', '))" -ForegroundColor Yellow
      return
    }

    Write-Host "Found $($candidates.Count) matching .json file(s) under: $InputFilePath"
    foreach ($candidate in $candidates) {
      Write-Host ""
      try {
        ConvertTo-StreamerbotTemplate -InputFilePath $candidate.FullName
      } catch {
        Write-Host "  Failed: $($candidate.FullName)" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
      }
    }
    return
  }

  $VcsRelativePath = Get-VcsRelativePath `
    -InputFilePath $InputFilePath `
    -Roots $streamerbotRoots `
    -Markers $script:SbotMarkers `
    -AppName "Streamer.bot"

  $vcsOutDirPath = Join-Path $PSScriptRoot "vcdata"
  $vcsOutDirPath = Join-Path $vcsOutDirPath $VcsRelativePath

  ConvertTo-VcsTemplateFile `
    -InputFilePath $InputFilePath `
    -VcsOutDirPath $vcsOutDirPath `
    -Rules $mappings
}

function ConvertFrom-StreamerbotTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath,
    [Parameter(Mandatory=$false)]
    [switch]$Backup
  )

  $InputFilePath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath $InputFilePath -Roots $streamerbotRoots

  if (Test-Path $InputFilePath -PathType Container) {
    $templates = Get-ChildItem $InputFilePath -Recurse -File -Filter "*.vcs-template.json" |
      Where-Object { Test-StreamerbotMarkerPath -Path $_.FullName }

    if (-not $templates) {
      Write-Host "No matching *.vcs-template.json files found under: $InputFilePath" -ForegroundColor Yellow
      return
    }

    Write-Host "Found $($templates.Count) matching *.vcs-template.json file(s) under: $InputFilePath"
    foreach ($template in $templates) {
      Write-Host ""
      try {
        ConvertFrom-StreamerbotTemplate `
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
Write-Host "Streamer.bot Templater: " -ForegroundColor Yellow

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
Write-Host "  All input files must be under:`n$(
  $script:streamerbotRoots.Path -join "`n"
)"
Write-Host "  ConvertTo-StreamerbotTemplate 'actions.json'                        # Creates vcs-template.json"
Write-Host "  ConvertTo-StreamerbotTemplate 'folder'                              # Recursively creates vcs-template.json for every matching .json under folder"
Write-Host "  ConvertFrom-StreamerbotTemplate 'actions.vcs-template.json'         # Creates actions.json"
Write-Host "  ConvertFrom-StreamerbotTemplate 'folder'                            # Recursively restores every matching *.vcs-template.json under folder"

Export-ModuleMember -Function ConvertTo-StreamerbotTemplate, ConvertFrom-StreamerbotTemplate
Write-Host "Healthcheck:" -ForegroundColor Cyan
@(
  "$script:SbotProductionPath\dlls\BroStreamerTools.dll"
  "$script:SbotFtpPath\dlls\BroStreamerTools.dll"
) | Test-StreamerbotDllSymlinks

Write-Host ""
Write-Host "Streamer.bot Templater functions loaded!" -ForegroundColor Green
