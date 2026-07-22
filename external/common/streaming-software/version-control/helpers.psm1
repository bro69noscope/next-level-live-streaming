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

  $mappings = [ordered]@{}
  foreach ($category in $raw.PSObject.Properties) {
    foreach ($prop in $category.Value.PSObject.Properties) {
      $mappings[$prop.Name] = $prop.Value
    }
  }

  return $mappings
}

function Read-ReplacementMappings {
  param(
    [string]$CommonMappingsPath,
    [string]$MappingsPath,
    [string[]]$PortsMappingPaths = @()
  )

  $merged = [ordered]@{}

  if ($CommonMappingsPath -and (Test-Path $CommonMappingsPath)) {
    (Read-MappingsFile $CommonMappingsPath).GetEnumerator() |
      ForEach-Object {
        $merged[$_.Key] = $_.Value
      }
  }

  if ($MappingsPath -and (Test-Path $MappingsPath)) {
    (Read-MappingsFile $MappingsPath).GetEnumerator() |
      ForEach-Object {
        if ($merged.Contains($_.Key)) {
          Write-Host "  Note: '$($_.Key)' overrides common mapping" `
            -ForegroundColor DarkYellow
        }
        $merged[$_.Key] = $_.Value
      }
  }

  foreach ($path in $PortsMappingPaths) {
    (Read-PortMappings $path).GetEnumerator() |
      ForEach-Object {
        if ($merged.Contains($_.Key)) {
          Write-Host "  Note: '$($_.Key)' overrides previous mapping" `
            -ForegroundColor DarkYellow
        }
        $merged[$_.Key] = $_.Value
      }
  }

  return $merged
}

function Read-PortMappings {
  param([Parameter(Mandatory)][string]$Path)

  $config = ConvertFrom-Json5 $Path
  $mappings = [ordered]@{}

  function Visit($obj) {
    if ($null -eq $obj) {
      return
    }

    if (
      $obj.PSObject.Properties.Name -contains "token" -and
      $obj.PSObject.Properties.Name -contains "port"
    ) {
      $mappings[$obj.token] = [string]$obj.port
    }

    foreach ($prop in $obj.PSObject.Properties) {
      if ($prop.Value -is [psobject]) {
        Visit $prop.Value
      }
    }
  }

  Visit $config

  return $mappings
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

function ConvertTo-VcsTemplateFile {
  param(
    [Parameter(Mandatory=$true)]  [string]$InputFilePath,
    [Parameter(Mandatory=$true)]  [string]$VcsOutDirPath,
    [Parameter(Mandatory=$true)] [hashtable]$Mappings
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
  $sortedMappings = $Mappings.GetEnumerator() |
    Sort-Object { $_.Value.Length } -Descending

  foreach ($entry in $sortedMappings) {
    $token     = $entry.Key
    $localPath = [string]$entry.Value
    $isNumeric = $localPath -match '^\d+$'

    $variants = @(
      $localPath,
      ($localPath | ConvertTo-Json -Compress).Trim('"')
    )

    if ($isNumeric) {
      $quotedPattern = "`"$([regex]::Escape($localPath))`""
      $barePattern   = "(?<!\d)$([regex]::Escape($localPath))(?!\d)"
      if ($content -match $quotedPattern) {
        $content = $content -replace $quotedPattern, "`"$token`""
        Write-Host "  Replaced: `"$localPath`" -> `"$token`"" -ForegroundColor DarkCyan
      } elseif ($content -match $barePattern) {
        $content = [regex]::Replace($content, $barePattern, "`"$token`"")
        Write-Host "  Replaced: $localPath -> `"$token`"" -ForegroundColor DarkCyan
      }
      continue
    }

    foreach ($variant in $variants) {
      if ($content.Contains($variant)) {
        $content = $content.Replace($variant, $token)
        Write-Host "  Replaced: $variant -> $token" -ForegroundColor DarkCyan
      }
    }
  }

  $content | Set-Content $vcsOutFilePath -Encoding UTF8
  Format-JsonWithPrettier -FilePath $vcsOutFilePath
  Write-Host "Template saved: $vcsOutFilePath" -ForegroundColor Green

  New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $vcsOutFilePath | Out-Null
}

$FunctionsToExport = @(
  "Read-ReplacementMappings"
  "Format-JsonWithPrettier"
  "ConvertTo-VcsTemplateFile"
)

Export-ModuleMember -Function $FunctionsToExport
