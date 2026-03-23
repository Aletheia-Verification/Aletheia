# ──────────────────────────────────────────────────────────────────
# ALETHEIA — Build Script (Windows PowerShell)
# Builds frontend, verifies source files, then packages into a
# Cython-protected Docker image (two-stage build).
# ──────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "=== ALETHEIA BUILD (Cython-protected) ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Build frontend
Write-Host "[1/3] Building frontend..." -ForegroundColor Yellow
Push-Location "$ProjectDir\frontend"
npm run build
Pop-Location
Write-Host "      Frontend build complete." -ForegroundColor Green
Write-Host ""

# Step 2: Verify required files
Write-Host "[2/3] Verifying source files..." -ForegroundColor Yellow
$requiredFiles = @(
    "setup_cython.py", "cli_entry.py",
    "core_logic.py", "vault.py", "shadow_diff.py", "ebcdic_utils.py",
    "copybook_resolver.py", "cobol_analyzer_api.py",
    "generate_full_python.py", "parse_conditions.py",
    "compiler_config.py", "cobol_types.py",
    "exec_sql_parser.py", "dependency_crawler.py", "report_signing.py",
    "aletheia_cli.py", "abend_handler.py",
    "Cobol85Lexer.py", "Cobol85Parser.py", "Cobol85Listener.py",
    "license_manager.py"
)
Push-Location $ProjectDir
foreach ($f in $requiredFiles) {
    if (-not (Test-Path $f)) {
        Write-Host "ERROR: Missing required file: $f" -ForegroundColor Red
        Pop-Location
        exit 1
    }
}
Pop-Location
Write-Host "      All source files present." -ForegroundColor Green
Write-Host ""

# Step 3: Build Docker image (multi-stage with Cython)
Write-Host "[3/3] Building Docker image (Cython compilation)..." -ForegroundColor Yellow
Push-Location $ProjectDir
docker build -t aletheia:latest .
Pop-Location
Write-Host ""

Write-Host "=== BUILD COMPLETE ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run in air-gapped mode (default):"
Write-Host "  docker run -p 8000:8000 aletheia:latest" -ForegroundColor White
Write-Host ""
Write-Host "Run in connected mode (GPT-4o enabled):"
Write-Host "  docker run -p 8000:8000 -e ALETHEIA_MODE=connected -e OPENAI_API_KEY=sk-... aletheia:latest" -ForegroundColor White
Write-Host ""
Write-Host "Run CLI batch:"
Write-Host "  docker run aletheia:latest python cli_entry.py analyze /app/DEMO_LOAN_INTEREST.cbl" -ForegroundColor White
Write-Host ""
Write-Host "Run with persistent storage:"
Write-Host "  docker compose up" -ForegroundColor White
