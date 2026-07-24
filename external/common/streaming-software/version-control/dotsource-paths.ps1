. "$PSScriptRoot\common-vcs-paths.bro.ps1"

Get-ChildItem "$PSScriptRoot\common-vcs-paths*.ps1" |
  Where-Object { $_.Name -ne "common-vcs-paths.bro.ps1" } |
  ForEach-Object {
    . $_.FullName
  }

