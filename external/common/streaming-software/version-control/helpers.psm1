$script:PrettierPath = Join-Path $env:LOCALAPPDATA "nvim-data\mason\bin\prettier.cmd"
function ConvertFrom-Json5 {
  param([string]$Path)

  $json5Path = (Join-Path $PSScriptRoot "node_modules\json5") -replace '\\', '/'

  # Escape backslashes so the path survives as a JS string literal
  $safePath = $Path -replace '\\', '/'

  $json = node -e "
    const JSON5 = require('$json5Path');
    const fs = require('fs');
    console.log(JSON.stringify(
      JSON5.parse(fs.readFileSync('$safePath','utf8'))
    ));
  "

  return $json | ConvertFrom-Json
}

function Read-MappingsFile {
  param([Parameter(Mandatory=$true)][string]$Path)

  if (-not (Test-Path $Path)) {
    throw "Mappings file not found: $Path"
  }

  $raw = ConvertFrom-Json5 $Path
  $rules = @()

  foreach ($category in $raw.PSObject.Properties) {
    foreach ($prop in $category.Value.PSObject.Properties) {
      $rules += [PSCustomObject]@{
        Key   = $null
        Value = [string]$prop.Value
        Token = $prop.Name
      }
    }
  }

  return $rules
}

function Read-ScopedMappingsFile {
  param([Parameter(Mandatory=$true)][string]$Path)

  if (-not (Test-Path $Path)) {
    throw "Scoped mappings file not found: $Path"
  }

  $raw = ConvertFrom-Json5 $Path

  if (-not $raw.PSObject.Properties.Name -contains "scoped") {
    throw "Scoped mappings file is missing a top-level 'scoped' array: $Path"
  }
  if (-not $raw.scoped -or $raw.scoped.Count -eq 0) {
    throw "Scoped mappings file has an empty 'scoped' array: $Path"
  }

  $rules = @()
  foreach ($entry in $raw.scoped) {
    if (-not $entry.key -or -not $entry.value -or -not $entry.token) {
      throw "Scoped mapping entry missing key/value/token: $($entry | ConvertTo-Json -Compress)"
    }
    $rules += [PSCustomObject]@{
      Key   = [string]$entry.key
      Value = [string]$entry.value
      Token = [string]$entry.token
    }
  }

  return $rules
}

function Read-ReplacementMappings {
  param(
    [string]$CommonMappingsPath,
    [string]$MappingsPath,
    [Parameter(Mandatory=$true)] [string[]]$ScopedMappingsPaths
  )

  if (-not $ScopedMappingsPaths -or $ScopedMappingsPaths.Count -eq 0) {
    throw "Read-ReplacementMappings requires at least one -ScopedMappingsPaths entry `
    (e.g. a ports file)."
  }

  $rules = @()

  if ($CommonMappingsPath -and (Test-Path $CommonMappingsPath)) {
    $rules += Read-MappingsFile $CommonMappingsPath
  }
  if ($MappingsPath -and (Test-Path $MappingsPath)) {
    $rules += Read-MappingsFile $MappingsPath
  }
  foreach ($path in $ScopedMappingsPaths) {
    $rules += Read-ScopedMappingsFile $path
  }

  if ($rules.Count -eq 0) {
    throw "Read-ReplacementMappings produced zero rules — check your mapping file paths and contents."
  }

  # Longest value first — so a full URL is matched before a bare port
  # substring that happens to be embedded inside it.
  return $rules | Sort-Object { $_.Value.Length } -Descending
}

function Format-JsonWithPrettier {
  param([string]$FilePath)

  if (-not (Test-Path $script:PrettierPath)) {
    Write-Host "Warning: Prettier not found at $script:PrettierPath. Skipping
    formatting." -ForegroundColor Yellow
    return
  }

  & $script:PrettierPath --write $FilePath
}

function Assert-InputPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [array]$Roots
  )

  $valid = $Roots | Where-Object {
    $Path.StartsWith(
      $_.Path,
      [System.StringComparison]::OrdinalIgnoreCase
    )
  }

  if (-not $valid) {
    Write-Host "This function must target files under:" -ForegroundColor Red
    $Roots.Path | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "Current target: $Path" -ForegroundColor Red
    throw "Invalid target path: $Path"
  }
}

