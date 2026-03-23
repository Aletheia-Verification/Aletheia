"""
test_copybook.py — COPYBOOK Resolver Test Suite
=================================================

12 tests covering all 4 components:
  - Component 1: COPY statement detector (tests 1-4)
  - Component 2: Copybook library (tests 5-6)
  - Component 3: Source preprocessor (tests 7-10)
  - Component 4: REDEFINES resolver (tests 11-12)
"""

import os
import pytest

from copybook_resolver import (
    detect_copy_statements,
    store_copybook,
    load_copybook,
    list_copybooks,
    delete_copybook,
    store_copybooks_from_zip,
    preprocess_source,
    resolve_redefines,
    _pic_byte_length,
    _apply_replacing,
    CopybookNotFoundError,
    COPYBOOK_DIR,
)
import copybook_resolver


# ══════════════════════════════════════════════════════════════════
# COMPONENT 1 — COPY Statement Detector
# ══════════════════════════════════════════════════════════════════

class TestDetectCopyStatements:

    def test_detect_simple_copy(self):
        """Test 1: Detects simple COPY statement."""
        source = """\
       WORKING-STORAGE SECTION.
       01 WS-CUSTOMER-RECORD.
           COPY CUSTOMER-REC.
       01 WS-OTHER PIC X(10).
"""
        results = detect_copy_statements(source)
        assert len(results) == 1
        assert results[0]["name"] == "CUSTOMER-REC"
        assert results[0]["library"] is None
        assert results[0]["replacing"] is None
        assert results[0]["line_number"] == 3

    def test_detect_copy_of_library(self):
        """Test 2: Detects COPY with OF library qualifier."""
        source = "           COPY CUSTOMER-REC OF MYLIB.\n"
        results = detect_copy_statements(source)
        assert len(results) == 1
        assert results[0]["name"] == "CUSTOMER-REC"
        assert results[0]["library"] == "MYLIB"

    def test_detect_copy_replacing(self):
        """Test 3: Detects COPY with REPLACING clause."""
        source = (
            "           COPY CUSTOMER-REC\n"
            "               REPLACING ==WS-OLD== BY ==WS-NEW==\n"
            "                         ==FIELD-A== BY ==FIELD-B==.\n"
        )
        results = detect_copy_statements(source)
        assert len(results) == 1
        assert results[0]["name"] == "CUSTOMER-REC"
        replacing = results[0]["replacing"]
        assert len(replacing) == 2
        assert replacing[0] == ("WS-OLD", "WS-NEW")
        assert replacing[1] == ("FIELD-A", "FIELD-B")

    def test_detect_multiple_copies(self):
        """Test 4: Finds all COPY statements in multi-COPY source."""
        source = """\
       01 WS-REC1.
           COPY CUSTOMER-REC.
       01 WS-REC2.
           COPY RATE-TABLE.
       01 WS-REC3.
           COPY ACCOUNT-INFO OF BANKLIB.
"""
        results = detect_copy_statements(source)
        assert len(results) == 3
        names = [r["name"] for r in results]
        assert names == ["CUSTOMER-REC", "RATE-TABLE", "ACCOUNT-INFO"]
        assert results[2]["library"] == "BANKLIB"


# ══════════════════════════════════════════════════════════════════
# COMPONENT 2 — Copybook Library
# ══════════════════════════════════════════════════════════════════

class TestCopybookLibrary:

    @pytest.fixture(autouse=True)
    def use_temp_dir(self, tmp_path, monkeypatch):
        """Redirect COPYBOOK_DIR to a temp directory for test isolation."""
        monkeypatch.setattr(copybook_resolver, "COPYBOOK_DIR", str(tmp_path))

    def test_store_and_load_copybook(self):
        """Test 5: Round-trip store → load."""
        content = "       05 WS-FIELD PIC X(10).\n"
        filename = store_copybook("MY-COPY", content)
        assert filename == "MY-COPY.CPY"

        loaded = load_copybook("MY-COPY")
        assert loaded == content

        # Case-insensitive lookup
        loaded2 = load_copybook("my-copy")
        assert loaded2 == content

        # Verify list
        items = list_copybooks()
        assert len(items) == 1
        assert items[0]["name"] == "MY-COPY"

    def test_load_missing_copybook(self):
        """Test 6: Raises CopybookNotFoundError for missing copybook."""
        with pytest.raises(CopybookNotFoundError):
            load_copybook("NONEXISTENT")


# ══════════════════════════════════════════════════════════════════
# COMPONENT 3 — Source Preprocessor
# ══════════════════════════════════════════════════════════════════

