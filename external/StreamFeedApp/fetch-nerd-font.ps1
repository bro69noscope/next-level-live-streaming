$ErrorActionPreference = "Stop"

$version = "v3.2.1"
$family = "JetBrainsMono"
$url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$version/$family.zip"
$destDir = "wwwroot/fonts"
$zipPath = "$env:TEMP\$family.zip"

New-Item -ItemType Directory -Force -Path $destDir | Out-Null
curl.exe -L $url -o $zipPath

Expand-Archive -Path $zipPath -DestinationPath "$env:TEMP\$family-extract" -Force
Copy-Item "$env:TEMP\$family-extract\JetBrainsMonoNerdFont-Regular.ttf" -Destination $destDir

Remove-Item $zipPath, "$env:TEMP\$family-extract" -Recurse -Force
