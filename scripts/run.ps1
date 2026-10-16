param([switch]$Headless, [switch]$Smoke)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$enginePath = Join-Path $projectRoot '.tools\godot\Godot_v4.7-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { $enginePath = (Get-Command godot -ErrorAction Stop).Source }
$env:APPDATA = Join-Path $projectRoot '.tools\rebuild-user'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$gameArgs = @('--path', (Join-Path $projectRoot 'game'))
if ($Headless -or $Smoke) { $gameArgs += '--headless' }
if ($Smoke) { $gameArgs += @('--script', 'res://rebuild/smoke.gd') }
& $enginePath @gameArgs
exit $LASTEXITCODE
