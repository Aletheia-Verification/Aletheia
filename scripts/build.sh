#!/bin/bash
# ──────────────────────────────────────────────────────────────────
# ALETHEIA — Build Script (Linux/macOS)
# Builds frontend, verifies source files, then packages into a
# Cython-protected Docker image (two-stage build).
# ──────────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== ALETHEIA BUILD (Cython-protected) ==="
echo ""

# Step 1: Build frontend
echo "[1/3] Building frontend..."
cd "$PROJECT_DIR/frontend"
npm run build
cd "$PROJECT_DIR"
echo "      Frontend build complete."
echo ""

# Step 2: Verify required files
echo "[2/3] Verifying source files..."
REQUIRED_FILES=(
    setup_cython.py cli_entry.py
    core_logic.py vault.py shadow_diff.py ebcdic_utils.py
    copybook_resolver.py cobol_analyzer_api.py
    generate_full_python.py parse_conditions.py
    compiler_config.py cobol_types.py
    exec_sql_parser.py dependency_crawler.py report_signing.py
    aletheia_cli.py abend_handler.py
    Cobol85Lexer.py Cobol85Parser.py Cobol85Listener.py
    license_manager.py
)
for f in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: Missing required file: $f" >&2
        exit 1
    fi
done
echo "      All source files present."
echo ""

# Step 3: Build Docker image (multi-stage with Cython)
echo "[3/3] Building Docker image (Cython compilation)..."
docker build -t aletheia:latest .
echo ""

echo "=== BUILD COMPLETE ==="
echo ""
echo "Run in air-gapped mode (default):"
echo "  docker run -p 8000:8000 aletheia:latest"
echo ""
echo "Run in connected mode (GPT-4o enabled):"
echo "  docker run -p 8000:8000 -e ALETHEIA_MODE=connected -e OPENAI_API_KEY=sk-... aletheia:latest"
echo ""
echo "Run CLI batch:"
echo "  docker run aletheia:latest python cli_entry.py analyze /app/DEMO_LOAN_INTEREST.cbl"
echo ""
echo "Run with persistent storage:"
echo "  docker compose up"