function Get-VcsRelativePath {
  param(
    [Parameter(Mandatory=$true)]
    [string]$InputFilePath,

    [Parameter(Mandatory=$true)]
    [array]$Roots,

    [Parameter(Mandatory=$true)]
    [array]$Markers,

    [Parameter(Mandatory=$true)]
    [string]$AppName
  )

  $prefix = $null

  foreach ($root in $Roots) {
    if ($InputFilePath.StartsWith(
        $root.Path,
        [System.StringComparison]::OrdinalIgnoreCase
      )) {
      $prefix = $root.Name
      $relative = $InputFilePath.Substring(
        $root.Path.Length
      ).TrimStart('\')
      break
    }
  }

  if ($null -eq $prefix) {
    throw "Unexpected $AppName import path: $InputFilePath"
  }

  $parts = $relative -split '\\'
  $dirOnlyParts = $parts[0..($parts.Count - 2)]

  foreach ($marker in $Markers) {
    $index = $dirOnlyParts.IndexOf($marker)

    if ($index -ge 0) {
      $remainingCount = $dirOnlyParts.Count - ($index + 1)

      if ($remainingCount -le 0) {
        return Join-Path $prefix $marker
      }

      $dirParts = $dirOnlyParts[
      ($index + 1)..($dirOnlyParts.Count - 1)
      ]

      return Join-Path $prefix (
        Join-Path $marker ($dirParts -join '\')
      )
    }
  }

  Write-Host "Expected config locations:" -ForegroundColor Red
  foreach ($marker in $Markers) {
    Write-Host "  <root>\$marker\..." -ForegroundColor Red
  }
  throw (
    "Unexpected $AppName config location: $relative"
  )
}

function Invoke-ScopedReplace {
  param(
    [Parameter(Mandatory=$true)] [string]$Content,
    [Parameter(Mandatory=$true)] [string]$Key,
    [Parameter(Mandatory=$true)] [string]$SearchValue,
    [Parameter(Mandatory=$true)] [string]$Token
  )

  $isNumericSearch = $SearchValue -match '^-?\d+(\.\d+)?$'

  # "Key": "quoted value" OR "Key": bareNumber
  $pattern = "(?<prefix>`"$([regex]::Escape($Key))`"\s*:\s*)" +
  "(?<val>`"(?:[^`"\\]|\\.)*`"|-?\d+(?:\.\d+)?)"

  return [regex]::Replace($Content, $pattern, {
      param($m)
      $prefix = $m.Groups['prefix'].Value
      $val    = $m.Groups['val'].Value

      if ($val.StartsWith('"')) {
        $inner = $val.Substring(1, $val.Length - 2)   # strip surrounding quotes

        if ($isNumericSearch) {
          # Numeric rule values require an exact match even if the target
          # happens to be quoted — never a substring match on digits.
          if ($inner -eq $SearchValue) {
            Write-Host "  Replaced ($Key): `"$SearchValue`" -> `"$Token`"" -ForegroundColor DarkCyan
            return $prefix + "`"$Token`""
          }
        } elseif ($inner.Contains($SearchValue)) {
          Write-Host "  Replaced ($Key): $SearchValue -> $Token in $val" -ForegroundColor DarkCyan
          return $prefix + "`"$($inner.Replace($SearchValue, $Token))`""
        }
      } elseif ($val -eq $SearchValue) {
        Write-Host "  Replaced ($Key): $SearchValue -> `"$Token`"" -ForegroundColor DarkCyan
        return $prefix + "`"$Token`""
      }

      return $m.Value
    })
}

