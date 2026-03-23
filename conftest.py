"""Pytest configuration — runs before any test module imports."""
import os
import pytest
from decimal import getcontext

# Use inline exec mode for tests (fast). Production defaults to subprocess.
os.environ.setdefault("ALETHEIA_EXEC_MODE", "inline")


@pytest.fixture(autouse=True, scope="function")
def _protect_decimal_context():
    """Save/restore Decimal context and compiler config around every test."""
    original_prec = getcontext().prec
    original_rounding = getcontext().rounding
    yield
    getcontext().prec = original_prec
    getcontext().rounding = original_rounding
    # Reset compiler config to defaults (prevents TRUNC/ARITH mode leaking)
    try:
        from compiler_config import reset_config
        reset_config()
    except ImportError:
        pass
