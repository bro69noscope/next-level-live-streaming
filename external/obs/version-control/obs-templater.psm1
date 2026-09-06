# Used to create an editable template from an OBS "scenes.json" file.
if (-not $Global:RepoPath) {
  $Global:RepoPath = Find-RepoRoot -StartPath $PSScriptRoot
}

. "$RepoPath\external\common\streaming-software\version-control\init.ps1"

try {
  . "$PSScriptRoot\dotsource-obs-paths.ps1"
} catch {
  Write-VcsMessage -Message "Failed to load OBS paths: $($_.Exception.Message)" -Color Red
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
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath
  )

  $isRootCall = ($null -eq $vcsFormatQueue)

  try {
    if ($isRootCall) {
      $vcsFormatQueue = [System.Collections.Generic.List[string]]::new()
      $vcsReplacedCount = 0
      Set-VcsVerbose -Enabled:$PSBoundParameters.ContainsKey('Verbose')
      Set-VcsLogFilePath -LogDirPath (Join-Path $PSScriptRoot "log") -AppName "obs"
      Write-VcsLogSeparator
    }

    $InputPath = (Resolve-Path $InputFilePath).Path
    Assert-InputPath $InputPath -Roots $obsRoots

    if (Test-Path $InputPath -PathType Container) {
      $candidates = Get-ChildItem $InputPath -Recurse -File -Filter "*.json" |
        Where-Object {
          $_.Name -notmatch '\.vcs-template\.json$' -and
          (Test-ObsMarkerPath -Path $_.FullName)
        }

      if (-not $candidates) {
        Write-VcsMessage -Message "No matching .json files found under: $InputPath" -Color Yellow
        Write-VcsMessage -Message "  (must live under one of: $($script:ObsMarkers -join ', '))" `
          -Color Yellow
        return
      }

      Write-VcsMessage -AsVerbose -Message ("Found $($candidates.Count) matching .json file(s) " `
          + "under: $InputPath")

      foreach ($candidate in $candidates) {
        try {
          ConvertTo-ObsTemplate -InputFilePath $candidate.FullName
        } catch {
          Write-VcsMessage -Message "  Failed to convert: $($candidate.FullName)" -Color Red
          Write-VcsMessage -Message "  $($_.Exception.Message)" -Color Red
          Write-ThrowContext
          throw "Failed to convert $($candidate.FullName) to vcs-template"
        }
      }

      if ($vcsFormatQueue.Count -gt 0) {
        Format-JsonWithPrettier -FilePaths $vcsFormatQueue
      }
      return
    }

    $VcsRelativePath = Get-VcsRelativePath `
      -InputFilePath $InputPath `
      -Roots $obsRoots `
      -Markers $script:ObsMarkers `
      -AppName "OBS"

    $vcsOutBaseDirPath = Join-Path $PSScriptRoot "vcdata"
    $vcsOutDirPath = Join-Path $vcsOutBaseDirPath $VcsRelativePath

    ConvertTo-VcsTemplateFile `
      -InputFilePath $InputPath `
      -VcsOutDirPath $vcsOutDirPath `
      -Rules $mappings `
      -FormatQueue $vcsFormatQueue `
      -ReplacedCount ([ref]$vcsReplacedCount)

  } finally {
    if ($isRootCall) {
      Write-VcsMessage -Message "Replaced $vcsReplacedCount token(s)" -Color Cyan
      $vcsFormatQueue = $null
      $vcsReplacedCount = $null
    }
  }
}

function ConvertFrom-ObsTemplate {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath,
    [Parameter(Mandatory=$false)]
    [switch]$Backup
  )

  $isRootCall = ($null -eq $vcsReplacedCount)

  try {
    if ($isRootCall) {
      $vcsReplacedCount = 0
      $vcsFormatQueue = [System.Collections.Generic.List[string]]::new()
      Set-VcsVerbose -Enabled:$PSBoundParameters.ContainsKey('Verbose')
      Set-VcsLogFilePath -LogDirPath (Join-Path $PSScriptRoot "log") -AppName "obs"
      Write-VcsLogSeparator
    }

    $InputPath = (Resolve-Path $InputFilePath).Path
    Assert-InputPath $InputPath -Roots $obsRoots

    if (Test-Path $InputPath -PathType Container) {
      $templates = Get-ChildItem $InputPath -Recurse -File -Filter "*.vcs-template.json" |
        Where-Object { Test-ObsMarkerPath -Path $_.FullName }

      if (-not $templates) {
        Write-VcsMessage -Message "No matching *.vcs-template.json files found under: $InputPath" `
          -Color Yellow
        return
      }

      Write-VcsMessage -AsVerbose -Message ("Found $($templates.Count) matching " `
          + "*.vcs-template.json file(s) under: $InputPath")
      foreach ($template in $templates) {
        try {
          ConvertFrom-ObsTemplate `
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
      -Backup:$Backup `
      -ReplacedCount ([ref]$vcsReplacedCount) `
      -FormatQueue $vcsFormatQueue

  } finally {
    if ($isRootCall) {
      if ($vcsFormatQueue.Count -gt 0) {
        Format-JsonWithPrettier -FilePaths $vcsFormatQueue
      }
      Write-VcsMessage -Message "Replaced $vcsReplacedCount token(s)" -Color Cyan
      $vcsReplacedCount = $null
    }
  }
}

Write-VcsMessage -NoLog -Message ""
Write-VcsMessage -Message "OBS Templater:" -Color Yellow

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
  $obsRoots.Path -join "`n"
)")

Write-VcsMessage -NoLog -Message ("  ConvertTo-ObsTemplate 'scenes.json'                         " +
  "       # Creates vcs-template.json")

Write-VcsMessage -NoLog -Message ("  ConvertTo-ObsTemplate 'folder' (or '.')                     " +
  "       # Recursively creates vcs-template.json for every matching .json under folder")

Write-VcsMessage -NoLog -Message ("  ConvertFrom-ObsTemplate 'scenes.vcs-template.json'          " +
  "       # Creates scenes.json")

Write-VcsMessage -NoLog -Message ("  ConvertFrom-ObsTemplate 'folder' (or '.')                   " +
  "       # Recursively restores every matching *.vcs-template.json under folder")

Export-ModuleMember -Function ConvertTo-ObsTemplate, ConvertFrom-ObsTemplate
Write-VcsMessage -NoLog -Message "OBS Templater functions loaded!" -Color Green

