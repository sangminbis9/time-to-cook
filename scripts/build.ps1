$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$env:APPDATA = Join-Path $projectRoot '.tools\rebuild-user'
$env:TEMP = Join-Path $projectRoot '.tools\export-temp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force $env:TEMP | Out-Null
$enginePath = Join-Path $projectRoot '.tools\godot\Godot_v4.7-stable_win64_console.exe'
New-Item -ItemType Directory -Force (Join-Path $projectRoot 'release\windows') | Out-Null
& $enginePath --headless --path (Join-Path $projectRoot 'game') --export-release 'Windows Desktop'
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
