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

$mappings = Read-ReplacementMappings `
  -CommonMappingsPath $script:CommonMappingsPath `
  -MappingsPath $script:MappingsPath `
  -ScopedMappingsPaths @($script:PortsPath)

function ConvertTo-StreamerbotTemplate {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath
  )

  $InputFilePath = (Resolve-Path $InputFilePath).Path
  Assert-InputPath $InputFilePath -Roots $streamerbotRoots

  $VcsRelativePath = Get-VcsRelativePath `
    -InputFilePath $InputFilePath `
    -Roots $streamerbotRoots `
    -Markers @("data") `
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

  ConvertFrom-VcsTemplateFile `
    -InputFilePath $InputFilePath `
    -Rules $mappings `
    -Backup:$Backup
}

Write-Host ""
Write-Host "Streamer.bot Templater functions loading..." -ForegroundColor Yellow

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
Write-Host "  All input files must be under:`n$(
  $script:StreamerbotBasePaths -join "`n"
)"
Write-Host "  Default VCS outPath: $script:DefaultVcsOutPath"
Write-Host "  ConvertTo-StreamerbotTemplate 'actions.json'                # Creates vcs-template.json"
Write-Host "  ConvertFrom-StreamerbotTemplate 'actions.vcs-template.json' # Creates actions.json"

Export-ModuleMember -Function ConvertTo-StreamerbotTemplate, ConvertFrom-StreamerbotTemplate
Write-Host "Streamer.bot Templater functions loaded!" -ForegroundColor Green


