function Write-ThrowContext {
  <#
    .SYNOPSIS
        Writes the throwing file and full call stack to host. Call this
        immediately before any `throw` to get diagnostic context in the console.
    #>
  [CmdletBinding()]
  param()
  $callStack = Get-PSCallStack
  $caller = $callStack[1]
  $callerFile = Split-Path -Leaf $caller.ScriptName

  $message = ("Error thrown from: $($caller.FunctionName) in " + `
      "$($callerFile):$($caller.ScriptLineNumber)")

  $bold = "$($PSStyle.Bold)$message$($PSStyle.BoldOff)"

  Write-Host $bold -ForegroundColor Red
  Write-Host "  Call stack:" -ForegroundColor Red
  $callStack | Select-Object -Skip 1 | ForEach-Object { # 1 is always this module function, skipped
    Write-Host "    at $($_.FunctionName) in $($_.ScriptName):$($_.ScriptLineNumber)" `
      -ForegroundColor Red
  }
  Write-Host ""
}

Export-ModuleMember -Function Write-ThrowContext
