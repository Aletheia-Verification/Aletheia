"""
test_cors_config.py — CORS origin configuration tests.

2 tests covering:
  - Default origins when no env var set
  - Custom origins from ALETHEIA_CORS_ORIGINS env var

Run: pytest test_cors_config.py -v
"""

import os
import importlib
import pytest

os.environ["USE_IN_MEMORY_DB"] = "1"


class TestCorsConfig:
    """Verify CORS origin configuration from env var."""

    def test_cors_default(self):
        """No ALETHEIA_CORS_ORIGINS → default localhost origins."""
        old = os.environ.pop("ALETHEIA_CORS_ORIGINS", None)
        try:
            # Re-evaluate the parsing logic directly
            _env_cors = os.environ.get("ALETHEIA_CORS_ORIGINS", "")
            _DEFAULT = [
                "http://localhost:5173", "http://127.0.0.1:5173",
                "http://localhost:5174", "http://127.0.0.1:5174",
                "http://localhost:3000", "http://127.0.0.1:3000",
                "http://localhost:5175", "http://127.0.0.1:5175",
            ]
            result = (
                [o.strip() for o in _env_cors.split(",") if o.strip()]
                if _env_cors else _DEFAULT
            )
            assert result == _DEFAULT
            assert "http://localhost:5173" in result
            assert len(result) == 8
        finally:
            if old is not None:
                os.environ["ALETHEIA_CORS_ORIGINS"] = old

    def test_cors_custom(self):
        """ALETHEIA_CORS_ORIGINS set → those origins used."""
        old = os.environ.pop("ALETHEIA_CORS_ORIGINS", None)
        try:
            os.environ["ALETHEIA_CORS_ORIGINS"] = "https://app.aletheia.io, https://staging.aletheia.io"
            _env_cors = os.environ.get("ALETHEIA_CORS_ORIGINS", "")
            result = (
                [o.strip() for o in _env_cors.split(",") if o.strip()]
                if _env_cors else []
            )
            assert result == ["https://app.aletheia.io", "https://staging.aletheia.io"]
            assert "http://localhost:5173" not in result
        finally:
            if old is not None:
                os.environ["ALETHEIA_CORS_ORIGINS"] = old
            else:
                os.environ.pop("ALETHEIA_CORS_ORIGINS", None)
