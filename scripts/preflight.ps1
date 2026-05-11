# Phase 8.1 — pre-merge gate (PowerShell port of preflight.sh).
#
# Identical contract: zero analyze issues, every test green, no
# forbidden patterns in lib/. Exit code 0 on green, 1 on failure.
#
# Use this from a native PowerShell prompt; the .sh sibling is for
# Git Bash and CI.

$ErrorActionPreference = 'Stop'
$rootDir = Split-Path -Parent $PSScriptRoot
Set-Location $rootDir

function Section($name) {
  Write-Host ""
  Write-Host "==> $name" -ForegroundColor Cyan
}

function FailWith($msg) {
  Write-Host ""
  Write-Host "FAIL — $msg" -ForegroundColor Red
  exit 1
}

# 1. Static analyzer.
Section 'flutter analyze'
& flutter analyze
if ($LASTEXITCODE -ne 0) { FailWith 'flutter analyze reported issues' }

# 2. Full test suite (includes test/lint/ structural checks).
Section 'flutter test'
& flutter test --concurrency=4
if ($LASTEXITCODE -ne 0) { FailWith 'flutter test failed' }

# 3. Forbidden-pattern sweep.
Section 'forbidden pattern sweep (lib/)'

$rules = @(
  @{Pattern = '\.withOpacity\s*\(';                        Label = 'withOpacity(  (use withValues(alpha: …))'},
  @{Pattern = '(^|[^A-Za-z_])print\s*\(';                  Label = 'print(  (use debugPrint or CrashLog.record)'},
  @{Pattern = 'GoogleFonts';                               Label = 'GoogleFonts reference  (Phase 2.3 removed package)'},
  @{Pattern = "import\s+['""]\.\.?\/main\.dart['""]";      Label = "import '../main.dart'  (Phase 2.1 extracted AppColors)"},
  @{Pattern = "import\s+['""]package:budget_tracker\/";    Label = 'package self-import  (use relative path)'}
)

$dartFiles = Get-ChildItem -Path 'lib' -Recurse -Filter '*.dart' -File
foreach ($rule in $rules) {
  $hits = $dartFiles | Select-String -Pattern $rule.Pattern -SimpleMatch:$false
  if ($hits) {
    foreach ($hit in $hits) {
      Write-Host ("{0}:{1}  {2}" -f $hit.Path, $hit.LineNumber, $hit.Line.Trim())
    }
    FailWith ('Forbidden pattern hit: ' + $rule.Label)
  }
}

Write-Host ""
Write-Host 'preflight green' -ForegroundColor Green
