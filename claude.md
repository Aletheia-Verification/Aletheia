# CLAUDE.md — Aletheia Agent Instructions

## Architecture
ANTLR4 COBOL85 parser → deterministic Python generator → arithmetic risk analyzer → Shadow Diff verifier.
LLM (GPT-4o) ONLY for explanation formatting. NEVER for correctness.
Verdict: VERIFIED or REQUIRES_MANUAL_REVIEW. No percentages. No confidence scores.
Unparseable → `# MANUAL REVIEW: ...` — never garbage output.

## Key Files (1 line each)
| File | Purpose |
|------|---------|
| `core_logic.py` | FastAPI backend, all `/engine/*` endpoints, auth, rate limiting |
| `cobol_analyzer_api.py` | ANTLR4 parser wrapper, variable/statement extraction |
| `generate_full_python.py` | Deterministic Python generator (Decimal precision, IBM-matching) |
| `parse_conditions.py` | IF/EVALUATE/condition converter, `_convert_single_statement()` |
| `cobol_types.py` | CobolDecimal class, PIC truncation, COMP-3/COMP-1/COMP-2, PIC P scaling |
| `shadow_diff.py` | Shadow Diff engine, exec() sandbox, streaming pipeline, drift diagnosis |
| `vault.py` | SQLite audit trail, SHA-256 hash chain, RSA-PSS signing |
| `cobol_file_io.py` | Abstract I/O layer (StreamBackend + RealFileBackend) |
| `ebcdic_utils.py` | EBCDIC string comparison (CP037/CP500) |
| `copybook_resolver.py` | COPY/REPLACING preprocessor, REDEFINES byte offset resolution |
| `compiler_config.py` | Per-request TRUNC(STD/BIN/OPT) + ARITH(COMPAT/EXTEND) via contextvars |
| `execution_trace.py` | Trace comparison engine, divergence detection, root-cause diagnosis |
| `layout_generator.py` | Auto-generates Shadow Diff layout JSON from DATA DIVISION |
| `report_signing.py` | RSA-PSS 2048-bit report signing + verification |
| `license_manager.py` | RSA-PSS license validation, feature gating, daily limits |
| `aletheia_cli.py` | CLI batch automation (calls engine directly, no HTTP) |
| `risk_heatmap.py` | Risk heatmap from enriched analysis |
| `dead_code_analyzer.py` | Paragraph-level reachability analysis |
| `verb_handlers.py` | INITIALIZE/SET/STRING/UNSTRING emit helpers |
| `jcl_parser.py` | JCL job/step/DD parser |
| `sbom_generator.py` | CycloneDX 1.4 SBOM from COBOL |
| `dependency_crawler.py` | CALL graph builder, linkage section mapper |
| `audit_logger.py` | Compliance event logging |
| `abend_handler.py` | S0C7 data exception emulation |
| `exec_sql_parser.py` | EXEC SQL/CICS detection + taint analysis |
| `poison_pill_generator.py` | Edge-case test record generator |

## Tech Stack
Backend: Python 3.12, FastAPI, ANTLR4, SQLite. Frontend: React 19, Vite 7, Tailwind 3.
Auth: JWT HS256 via `JWT_SECRET_KEY` env var. Token key: `alethia_token` in localStorage.
`USE_IN_MEMORY_DB=1` for tests (set automatically). Default compiler: TRUNC(STD), ARITH(COMPAT).

## Engineering Rules
- NEVER use float for currency. Always `decimal.Decimal`.
- `generate_python_module()` returns `{"code": str, "emit_counts": dict, "mr_flags": list, "compiler_warnings": list}` — callers unwrap `["code"]`.
- Satellite modules (vault, shadow_diff, copybook_resolver): own APIRouter, lazy-import auth, mounted in core_logic.
- `parse_fixed_width()` and `execute_generated_python()` return generators — wrap with `list()` if you need len/indexing.
- exec() sandbox: `_SAFE_BUILTINS` removes eval/exec/compile/open/getattr/setattr/__import__. AST check blocks `__subclasses__`/`__bases__`/`__globals__`. Default: subprocess isolation. Constants type-checked.
- Qualified names: duplicate field names get `PARENT__FIELD` keys in var_info. `cobol_to_qualified` reverse map for lookups.
- Compiler config uses `contextvars.ContextVar` — thread-safe, per-request isolation.

## Testing
**1006+ tests. Run after every change. Zero regressions policy.**
**PVR: 94.3% on 459 programs (433 VERIFIED, 26 MANUAL REVIEW).**
```
"venv\Scripts\python.exe" -m pytest test_core_logic.py test_shadow_diff.py test_ebcdic.py test_copybook.py test_abend.py test_cobol_types.py test_cli.py test_cli_verify.py test_dependency.py test_exec_sql.py test_signing.py test_generator_edge_cases.py test_integration_stress.py test_layout_generator.py test_dead_code.py test_file_io.py test_generator_fixes.py test_resilience_fixes.py test_security_fixes.py test_parse_conditions.py test_endpoints_new.py test_sort.py test_integration.py test_negative_verification.py test_compiler_matrix.py test_risk_heatmap.py test_search.py test_execution_trace.py test_scoped_namespace.py test_odo.py test_pic_scaling.py test_exec_sandbox.py test_sign_clause.py test_goto_thru.py test_streaming_compare.py test_generator_wiring.py test_mr_top3.py test_audit_logger.py semantic_corpus/run_corpus.py -v
```
Single: `"venv\Scripts\python.exe" -m pytest test_shadow_diff.py::TestFullPipeline::test_demo_data_zero_drift -v`
Frontend: `cd frontend && npm run build`
Corpus: `python semantic_corpus/run_corpus.py` (168 behavioral execution tests — 50 base + 118 adversarial)