class TestPreprocessor:

    @pytest.fixture(autouse=True)
    def use_temp_dir(self, tmp_path, monkeypatch):
        """Redirect COPYBOOK_DIR to a temp directory for test isolation."""
        monkeypatch.setattr(copybook_resolver, "COPYBOOK_DIR", str(tmp_path))

    def test_preprocess_simple_expansion(self):
        """Test 7: COPY replaced with copybook content."""
        store_copybook("CUSTOMER-REC",
                        "       05 WS-CUST-ID PIC X(10).\n")

        source = """\
       01 WS-REC.
           COPY CUSTOMER-REC.
       01 WS-OTHER PIC X(5).
"""
        expanded, issues = preprocess_source(source)
        assert "WS-CUST-ID" in expanded
        assert "COPY CUSTOMER-REC" not in expanded
        assert len(issues) == 0

    def test_preprocess_with_replacing(self):
        """Test 8: REPLACING substitution applied."""
        store_copybook("TEMPLATE",
                        "       05 WS-PREFIX-FIELD PIC X(10).\n")

        source = '           COPY TEMPLATE REPLACING ==WS-PREFIX== BY ==WS-CUST==.\n'
        expanded, issues = preprocess_source(source)
        assert "WS-CUST-FIELD" in expanded
        assert "WS-PREFIX-FIELD" not in expanded
        assert len(issues) == 0

    def test_preprocess_missing_copybook(self):
        """Test 9: Unresolved copybook → MANUAL REVIEW comment."""
        source = "           COPY MISSING-COPY.\n"
        expanded, issues = preprocess_source(source)
        assert "MANUAL REVIEW" in expanded
        assert "MISSING-COPY" in expanded
        assert len(issues) == 1
        assert "not found" in issues[0]

    def test_preprocess_recursive(self):
        """Test 10: Copybook containing COPY is expanded recursively."""
        store_copybook("INNER", "       05 WS-INNER-FIELD PIC 9(5).\n")
        store_copybook("OUTER",
                        "       05 WS-OUTER-FIELD PIC X(10).\n"
                        "           COPY INNER.\n")

        source = "           COPY OUTER.\n"
        expanded, issues = preprocess_source(source)
        assert "WS-OUTER-FIELD" in expanded
        assert "WS-INNER-FIELD" in expanded
        assert "COPY" not in expanded
        assert len(issues) == 0


# ══════════════════════════════════════════════════════════════════
# COMPONENT 4 — REDEFINES Resolver
# ══════════════════════════════════════════════════════════════════

class TestRedefinesResolver:

    def test_redefines_detection(self):
        """Test 11: Detects REDEFINES in variable list."""
        variables = [
            {
                "raw": "05WS-DATEPICX(8).",
                "name": "WS-DATE",
                "pic_raw": "X(8)",
                "pic_info": None,
                "comp3": False,
            },
            {
                "raw": "05WS-DATE-NUMREDEFINESWS-DATEPIC9(8).",
                "name": "WS-DATE-NUM",
                "pic_raw": "9(8)",
                "pic_info": {"signed": False, "integers": 8, "decimals": 0},
                "comp3": False,
            },
        ]
        result = resolve_redefines(variables)
        assert len(result["redefines_groups"]) == 1
        group = result["redefines_groups"][0]
        assert group["base"] == "WS-DATE"
        assert "WS-DATE-NUM" in group["overlays"]

        # Should flag type mismatch (X vs 9)
        assert len(result["ambiguous_references"]) == 1
        assert result["ambiguous_references"][0]["reason"] == \
            "Type mismatch in REDEFINES (string vs numeric)"

    def test_redefines_memory_map(self):
        """Test 12: Correct byte offsets for overlapping fields."""
        variables = [
            {
                "raw": "05WS-FULL-NAMEPICX(30).",
                "name": "WS-FULL-NAME",
                "pic_raw": "X(30)",
                "pic_info": None,
                "comp3": False,
            },
            {
                "raw": "05WS-BALANCEPICS9(9)V99.",
                "name": "WS-BALANCE",
                "pic_raw": "S9(9)V99",
                "pic_info": {"signed": True, "integers": 9, "decimals": 2},
                "comp3": False,
            },
            {
                "raw": "05WS-BAL-RAWREDEFINESWS-BALANCEPICX(12).",
                "name": "WS-BAL-RAW",
                "pic_raw": "X(12)",
                "pic_info": None,
                "comp3": False,
            },
        ]
        result = resolve_redefines(variables)
        mem = result["memory_map"]

        # WS-FULL-NAME: offset 0, length 30
        assert mem[0]["name"] == "WS-FULL-NAME"
        assert mem[0]["offset"] == 0
        assert mem[0]["length"] == 30

        # WS-BALANCE: offset 30, length 12 (sign + 9 + 2 digits)
        assert mem[1]["name"] == "WS-BALANCE"
        assert mem[1]["offset"] == 30
        assert mem[1]["length"] == 12

        # WS-BAL-RAW: REDEFINES WS-BALANCE → same offset 30
        assert mem[2]["name"] == "WS-BAL-RAW"
        assert mem[2]["offset"] == 30
        assert mem[2]["length"] == 12
        assert mem[2]["redefines"] == "WS-BALANCE"


