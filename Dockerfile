# ──────────────────────────────────────────────────────────────────
# ALETHEIA — IP-Protected Multi-Stage Build
# Stage 1: Compile Python → .so via Cython
# Stage 2: Runtime image with only .so + non-IP assets
# ──────────────────────────────────────────────────────────────────

# ============================================================
# STAGE 1: COMPILE
# ============================================================
FROM python:3.12-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       gcc \
       python3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Python dependencies + Cython (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir cython

# Core engine files (15)
COPY core_logic.py vault.py shadow_diff.py ebcdic_utils.py \
     copybook_resolver.py cobol_analyzer_api.py \
     generate_full_python.py parse_conditions.py \
     compiler_config.py cobol_types.py \
     exec_sql_parser.py dependency_crawler.py report_signing.py \
     aletheia_cli.py abend_handler.py ./

# ANTLR4 generated parser files (3)
COPY Cobol85Lexer.py Cobol85Parser.py Cobol85Listener.py ./

# Cython build config
COPY setup_cython.py ./

# Compile all files to .so (tolerates individual file failures)
RUN python setup_cython.py build_ext --inplace 2>&1 | tee /build/cython_build.log \
    || echo "[Cython] Some files failed — fallback will handle them"

# Collect results — fallback .py for any files that failed
RUN python setup_cython.py collect \
    && touch /build/cython_fallback/.keep

# Remove source .py and intermediate .c from builder
RUN rm -f *.c *.py

# ============================================================
# STAGE 2: RUNTIME (no source code, no compiler)
# ============================================================
FROM python:3.12-slim

WORKDIR /app

# Runtime dependencies only (no build-essential, no gcc, no Cython)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Compiled modules (.so) from Stage 1 ──
COPY --from=builder /build/*.so ./

# ── Fallback .py files (any that Cython couldn't compile) ──
COPY --from=builder /build/cython_fallback/ ./cython_fallback_tmp/
RUN if ls cython_fallback_tmp/*.py 1>/dev/null 2>&1; then \
        mv cython_fallback_tmp/*.py ./; \
    fi && rm -rf cython_fallback_tmp/

# ── Non-compiled Python files (not core IP) ──
COPY license_manager.py ./
COPY auditor_pipeline.py email_service.py database.py models.py ./
COPY cli_entry.py ./

# ── Non-Python assets ──
# Alembic migrations
COPY alembic/ ./alembic/
COPY alembic.ini* ./

# SBOM (Software Bill of Materials)
COPY sbom.json ./

# Demo data
COPY demo_data/ ./demo_data/
COPY DEMO_LOAN_INTEREST.cbl ./

# Frontend (pre-built static files)
COPY frontend/dist/ ./frontend/dist/

# Copybooks directory (empty — volume-mounted in production)
RUN mkdir -p copybooks

# License directory (volume-mounted in production)
RUN mkdir -p license

# Default: air-gapped mode (no external API calls)
ENV ALETHEIA_MODE=air-gapped
ENV PYTHONUNBUFFERED=1

# Zero telemetry
ENV DO_NOT_TRACK=1

# Run as non-root user
RUN adduser --disabled-password --no-create-home appuser
USER appuser

EXPOSE 8000

# Web UI mode (default)
CMD ["uvicorn", "core_logic:app", "--host", "0.0.0.0", "--port", "8000"]
# CLI mode: docker run aletheia:latest python cli_entry.py analyze /app/DEMO_LOAN_INTEREST.cbl
