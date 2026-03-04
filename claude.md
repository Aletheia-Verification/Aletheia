# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

ALETHEIA — Behavioral Verification Engine
1. PROJECT IDENTITY
Deterministic behavioral verification engine for COBOL-to-Python legacy system migration, targeting banks.
NOT a transpiler. NOT an AI translator. The engine provides risk reduction and behavioral proof.
Brand values: Quiet Confidence, Mathematical Truth, Institutional Power.
YC Spring 2026 applicant.
2. ARCHITECTURE

ANTLR4 COBOL85 parser → deterministic Python generator → arithmetic risk analyzer
LLM (GPT-4o) is ONLY for formatting/explanation. NEVER for correctness.
If something can't be parsed cleanly → # MANUAL REVIEW: ... — never garbage output
Binary verification: VERIFIED or REQUIRES_MANUAL_REVIEW. No percentages. No confidence scores.
21/21 edge case tests, 1,000,000 stress tests, 100% accuracy

3. KEY FILES

core_logic.py — FastAPI backend (2200+ lines), main endpoint /engine/analyze
cobol_analyzer_api.py — ANTLR4 parser wrapper
generate_full_python.py — deterministic Python generator (Decimal precision, IBM-matching)
parse_conditions.py — IF statement / 88-level condition converter
vault.py — SQLite audit trail storage (vault.db)
shadow_diff.py — Shadow Diff verification engine
frontend/src/components/Engine.jsx — main analysis UI
frontend/src/components/ShadowDiff.jsx — Shadow Diff UI
frontend/src/components/Vault.jsx — audit trail UI
frontend/src/utils/pdfExport.js — Engine PDF report generation (engineer + executive modes)
frontend/src/utils/shadowDiffPdf.js — Shadow Diff PDF report generation (engineer + executive modes)
DEMO_LOAN_INTEREST.cbl — primary test file
abend_handler.py — S0C7 exception emulation + zoned decimal overpunch decoder
cobol_types.py — CobolDecimal class, PIC arithmetic constraints
ebcdic_utils.py — EBCDIC string comparison (CP037/CP500)
copybook_resolver.py — COPY/REPLACING preprocessor + REDEFINES resolver
compiler_config.py — per-request TRUNC mode (STD/BIN/OPT)
dependency_crawler.py — CALL statement detection, dependency tree
exec_sql_parser.py — EXEC SQL/CICS parsing, taint analysis
report_signing.py — RSA signing of verification reports
aletheia_cli.py — CLI for headless batch automation (no HTTP, calls engine directly)
test_generator_edge_cases.py — edge case tests for Python generator
test_integration_stress.py — integration stress tests

4. TECH STACK