function Invoke-ScopedRestore {
  param(
    [Parameter(Mandatory=$true)] [string]$Content,
    [Parameter(Mandatory=$true)] [string]$Value,
    [Parameter(Mandatory=$true)] [string]$Token
  )

  $isNumeric = $Value -match '^-?\d+(\.\d+)?$'

  if ($isNumeric) {
    $quotedToken = "`"$Token`""
    if ($Content.Contains($quotedToken)) {
      $Content = $Content.Replace($quotedToken, $Value)
      Write-Host "  Replaced: $quotedToken -> $Value" -ForegroundColor DarkCyan
    }
  } elseif ($Content.Contains($Token)) {
    $Content = $Content.Replace($Token, $Value)
    Write-Host "  Replaced: $Token -> $Value" -ForegroundColor DarkCyan
  }

  return $Content
}

function ConvertTo-VcsTemplateFile {
  param(
    [Parameter(Mandatory=$true)] [string]$InputFilePath,
    [Parameter(Mandatory=$true)] [string]$VcsOutDirPath,
    [Parameter(Mandatory=$true)] [array]$Rules
  )

  $inputFileName  = Split-Path $InputFilePath -Leaf
  $inputDirectory = Split-Path $InputFilePath -Parent

  if ($InputFilePath -notmatch '\.json$') {
    throw "Input file must be a .json file, got: $inputFileName"
  }

  $templateFileName = $inputFileName -replace "\.json$", ".vcs-template.json"
  $vcsOutFilePath   = Join-Path $VcsOutDirPath $templateFileName

  Write-Host "Creating vcs template from real config..."
  Write-Host "Input:  $InputFilePath"
  Write-Host "Output: $vcsOutFilePath"

  if (-not (Test-Path $VcsOutDirPath)) {
    New-Item -ItemType Directory -Path $VcsOutDirPath -Force | Out-Null
    Write-Host "Created VCS directory: $VcsOutDirPath" -ForegroundColor Yellow
  }

  $symlinkPath = Join-Path $inputDirectory $templateFileName
  if (Test-Path $symlinkPath) {
    Remove-Item $symlinkPath -Force
  }

  $content = Get-Content $InputFilePath -Raw
  $sortedRules = $Rules | Sort-Object { $_.Value.Length } -Descending

  foreach ($rule in $sortedRules) {
    if ($rule.Key) {
      $content = Invoke-ScopedReplace -Content $content -Key $rule.Key `
        -SearchValue $rule.Value -Token $rule.Token
    } else {
      $variants = @(
        $rule.Value,
        ($rule.Value | ConvertTo-Json -Compress).Trim('"')
      )
      foreach ($variant in $variants) {
        if ($content.Contains($variant)) {
          $content = $content.Replace($variant, $rule.Token)
          Write-Host "  Replaced: $variant -> $($rule.Token)" -ForegroundColor DarkCyan
        }
      }
    }
  }

  $content | Set-Content $vcsOutFilePath -Encoding UTF8
  Format-JsonWithPrettier -FilePath $vcsOutFilePath
  Write-Host "Template saved: $vcsOutFilePath" -ForegroundColor Green

  New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $vcsOutFilePath | Out-Null
}

function ConvertFrom-VcsTemplateFile {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath,
    [Parameter(Mandatory=$true)]  [array]$Rules,
    [Parameter(Mandatory=$false)] [switch]$Backup
  )

  $inputFileName = Split-Path $InputFilePath -Leaf

  if ($InputFilePath -notmatch '\.vcs-template\.json$') {
    throw "Input filename must be like **.vcs-template.json, got: $inputFileName"
  }

  $outFilePath = $InputFilePath -replace '\.vcs-template\.json$', '.json'

  Write-Host "Restoring real config from template..."
  Write-Host "Input:  $InputFilePath"
  Write-Host "Output: $outFilePath"

  if ($Backup -and (Test-Path $outFilePath)) {
    $backupPath = "$outFilePath.bak"
    Copy-Item $outFilePath $backupPath -Force
    Write-Host "Backup saved: $backupPath" -ForegroundColor Magenta
  }

  $content = Get-Content $InputFilePath -Raw

  foreach ($rule in $Rules) {
    $content = Invoke-ScopedRestore -Content $content -Value $rule.Value -Token $rule.Token
  }

  $unresolvedMatches = [regex]::Matches($content, '\{\{[A-Z0-9_]+\}\}') |
    Select-Object -ExpandProperty Value -Unique
  foreach ($unresolved in $unresolvedMatches) {
    Write-Host "Warning: No mapping found for token $unresolved — left as-is" `
      -ForegroundColor Yellow
  }

  $content | Set-Content $outFilePath -Encoding UTF8
  Format-JsonWithPrettier -FilePath $outFilePath
  Write-Host "Real config saved: $outFilePath" -ForegroundColor Green

  return $outFilePath
}

$FunctionsToExport = @(
  "Read-ReplacementMappings"
  "Format-JsonWithPrettier"
  "ConvertTo-VcsTemplateFile"
  "ConvertFrom-VcsTemplateFile"
  "Get-VcsRelativePath"
  "Assert-InputPath"
)

Export-ModuleMember -Function $FunctionsToExport
