# Used to create an editable template from a Streamer.bot "actions/settings.json" file.
if (-not $Global:RepoPath) {
  $Global:RepoPath = Find-RepoRoot -StartPath $PSScriptRoot
}

. "$RepoPath\external\common\streaming-software\version-control\init.ps1"

try {
  . "$PSScriptRoot\dotsource-streamerbot-paths.ps1"
} catch {
  Write-VcsMessage -Message "Failed to load Streamer.bot paths: $($_.Exception.Message)" -Color Red
  throw
}

Import-Module "$PSScriptRoot\healthcheck.psm1" -Force

$script:streamerbotRoots = @(
  @{
    Path = $script:SbotFtpPath
    Name = "ftp"
  },
  @{
    Path = $script:SbotProductionPath
    Name = "production"
  }
)

$script:SbotCsharpTestMode = $true
$script:SbotCsharpTestSources = @(
  "vcdata\common\csharp\SubActions\Production\General\Tests"
)

# Every .cs files source must live under <SubActionsRoot>\<one of the environment folders>\.
$script:SbotCsharpSubActionsRoot = "vcdata\common\csharp\SubActions"
$script:SbotCsharpEnvDirs = @("Common", "Ftp", "Production")

$script:SbotCsharpEnvDirsByRoot = @{
  ftp        = @("Common", "Ftp")
  production = @("Common", "Production")
}

$script:SbotCsharpExcludedDirs = @("bin", "obj")

# <Name>.shadow.csproj flag => the "references" entry Streamer.bot needs to compile <Name>.cs.
# The path is relative to the Streamer.bot folder, as Streamer.bot itself stores it.
$script:SbotCsharpReferenceByFlag = [ordered]@{
  SbotRefBroStreamerTools = ".\dlls\BroStreamerTools.dll"
  SbotRefNewtonsoftJson   = ".\Newtonsoft.Json.dll"
}

