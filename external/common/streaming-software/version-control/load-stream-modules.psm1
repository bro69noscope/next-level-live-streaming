function Import-StreamingTemplatesModules {
  try {
    if (-not $Global:RepoPath) {
      $Global:RepoPath = Find-RepoRoot
    }

    $repo = $Global:RepoPath.TrimEnd('\')
    Import-Module "$repo\external\common\helpers\ps1\helpers.psm1" -Force

    $modules = [ordered]@{
      OBS = Join-Path $repo `
        "external\obs\version-control\obs-templater.psm1"

      StreamDeck = Join-Path $repo `
        "external\streamdeck\version-control\streamdeck-templater.psm1"

      StreamerBot = Join-Path $repo `
        "external\streamerbot\version-control\streamerbot-templater.psm1"

      Orchestrator = Join-Path $repo `
        "external\common\streaming-software\version-control\vcs-orchestrator.psm1"
    }

    foreach ($module in $modules.GetEnumerator()) {
      if (-not (Test-Path $module.Value)) {
        Write-ThrowContext
        throw "$($module.Key) module not found at: $($module.Value)"
      }
      try {
        Import-Module $module.Value -Force -Global -ErrorAction Stop
      } catch {
        Write-ThrowContext
        Write-Host "Failed to load $($module.Key) module: $($_.Exception.Message)" -ForegroundColor Red
        throw
      }
    }
    Write-Host "Streaming tools loaded!" -ForegroundColor Green
  } catch {
    Write-Host "Import-StreamingTemplatesModules failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
  }
  Write-Host "Streaming tools loaded!" -ForegroundColor Green
}

Export-ModuleMember -Function Import-StreamingTemplatesModules
