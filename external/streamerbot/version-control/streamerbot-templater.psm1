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

$script:SbotCsharpTestMode = $false
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

# .NET Framework assemblies (System.Core, System.Net.Http ...) are listed by name in one property,
# in the shadow csproj, e.g. <SbotRefFramework>System.Core;System.Net.Http</SbotRefFramework>
$script:SbotCsharpFrameworkRefProperty = "SbotRefFramework"
$script:SbotCsharpFrameworkDirUnderWindows = "Microsoft.NET\Framework64\v4.0.30319"

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

function ConvertTo-StreamerbotActionName {
  param([Parameter(Mandatory=$true)] [string]$FolderName)

  return "sbact__$FolderName"
}

function ConvertTo-StreamerbotFolderName {
  param([Parameter(Mandatory=$true)] [string]$ActionName)

  return $ActionName -replace '^sbact__', ''
}

function Get-StreamerbotRootFor {
  param([Parameter(Mandatory=$true)] [string]$ActionsFilePath)

  return $script:streamerbotRoots | Where-Object {
    $ActionsFilePath.StartsWith("$($_.Path)\", [System.StringComparison]::OrdinalIgnoreCase)
  } | Select-Object -First 1
}

function Get-StreamerbotCsharpFiles {
  param([Parameter(Mandatory=$true)] [string]$Path)

  Get-ChildItem $Path -Recurse -File -Filter "*.cs" | Where-Object {
    $parts = $_.FullName -split '\\'
    -not ($parts | Where-Object { $script:SbotCsharpExcludedDirs -contains $_ })
  }
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

function Assert-StreamerbotCsharpNoDuplicateActions {
  $root = Join-Path $PSScriptRoot $script:SbotCsharpSubActionsRoot
  $pathsByKey = @{}

  foreach ($envDir in $script:SbotCsharpEnvDirs) {
    $envPath = Join-Path $root $envDir
    if (-not (Test-Path $envPath -PathType Container)) {
      continue
    }
    foreach ($file in Get-StreamerbotCsharpFiles -Path $envPath) {
      $action = Split-Path $file.DirectoryName -Leaf
      $key = "$action|$($file.Name)"
      if (-not $pathsByKey.ContainsKey($key)) {
        $pathsByKey[$key] = @()
      }
      $pathsByKey[$key] += $file.FullName
    }
  }

  $duplicates = $pathsByKey.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } |
    Sort-Object Name
  if ($duplicates) {
    $lines = foreach ($dup in $duplicates) {
      $action, $subAction = $dup.Name -split '\|', 2
      "  action '$action', sub-action '$subAction':"
      $dup.Value | ForEach-Object { "    $_" }
    }
    Write-ThrowContext
    throw ("C# directory structure mismatch: an action's sub-action must live in only one of" +
      " $($script:SbotCsharpEnvDirs -join ', '), never in two at once (this includes" +
      " Ftp and Production):`n" + ($lines -join "`n"))
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
  Assert-StreamerbotCsharpNoDuplicateActions

  foreach ($relPath in $searchPaths) {
    $path = Join-Path $PSScriptRoot $relPath
    if (Test-Path $path -PathType Container) {
      (Get-StreamerbotCsharpFiles -Path $path).FullName
    } elseif (Test-Path $path -PathType Leaf) {
      $path
    } else {
      Write-VcsMessage -Message "C# source not found, skipping: $path" -Color Yellow
    }
  }
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

function Assert-StreamerbotCsharpNoCondition {
  param(
    [Parameter(Mandatory=$true)] [System.Xml.XmlElement]$Node,
    [Parameter(Mandatory=$true)] [string]$Name,
    [Parameter(Mandatory=$true)] [string]$CsprojPath
  )

  for ($el = $Node; $el -is [System.Xml.XmlElement]; $el = $el.ParentNode) {
    if ($el.HasAttribute("Condition")) {
      Write-ThrowContext
      throw ("Conditions in a shadow csproj are not supported yet : <$($el.Name) Condition=" +
        """$($el.GetAttribute('Condition'))""> around $Name in $CsprojPath")
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
    "== ($($withoutFile.Count)) C# sub-actions without a matching .cs file =="
    $withoutFile
    ""
    ""
    "== ($($withoutSubAction.Count)) .cs files without a matching C# sub-action =="
    $withoutSubAction | Sort-Object
    ""
    ""
    "== ($($withoutCsproj.Count)) .cs files without a .shadow.csproj, references not managed =="
    $withoutCsproj | Sort-Object
    ""
    ""
    "== ($($otherEnvOnly.Count)) Common .cs files whose action is not in this environment, " +
    "not orphans =="
    $otherEnvOnly | Sort-Object
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
    "  $($withoutCsproj.Count) file(s) without shadow csproj"
    "  $($otherEnvOnly.Count) Common file(s) for other environment only"
    "  Report: $reportPath"
  )
  foreach ($summaryLine in $summary) {
    Write-VcsMessage -Message $summaryLine -Color $color
  }
}

function Get-StreamerbotFrameworkDir {
  $windowsDir = Join-Path (Split-Path $env:windir -Qualifier) "Windows"
  return Join-Path $windowsDir $script:SbotCsharpFrameworkDirUnderWindows
}

function Get-StreamerbotFrameworkRefDir {
  param([Parameter(Mandatory=$true)] [string]$ActionsFilePath)

  # <Streamer.bot>\data\actions.json
  $streamerbotDir = Split-Path (Split-Path $ActionsFilePath -Parent) -Parent
  $frameworkDir = Get-StreamerbotFrameworkDir
  if (-not (Test-Path $frameworkDir -PathType Container)) {
    Write-VcsMessage -Message (".NET Framework folder not found: $frameworkDir : existing " +
      "framework reference paths are left as they are") -Color Red
    return $null
  }

  # On another drive GetRelativePath returns an absolute path. Only relative references are
  # currently supported: it is not known if Streamer.bot accepts an absolute one.
  $relativeDir = [System.IO.Path]::GetRelativePath($streamerbotDir, $frameworkDir)
  if ([System.IO.Path]::IsPathRooted($relativeDir)) {
    Write-VcsMessage -Message ("Streamer.bot ($streamerbotDir) and the .NET Framework folder " +
      "($frameworkDir) are on different drives : no relative path possible, framework " +
      "reference paths are left as they are") -Color Red
    return $null
  }

  return $relativeDir
}

function Get-StreamerbotCsharpRequiredReferences {
  param(
    [Parameter(Mandatory=$true)] [string]$SourcePath,
    [Parameter(Mandatory=$true)] [AllowNull()] [AllowEmptyString()] [string]$FrameworkRefDir
  )

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

    Assert-StreamerbotCsharpNoCondition -Node $node -Name $flag -CsprojPath $csprojPath
    if ($node.InnerText -eq "true") {
      $script:SbotCsharpReferenceByFlag[$flag].Replace('\', '\\')
    }
  }

  $frameworkProperty = $script:SbotCsharpFrameworkRefProperty
  $node = $csproj.SelectSingleNode("//$frameworkProperty")

  if ($node) {
    Assert-StreamerbotCsharpNoCondition -Node $node -Name $frameworkProperty `
      -CsprojPath $csprojPath
    $names = $node.InnerText -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    if ($names -and -not $FrameworkRefDir) {
      Write-ThrowContext
      throw (".NET Framework folder not found, or not reachable with a relative path (see the " +
        "message above), needed by $frameworkProperty in $csprojPath")
    }

    foreach ($name in $names) {
      if ($name -notmatch '^[A-Za-z0-9_.]+$' -or $name -match '\.dll$') {
        Write-ThrowContext
        throw ("Invalid framework reference '$name' in $frameworkProperty of $csprojPath : " +
          "use the assembly name without .dll, separated by ';' (e.g. System.Core;System.Data)")
      }
      if (-not (Test-Path (Join-Path (Get-StreamerbotFrameworkDir) "$name.dll") -PathType Leaf)) {
        Write-ThrowContext
        throw ("Framework reference '$name' in $frameworkProperty of $csprojPath : " +
          "$name.dll not found in $(Get-StreamerbotFrameworkDir) (not a .NET Framework assembly?)")
      }
      "$FrameworkRefDir\$name.dll".Replace('\', '\\')
    }
  }
}

function Get-StreamerbotJsonObjectIndex {
  param([Parameter(Mandatory=$true)] [string]$Text)

  $startPos = [System.Collections.Generic.List[int]]::new()
  $endPos = [System.Collections.Generic.List[int]]::new()
  $parentIdx = [System.Collections.Generic.List[int]]::new()
  $openIdx = [System.Collections.Generic.Stack[int]]::new()

  foreach ($token in [regex]::Matches($Text, '"[^"\\]*(?:\\.[^"\\]*)*"|[{}]')) {
    if ($token.Value -eq "{") {
      $parentIdx.Add($(if ($openIdx.Count -gt 0) {
            $openIdx.Peek()
          } else {
            -1 # -1 means no parent (outermost object)
          }))
      $startPos.Add($token.Index)
      $endPos.Add(-1) # -1 means not closed yet, overwritten when we find the closing `}`
      $openIdx.Push($startPos.Count - 1)
    } elseif ($token.Value -eq "}" -and $openIdx.Count -gt 0) {
      $endPos[$openIdx.Pop()] = $token.Index
    }
  }

  return [pscustomobject]@{ StartPos = $startPos; EndPos = $endPos; ParentIdx = $parentIdx }
}

function Get-StreamerbotJsonObjectBounds {
  param(
    [Parameter(Mandatory=$true)] [object]$ObjectIndex,
    [Parameter(Mandatory=$true)] [int]$Index
  )

  $found = $ObjectIndex.StartPos.BinarySearch($Index)
  if ($found -ge 0) {
    # $Index is the position of a "name", never of a {, so the search should never hit exactly.
    Write-VcsMessage -Message ("Unexpected: position $Index is exactly the start of a JSON " +
      "object (expected a ""name"" position). An unexpected `$Index was passed to " +
      "Get-StreamerbotJsonObjectBounds") -Color Red
    $obj = $found - 1
  } else {
    $obj = (-bnot $found) - 1
  }
  while ($obj -ge 0) {
    if ($ObjectIndex.EndPos[$obj] -gt $Index) {
      return [pscustomobject]@{
        Start = $ObjectIndex.StartPos[$obj]
        End = $ObjectIndex.EndPos[$obj]
      }
    }
    $obj = $ObjectIndex.ParentIdx[$obj]
  }
}

function Set-StreamerbotCsharpBytecode {
  param(
    [Parameter(Mandatory=$true)] [string]$ActionsFilePath,
    [string]$TemplateFilePath
  )

  $content = [System.IO.File]::ReadAllText($ActionsFilePath)

  $fileLabel = if ($TemplateFilePath) {
    $TemplateFilePath
  } else {
    $ActionsFilePath
  }

  $sourcePaths = @(Get-StreamerbotCsharpSourcePaths -ActionsFilePath $ActionsFilePath)

  $frameworkRefDir = Get-StreamerbotFrameworkRefDir -ActionsFilePath $ActionsFilePath
  $frameworkPathRe = $null
  $frameworkPathNew = $null
  if ($frameworkRefDir) {
    $frameworkTail = [regex]::Escape(
      ("Windows\" + $script:SbotCsharpFrameworkDirUnderWindows).Replace('\', '\\') + '\\')
    $frameworkPathRe = [regex]::new(
      '"(?:\.\.\\\\)+' + $frameworkTail,
      [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $frameworkPathNew = '"' + $frameworkRefDir.Replace('\', '\\') + '\\'
  }

  $objectIndex = Get-StreamerbotJsonObjectIndex -Text $content
  $actionNameIndexes = [System.Collections.Generic.Dictionary[string, int]]::new(
    [System.StringComparer]::Ordinal)

  $repeatedNames = @()
  foreach ($nameHit in [regex]::Matches($content, '"name":\s*"(sbact__[^"\\]*)"')) {
    $hitName = $nameHit.Groups[1].Value
    if ($actionNameIndexes.ContainsKey($hitName)) {
      $firstLine = Get-StreamerbotLineNumber -Content $content -Index $actionNameIndexes[$hitName]
      $line = Get-StreamerbotLineNumber -Content $content -Index $nameHit.Index
      $repeatedNames += "'$hitName' at lines $firstLine and $line"
    } else {
      $actionNameIndexes[$hitName] = $nameHit.Index
    }
  }
  if ($repeatedNames) {
    Write-ThrowContext
    throw ("Duplicate action names in ${fileLabel}: $($repeatedNames -join '; ')." +
      " Streamer.bot does not allow two actions with the same name.")
  }
  $edits = @{}
  $nl = if ($content.Contains("`r`n")) {
    "`r`n"
  } else {
    "`n"
  }

  foreach ($sourcePath in $sourcePaths) {
    $folderName = Split-Path (Split-Path $sourcePath -Parent) -Leaf
    $actionName = ConvertTo-StreamerbotActionName -FolderName $folderName
    $subActionName = Split-Path $sourcePath -Leaf # this = SubActionExecuteCodeName from README.md

    # Always CRLF so the bytecode is the same. UTF-8 BOM-less.
    $sourceText = [System.IO.File]::ReadAllText($sourcePath) -replace '\r?\n', "`r`n"
    $b64 = [Convert]::ToBase64String([System.Text.UTF8Encoding]::new($false).GetBytes($sourceText))

    if (-not $actionNameIndexes.ContainsKey($actionName)) {
      continue
    }
    $actionNameAt = $actionNameIndexes[$actionName]

    $actionNameAt = $actionNameIndexes[$actionName]
    $actionBounds = Get-StreamerbotJsonObjectBounds -ObjectIndex $objectIndex -Index $actionNameAt

    if (-not $actionBounds) {
      $nameLine = Get-StreamerbotLineNumber -Content $content -Index $actionNameAt
      Write-VcsMessage -Message ("No enclosing JSON object found around action '$actionName'" +
        " (""name"" at line $nameLine of $fileLabel) : bytecode not injected") -Color Red
      continue
    }

    $actionObject = $content.Substring(
      $actionBounds.Start, $actionBounds.End - $actionBounds.Start + 1)

    $nameMatches = [regex]::Matches(
      $actionObject, '"name":\s*"' + [regex]::Escape($subActionName) + '"')

    if ($nameMatches.Count -eq 0) {
      # We will handle this in the orphan report
      continue
    }

    if ($nameMatches.Count -gt 1) {
      $nameLines = $nameMatches | ForEach-Object {
        Get-StreamerbotLineNumber -Content $content -Index ($actionBounds.Start + $_.Index)
      }
      Write-ThrowContext
      throw ("Sub-action '$subActionName' appears $($nameMatches.Count) times in action" +
        " '$actionName' (""name"" at lines $($nameLines -join ', ') of $fileLabel)." +
        " One .cs file feeds one sub-action: move the shared code to its own Streamer.bot" +
        " action and call that action from each place.")
    }
    $nameMatch = $nameMatches[0]

    $subNameAt = $actionBounds.Start + $nameMatch.Index
    $subBounds = Get-StreamerbotJsonObjectBounds -ObjectIndex $objectIndex -Index $subNameAt

    if (-not $subBounds) {
      $subNameLine = Get-StreamerbotLineNumber -Content $content -Index $subNameAt
      Write-VcsMessage -Message ("No enclosing JSON object found around sub-action" +
        " '$subActionName' of action '$actionName' (""name"" at line $subNameLine of" +
        " $fileLabel) : bytecode not injected") -Color Red
      continue
    }

    $subActionObject = $content.Substring($subBounds.Start, $subBounds.End - $subBounds.Start + 1)

    $referencesRe = [regex]::new('("references":\s*\[)([^\]]*)(\])')
    $byteCodeRe = [regex]::new('("byteCode":\s*")[^"]*(")')
    # Type 99900 is a group (holds nested subActions)
    if ($subActionObject -match '"type":\s*99900') {
      continue
    }
    $missingKeys = @(
      if (-not $referencesRe.IsMatch($subActionObject)) {
        '"references"'
      }
      if (-not $byteCodeRe.IsMatch($subActionObject)) {
        '"byteCode"'
      }
    )
    if ($missingKeys.Count -gt 0) {
      Write-VcsMessage -Message ("Sub-action '$subActionName' of action '$actionName' in " +
        "$fileLabel is missing $($missingKeys -join ' and ') : bytecode not injected") `
        -Color Red
      continue
    }

    $requiredRefs = @(Get-StreamerbotCsharpRequiredReferences `
        -SourcePath $sourcePath -FrameworkRefDir $frameworkRefDir)

    $addedRefs = [System.Collections.Generic.List[string]]::new()
    $frameworkPathsUpdated = [ref]$false

    $newSubActionObject = $byteCodeRe.Replace($subActionObject, {
        param($m) $m.Groups[1].Value + $b64 + $m.Groups[2].Value
      }, 1)

    $newSubActionObject = $referencesRe.Replace($newSubActionObject, {
        param($m)
        $refs = $m.Groups[2].Value

        if ($frameworkPathRe) {
          $movedRefs = $frameworkPathRe.Replace($refs, $frameworkPathNew)
          if ($movedRefs -cne $refs) {
            $frameworkPathsUpdated.Value = $true
            $refs = $movedRefs
          }
        }

        foreach ($ref in $requiredRefs) {
          $quoted = '"' + $ref + '"'
          if ($refs.IndexOf($quoted, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            continue
          }
          $entries = [regex]::Matches($refs, '"(?:[^"\\]|\\.)*"') | Where-Object { $_.Length -gt 2 }
          $refs = if ($entries) {
            $refs.TrimEnd() + "," + $nl + $quoted + $nl
          } else {
            $nl + $quoted + $nl
          }
          $addedRefs.Add($ref)
        }
        $m.Groups[1].Value + $refs + $m.Groups[3].Value
      }, 1)

    if ($newSubActionObject -cne $subActionObject) {
      $edits[$subBounds.Start] = @{
        Start = $subBounds.Start
        End = $subBounds.End
        Text = $newSubActionObject
      }

      $notes = @()

      if ($addedRefs.Count -gt 0) {
        $addedNames = $addedRefs | ForEach-Object { $_.Replace('\\', '\') }
        foreach ($addedName in $addedNames) {
          $notes += "+ reference: $addedName"
        }
      }
      if ($frameworkPathsUpdated.Value) {
        $notes += ".net framework paths updated"
      }
      $refsNote = if ($notes) {
        "`n  " + ($notes -join "`n  ")
      } else {
        ""
      }
      Write-VcsMessage -Message "Injected C# bytecode: $actionName <= $subActionName$refsNote" `
        -Color Cyan
    }
  }

  if ($edits.Count -gt 0) {
    $result = [System.Text.StringBuilder]::new($content.Length)
    $position = 0
    foreach ($edit in $edits.Values | Sort-Object { $_.Start }) {
      if ($edit.Start -lt $position) {
        Write-ThrowContext
        throw "Overlapping C# bytecode edits at offset $($edit.Start) of $ActionsFilePath"
      }
      [void]$result.Append($content.Substring($position, $edit.Start - $position))
      [void]$result.Append($edit.Text)
      $position = $edit.End + 1
    }
    [void]$result.Append($content.Substring($position))

    $tempPath = "$ActionsFilePath.vcs-tmp"
    try {
      [System.IO.File]::WriteAllText(
        $tempPath, $result.ToString(), [System.Text.UTF8Encoding]::new($false))
      [System.IO.File]::Move($tempPath, $ActionsFilePath, $true)
    } finally {
      if (Test-Path $tempPath) {
        Remove-Item $tempPath -Force
      }
    }
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
        Write-VcsMessage -Message "No matching .json files found under: $InputPath" -Color Yellow `
          -Bold
        return
      }

      Write-VcsMessage -AsVerbose -Message ("Found $($candidates.Count) matching .json file(s)" +
        "under: $InputPath")

      foreach ($candidate in $candidates) {
        try {
          ConvertTo-StreamerbotTemplate -InputFilePath $candidate.FullName
        } catch {
          Write-VcsMessage -Message "  Failed to convert: $($candidate.FullName)`n" -Color Red
          Write-VcsMessage -Message "  $($_.Exception.Message)" -Color Red -Bold
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
          -Color Yellow -Bold
        return
      }

      Write-VcsMessage -AsVerbose -Message ("Found $($templates.Count) matching" +
        "*.vcs-template.json file(s) under: $InputPath")

      foreach ($template in $templates) {
        try {
          ConvertFrom-StreamerbotTemplate `
            -InputFilePath $template.FullName `
            -Backup:$Backup
        } catch {
          Write-VcsMessage -Message "  Failed to convert from: $($template.FullName):`n" -Color Red
          Write-VcsMessage -Message "  $($_.Exception.Message)" -Color Red -Bold
        }
      }
      return
    }

    $validate = $null
    # only validating csharp sub-actions code right now (present in actions.json)
    if ((Split-Path $InputPath -Leaf) -eq "actions.vcs-template.json") {
      $validate = {
        param($tmpTemplate, $vcsTemplate)
        Set-StreamerbotCsharpBytecode `
          -ActionsFilePath $tmpTemplate -TemplateFilePath $vcsTemplate
        $true
      }
    }

    ConvertFrom-VcsTemplateFile `
      -InputFilePath $InputPath `
      -Rules $mappings `
      -Backup:$Backup `
      -ReplacedCount ([ref]$vcsReplacedCount) `
      -FormatQueue $vcsFormatQueue `
      -Validate $validate

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