$mappings = Read-ReplacementMappings `
  -CommonMappingsPath $script:CommonUserMappingsPath `
  -MappingsPath $script:SbotMappingsPath `
  -ScopedMappingsPaths @($script:SbotScopedPath)

$script:SbotMarkers = @("data")
$script:SbotFileAllowlist = @("obs.json", "settings.json", "actions.json")
$script:SbotTestSuffixPattern = '_(fake|test)\.json$'

function Test-StreamerbotMarkerPath {
  param([Parameter(Mandatory=$true)] [string]$Path)

  $parts = $Path -split '\\'
  if ([array]::IndexOf($parts, "data") -lt 0) {
    return $false
  }

  $baseFileName = $parts[-1] -replace '\.vcs-template\.json$', '' -replace '\.json$', ''

  return (
    $script:SbotFileAllowlist -contains "$baseFileName.json" -or
    "$baseFileName.json" -match $script:SbotTestSuffixPattern
  )
}

# PascalCase folder name => action name, e.g. TestBytecode => sbact__TestBytecode
function ConvertTo-StreamerbotActionName {
  param([Parameter(Mandatory=$true)] [string]$FolderName)

  return "sbact__$FolderName"
}

function Get-StreamerbotCsharpSearchPaths {
  param(
    [Parameter(Mandatory=$true)] [bool]$TestMode,
    [Parameter(Mandatory=$true)] [AllowEmptyCollection()] [string[]]$EnvDirs
  )

  if ($TestMode) {
    return $script:SbotCsharpTestSources
  }

  return $EnvDirs | ForEach-Object {
    Join-Path $script:SbotCsharpSubActionsRoot $_
  }
}

function Get-StreamerbotRootFor {
  param([Parameter(Mandatory=$true)] [string]$ActionsFilePath)

  return $script:streamerbotRoots | Where-Object {
    $ActionsFilePath.StartsWith("$($_.Path)\", [System.StringComparison]::OrdinalIgnoreCase)
  } | Select-Object -First 1
}

function Get-StreamerbotCsharpEnvDirsFor {
  param([Parameter(Mandatory=$true)] [string]$ActionsFilePath)

  $root = Get-StreamerbotRootFor -ActionsFilePath $ActionsFilePath

  if (-not $root -or -not $script:SbotCsharpEnvDirsByRoot.ContainsKey($root.Name)) {
    Write-ThrowContext
    throw ("C# directory structure mismatch: no environment folders known for '$ActionsFilePath'" +
      " (it must be under one of: $(($script:streamerbotRoots.Path) -join ', '))")
  }

  return $script:SbotCsharpEnvDirsByRoot[$root.Name]
}

function Assert-StreamerbotCsharpLayout {
  param([Parameter(Mandatory=$true)] [string[]]$SearchPaths)

  $root = Join-Path $PSScriptRoot $script:SbotCsharpSubActionsRoot
  $expected = $script:SbotCsharpEnvDirs -join ", "

  if (-not (Test-Path $root -PathType Container)) {
    Write-ThrowContext
    throw "C# directory structure mismatch: SubActions folder not found: $root"
  }

  $children = (Get-ChildItem $root -Directory).Name
  $missing = $script:SbotCsharpEnvDirs | Where-Object { $children -notcontains $_ }
  if ($missing) {
    Write-ThrowContext
    throw ("C# directory structure mismatch: $root must contain $expected, " +
      "missing: $($missing -join ', ')")
  }

  foreach ($relPath in $SearchPaths) {
    $path = Join-Path $PSScriptRoot $relPath
    $underEnv = $script:SbotCsharpEnvDirs | Where-Object {
      ("$path\").StartsWith("$root\$_\", [System.StringComparison]::OrdinalIgnoreCase)
    }
    if (-not $underEnv) {
      Write-ThrowContext
      throw "C# directory structure mismatch: source '$relPath' is not under $root\<$expected>"
    }
  }
}

function Get-StreamerbotCsharpSourcePaths {
  param(
    [Parameter(Mandatory=$true)] [string]$ActionsFilePath,
    [bool]$TestMode = $script:SbotCsharpTestMode
  )

  $envDirs = @()
  if (-not $TestMode) {
    $envDirs = @(Get-StreamerbotCsharpEnvDirsFor -ActionsFilePath $ActionsFilePath)
  }
  $searchPaths = @(Get-StreamerbotCsharpSearchPaths -TestMode $TestMode -EnvDirs $envDirs)
  Assert-StreamerbotCsharpLayout -SearchPaths $searchPaths

  foreach ($relPath in $searchPaths) {
    $path = Join-Path $PSScriptRoot $relPath
    if (Test-Path $path -PathType Container) {
      (Get-ChildItem $path -Recurse -File -Filter "*.cs" |
        Where-Object {
          $parts = $_.FullName -split '\\'
          -not ($parts | Where-Object { $script:SbotCsharpExcludedDirs -contains $_ })
        }).FullName
    } elseif (Test-Path $path -PathType Leaf) {
      $path
    } else {
      Write-VcsMessage -Message "C# source not found, skipping: $path" -Color Yellow
    }
  }
}

# Action name => PascalCase folder name, e.g. sbact__TestBytecode => TestBytecode
function ConvertTo-StreamerbotFolderName {
  param([Parameter(Mandatory=$true)] [string]$ActionName)

  return $ActionName -replace '^sbact__', ''
}

function Get-StreamerbotLineNumber {
  param(
    [Parameter(Mandatory=$true)] [string]$Content,
    [Parameter(Mandatory=$true)] [int]$Index
  )

  return [regex]::Matches($Content.Substring(0, $Index), "`n").Count + 1
}

# C# sub-actions is type 99999 in sbot, including the ones nested inside groups.
function Get-StreamerbotCsharpSubActions {
  param([Parameter(Mandatory=$true)] [object[]]$SubActions)

  foreach ($sub in $SubActions) {
    if ($sub.type -eq 99999) {
      $sub
    }
    if ($sub.subActions) {
      Get-StreamerbotCsharpSubActions -SubActions $sub.subActions
    }
  }
}

