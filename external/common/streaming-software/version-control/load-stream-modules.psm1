. "$PSScriptRoot\dotsource-common-paths.ps1"

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
      Write-ThrowContext
      throw "$($module.Key) module not found at: $($module.Value)"
    }

    Import-Module $module.Value -Force -Global
  }

  Write-Host "Streaming tools loaded!" -ForegroundColor Green
}

Export-ModuleMember -Function Import-StreamingTemplatesModules
