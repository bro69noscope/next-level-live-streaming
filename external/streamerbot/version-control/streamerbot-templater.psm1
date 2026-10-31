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

$script:SbotCsharpSources = @(
  "vcdata\common\csharp\SubActions\Production\General\Tests"
)

$script:SbotCsharpExcludedDirs = @("bin", "obj")

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

# PascalCase folder name => action name, e.g. TestBytecode => sbact__test_bytecode
function ConvertTo-StreamerbotActionName {
  param([Parameter(Mandatory=$true)] [string]$FolderName)

  return "sbact__" + ($FolderName -creplace '(?<!^)([A-Z])', '_$1').ToLower()
}

function Get-StreamerbotCsharpSourcePaths {
  foreach ($relPath in $script:SbotCsharpSources) {
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

# Action name => PascalCase folder name, e.g. sbact__test_bytecode => TestBytecode
function ConvertTo-StreamerbotFolderName {
  param([Parameter(Mandatory=$true)] [string]$ActionName)

  $words = ($ActionName -replace '^sbact__', '') -split '_' | Where-Object { $_ }
  return ($words | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ''
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
    [Parameter(Mandatory=$true)] [string]$RealActionsFilePath,
    [Parameter(Mandatory=$true)] [AllowEmptyCollection()] [string[]]$SourcePaths
  )

  $content = [System.IO.File]::ReadAllText($RealActionsFilePath)
  $actions = ($content | ConvertFrom-Json).actions

  $sourceByKey = @{}
  foreach ($sourcePath in $SourcePaths) {
    $folderName = Split-Path (Split-Path $sourcePath -Parent) -Leaf
    $actionName = ConvertTo-StreamerbotActionName -FolderName $folderName
    $sourceByKey["$actionName|$(Split-Path $sourcePath -Leaf)"] = $sourcePath
  }

  $jsonKeys = @{}
  $withoutFile = [System.Collections.Generic.List[string]]::new()

  foreach ($action in $actions) {
    if (-not $action.subActions) {
      continue
    }

    foreach ($sub in (Get-StreamerbotCsharpSubActions -SubActions $action.subActions)) {
      $key = "$($action.name)|$($sub.name)"
      $jsonKeys[$key] = $true
      if ($sourceByKey.ContainsKey($key)) {
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

  $withoutSub = [System.Collections.Generic.List[string]]::new()
  foreach ($key in $sourceByKey.Keys) {
    if ($jsonKeys.ContainsKey($key)) {
      continue
    }

    $actionName, $subActionName = $key -split '\|', 2
    $relPath = $sourceByKey[$key] -replace ('^' + [regex]::Escape("$PSScriptRoot\")), ''
    $actionMatch = [regex]::Match($content, '"name":\s*"' + [regex]::Escape($actionName) + '"')
    $why = if ($actionMatch.Success) {
      $line = Get-StreamerbotLineNumber -Content $content -Index $actionMatch.Index
      "action '$actionName' (line $line) has no C# sub-action named '$subActionName'"
    } else {
      "action '$actionName' not found in actions file"
    }
    $withoutSub.Add("$relPath  ->  $why")
  }

  $report = @(
    "Streamer.bot C# orphans, generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "Actions file: $RealActionsFilePath"
    "(line numbers also apply to the matching .vcs-template.json)"
    ""
    "== C# sub-actions without a matching .cs file ($($withoutFile.Count)) =="
    $withoutFile
    ""
    "== .cs files without a matching C# sub-action ($($withoutSub.Count)) =="
    $withoutSub | Sort-Object
  )

  $reportPath = Join-Path $PSScriptRoot "log\streamerbot-csharp-orphans.txt"
  New-Item -ItemType Directory -Force (Split-Path $reportPath -Parent) | Out-Null
  $report | Set-Content $reportPath -Encoding UTF8

  $color = if ($withoutFile.Count + $withoutSub.Count -gt 0) {
    "Yellow"
  } else {
    "Green"
  }
  Write-VcsMessage -Message ("C# orphans: $($withoutFile.Count) sub-action(s) without file, " +
    "$($withoutSub.Count) file(s) without sub-action. Report: $reportPath") -Color $color
}

function Set-StreamerbotCsharpBytecode {
  param([Parameter(Mandatory=$true)] [string]$RealActionsFilePath)

  $content = [System.IO.File]::ReadAllText($RealActionsFilePath)
  $changed = $false

  $sourcePaths = @(Get-StreamerbotCsharpSourcePaths)

  foreach ($sourcePath in $sourcePaths) {
    $folderName = Split-Path (Split-Path $sourcePath -Parent) -Leaf
    $actionName = ConvertTo-StreamerbotActionName -FolderName $folderName
    $subActionName = Split-Path $sourcePath -Leaf # this = SubActionExecuteCodeName from README.md
    $b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($sourcePath))

    $actionMatch = [regex]::Match($content, '"name":\s*"' + [regex]::Escape($actionName) + '"')
    if (-not $actionMatch.Success) {
      Write-VcsMessage -Message "Action not found in actions file: $actionName" -Color Yellow
      continue
    }
    $actionIdx = $actionMatch.Index

    # "collapsedGroups" should be the last key of every action, after all its subActions
    # (Streamer.bot generates this way). Stop the script if that no longer holds: the search span
    # would be wrong.
    $endIdx = $content.IndexOf('"collapsedGroups"', $actionIdx)
    $closesAction = $endIdx -ge 0 -and
    $content.Substring($endIdx) -match '^"collapsedGroups":\s*\[[^\]]*\]\s*\}'
    if (-not $closesAction) {
      $keyLine = if ($endIdx -ge 0) {
        "line $(($content.Substring(0, $endIdx) -split "`n").Count)"
      } else {
        "not found"
      }
      $templatePath = $RealActionsFilePath -replace '\.json$', '.vcs-template.json'
      Write-ThrowContext
      throw ("Streamer.bot actions format erroneous: ""collapsedGroups"" is not the last key " +
        "of action '$actionName' (""collapsedGroups"" at $keyLine, template $templatePath)")
    }
    $span = $content.Substring($actionIdx, $endIdx - $actionIdx)

    $pattern = '("name":\s*"' + [regex]::Escape($subActionName) +
    '"[\s\S]*?"byteCode":\s*")[^"]*(")'
    $re = [regex]::new($pattern)
    if (-not $re.IsMatch($span)) {
      Write-VcsMessage -Message "Sub-action $subActionName not found in action: $actionName" `
        -Color Yellow
      continue
    }

    $newSpan = $re.Replace($span, { param($m) $m.Groups[1].Value + $b64 + $m.Groups[2].Value }, 1)
    if ($newSpan -ne $span) {
      $content = $content.Substring(0, $actionIdx) + $newSpan + $content.Substring($endIdx)
      $changed = $true
      Write-VcsMessage -Message "Injected C# bytecode: $actionName <= $subActionName" -Color Cyan
    }
  }

  if ($changed) {
    [System.IO.File]::WriteAllText(
      $RealActionsFilePath, $content, [System.Text.UTF8Encoding]::new($false))
  }

  Write-StreamerbotCsharpOrphanReport -RealActionsFilePath $RealActionsFilePath -SourcePaths $sourcePaths
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
      Set-StreamerbotCsharpBytecode -RealActionsFilePath $restoredPath
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
