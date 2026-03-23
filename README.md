# Aletheia

Deterministic behavioral verification engine for COBOL-to-Python migrations.

Aletheia parses COBOL source code using ANTLR4, generates a deterministic Python verification model, and proves field-by-field equivalence between mainframe output and migrated output via Shadow Diff.

**PVR:** 94.3% on 459 banking programs (433 VERIFIED, 26 MANUAL REVIEW).
**Tests:** 1006 tests, 0 failures.

## Quick Start

### Backend

```bash
python -m venv venv
venv\Scripts\activate        # Windows
source venv/bin/activate     # Linux/Mac
pip install -r requirements.txt
JWT_SECRET_KEY=your-secret uvicorn core_logic:app --port 8000
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

### Docker

```bash
docker build -t aletheia .
docker run -p 8000:8000 -e JWT_SECRET_KEY=your-secret aletheia
```

## API

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/engine/analyze` | Analyze COBOL source |
| POST | `/engine/verify-full` | Analyze + Shadow Diff verification |
| POST | `/engine/trace-compare` | Execution trace divergence |
| POST | `/engine/compiler-matrix` | TRUNC/ARITH matrix |
| POST | `/engine/risk-heatmap` | Portfolio risk heatmap |
| POST | `/auth/login` | JWT authentication |
| GET | `/api/health` | Health check |

## Testing

```bash
python -m pytest test_core_logic.py test_shadow_diff.py ... -v
```

See `claude.md` for the full test command.

## Documentation

- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- [Security Whitepaper](docs/SECURITY_WHITEPAPER_V2.md)
- [API Reference](docs/API_REFERENCE.md)
- [Changelog](docs/CHANGELOG.md)

## Architecture

ANTLR4 COBOL85 parser -> deterministic Python generator -> arithmetic risk analyzer -> Shadow Diff verifier.

LLM (GPT-4o) used ONLY for explanation formatting. NEVER for correctness.

Verdict: VERIFIED or REQUIRES_MANUAL_REVIEW. No percentages. No confidence scores.
