# Used to create an editable template from an OBS "scenes.json" file.
. "$PSScriptRoot\obs-vcs-paths.bro.ps1"
Import-Module $HelpersModulePath -Force

Get-ChildItem "$PSScriptRoot\obs-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "obs-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$script:DefaultVcsOutPath = Join-Path $PSScriptRoot "scenes"

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
  -CommonMappingsPath $script:CommonMappingsPath `
  -MappingsPath $script:MappingsPath `
  -PortsMappingPaths @($script:PortsPath)

function Get-ObsVcsPath {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath
  )

  Get-VcsRelativePath `
    -InputFilePath $InputFilePath `
    -Roots $obsRoots `
    -Markers @(
    "scenes",
    "profiles",
    "plugin_config"
  ) `
    -AppName "OBS"
}

function Assert-ObsPath {
  param([Parameter(Mandatory=$true)][string]$Path)

  $valid = $obsRoots | Where-Object {
    $Path.StartsWith(
      $_.Path,
      [System.StringComparison]::OrdinalIgnoreCase
    )
  }

  if (-not $valid) {
    Write-Host "This function must target files under:" -ForegroundColor Red
    $obsRoots.Path | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "Current target: $Path" -ForegroundColor Red
    throw "Invalid target path: $Path"
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
    $VcsRelativePath = Get-ObsVcsPath $InputFilePath
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
Write-Host "  All input files must be under:`n  $($obsRoots.Path -join "`n  ")"
Write-Host "  Default VCS outPath: $script:DefaultVcsOutPath"
Write-Host "  ConvertTo-ObsTemplate 'scenes.json'                # Creates vcs-template.json"
Write-Host "  ConvertTo-ObsTemplate 'scenes.json' 'custom/path'  # Uses custom out path relative to this script location"
Write-Host "  ConvertFrom-ObsTemplate 'scenes.vcs-template.json' # Creates scenes.json"

Export-ModuleMember -Function ConvertTo-ObsTemplate, ConvertFrom-ObsTemplate

