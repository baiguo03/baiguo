$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Project = Split-Path -Parent $Root
$OutDir = Join-Path $Project "outputs"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Zip = Join-Path $OutDir "lizi-backend.zip"
if (Test-Path $Zip) { Remove-Item $Zip -Force }
Compress-Archive -Path (Join-Path $Root "*") -DestinationPath $Zip
Write-Host "Backend package created: $Zip"
