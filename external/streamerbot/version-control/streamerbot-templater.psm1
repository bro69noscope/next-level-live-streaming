# Used to create an editable template from a Streamer.bot "actions/settings.json" file.
. "$PSScriptRoot\streamerbot-vcs-paths.bro.ps1"
Import-Module $HelpersModulePath -Force

Get-ChildItem "$PSScriptRoot\streamerbot-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "streamerbot-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$script:DefaultVcsOutPath = Join-Path $PSScriptRoot "vcdata"

$script:streamerbotRoots = @(
  @{
    Path = $script:StreamerbotFtpPath
    Name = "ftp"
  },
  @{
    Path = $script:StreamerbotProductionPath
    Name = "production"
  }
)

function Get-StreamerbotVcsPath {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath
  )

  Get-VcsRelativePath `
    -InputFilePath $InputFilePath `
    -Roots $streamerbotRoots `
    -Markers @("data") `
    -AppName "Streamer.bot"
}

$mappings = Read-ReplacementMappings `
  -CommonMappingsPath $script:CommonMappingsPath `
  -MappingsPath $script:MappingsPath `
  -PortsMappingPaths @($script:PortsPath)

function Assert-StreamerbotPath {
  param([Parameter(Mandatory=$true)][string]$Path)

  $valid = $streamerbotRoots | Where-Object {
    $Path.StartsWith(
      $_.Path,
      [System.StringComparison]::OrdinalIgnoreCase
    )
  }

  if (-not $valid) {
    Write-Host "This function must target files under:" -ForegroundColor Red
    $streamerbotRoots.Path | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "Current target: $Path" -ForegroundColor Red
    throw "Invalid target path: $Path"
  }
}


function ConvertTo-StreamerbotTemplate {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath,
    [Parameter(Mandatory=$false)] [string]$VcsRelativePath
  )
  $InputFilePath = (Resolve-Path $InputFilePath).Path
  Assert-StreamerbotPath $InputFilePath

  if (-not $VcsRelativePath) {
    $VcsRelativePath = Get-StreamerbotVcsPath $InputFilePath
  }

  $vcsOutDirPath = Join-Path $PSScriptRoot "vcdata"
  $vcsOutDirPath = Join-Path $vcsOutDirPath $VcsRelativePath

  ConvertTo-VcsTemplateFile `
    -InputFilePath $InputFilePath `
    -VcsOutDirPath $vcsOutDirPath `
    -Mappings $mappings
}

function ConvertFrom-StreamerbotTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath,
    [Parameter(Mandatory=$false)]
    [switch]$Backup
  )

  $InputFilePath = (Resolve-Path $InputFilePath).Path
  Assert-StreamerbotPath $InputFilePath

  ConvertFrom-VcsTemplateFile `
    -InputFilePath $InputFilePath `
    -Mappings $mappings `
    -Backup:$Backup
}

Write-Host ""
Write-Host "Streamer.bot Templater functions loaded!" -ForegroundColor Green

Write-Host "Mappings:" -ForegroundColor Cyan
$mappings.GetEnumerator() | ForEach-Object {
  Write-Host "  $($_.Key) => $($_.Value)"
}

Write-Host "Script location:" -ForegroundColor Cyan
Write-Host "  $PSScriptRoot"

Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  All input files must be under:`n$(
  $script:StreamerbotBasePaths -join "`n"
)"
Write-Host "  Default VCS outPath: $script:DefaultVcsOutPath"
Write-Host "  ConvertTo-StreamerbotTemplate 'actions.json'                # Creates vcs-template.json"
Write-Host "  ConvertTo-StreamerbotTemplate 'actions.json' 'custom/path'  # Uses custom out path relative to this script location"
Write-Host "  ConvertFrom-StreamerbotTemplate 'actions.vcs-template.json' # Creates actions.json"

Export-ModuleMember -Function ConvertTo-StreamerbotTemplate, ConvertFrom-StreamerbotTemplate


