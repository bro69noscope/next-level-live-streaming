function Write-ThrowContext {
  <#
    .SYNOPSIS
        Writes the throwing file and full call stack to host. Call this
        immediately before any `throw` to get diagnostic context in the console.
    #>
  [CmdletBinding()]
  param()

  Write-Host "  Error thrown from: $PSCommandPath" -ForegroundColor Red
  Write-Host "  Call stack:" -ForegroundColor Red
  Get-PSCallStack | ForEach-Object {
    Write-Host "    at $($_.FunctionName) in $($_.ScriptName):$($_.ScriptLineNumber)" `
      -ForegroundColor Red
  }
}

Export-ModuleMember -Function Write-ThrowContext
