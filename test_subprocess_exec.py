"""
test_subprocess_exec.py — Subprocess execution isolation tests.

5 tests covering:
  - Simple program execution in subprocess (1)
  - Timeout kills cleanly (1)
  - Error handling (1)
  - Inline mode unchanged (1)
  - Process isolation (1)

Run: pytest test_subprocess_exec.py -v
"""

import os
import pytest
from decimal import Decimal

os.environ["USE_IN_MEMORY_DB"] = "1"

from compiler_config import reset_config


@pytest.fixture(autouse=True)
def _reset():
    reset_config()
    yield
    reset_config()


# Minimal generated Python that mirrors Aletheia's output format
SIMPLE_PROGRAM = """\
from decimal import Decimal, getcontext, ROUND_DOWN
from cobol_types import CobolDecimal
from compiler_config import set_config, get_config

set_config(trunc_mode='STD', arith_mode='COMPAT')
getcontext().prec = 31

ws_result = CobolDecimal('0', pic_integers=5, pic_decimals=2, is_signed=False)
ws_input = CobolDecimal('0', pic_integers=5, pic_decimals=2, is_signed=False)

def main():
    ws_result.store(ws_input.value * Decimal('2'))
"""

INFINITE_LOOP_PROGRAM = """\
from decimal import Decimal, getcontext, ROUND_DOWN
from cobol_types import CobolDecimal
from compiler_config import set_config, get_config

set_config(trunc_mode='STD', arith_mode='COMPAT')
getcontext().prec = 31

ws_result = CobolDecimal('0', pic_integers=5, pic_decimals=2, is_signed=False)

def main():
    while True:
        pass
"""

SYNTAX_ERROR_PROGRAM = """\
from decimal import Decimal
def main(
    # missing closing paren — SyntaxError
"""


class TestSubprocessExec:
    """Test subprocess execution mode for generated Python."""

    def test_subprocess_simple_program(self):
        """Basic program runs in subprocess and returns correct output."""
        from shadow_diff import _subprocess_execute_one_record

        result = _subprocess_execute_one_record(
            source=SIMPLE_PROGRAM,
            record={"INPUT_VAL": Decimal("12.50")},
            rec_idx=0,
            input_mapping={"INPUT_VAL": "ws_input"},
            output_fields=["ws_result"],
            timeout_seconds=10,
        )
        assert "_error" not in result, f"Unexpected error: {result.get('_error')}"
        assert result["ws_result"] == "25.00", f"Expected 25.00, got {result['ws_result']}"
        assert result["_record_index"] == 0

    def test_subprocess_timeout(self):
        """Infinite loop killed cleanly within timeout."""
        from shadow_diff import _subprocess_execute_one_record

        result = _subprocess_execute_one_record(
            source=INFINITE_LOOP_PROGRAM,
            record={},
            rec_idx=0,
            input_mapping={},
            output_fields=["ws_result"],
            timeout_seconds=2,
        )
        assert "_error" in result
        assert "Timeout" in result["_error"] or "timeout" in result["_error"].lower()

    def test_subprocess_error_handling(self):
        """Invalid Python returns error dict, not crash."""
        from shadow_diff import _subprocess_execute_one_record

        result = _subprocess_execute_one_record(
            source=SYNTAX_ERROR_PROGRAM,
            record={},
            rec_idx=0,
            input_mapping={},
            output_fields=[],
            timeout_seconds=5,
        )
        assert "_error" in result
        # Should contain error info, not crash the test

    def test_inline_mode_unchanged(self):
        """Default inline mode uses exec() — existing behavior."""
        from shadow_diff import _execute_one_record

        result = _execute_one_record(
            source=SIMPLE_PROGRAM,
            record={"INPUT_VAL": Decimal("10.00")},
            rec_idx=0,
            input_mapping={"INPUT_VAL": "ws_input"},
            output_fields=["ws_result"],
            timeout_seconds=5,
        )
        assert "_error" not in result, f"Unexpected error: {result.get('_error')}"
        assert result["ws_result"] == "20.00"

    def test_subprocess_isolation(self):
        """Subprocess can't modify parent process globals."""
        import shadow_diff

        # Store a sentinel in the parent module
        shadow_diff._TEST_SENTINEL = "PARENT_INTACT"

        # Run subprocess — it has its own memory space
        from shadow_diff import _subprocess_execute_one_record

        program = """\
from decimal import Decimal, getcontext, ROUND_DOWN
from cobol_types import CobolDecimal
from compiler_config import set_config
set_config(trunc_mode='STD', arith_mode='COMPAT')
getcontext().prec = 31
ws_out = CobolDecimal('0', pic_integers=3, pic_decimals=0)
def main():
    ws_out.store(Decimal('42'))
"""
        result = _subprocess_execute_one_record(
            source=program,
            record={},
            rec_idx=0,
            input_mapping={},
            output_fields=["ws_out"],
            timeout_seconds=10,
        )
        assert result["ws_out"] == "42"

        # Parent process state untouched
        assert shadow_diff._TEST_SENTINEL == "PARENT_INTACT"
        del shadow_diff._TEST_SENTINEL
