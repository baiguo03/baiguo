$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $env:LIZI_PORT) { $env:LIZI_PORT = "8787" }
Write-Host "Starting Lizi local backend on port $env:LIZI_PORT"
Write-Host "If AI key is needed, set LIZI_AI_KEY before running this script."
python "$Root\lizi_ai_backend.py"
