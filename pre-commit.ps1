$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$skipped = '\\(vendor|scratch|dist|\.git)\\'
$luaFiles = @(
  Get-ChildItem -Recurse -File -Filter *.lua |
    Where-Object { $_.FullName -notmatch $skipped } |
    ForEach-Object { (Resolve-Path -Relative $_.FullName).Replace('\', '/') }
)
$testFiles = @($luaFiles | Where-Object { $_ -like '*.test.lua' })

function Invoke-Step([string]$name, [scriptblock]$command) {
  Write-Host "== $name" -ForegroundColor Cyan
  & $command
  if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: $name" -ForegroundColor Red
    exit 1
  }
}

Invoke-Step 'format' { stylua --check . }
Invoke-Step 'lint' { luacheck . }
Invoke-Step 'rules' { lua53 dev/lint/check-code-rules.lua @luaFiles }
Invoke-Step 'tests' { lua53 test/run.lua @testFiles }
Write-Host 'All checks passed' -ForegroundColor Green
