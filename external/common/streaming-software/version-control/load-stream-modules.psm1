. "$PSScriptRoot\dotsource-paths.ps1"
Import-Module "$PSScriptRoot\healthcheck.psm1" -Force

function Import-StreamingTemplatesModules {
  $repo = $Script:repoPath.TrimEnd('\')
  $modules = @{
    OBS = Join-Path $repo `
      "external\obs\version-control\obs-templater.psm1"

    StreamDeck = Join-Path $repo `
      "external\streamdeck\version-control\streamdeck-templater.psm1"

    StreamerBot = Join-Path $repo `
      "external\streamerbot\version-control\streamerbot-templater.psm1"
  }

  foreach ($module in $modules.GetEnumerator()) {
    if (-not (Test-Path $module.Value)) {
      throw "$($module.Key) module not found at: $($module.Value)"
    }

    Import-Module $module.Value -Force -Global
  }

  Write-Host "Streaming tools loaded!" -ForegroundColor Green
  Write-Host "Healthcheck:" -ForegroundColor Cyan
  Write-Host "  Streamerbot:" -ForegroundColor Cyan
  Test-StreamerbotDllSymlinks
}

Export-ModuleMember -Function Import-StreamingTemplatesModules
