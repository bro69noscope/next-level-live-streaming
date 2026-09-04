# Used to create an editable template from a Streamer.bot "actions/settings.json" file.
if (-not $Global:RepoPath) {
  $Global:RepoPath = Find-RepoRoot -StartPath $PSScriptRoot
}

. "$RepoPath\external\common\streaming-software\version-control\init.ps1"

try {
  . "$PSScriptRoot\dotsource-streamerbot-paths.ps1"
} catch {
  Write-VcsMessage -Message "Failed to load Streamer.bot paths: $($_.Exception.Message)" -Color Red
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
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath
  )

  Set-VcsVerbose -Enabled:$PSBoundParameters.ContainsKey('Verbose')
  Set-VcsLogFilePath -LogDirPath (Join-Path $PSScriptRoot "log") -AppName "streamerbot"
  Write-VcsLogSeparator

  $InputPath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath $InputPath -Roots $streamerbotRoots

  if (Test-Path $InputPath -PathType Container) {
    $candidates = Get-ChildItem $InputPath -Recurse -File -Filter "*.json" |
      Where-Object {
        $_.Name -notmatch '\.vcs-template\.json$' -and
        (Test-StreamerbotMarkerPath -Path $_.FullName)
      }

    if (-not $candidates) {
      Write-VcsMessage -Message "No matching .json files found under: $InputPath" -Color Yellow
      Write-VcsMessage -Message "  (must live under one of: $($script:SbotMarkers -join ', '))" `
        -Color Yellow
      return
    }

    Write-VcsMessage -Message "Found $($candidates.Count) matching .json file(s) under: $InputPath"
    foreach ($candidate in $candidates) {
      Write-VcsMessage -Message ""
      try {
        ConvertTo-StreamerbotTemplate -InputFilePath $candidate.FullName
      } catch {
        Write-VcsMessage -Message "  Failed: $($candidate.FullName)" -Color Red
        Write-VcsMessage -Message "  $($_.Exception.Message)" -Color Red
      }
    }
    return
  }

  $VcsRelativePath = Get-VcsRelativePath `
    -InputFilePath $InputPath `
    -Roots $streamerbotRoots `
    -Markers $script:SbotMarkers `
    -AppName "Streamer.bot"

  $vcsOutDirPath = Join-Path $PSScriptRoot "vcdata"
  $vcsOutDirPath = Join-Path $vcsOutDirPath $VcsRelativePath

  ConvertTo-VcsTemplateFile `
    -InputFilePath $InputPath `
    -VcsOutDirPath $vcsOutDirPath `
    -Rules $mappings
}

function ConvertFrom-StreamerbotTemplate {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath,
    [Parameter(Mandatory=$false)]
    [switch]$Backup
  )

  Set-VcsVerbose -Enabled:$PSBoundParameters.ContainsKey('Verbose')
  Set-VcsLogFilePath -LogDirPath (Join-Path $PSScriptRoot "log") -AppName "streamerbot"
  Write-VcsLogSeparator

  $InputPath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath $InputPath -Roots $streamerbotRoots

  if (Test-Path $InputPath -PathType Container) {
    $templates = Get-ChildItem $InputPath -Recurse -File -Filter "*.vcs-template.json" |
      Where-Object { Test-StreamerbotMarkerPath -Path $_.FullName }

    if (-not $templates) {
      Write-VcsMessage -Message "No matching *.vcs-template.json files found under: $InputPath" `
        -Color Yellow
      return
    }

    Write-VcsMessage -Message ("Found $($templates.Count) matching *.vcs-template.json file(s) " `
        + "under: $InputPath")
    foreach ($template in $templates) {
      Write-VcsMessage -Message ""
      try {
        ConvertFrom-StreamerbotTemplate `
          -InputFilePath $template.FullName `
          -Backup:$Backup
      } catch {
        Write-VcsMessage -Message "  Failed: $($template.FullName)" -Color Red
        Write-VcsMessage -Message "  $($_.Exception.Message)" -Color Red
      }
    }
    return
  }

  ConvertFrom-VcsTemplateFile `
    -InputFilePath $InputPath `
    -Rules $mappings `
    -Backup:$Backup
}

Write-VcsMessage -NoLog -Message ""
Write-VcsMessage -Message "Streamer.bot Templater:" -Color Yellow

Write-VcsMessage -AsVerbose -Message "Mappings:"
$mappings | ForEach-Object {
  $scope = if ($_.Key) {
    "[$($_.Key)] "
  } else {
    ""
  }
  Write-VcsMessage -AsVerbose -Message "  $scope$($_.Token) => $($_.Value)"
}

Write-VcsMessage -NoLog -Message "Script location:" -Color Cyan
Write-VcsMessage -NoLog -Message "  $PSScriptRoot"

Write-VcsMessage -NoLog -Message "Usage:" -Color Cyan
Write-VcsMessage -NoLog -Message ("  All input files must be under:`n$(
  $script:streamerbotRoots.Path -join "`n"
)")
Write-VcsMessage -NoLog -Message ("  ConvertTo-StreamerbotTemplate 'actions.json'                " `
    + "       # Creates vcs-template.json")

Write-VcsMessage -NoLog -Message ("  ConvertTo-StreamerbotTemplate 'folder' (or '.')             " `
    + "       # Recursively creates vcs-template.json for every matching .json under folder")

Write-VcsMessage -NoLog -Message ("  ConvertFrom-StreamerbotTemplate 'actions.vcs-template.json' " `
    + "       # Creates actions.json")

Write-VcsMessage -NoLog -Message ("  ConvertFrom-StreamerbotTemplate 'folder' (or '.')           " `
    + "       # Recursively restores every matching *.vcs-template.json under folder")

Export-ModuleMember -Function ConvertTo-StreamerbotTemplate, ConvertFrom-StreamerbotTemplate
Write-VcsMessage -NoLog -Message "Healthcheck:" -Color Cyan
@(
  "$script:SbotProductionPath\dlls\BroStreamerTools.dll"
  "$script:SbotFtpPath\dlls\BroStreamerTools.dll"
) | Test-StreamerbotDllSymlinks

Write-VcsMessage -NoLog -Message ""
Write-VcsMessage -NoLog -Message "Streamer.bot Templater functions loaded!" -Color Green
