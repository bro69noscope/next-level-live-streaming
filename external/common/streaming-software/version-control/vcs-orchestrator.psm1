# Orchestrates the full VCS templating pipeline across all apps:
#   1. Regenerates per-consumer scoped port mapping files from ports.json5
#   2. Re-imports each app's templater module (picking up the fresh mappings)
#   3. Runs ConvertTo or ConvertFrom against every known root path for every app
#
# Usage:
#   Import-Module .\vcs-orchestrator.psm1 -Force
#   Invoke-VcsTemplating -Direction To
#   Invoke-VcsTemplating -Direction From -Backup

. "$PSScriptRoot\dotsource-common-paths.ps1"
Import-Module "$script:repoPath\external\pwsh\helpers.psm1" -Force

$script:StreamDeckDir = Join-Path $script:repoPath "external\streamdeck\version-control"
$script:ObsDir = Join-Path $script:repoPath "external\obs\version-control"
$script:StreamerbotDir = Join-Path $script:repoPath "external\streamerbot\version-control"
$script:CommonDir = Join-Path $script:repoPath "external\common\streaming-software\version-control"

$script:PortsGeneratorPath = Join-Path $script:repoPath "src\scripts\generate_scoped_mappings.py"

function Invoke-PortsGeneration {
  param([string]$PythonExe = "py")

  if (-not (Test-Path $script:PortsGeneratorPath)) {
    Write-ThrowContext
    throw "Ports generator script not found: $script:PortsGeneratorPath"
  }

  Write-Host "Regenerating scoped port mappings..." -ForegroundColor Cyan
  & $PythonExe $script:PortsGeneratorPath
  if ($LASTEXITCODE -ne 0) {
    Write-ThrowContext
    throw "generate_scoped_mappings.py failed with exit code $LASTEXITCODE"
  }
}

function Import-VcsTemplaterModules {
  $pathFiles = @(
    (Join-Path $script:StreamDeckDir "dotsource-streamdeck-paths.ps1"),
    (Join-Path $script:ObsDir "dotsource-obs-paths.ps1"),
    (Join-Path $script:StreamerbotDir "dotsource-streamerbot-paths.ps1")
  )

  foreach ($pathFile in $pathFiles) {
    if (-not (Test-Path $pathFile)) {
      Write-ThrowContext
      throw "Path-definitions file not found: $pathFile"
    }
    . $pathFile
  }

  $moduleFiles = @(
    (Join-Path $script:StreamDeckDir "streamdeck-templater.psm1"),
    (Join-Path $script:ObsDir "obs-templater.psm1"),
    (Join-Path $script:StreamerbotDir "streamerbot-templater.psm1")
  )

  foreach ($moduleFile in $moduleFiles) {
    if (-not (Test-Path $moduleFile)) {
      Write-ThrowContext
      throw "Templater module not found: $moduleFile"
    }
    Import-Module $moduleFile -Force -ErrorAction Stop
  }
}

function Get-VcsTargets {
  @(
    @{
      App          = "StreamDeck"
      Paths        = @($script:SdeckBasePath)
      ToFunction   = "ConvertTo-StreamDeckTemplate"
      FromFunction = "ConvertFrom-StreamDeckTemplate"
      ParamName    = "InputFilePath"
    },
    @{
      App          = "OBS"
      Paths        = @($script:ObsVcamPath, $script:ObsFtpPath, $script:ObsProductionPath)
      ToFunction   = "ConvertTo-ObsTemplate"
      FromFunction = "ConvertFrom-ObsTemplate"
      ParamName    = "InputFilePath"
    },
    @{
      App          = "Streamer.bot"
      Paths        = @($script:SbotFtpPath, $script:SbotProductionPath)
      ToFunction   = "ConvertTo-StreamerbotTemplate"
      FromFunction = "ConvertFrom-StreamerbotTemplate"
      ParamName    = "InputFilePath"
    }
  )
}

function Invoke-VcsTemplating {
  param(
    [Parameter(Mandatory=$true)] [ValidateSet("To", "From")] [string]$Direction,
    [Parameter(Mandatory=$false)] [switch]$Backup,
    [Parameter(Mandatory=$false)] [switch]$SkipPortsGeneration
  )

  if (-not $SkipPortsGeneration) {
    Invoke-PortsGeneration
  }

  Import-VcsTemplaterModules
  $targets = Get-VcsTargets

  $failures = @()

  foreach ($target in $targets) {
    Write-Host ""
    Write-Host "== $($target.App) (Convert-$Direction) ==" -ForegroundColor Magenta

    $functionName = if ($Direction -eq "To") {
      $target.ToFunction
    } else {
      $target.FromFunction
    }

    foreach ($path in $target.Paths) {
      if ([string]::IsNullOrWhiteSpace($path)) {
        continue
      }
      if (-not (Test-Path $path)) {
        Write-Host "  Skipping missing path: $path" -ForegroundColor Yellow
        continue
      }

      Write-Host "  -> $path" -ForegroundColor Cyan

      $callParams = @{ $target.ParamName = $path }
      if ($Direction -eq "From") {
        $callParams["Backup"] = [bool]$Backup
      }

      try {
        & $functionName @callParams
      } catch {
        Write-Host "  Failed: $path" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        $failures += [PSCustomObject]@{ App = $target.App; Path = $path; Error = $_.Exception.Message }
      }
    }
  }

  Write-Host ""
  if ($failures.Count -gt 0) {
    Write-Host "Completed with $($failures.Count) failure(s):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  [$($_.App)] $($_.Path): $($_.Error)" -ForegroundColor Red }
  } else {
    Write-Host "All targets completed successfully." -ForegroundColor Green
  }

  return $failures
}

Write-Host ""
Write-Host "VCS Orchestrator functions loaded" -ForegroundColor Green
write-Host "Usage:" -ForegroundColor Cyan
write-Host "  Invoke-VcsTemplating -Direction To [-SkipPortsGeneration]   # Regenerates ports and converts to vcs-template.json"
write-Host "  Invoke-VcsTemplating -Direction From [-Backup]              # Converts from vcs-template.json to original files"
Export-ModuleMember -Function Invoke-VcsTemplating, Invoke-PortsGeneration