# ══════════════════════════════════════════════════════════════════
# BONUS — PIC Byte Length Unit Tests
# ══════════════════════════════════════════════════════════════════

class TestPicByteLength:

    def test_pic_x(self):
        assert _pic_byte_length("X(10)") == 10

    def test_pic_a(self):
        assert _pic_byte_length("A(20)") == 20

    def test_pic_numeric_display(self):
        # S9(9)V99 → sign(1) + 9 + 2 = 12
        assert _pic_byte_length("S9(9)V99") == 12

    def test_pic_unsigned(self):
        # 9(5) → 5
        assert _pic_byte_length("9(5)") == 5

    def test_pic_comp3(self):
        # S9(9)V99 COMP-3 → (9+2+1+1)//2 = 6 (11 digits + sign nibble, packed)
        assert _pic_byte_length("S9(9)V99", is_comp3=True) == 6

    def test_pic_empty(self):
        assert _pic_byte_length("") == 0


class TestReplacingBoundary:
    """REPLACING respects COBOL token boundaries."""

    def test_replacing_word_boundary(self):
        """WS-AMOUNT → CUST-AMOUNT (prefix match at token start)."""
        result = _apply_replacing("       05 WS-AMOUNT PIC 9(5).\n",
                                  [("WS", "CUST")])
        assert "CUST-AMOUNT" in result

    def test_replacing_no_partial_rows(self):
        """ROWS-COUNT unchanged (WS inside ROWS is not a token boundary)."""
        result = _apply_replacing("       05 ROWS-COUNT PIC 9(3).\n",
                                  [("WS", "CUST")])
        assert "ROWS-COUNT" in result
        assert "ROCUST" not in result

    def test_replacing_no_partial_news(self):
        """NEWS-FLAG unchanged (WS inside NEWS is not a token boundary)."""
        result = _apply_replacing("       05 NEWS-FLAG PIC X(1).\n",
                                  [("WS", "CUST")])
        assert "NEWS-FLAG" in result
        assert "NECUST" not in result

    def test_replacing_still_works_basic(self):
        """Full token replacement still works (WS-OLD → WS-NEW)."""
        result = _apply_replacing("       05 WS-OLD-FIELD PIC X(10).\n",
                                  [("WS-OLD", "WS-NEW")])
        assert "WS-NEW-FIELD" in result
        assert "WS-OLD" not in result

    def test_replacing_leading(self):
        """LEADING replaces prefix only: WS-AMOUNT → CUST-AMOUNT."""
        result = _apply_replacing(
            "       05 WS-AMOUNT PIC 9(5).\n       05 WS-NAME PIC X(10).\n",
            [("WS-", "CUST-", "LEADING")]
        )
        assert "CUST-AMOUNT" in result
        assert "CUST-NAME" in result

    def test_replacing_leading_no_mid_match(self):
        """LEADING does NOT replace in the middle of an identifier."""
        result = _apply_replacing(
            "       05 MY-WS-FIELD PIC 9(5).\n",
            [("WS-", "NEW-", "LEADING")]
        )
        assert "MY-WS-FIELD" in result

    def test_replacing_trailing(self):
        """TRAILING replaces suffix only: AMOUNT-WS → AMOUNT-NEW."""
        result = _apply_replacing(
            "       05 AMOUNT-WS PIC 9(5).\n",
            [("-WS", "-NEW", "TRAILING")]
        )
        assert "AMOUNT-NEW" in result

    def test_replacing_trailing_no_start_match(self):
        """TRAILING does NOT replace at the start of an identifier."""
        result = _apply_replacing(
            "       05 WS-FIELD PIC 9(5).\n",
            [("WS", "NEW", "TRAILING")]
        )
        # WS at start should NOT be replaced by TRAILING mode
        assert "WS-FIELD" in result
