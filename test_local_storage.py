"""
test_local_storage.py -- LOCAL-STORAGE SECTION support.

LOCAL-STORAGE variables reinitialize on every CALL/entry to the program,
unlike WORKING-STORAGE which persists between calls.

3 tests:
  (a) WORKING-STORAGE only — variables persist between calls
  (b) LOCAL-STORAGE only — variables reset each call
  (c) BOTH sections — WORKING persists, LOCAL resets
"""

from decimal import Decimal
from cobol_analyzer_api import analyze_cobol
from generate_full_python import generate_python_module


# ── Test helpers ────────────────────────────────────────────────


def _parse_and_generate(cobol_code: str) -> dict:
    """Parse COBOL, generate Python, return result dict."""
    analysis = analyze_cobol(cobol_code)
    assert analysis.get("success"), f"Parse failed: {analysis.get('parse_errors')}"
    return generate_python_module(analysis)


def _exec_main_twice(generated_code: str) -> tuple:
    """Execute main() twice, return (globals_after_call1, globals_after_call2)."""
    ns = {}
    exec(generated_code, ns)
    main_fn = ns["main"]

    # Call 1
    main_fn()
    snapshot1 = {k: v for k, v in ns.items()
                 if not k.startswith("_") and not callable(v)
                 and k not in ("__builtins__",)}

    # Deep-copy CobolDecimal values (they're mutable)
    values1 = {}
    for k, v in snapshot1.items():
        if hasattr(v, "value"):
            values1[k] = v.value
        elif isinstance(v, str):
            values1[k] = v

    # Call 2
    main_fn()
    values2 = {}
    for k, v in ns.items():
        if hasattr(v, "value"):
            values2[k] = v.value
        elif isinstance(v, str) and not k.startswith("_") and k not in ("__builtins__",):
            values2[k] = v

    return values1, values2


# ── Test (a): WORKING-STORAGE only — persists between calls ───


WS_ONLY_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. WS-ONLY-TEST.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-COUNTER           PIC 9(5).
       01  WS-TOTAL             PIC S9(7)V99.

       PROCEDURE DIVISION.
       0000-MAIN.
           ADD 1 TO WS-COUNTER.
           ADD 10.50 TO WS-TOTAL.
           STOP RUN.
"""


class TestWorkingStorageOnly:
    """WORKING-STORAGE variables persist across calls."""

    def test_variables_tagged_working(self):
        analysis = analyze_cobol(WS_ONLY_COBOL)
        for v in analysis["variables"]:
            if v.get("name"):
                assert v.get("storage_section") == "WORKING", \
                    f"{v['name']} should be WORKING, got {v.get('storage_section')}"

    def test_values_persist_between_calls(self):
        result = _parse_and_generate(WS_ONLY_COBOL)
        code = result["code"]

        # Verify no LOCAL reinitialization in main()
        assert "# LOCAL-STORAGE" not in code or "LOCAL" not in code.split("def main():")[1].split("def ")[0]

        v1, v2 = _exec_main_twice(code)

        # After call 1: counter=1, total=10.50
        assert v1["ws_counter"] == Decimal("1"), f"Call 1 counter: {v1['ws_counter']}"
        assert v1["ws_total"] == Decimal("10.50"), f"Call 1 total: {v1['ws_total']}"

        # After call 2: counter=2, total=21.00 (accumulated)
        assert v2["ws_counter"] == Decimal("2"), f"Call 2 counter: {v2['ws_counter']}"
        assert v2["ws_total"] == Decimal("21.00"), f"Call 2 total: {v2['ws_total']}"


# ── Test (b): LOCAL-STORAGE only — resets each call ───────────


LOCAL_ONLY_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOCAL-ONLY-TEST.

       DATA DIVISION.
       LOCAL-STORAGE SECTION.
       01  LS-COUNTER           PIC 9(5).
       01  LS-TOTAL             PIC S9(7)V99.

       PROCEDURE DIVISION.
       0000-MAIN.
           ADD 1 TO LS-COUNTER.
           ADD 10.50 TO LS-TOTAL.
           STOP RUN.
"""


class TestLocalStorageOnly:
    """LOCAL-STORAGE variables reset on each call."""

    def test_variables_tagged_local(self):
        analysis = analyze_cobol(LOCAL_ONLY_COBOL)
        for v in analysis["variables"]:
            if v.get("name"):
                assert v.get("storage_section") == "LOCAL", \
                    f"{v['name']} should be LOCAL, got {v.get('storage_section')}"

    def test_values_reset_between_calls(self):
        result = _parse_and_generate(LOCAL_ONLY_COBOL)
        code = result["code"]

        v1, v2 = _exec_main_twice(code)

        # After call 1: counter=1, total=10.50
        assert v1["ls_counter"] == Decimal("1"), f"Call 1 counter: {v1['ls_counter']}"
        assert v1["ls_total"] == Decimal("10.50"), f"Call 1 total: {v1['ls_total']}"

        # After call 2: counter=1, total=10.50 (reset, not accumulated)
        assert v2["ls_counter"] == Decimal("1"), \
            f"Call 2 counter should reset to 1, got {v2['ls_counter']}"
        assert v2["ls_total"] == Decimal("10.50"), \
            f"Call 2 total should reset to 10.50, got {v2['ls_total']}"


# ── Test (c): BOTH sections — WORKING persists, LOCAL resets ──


BOTH_SECTIONS_COBOL = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. BOTH-SECTIONS-TEST.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RUN-COUNT         PIC 9(5).

       LOCAL-STORAGE SECTION.
       01  LS-TEMP              PIC S9(7)V99.

       PROCEDURE DIVISION.
       0000-MAIN.
           ADD 1 TO WS-RUN-COUNT.
           COMPUTE LS-TEMP = WS-RUN-COUNT * 100.
           STOP RUN.
"""


class TestBothSections:
    """WORKING-STORAGE persists, LOCAL-STORAGE resets."""

    def test_mixed_section_tags(self):
        analysis = analyze_cobol(BOTH_SECTIONS_COBOL)
        sections = {v["name"]: v.get("storage_section") for v in analysis["variables"]
                    if v.get("name")}
        assert sections["WS-RUN-COUNT"] == "WORKING"
        assert sections["LS-TEMP"] == "LOCAL"

    def test_working_persists_local_resets(self):
        result = _parse_and_generate(BOTH_SECTIONS_COBOL)
        code = result["code"]

        v1, v2 = _exec_main_twice(code)

        # Call 1: run_count=1, temp=1*100=100
        assert v1["ws_run_count"] == Decimal("1")
        assert v1["ls_temp"] == Decimal("100.00")

        # Call 2: run_count=2 (persisted), temp=2*100=200
        # But LOCAL resets ls_temp to 0 before computation,
        # then COMPUTE sets it to run_count*100 = 200
        assert v2["ws_run_count"] == Decimal("2"), \
            f"WORKING should persist: {v2['ws_run_count']}"
        assert v2["ls_temp"] == Decimal("200.00"), \
            f"LOCAL should reset then compute: {v2['ls_temp']}"
