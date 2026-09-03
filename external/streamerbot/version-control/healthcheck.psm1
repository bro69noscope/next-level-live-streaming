function Test-StreamerbotDllSymlinks {
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline)]
    [string[]]$Path
  )

  process {
    foreach ($p in $Path) {
      $item = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue

      if (-not $item) {
        Write-Warning "MISSING: $p"
        continue
      }

      if (-not ($item.LinkType -eq 'SymbolicLink')) {
        Write-Warning "NOT A SYMLINK: $p"
        continue
      }

      $target = $item.Target
      if (-not $target -or -not (Test-Path -LiteralPath $target)) {
        Write-Warning "BROKEN LINK: $p -> $target"
        continue
      }

      Write-Host "OK: $p -> $target" -ForegroundColor Green
    }
  }
}

Export-ModuleMember -Function Test-StreamerbotDllSymlinks