function Write-StreamerbotCsharpOrphanReport {
  param(
    [Parameter(Mandatory=$true)] [string]$ActionsFilePath,
    [Parameter(Mandatory=$true)] [AllowEmptyCollection()] [string[]]$SourcePaths
  )

  $content = [System.IO.File]::ReadAllText($ActionsFilePath)
  $actions = ($content | ConvertFrom-Json).actions

  $csFilePathByKey = @{}
  foreach ($sourcePath in $SourcePaths) {
    $folderName = Split-Path (Split-Path $sourcePath -Parent) -Leaf
    $actionName = ConvertTo-StreamerbotActionName -FolderName $folderName
    $csFilePathByKey["$actionName|$(Split-Path $sourcePath -Leaf)"] = $sourcePath
  }

  # Test mode: only flag actions that have a folder under the test sources (Tests\...).
  $testActionNames = @()
  if ($script:SbotCsharpTestMode) {
    $testActionNames = @($script:SbotCsharpTestSources | ForEach-Object {
        Get-ChildItem (Join-Path $PSScriptRoot $_) -Directory -Recurse -ErrorAction SilentlyContinue
      } | ForEach-Object {
        ConvertTo-StreamerbotActionName -FolderName $_.Name
      })
  }

  $jsonSubActionKeys = @{}
  $withoutFile = [System.Collections.Generic.List[string]]::new()

  foreach ($action in $actions) {
    if (-not $action.subActions) {
      continue
    }

    foreach ($sub in (Get-StreamerbotCsharpSubActions -SubActions $action.subActions)) {
      if ([string]::IsNullOrEmpty($action.name)) {
        $actionIdMatch = [regex]::Match($content, '"id":\s*"' + [regex]::Escape($action.id) + '"')
        $actionLine = if ($action.id -and $actionIdMatch.Success) {
          "$(Get-StreamerbotLineNumber -Content $content -Index $actionIdMatch.Index) (id line)"
        } else {
          "unknown"
        }
        $withoutFile.Add("line $actionLine  action <no name>  sub-action '$($sub.name)'")
        continue
      }

      if ($script:SbotCsharpTestMode -and $action.name -notin $testActionNames) {
        continue
      }

      $key = "$($action.name)|$($sub.name)"
      $jsonSubActionKeys[$key] = $true
      if ($csFilePathByKey.ContainsKey($key)) {
        continue
      }

      $idMatch = [regex]::Match($content, '"id":\s*"' + [regex]::Escape($sub.id) + '"')
      $nameIdx = $content.LastIndexOf('"name"', $idMatch.Index)

      $ownName = $nameIdx -ge 0 -and
      $content.Substring($nameIdx, $idMatch.Index - $nameIdx) -match
      ('^"name":\s*"' + [regex]::Escape($sub.name) + '"[^{}]*$')

      $line = if ($ownName) {
        Get-StreamerbotLineNumber -Content $content -Index $nameIdx
      } else {
        $idLine = Get-StreamerbotLineNumber -Content $content -Index $idMatch.Index
        Write-VcsMessage -Message ("Could not locate the name line of sub-action " +
          "'$($sub.name)' in '$($action.name)': ""name"" is not before ""id"" as expected. " +
          "Showing the id line ($idLine) instead.") -Color Yellow
        "$idLine (id line)"
      }
      $folder = ConvertTo-StreamerbotFolderName -ActionName $action.name
      $withoutFile.Add("line $line  action '$($action.name)'  sub-action '$($sub.name)'" +
        "  (expected file: $folder\$($sub.name))")
    }
  }

  $instance = (Get-StreamerbotRootFor -ActionsFilePath $ActionsFilePath).Name

  $otherEnvTemplates = @{}
  foreach ($otherRoot in ($script:streamerbotRoots | Where-Object { $_.Name -ne $instance })) {
    $templatePath = Join-Path $PSScriptRoot (
      "vcdata\$($otherRoot.Name)\data\actions.vcs-template.json")
    if (Test-Path $templatePath -PathType Leaf) {
      $otherEnvTemplates[$otherRoot.Name] = [System.IO.File]::ReadAllText($templatePath)
    } else {
      Write-VcsMessage -Message "Other environment template not found: $templatePath" -Color Red
    }
  }

  $withoutSubAction = [System.Collections.Generic.List[string]]::new()
  $otherEnvOnly = [System.Collections.Generic.List[string]]::new()
  foreach ($key in $csFilePathByKey.Keys) {
    if ($jsonSubActionKeys.ContainsKey($key)) {
      continue
    }

    $actionName, $subActionName = $key -split '\|', 2
    $subActionsRoot = Join-Path $PSScriptRoot $script:SbotCsharpSubActionsRoot
    $relPath = $csFilePathByKey[$key] -replace ('^' + [regex]::Escape("$subActionsRoot\")), ''
    $namePattern = '"name":\s*"' + [regex]::Escape($actionName) + '"'
    $actionMatch = [regex]::Match($content, $namePattern)

    if ($actionMatch.Success) {
      $line = Get-StreamerbotLineNumber -Content $content -Index $actionMatch.Index
      $withoutSubAction.Add("$relPath  ->  action '$actionName' (line $line) has no C# sub-action" +
        " named '$subActionName'")

    } else {
      $presentIn = @()
      if ($relPath -match '^Common\\') {
        $presentIn = @($otherEnvTemplates.Keys | `
              Where-Object { $otherEnvTemplates[$_] -match $namePattern })
      }
      if ($presentIn.Count -gt 0) {
        $otherEnvOnly.Add("$relPath  ->  action '$actionName' only in: $($presentIn -join ', ')")
      } else {
        $withoutSubAction.Add("$relPath  ->  action '$actionName' not found in actions file")
      }
    }
  }

  $withoutCsproj = [System.Collections.Generic.List[string]]::new()
  $subActionsRoot = Join-Path $PSScriptRoot $script:SbotCsharpSubActionsRoot
  foreach ($sourcePath in $SourcePaths) {
    $csprojPath = [System.IO.Path]::ChangeExtension($sourcePath, ".shadow.csproj")
    if (-not (Test-Path $csprojPath -PathType Leaf)) {
      $withoutCsproj.Add(($sourcePath -replace ('^' + [regex]::Escape("$subActionsRoot\")), ''))
    }
  }

  $report = @(
    "Streamer.bot C# orphans, generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "Instance: $instance"
    "Actions file: $ActionsFilePath"
    "(line numbers also apply to the matching .vcs-template.json)"
    if ($script:SbotCsharpTestMode) {
      ""
      "=== TEST MODE: only actions with a folder in list below: ==="
      $script:SbotCsharpTestSources | ForEach-Object { "  $_" }
    }
    ""
    ""
    "== C# sub-actions without a matching .cs file ($($withoutFile.Count)) =="
    $withoutFile
    ""
    ""
    "== .cs files without a matching C# sub-action ($($withoutSubAction.Count)) =="
    $withoutSubAction | Sort-Object
    ""
    ""
    "== Common .cs files whose action is not in this environment, not orphans " +
    "($($otherEnvOnly.Count)) =="
    $otherEnvOnly | Sort-Object
    ""
    ""
    "== .cs files without a .shadow.csproj, references not managed ($($withoutCsproj.Count)) =="
    $withoutCsproj | Sort-Object
  )

  $reportPath = Join-Path $PSScriptRoot "logs\$instance-csharp-orphans.txt"
  New-Item -ItemType Directory -Force (Split-Path $reportPath -Parent) | Out-Null
  $report | Set-Content $reportPath -Encoding UTF8

  $color = if ($withoutFile.Count + $withoutSubAction.Count -gt 0) {
    "Yellow"
  } else {
    "Green"
  }

  $summary = @(
    "C# orphans:"
    "  $($withoutFile.Count) sub-action(s) without file"
    "  $($withoutSubAction.Count) file(s) without sub-action"
    "  $($otherEnvOnly.Count) Common file(s) for other environment only"
    "  $($withoutCsproj.Count) file(s) without shadow csproj"
    "  Report: $reportPath"
  )
  foreach ($summaryLine in $summary) {
    Write-VcsMessage -Message $summaryLine -Color $color
  }
}

function Get-StreamerbotCsharpRequiredReferences {
  param([Parameter(Mandatory=$true)] [string]$SourcePath)

  $csprojName = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath) + ".shadow.csproj"
  $csprojPath = Join-Path (Split-Path $SourcePath -Parent) $csprojName
  if (-not (Test-Path $csprojPath -PathType Leaf)) {
    # Reported in the orphan report: references are simply not managed for this file.
    return
  }

  $csproj = [xml][System.IO.File]::ReadAllText($csprojPath)
  foreach ($flag in $script:SbotCsharpReferenceByFlag.Keys) {
    $node = $csproj.SelectSingleNode("//$flag")
    if (-not $node) {
      continue
    }

    # The flag is read as plain text here, MSBuild conditions are not evaluated.
    for ($el = $node; $el -is [System.Xml.XmlElement]; $el = $el.ParentNode) {
      if ($el.HasAttribute("Condition")) {
        Write-ThrowContext
        throw ("Conditions in a shadow csproj are not supported yet : <$($el.Name) Condition=" +
          """$($el.GetAttribute('Condition'))""> around $flag in $csprojPath")
      }
    }

    if ($node.InnerText -eq "true") {
      $script:SbotCsharpReferenceByFlag[$flag].Replace('\', '\\')
    }
  }
}

function Get-StreamerbotJsonObjectBounds {
  param(
    [Parameter(Mandatory=$true)] [string]$Text,
    [Parameter(Mandatory=$true)] [int]$Index
  )

  $starts = [System.Collections.Generic.Stack[int]]::new()
  foreach ($token in [regex]::Matches($Text, '"[^"\\]*(?:\\.[^"\\]*)*"|[{}]')) {
    if ($token.Value -eq "{") {
      $starts.Push($token.Index)
    } elseif ($token.Value -eq "}" -and $starts.Count -gt 0) {
      $start = $starts.Pop()
      if ($start -lt $Index -and $Index -lt $token.Index) {
        return [pscustomobject]@{ Start = $start; End = $token.Index }
      }
    }
  }
}

function Set-StreamerbotCsharpBytecode {
  param([Parameter(Mandatory=$true)] [string]$ActionsFilePath)

  $content = [System.IO.File]::ReadAllText($ActionsFilePath)
  $changed = $false

  $sourcePaths = @(Get-StreamerbotCsharpSourcePaths -ActionsFilePath $ActionsFilePath)

  foreach ($sourcePath in $sourcePaths) {
    $folderName = Split-Path (Split-Path $sourcePath -Parent) -Leaf
    $actionName = ConvertTo-StreamerbotActionName -FolderName $folderName
    $subActionName = Split-Path $sourcePath -Leaf # this = SubActionExecuteCodeName from README.md

    # Always CRLF so the bytecode is the same. UTF-8 BOM-less.
    $sourceText = [System.IO.File]::ReadAllText($sourcePath) -replace '\r?\n', "`r`n"
    $b64 = [Convert]::ToBase64String([System.Text.UTF8Encoding]::new($false).GetBytes($sourceText))

    $actionMatch = [regex]::Match($content, '"name":\s*"' + [regex]::Escape($actionName) + '"')
    if (-not $actionMatch.Success) {
      continue
    }

    # The action's own { } : the span is the whole action object, whatever its key order.
    # TODO: perf. This rescans $content from position 0 for every .cs file (~130 ms per call
    # on a 2.3 MB file, so ~130 s for 1000 files). Scan once up front into a lookup of
    # object start -> end, collect the edits against the original text, and apply them
    # last-to-first at the end.
    $actionBounds = Get-StreamerbotJsonObjectBounds -Text $content -Index $actionMatch.Index
    if (-not $actionBounds) {
      $nameLine = Get-StreamerbotLineNumber -Content $content -Index $actionMatch.Index
      Write-VcsMessage -Message ("No enclosing JSON object found around action '$actionName'" +
        " (""name"" at line $nameLine of $ActionsFilePath) : bytecode not injected") `
        -Color Red
      continue
    }

    $actionStart = $actionBounds.Start
    $actionEnd = $actionBounds.End
    $span = $content.Substring($actionStart, $actionEnd - $actionStart + 1)

    $nameMatch = [regex]::Match($span, '"name":\s*"' + [regex]::Escape($subActionName) + '"')
    if (-not $nameMatch.Success) {
      # We will handle this in the orphan report
      continue
    }
    $bounds = Get-StreamerbotJsonObjectBounds -Text $span -Index $nameMatch.Index
    if (-not $bounds) {
      Write-VcsMessage -Message ("No enclosing JSON object found around sub-action" +
        " '$subActionName' of action '$actionName' in $ActionsFilePath" +
        " : bytecode not injected") -Color Red
      continue
    }
    $subObject = $span.Substring($bounds.Start, $bounds.End - $bounds.Start + 1)

    $referencesRe = [regex]::new('("references":\s*\[)([^\]]*)(\])')
    $byteCodeRe = [regex]::new('("byteCode":\s*")[^"]*(")')
    # Type 99900 is a group (holds nested subActions)
    if ($subObject -match '"type":\s*99900') {
      continue
    }
    $missingKeys = @(
      if (-not $referencesRe.IsMatch($subObject)) {
        '"references"'
      }
      if (-not $byteCodeRe.IsMatch($subObject)) {
        '"byteCode"'
      }
    )
    if ($missingKeys.Count -gt 0) {
      Write-VcsMessage -Message ("Sub-action '$subActionName' of action '$actionName' in " +
        "$ActionsFilePath is missing $($missingKeys -join ' and ') : bytecode not injected") `
        -Color Red
      continue
    }

    # Only ever adds missing references: ones added in the GUI are kept.
    $requiredRefs = @(Get-StreamerbotCsharpRequiredReferences -SourcePath $sourcePath)
    $addedRefs = [System.Collections.Generic.List[string]]::new()
    $nl = if ($content.Contains("`r`n")) {
      "`r`n"
    } else {
      "`n"
    }

    $newObject = $byteCodeRe.Replace($subObject, {
        param($m) $m.Groups[1].Value + $b64 + $m.Groups[2].Value
      }, 1)

    $newObject = $referencesRe.Replace($newObject, {
        param($m)
        $refs = $m.Groups[2].Value
        foreach ($ref in $requiredRefs) {
          $quoted = '"' + $ref + '"'
          if ($refs.Contains($quoted)) {
            continue
          }

          if ($refs.Contains('"')) {
            $indent = [regex]::Match($refs, '\r?\n([ \t]*)"').Groups[1].Value
            $trailing = [regex]::Match($refs, '\s*$').Value
            $refs = $refs.Substring(0, $refs.Length - $trailing.Length) + "," + $nl + $indent + `
              $quoted + $trailing
          } else {
            $refs = $nl + (" " * 12) + $quoted + $nl + (" " * 10)
          }
          $addedRefs.Add($ref)
        }
        $m.Groups[1].Value + $refs + $m.Groups[3].Value
      }, 1)

    $newSpan = $span.Substring(0, $bounds.Start) + $newObject + $span.Substring($bounds.End + 1)
    if ($newSpan -ne $span) {
      $content = $content.Substring(0, $actionStart) + $newSpan +
      $content.Substring($actionEnd + 1)
      $changed = $true
      $refsNote = if ($addedRefs.Count -gt 0) {
        " (+ references: $(($addedRefs | ForEach-Object { $_.Replace('\\', '\') }) -join ', '))"
      } else {
        ""
      }
      Write-VcsMessage -Message "Injected C# bytecode: $actionName <= $subActionName$refsNote" `
        -Color Cyan
    }
  }

  if ($changed) {
    [System.IO.File]::WriteAllText(
      $ActionsFilePath, $content, [System.Text.UTF8Encoding]::new($false))
  }

  Write-StreamerbotCsharpOrphanReport `
    -ActionsFilePath $ActionsFilePath -SourcePaths $sourcePaths
}

function ConvertTo-StreamerbotTemplate {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath
  )

  $isRootCall = ($null -eq $vcsFormatQueue)

  try {
    if ($isRootCall) {
      $vcsFormatQueue = [System.Collections.Generic.List[string]]::new()
      $vcsReplacedCount = 0
      Set-VcsVerbose -Enabled:$PSBoundParameters.ContainsKey('Verbose')
      Set-VcsLogFilePath -LogDirPath (Join-Path $PSScriptRoot "logs") -AppName "streamerbot"
      Write-VcsLogSeparator
    }

    $InputPath = (Resolve-Path $InputFilePath).Path
    Assert-InputPath $InputPath -Roots $streamerbotRoots

    if (Test-Path $InputPath -PathType Container) {
      $candidates = Get-ChildItem $InputPath -Recurse -File -Filter "*.json" |
        Where-Object {
          $_.Name -notmatch '\.vcs-template\.json$' -and
          (Test-StreamerbotMarkerPath -Path $_.FullName)
        }

      if (-not $candidates) {
        Write-VcsMessage -Message "No matching .json files found under: $InputPath" -Color Yellow
        Write-VcsMessage -Message "  (must live under one of: $($script:SbotMarkers -join ', '))" `
          -Color Yellow
        return
      }

      Write-VcsMessage -Message "Found $($candidates.Count) matching .json file(s) under: $InputPath"

      foreach ($candidate in $candidates) {
        try {
          ConvertTo-StreamerbotTemplate -InputFilePath $candidate.FullName
        } catch {
          Write-VcsMessage -Message "  Failed to convert: $($candidate.FullName)" -Color Red
          Write-VcsMessage -Message "  $($_.Exception.Message)" -Color Red
          Write-ThrowContext
          throw "Failed to convert $($candidate.FullName) to vcs-template"
        }
      }

      if ($vcsFormatQueue.Count -gt 0) {
        Format-JsonWithPrettier -FilePaths $vcsFormatQueue
      }
      return
    }

    $VcsRelativePath = Get-VcsRelativePath `
      -InputFilePath $InputPath `
      -Roots $streamerbotRoots `
      -Markers $script:SbotMarkers `
      -AppName "Streamer.bot"
    $vcsOutDirPath = Join-Path $PSScriptRoot "vcdata"
    $vcsOutDirPath = Join-Path $vcsOutDirPath $VcsRelativePath

    # TODO: warn here when the exported actions.json breaks the layout that
    # Set-StreamerbotCsharpBytecode relies on ("collapsedGroups" last key of an action, "name"
    # before "subActions"). The restore is a pure token substitution, so a bad layout is
    # committed into the template and only throws on the next restore.
    ConvertTo-VcsTemplateFile `
      -InputFilePath $InputPath `
      -VcsOutDirPath $vcsOutDirPath `
      -Rules $mappings `
      -FormatQueue $vcsFormatQueue `
      -ReplacedCount ([ref]$vcsReplacedCount)

  } finally {
    if ($isRootCall) {
      Write-VcsMessage -Message "Replaced $vcsReplacedCount token(s)" -Color Cyan
      $vcsFormatQueue = $null
      $vcsReplacedCount = $null
    }
  }
}

function ConvertFrom-StreamerbotTemplate {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath,
    [Parameter(Mandatory=$false)]
    [switch]$Backup
  )

  $isRootCall = ($null -eq $vcsReplacedCount)

  try {
    if ($isRootCall) {
      $vcsReplacedCount = 0
      $vcsFormatQueue = [System.Collections.Generic.List[string]]::new()
      Set-VcsVerbose -Enabled:$PSBoundParameters.ContainsKey('Verbose')
      Set-VcsLogFilePath -LogDirPath (Join-Path $PSScriptRoot "logs") -AppName "streamerbot"
      Write-VcsLogSeparator
    }

    $InputPath = (Resolve-Path $InputFilePath).Path
    Assert-InputPath $InputPath -Roots $streamerbotRoots

    if (Test-Path $InputPath -PathType Container) {
      $templates = Get-ChildItem $InputPath -Recurse -File -Filter "*.vcs-template.json" |
        Where-Object { Test-StreamerbotMarkerPath -Path $_.FullName }

      if (-not $templates) {
        Write-VcsMessage -Message "No matching *.vcs-template.json files found under: $InputPath" `
          -Color Yellow
        return
      }

      Write-VcsMessage -Message ("Found $($templates.Count) matching *.vcs-template.json file(s) " `
          + "under: $InputPath")
      foreach ($template in $templates) {
        try {
          ConvertFrom-StreamerbotTemplate `
            -InputFilePath $template.FullName `
            -Backup:$Backup
        } catch {
          Write-VcsMessage -Message "  Failed: $($template.FullName)" -Color Red
          Write-VcsMessage -Message "  $($_.Exception.Message)" -Color Red
        }
      }
      return
    }

    $restoredPath = $null
    ConvertFrom-VcsTemplateFile `
      -InputFilePath $InputPath `
      -Rules $mappings `
      -Backup:$Backup `
      -ReplacedCount ([ref]$vcsReplacedCount) `
      -FormatQueue $vcsFormatQueue `
      -RestoredPath ([ref]$restoredPath)

    if ((Split-Path $restoredPath -Leaf) -eq "actions.json") {
      Set-StreamerbotCsharpBytecode -ActionsFilePath $restoredPath
    }

  } finally {
    if ($isRootCall) {
      if ($vcsFormatQueue.Count -gt 0) {
        Format-JsonWithPrettier -FilePaths $vcsFormatQueue
      }
      Write-VcsMessage -Message "Replaced $vcsReplacedCount token(s)" -Color Cyan
      $vcsFormatQueue = $null
      $vcsReplacedCount = $null
    }
  }
}

Write-VcsMessage -NoLog -Message ""
Write-VcsMessage -Message "Streamer.bot Templater:" -Color Yellow

Write-VcsMessage -AsVerbose -Message "Mappings:"
$mappings | ForEach-Object {
  $scope = if ($_.Key) {
    "[$($_.Key)] "
  } else {
    ""
  }
  Write-VcsMessage -AsVerbose -Message "  $scope$($_.Token) => $($_.Value)"
}

Write-VcsMessage -NoLog -Message "Script location:" -Color Cyan
Write-VcsMessage -NoLog -Message "  $PSScriptRoot"

Write-VcsMessage -NoLog -Message "Usage:" -Color Cyan
Write-VcsMessage -NoLog -Message ("  All input files must be under:`n$(
  $script:streamerbotRoots.Path -join "`n"
)")
Write-VcsMessage -NoLog -Message ("  ConvertTo-StreamerbotTemplate 'actions.json'                " +
  "       # Creates vcs-template.json")

Write-VcsMessage -NoLog -Message ("  ConvertTo-StreamerbotTemplate 'folder' (or '.')             " +
  "       # Recursively creates vcs-template.json for every matching .json under folder")

Write-VcsMessage -NoLog -Message ("  ConvertFrom-StreamerbotTemplate 'actions.vcs-template.json' " +
  "       # Creates actions.json")

Write-VcsMessage -NoLog -Message ("  ConvertFrom-StreamerbotTemplate 'folder' (or '.')           " +
  "       # Recursively restores every matching *.vcs-template.json under folder")

Export-ModuleMember -Function ConvertTo-StreamerbotTemplate, ConvertFrom-StreamerbotTemplate
Write-VcsMessage -NoLog -Message "Healthcheck:" -Color Cyan
@(
  "$script:SbotProductionPath\dlls\BroStreamerTools.dll"
  "$script:SbotFtpPath\dlls\BroStreamerTools.dll"
) | Test-StreamerbotDllSymlinks

Write-VcsMessage -NoLog -Message ""
Write-VcsMessage -NoLog -Message "Streamer.bot Templater functions loaded!" -Color Green
