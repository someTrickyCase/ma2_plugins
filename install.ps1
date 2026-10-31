[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)][string]$Plugin,
  [string]$MaVersion,
  [ValidateRange(1, 9999)][int]$At
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$maRoot = 'C:\ProgramData\MA Lighting Technologies\grandma'

function Stop-WithError([string]$message) {
  Write-Host "FAILED: $message" -ForegroundColor Red
  exit 1
}

function Get-MaPluginsFolder {
  $folders = Get-ChildItem $maRoot -Directory -Filter 'gma2_V_*' |
    Sort-Object { [version]($_.Name -replace '^gma2_V_', '') } -Descending
  if ($MaVersion) {
    $folders = $folders | Where-Object { $_.Name -eq "gma2_V_$MaVersion" }
  }
  $folder = @($folders)[0]
  if (-not $folder) {
    Stop-WithError "no MA2 data folder found in $maRoot"
  }
  Join-Path $folder.FullName 'plugins'
}

function Get-Commit {
  $commit = git rev-parse --short HEAD
  if (git status --porcelain) {
    $commit = "$commit-dirty"
  }
  $commit
}

if (-not (Test-Path "plugins/$Plugin/plugin.lua")) {
  Stop-WithError "unknown plugin '$Plugin'"
}

& .\pre-commit.ps1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Stop-WithError 'checks are red, run .\pre-commit.ps1 to see why'
}

New-Item -ItemType Directory -Force dist -WhatIf:$false | Out-Null
$date = Get-Date -Format 'yyyy-MM-dd'
$bundleArguments = @($Plugin, 'dist', (Get-Commit), $date)
if ($At) {
  $bundleArguments += $At
}
$built = @(lua53 dev/build/bundle-plugin.lua @bundleArguments)
if ($LASTEXITCODE -ne 0) {
  Stop-WithError 'bundling failed'
}
$luaFile, $xmlFile, $instructions = $built

luac53 -p $luaFile
if ($LASTEXITCODE -ne 0) {
  Stop-WithError "$luaFile is not valid Lua 5.3"
}
& task build | Out-Null
if ($LASTEXITCODE -ne 0) {
  Stop-WithError 'building ma2kit failed'
}
& dist\ma2kit.exe check-rules $luaFile
if ($LASTEXITCODE -ne 0) {
  Stop-WithError "$luaFile breaks the code rules"
}

$target = Get-MaPluginsFolder
foreach ($file in $luaFile, $xmlFile) {
  if ($PSCmdlet.ShouldProcess($target, "Copy $file")) {
    Copy-Item $file $target
  }
}

if ($WhatIfPreference) {
  Write-Host 'Dry run: nothing was copied' -ForegroundColor Cyan
} else {
  Write-Host "Installed to $target" -ForegroundColor Green
}
Write-Host ''
foreach ($line in $instructions) {
  Write-Host $line
}
