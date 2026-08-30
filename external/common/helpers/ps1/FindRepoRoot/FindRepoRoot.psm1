$script:MarkFile = ".project-root"

function Find-RepoRoot {
  param([string]$StartPath = $PWD.Path)

  $current = $StartPath
  while ($current) {
    if (Test-Path (Join-Path $current $script:MarkFile)) {
      return $current
    }
    $parent = Split-Path $current -Parent
    if ($parent -eq $current) {
      break
    }
    $current = $parent
  }

  Get-PSCallStack | Out-String | Write-Host -ForegroundColor Red
  throw "Could not find $script:MarkFile file starting from: $StartPath"
}

Export-ModuleMember -Function Find-RepoRoot
