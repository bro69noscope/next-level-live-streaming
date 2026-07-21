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
    [string]$MappingsPath
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

  return $merged
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

$FunctionsToExport = @(
  "Read-ReplacementMappings"
  "Format-JsonWithPrettier"
)

Export-ModuleMember -Function $FunctionsToExport
