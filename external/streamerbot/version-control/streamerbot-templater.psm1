# Used to create an editable template from a Streamer.bot "actions/settings.json" file.
. "$PSScriptRoot\streamerbot-vcs-paths.bro.ps1"
Import-Module $HelpersModulePath -Force

Get-ChildItem "$PSScriptRoot\streamerbot-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "streamerbot-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

$script:DefaultVcsOutPath = Join-Path $PSScriptRoot "vcdata"

$mappings = Read-ReplacementMappings `
  -CommonMappingsPath $script:CommonMappingsPath `
  -MappingsPath $script:MappingsPath `
  -PortsMappingPaths @($script:PortsPath)

Write-Host "Ports: '$script:PortsPath'"

function Assert-StreamerbotPath {
  param([Parameter(Mandatory=$true)][string]$Path)

  $valid = $script:StreamerbotBasePaths | Where-Object {
    $Path.StartsWith(
      $_,
      [System.StringComparison]::OrdinalIgnoreCase
    )
  }

  if (-not $valid) {
    throw "This function must target files under:`n$(
      $script:StreamerbotBasePaths -join "`n"
    )`nCurrent target: $Path"
  }
}


function Format-JsonWithPrettier {
  param([string]$FilePath)

  if (-not (Test-Path $script:PrettierPath)) {
    Write-Host "Warning: Prettier not found at $script:PrettierPath. Skipping
    formatting." -ForegroundColor Yellow
    return
  }

  & $script:PrettierPath --write $FilePath
}

function ConvertTo-StreamerbotTemplate {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath,
    [Parameter(Mandatory=$false)] [string]$VcsRelativePath
  )
  $InputFilePath = (Resolve-Path $InputFilePath).Path
  Assert-StreamerbotPath $InputFilePath

  if (-not $VcsRelativePath) {
    $VcsRelativePath = "vcdata" 
  }
  $vcsOutDirPath = Join-Path $PSScriptRoot $VcsRelativePath

  ConvertTo-VcsTemplateFile `
    -InputFilePath $InputFilePath `
    -VcsOutDirPath $vcsOutDirPath `
    -Mappings $mappings
}

function ConvertFrom-StreamerbotTemplate {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath
  )

  $InputFilePath  = (Resolve-Path $InputFilePath).Path
  $inputFileName  = Split-Path $InputFilePath -Leaf

  Assert-StreamerbotPath $InputFilePath

  if ($InputFilePath -notmatch '\.vcs-template\.json$') {
    throw "Input filename must be like **.vcs-template.json, got: $inputFileName"
  }

  $outPath  = $InputFilePath -replace "\.vcs-template\.json$", ".json"

  Write-Host "Input:  $InputFilePath"
  Write-Host "Output: $outPath"

  if (Test-Path $outPath) {
    $backupPath = "$outPath.bak"
    Copy-Item $outPath $backupPath -Force
    Write-Host "Backup saved: $backupPath" -ForegroundColor Magenta
  }

  $content = Get-Content $InputFilePath -Raw

  foreach ($entry in $mappings.GetEnumerator()) {
    $token     = $entry.Key
    $localPath = $entry.Value
    $isNumeric = ([string]$localPath) -match '^\d+$'

    if ($isNumeric) {
      $quotedTokenPattern = [regex]::Escape("`"$token`"")
      if ($content -match $quotedTokenPattern) {
        $content = $content -replace $quotedTokenPattern, $localPath
        Write-Host "  Replaced: `"$token`" -> $localPath" -ForegroundColor DarkCyan
      }
    } elseif ($content -match [regex]::Escape($token)) {
      $content = $content -replace [regex]::Escape($token), $localPath
      Write-Host "  Replaced: $token -> $localPath" -ForegroundColor DarkCyan
    }
  }

  $unresolvedMatches = [regex]::Matches($content, '\{\{[A-Z0-9_]+\}\}') |
    Select-Object -ExpandProperty Value -Unique
  foreach ($unresolved in $unresolvedMatches) {
    Write-Host "Warning: No mapping found for token $unresolved — left as-is" `
      -ForegroundColor Yellow
  }

  $content | Set-Content $outPath -Encoding UTF8
  Format-JsonWithPrettier -FilePath $outPath
  Write-Host "Real config saved: $outPath" -ForegroundColor Green
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


