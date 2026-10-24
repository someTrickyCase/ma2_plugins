[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)][string]$Plugin,
  [string]$MaVersion
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

& .\check.ps1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Stop-WithError 'checks are red, run .\check.ps1 to see why'
}

New-Item -ItemType Directory -Force dist -WhatIf:$false | Out-Null
$date = Get-Date -Format 'yyyy-MM-dd'
$built = @(lua53 tools/bundle-cli.lua $Plugin dist (Get-Commit) $date)
if ($LASTEXITCODE -ne 0) {
  Stop-WithError 'bundling failed'
}
$luaFile = $built[0]
$xmlFile = $built[1]

luac53 -p $luaFile
if ($LASTEXITCODE -ne 0) {
  Stop-WithError "$luaFile is not valid Lua 5.3"
}
lua53 tools/check-rules-cli.lua $luaFile
if ($LASTEXITCODE -ne 0) {
  Stop-WithError "$luaFile breaks the code rules"
}

$target = Get-MaPluginsFolder
foreach ($file in $luaFile, $xmlFile) {
  if ($PSCmdlet.ShouldProcess($target, "Copy $file")) {
    Copy-Item $file $target
  }
}

$xmlName = Split-Path $xmlFile -Leaf
Write-Host "Installed to $target" -ForegroundColor Green
Write-Host 'In MA2 (replace 1 with a free plugin number):'
Write-Host "  Import `"$xmlName`" At Plugin 1"