## Construct Support Matrix
| Emitted (→ Python) | Flagged (→ MANUAL REVIEW) |
|---------------------|---------------------------|
| MOVE, COMPUTE, ADD/SUB/MUL/DIV (GIVING/REMAINDER) | CALL/CANCEL (subprogram not analyzed) |
| IF/ELSE, EVALUATE TRUE/variable/ALSO, WHEN/WHEN OTHER | ALTER (hard stop) |
| PERFORM paragraph/THRU/VARYING/TIMES/AFTER/TEST AFTER | EVALUATE ALSO (multi-subject) |
| STRING DELIMITED BY SIZE/SPACES, WITH POINTER, OVERFLOW | OCCURS DEPENDING ON (detected, not emitted) |
| UNSTRING DELIMITED BY (incl. OR), POINTER/COUNT/TALLYING | WRITE with ADVANCING, OPEN I-O/EXTEND |
| INSPECT TALLYING FOR ALL/CHARACTERS/LEADING/BEFORE/AFTER | MERGE (rare construct) |
| INSPECT REPLACING ALL/FIRST/CHARACTERS/BEFORE/AFTER | LINAGE (complex print control) |
| INSPECT CONVERTING (incl. figurative constants) | Section fall-through (warning emitted) |
| DISPLAY, GO TO, GO TO DEPENDING ON, STOP RUN, INITIALIZE | RENAMES THRU (byte-level range) |
| IS NUMERIC/ALPHABETIC class conditions | ADD/SUBTRACT CORRESPONDING |
| COMP-3, COMP/COMP-4/COMP-5/BINARY/PACKED-DECIMAL | INITIALIZE REPLACING |
| COMP-1/COMP-2 float, edited PIC (ZZZ,ZZ9.99 etc.) | Any unrecognized statement |
| 88-level conditions (single value, multiple values) | |
| EBCDIC string ordering (PIC X/A/N via ebcdic_compare) | |
| COPY/REPLACING (recursive, LEADING/TRAILING) | |
| EXEC SQL/CICS detection + taint analysis | |
| OCCURS tables, subscript access (1→0 indexed) | |
| OPEN/READ/WRITE/CLOSE, FILE STATUS, READ KEY IS | |
| SEARCH/SEARCH ALL, SORT (ASC/DESC KEY) | |
| FUNCTION intrinsics (12): LENGTH/MAX/MIN/ABS/MOD/etc. | |
| SIGN LEADING/TRAILING SEPARATE, PIC P scaling | |
| DECIMAL-POINT IS COMMA, MOVE CORRESPONDING | |
| ACCEPT FROM DATE/TIME/DAY, Level 66 RENAMES (simple) | |
| VALUE clause on all USAGE types (COMP-3/COMP/DISPLAY) | |
| Group MOVE with FILLER byte gaps preserved | |

## Agent Protocol
- Plan first. Show step-by-step before writing code.
- Never touch parser/generator/arithmetic unless explicitly told to.
- Run relevant tests after every code change.
- If tests fail, revert and report what went wrong.
- When asked to audit, ONLY report — do not fix.
- Reports must explain WHAT changed, WHY it matters, WHAT could break.

## Vocabulary
"Audit" → "Behavioral Verification" | "Translation" → "Logic Extraction"
"Generated Python" → "Verification Model" | "Confidence" → BANNED WORD

## Endpoints
| Method | Path | Auth | License | Purpose |
|--------|------|------|---------|---------|
| POST | `/engine/analyze` | JWT | Yes | Main COBOL analysis |
| POST | `/engine/analyze-batch` | JWT | Yes | Multi-file batch |
| POST | `/engine/verify-full` | JWT | Yes | Engine + Shadow Diff combined |
| POST | `/engine/trace-compare` | JWT | No | Execution trace divergence |
| POST | `/engine/compiler-matrix` | JWT | No | TRUNC/ARITH matrix |
| POST | `/engine/risk-heatmap` | JWT | No | Portfolio risk heatmap |
| POST | `/engine/generate-layout` | JWT | No | Auto-layout from DATA DIVISION |
| POST | `/engine/parse-jcl` | JWT | No | JCL parser |
| POST | `/engine/generate-sbom` | JWT | No | Software BOM |
| POST | `/auth/login` | No | No | JWT login (rate limited 5/min/IP) |
| GET | `/api/health` | No | No | Health check |

## Docker
Two-stage Cython build. Air-gapped default (`ALETHEIA_MODE=air-gapped`). Non-root user.
`docker run -p 8000:8000 aletheia:latest`
Connected: add `-e ALETHEIA_MODE=connected -e OPENAI_API_KEY=sk-...`
Volumes: vault.db, copybooks/, license/ (read-only)

## Design (frontend)
Style: "Luxury Brutalism" — sharp edges, wide tracking, heavy negative space.
Palette: navy #1B2A4A + gold #C9A84C. No gradients, no neon, no rounded buttons, no bouncy animations.
Target: bank executives and compliance officers.

## See Also
- `docs/CHANGELOG.md` — detailed feature history
- `docs/SECURITY_WHITEPAPER_V2.md` — full security architecture
- `docs/AUDIT_POST_MEGA_SESSION.md` — code audit findings
- `docs/DEPLOYMENT_GUIDE.md` — deployment documentation
- `docs/CLAUDE_MD_MAINTENANCE_PROMPT.md` — session-start checklist to keep CLAUDE.md current
- `docs/ADVERSARIAL_AUDIT.md` — adversarial security audit findings