Backend: Python, FastAPI, ANTLR4, SQLite
Frontend: React, Vite, Framer Motion (subtle transitions only)
Theme: Light/white professional (navy #1B2A4A + gold #C9A84C accents)
Python 3.12, React 19, Vite 7, Tailwind 3, Framer Motion 12, jsPDF (no plugins)
Auth: JWT (HS256, 24h), token key `alethia_token` in localStorage
USE_IN_MEMORY_DB env var controls test vs production mode (tests set it automatically)

5. DESIGN RULES (NON-NEGOTIABLE)

Style: "Luxury Brutalism" — sharp edges, wide tracking, heavy negative space
Palette: High-Trust Silver, Industrial White, Deep Carbon. Gold accents only.
Forbidden: No "AI Glow," no gradients, no neon, no rounded bubbly buttons, no tech-startup fluff, no bouncy animations
Animations: ONLY subtle fades (150ms) and smooth expand/collapse. Nothing playful.
The Gateway leads to THE ENGINE (verification) and THE VAULT (audit trail)
Target audience: Bank executives and compliance officers

6. ENGINEERING STANDARDS

NEVER use floating-point for currency. Always decimal.Decimal in Python.
0% error margin. If COBOL translation is ambiguous, output # MANUAL REVIEW
PIC arithmetic: Add/Sub integers = max(A,B)+1, Mul integers = A+B, Div = unbounded
Generated Python must match IBM mainframe precision exactly

7. TESTING (RUN AFTER EVERY CHANGE)

Backend: pytest test_core_logic.py -v (currently 60/60 passing)
Shadow Diff: pytest test_shadow_diff.py -v (currently 29/29 passing)
EBCDIC: pytest test_ebcdic.py -v (currently 22/22 passing)
Copybook: pytest test_copybook.py -v (currently 18/18 passing)
Abend: pytest test_abend.py -v (currently 20/20 passing)
Frontend: cd frontend && npm run build
Manual: Upload DEMO_LOAN_INTEREST.cbl → should show VERIFIED
CobolTypes: pytest test_cobol_types.py -v (currently 14/14 passing)
CLI: pytest test_cli.py -v (currently 12/12 passing)
Dependency: pytest test_dependency.py -v (currently 20/20 passing)
ExecSQL: pytest test_exec_sql.py -v (currently 13/13 passing)
Signing: pytest test_signing.py -v (currently 11/11 passing)
Windows venv: "venv\Scripts\python.exe" -m pytest <file> -v
Single test: "venv\Scripts\python.exe" -m pytest test_shadow_diff.py::TestFullPipeline::test_demo_data_zero_drift -v
Frontend dev: cd frontend && npm run dev (port 5173)
Frontend lint: cd frontend && npm run lint
Backend start: "venv\Scripts\python.exe" -m uvicorn core_logic:app --host 0.0.0.0 --port 8000

8. VOCABULARY

"Audit" → "Behavioral Verification"
"Translation" → "Logic Extraction"
"Generated Python" → "Verification Model"
"Confidence" → BANNED WORD

9. CLAUDE BEHAVIORAL PROTOCOL

Plan first: Always provide step-by-step plan before writing code
Audit: Before finishing, verify no startup-style design elements leaked in
Conciseness: No long explanations. Straight to the point.
Never touch parser, generator, or arithmetic analyzer unless explicitly told to
Never add confidence percentages or scores
NEVER edit a file without being explicitly told to
When asked to audit, ONLY report findings — do not fix anything
Show before/after diffs for every change
If tests fail, revert the change and report what went wrong
Run the relevant test suite after every code change
Zero regressions policy: all existing tests must pass after every change
Never rewrite or reorganize CLAUDE.md without explicit permission. Only append or update specific lines when told to.

10. SHADOW DIFF ENGINE (shadow_diff.py)

Ingests mainframe-style fixed-width flat files
Parses input records using layout definitions (JSON)
Executes generated Python against each input record
Compares outputs to real mainframe output data field-by-field
Exact Decimal match required — no epsilon tolerance
Vault UI has pagination, search, and Verify All button
Verdict: "ZERO DRIFT CONFIRMED" or "DRIFT DETECTED — X RECORDS"
COMP-3 packed decimal decoder included
diagnose_drift() enriches mismatches with root cause analysis + suggested fix
PDF export: frontend/src/utils/shadowDiffPdf.js (engineer + executive modes)
Demo data: loan_mainframe_output.dat (0% drift), loan_mainframe_output_WITH_DRIFT.dat (5 intentional mismatches)
Streaming pipeline handles files up to 50GB from disk, constant RAM usage
Endpoints at /shadow-diff/*
Demo data: 100 loan records in demo_data/
29 tests passing
generate_python_module() returns dict {"code": str, "emit_counts": dict} — all callers must unwrap ["code"]

11. EBCDIC STRING COMPARISON (ebcdic_utils.py)

IBM Code Page 037 (US/Canada) and 500 (International)
ebcdic_compare() replaces native Python string comparison for PIC X fields
Generated Python automatically uses ebcdic_compare for string ordering comparisons
Numeric comparisons (PIC 9) unchanged
22 tests passing

12. COPYBOOK RESOLVER (copybook_resolver.py)

Detects COPY statements in COBOL source
Resolves from uploaded copybook library (copybooks/ directory)
Handles REPLACING clause
Preprocesses source before ANTLR4 parsing
REDEFINES detection with byte offset mapping
Unresolved copybooks flagged, not fatal
Endpoints at /copybook/*
18 tests passing

13. DOCKER DEPLOYMENT

Dockerfile: python:3.12-slim, single container, everything included
Air-gapped mode (default): zero external calls, offline stubs
Connected mode: GPT-4o enabled for explanation formatting
docker-compose.yml: vault.db volume mount, copybooks volume
Build: scripts/build.sh (Linux) or scripts/build.ps1 (Windows)
Run: docker run -p 8000:8000 aletheia:latest
Connected: docker run -p 8000:8000 -e ALETHEIA_MODE=connected -e OPENAI_API_KEY=sk-... aletheia:latest
CLI batch: docker run aletheia:latest python aletheia_cli.py analyze /app/DEMO_LOAN_INTEREST.cbl
Volumes: docker compose up (vault.db + copybooks persisted)

14. FULL TEST SUITE (~230+ tests)

test_core_logic.py: 60 tests
test_shadow_diff.py: 29 tests
test_ebcdic.py: 22 tests
test_copybook.py: 18 tests
test_abend.py: 20 tests
test_cobol_types.py: 14 tests
test_cli.py: 12 tests
test_dependency.py: 20 tests
test_exec_sql.py: 13 tests
test_signing.py: 11 tests
test_generator_edge_cases.py: 13 tests
Run all: pytest test_core_logic.py test_shadow_diff.py test_ebcdic.py test_copybook.py test_abend.py test_cobol_types.py test_cli.py test_dependency.py test_exec_sql.py test_signing.py test_generator_edge_cases.py -v

15. MODULE ARCHITECTURE

Satellite modules (vault.py, shadow_diff.py, copybook_resolver.py) all follow the same pattern:
- Define their own APIRouter
- Proxy auth back to core_logic.verify_token via lazy import (avoids circular deps)
- Conditionally mounted in core_logic.py with app.include_router(router, prefix=...)
- parse_fixed_width() and execute_generated_python() return generators — callers needing len()/indexing must wrap with list()
- CLI (aletheia_cli.py) calls engine functions directly, not over HTTP

16. MULTI-FILE BATCH ANALYSIS

POST /engine/analyze-batch accepts multiple COBOL files + copybooks, processes in topological order
Cross-file CALL resolution injected as audit documentation blocks
Combined AND-gate verdict: all files must pass for batch VERIFIED