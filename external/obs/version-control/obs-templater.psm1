# Used to create an editable template from an OBS "scenes.json" file.
. "$PSScriptRoot\obs-vcs-paths.bro.ps1"
Import-Module $HelpersModulePath -Force

Get-ChildItem "$PSScriptRoot\obs-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "obs-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$script:DefaultVcsOutPath = Join-Path $PSScriptRoot "scenes"

$mappings = Read-ReplacementMappings `
  -CommonMappingsPath $script:CommonMappingsPath `
  -MappingsPath $script:MappingsPath `
  -PortsMappingPaths @($script:PortsPath)

function Get-VcsRelativePath {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath
  )
  $relative = $InputFilePath.Substring(
    $script:ObsBasePath.Length
  ).TrimStart('\')
  $parts = $relative -split '\\'
  $dirOnlyParts = $parts[0..($parts.Count - 2)]

  foreach ($marker in @("scenes", "profiles", "plugin_config")) {
    $index = $dirOnlyParts.IndexOf($marker)
    if ($index -ge 0) {
      $dirParts = $dirOnlyParts[($index + 1)..($dirOnlyParts.Count - 1)]
      if ($dirParts.Count -eq 0 -or $index -eq $dirOnlyParts.Count - 1) {
        return $marker
      }
      return Join-Path $marker ($dirParts -join '\')
    }
  }
  throw "Unknown OBS config location: $relative"
}

function Assert-ObsPath {
  param([Parameter(Mandatory=$true)][string]$Path)

  $valid = $script:ObsBasePath | Where-Object {
    $Path.StartsWith(
      $_,
      [System.StringComparison]::OrdinalIgnoreCase
    )
  }

  if (-not $valid) {
    throw "This function must target files under:`n$(
      $script:ObsBasePath -join "`n"
    )`nCurrent target: $Path"
  }
}

function ConvertTo-ObsTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath,

    [Parameter(Mandatory=$false)]
    [string]$VcsRelativePath
  )

  $InputFilePath = (Resolve-Path $InputFilePath).Path
  Assert-ObsPath $InputFilePath

  if (-not $VcsRelativePath) {
    $VcsRelativePath = Get-VcsRelativePath $InputFilePath
  }

  $vcsOutDirPath = Join-Path $PSScriptRoot "vcdata"
  $vcsOutDirPath = Join-Path $vcsOutDirPath $VcsRelativePath

  ConvertTo-VcsTemplateFile `
    -InputFilePath $InputFilePath `
    -VcsOutDirPath $vcsOutDirPath `
    -Mappings $mappings
}

function ConvertFrom-ObsTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath,
    [Parameter(Mandatory=$false)]
    [switch]$Backup
  )

  $InputFilePath = (Resolve-Path $InputFilePath).Path
  Assert-ObsPath $InputFilePath

  ConvertFrom-VcsTemplateFile `
    -InputFilePath $InputFilePath `
    -Mappings $mappings `
    -Backup:$Backup
}

Write-Host ""
Write-Host "OBS Templater functions loaded!" -ForegroundColor Green

Write-Host "Mappings:" -ForegroundColor Cyan
$mappings.GetEnumerator() | ForEach-Object {
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

