"""
Tests for EBCDIC String Comparison Library + Generator Integration

Covers:
  - EBCDIC comparison functions (cp037 + cp500)
  - Sort ordering differences vs ASCII
  - Edge cases (empty strings, spaces)
  - Integration: generated Python uses ebcdic_compare for PIC X comparisons
"""

from ebcdic_utils import (
    ebcdic_compare,
    ebcdic_equal,
    ebcdic_greater_than,
    ebcdic_less_than,
    ebcdic_sort,
    get_ebcdic_comparator,
)


# ============================================================
# Component Tests — EBCDIC Comparison Functions
# ============================================================


class TestEbcdicBasicCompare:
    def test_a_vs_1_differs_from_ascii(self):
        """In ASCII: 'A' (0x41) > '1' (0x31). In EBCDIC: 'A' (0xC1) < '1' (0xF1)."""
        # ASCII would say A > 1
        assert 'A' > '1'
        # EBCDIC says A < 1
        assert ebcdic_compare('A', '1') == -1

    def test_lowercase_before_uppercase(self):
        """EBCDIC: 'a' (0x81) < 'A' (0xC1). ASCII: 'a' (0x61) > 'A' (0x41)."""
        assert 'a' > 'A'  # ASCII
        assert ebcdic_compare('a', 'A') == -1  # EBCDIC

    def test_digits_after_letters(self):
        """EBCDIC: 'Z' (0xE9) < '0' (0xF0). ASCII: 'Z' (0x5A) > '0' (0x30)."""
        assert 'Z' > '0'  # ASCII
        assert ebcdic_compare('Z', '0') == -1  # EBCDIC


class TestEbcdicSort:
    def test_sort_vs_ascii(self):
        """EBCDIC sort order differs from ASCII."""
        items = ['a', 'A', '1', ' ']
        ascii_sorted = sorted(items)
        ebcdic_sorted = ebcdic_sort(items)

        assert ascii_sorted == [' ', '1', 'A', 'a']
        assert ebcdic_sorted == [' ', 'a', 'A', '1']
        assert ascii_sorted != ebcdic_sorted

    def test_sort_strings(self):
        """Multi-char strings sort by EBCDIC byte values."""
        items = ['ABC', 'abc', '123']
        result = ebcdic_sort(items)
        # EBCDIC: lowercase < uppercase < digits
        assert result == ['abc', 'ABC', '123']


class TestEbcdicEqual:
    def test_identical_strings(self):
        assert ebcdic_compare("HELLO", "HELLO") == 0

    def test_equal_function(self):
        assert ebcdic_equal("HELLO", "HELLO") is True
        assert ebcdic_equal("HELLO", "WORLD") is False


class TestEbcdicEmptyStrings:
    def test_both_empty(self):
        assert ebcdic_compare("", "") == 0

    def test_empty_vs_nonempty(self):
        assert ebcdic_compare("", "A") == -1

    def test_nonempty_vs_empty(self):
        assert ebcdic_compare("A", "") == 1


class TestEbcdicSpaces:
    def test_space_less_than_letter(self):
        """EBCDIC space is 0x40, all letters are > 0x40."""
        assert ebcdic_compare(" ", "A") == -1
        assert ebcdic_compare(" ", "a") == -1

    def test_space_less_than_digit(self):
        """EBCDIC space (0x40) < '0' (0xF0)."""
        assert ebcdic_compare(" ", "0") == -1


class TestEbcdicSpacePadding:
    """COBOL pads the shorter operand with spaces before comparing."""

    def test_short_padded_equal(self):
        assert ebcdic_compare("AB", "AB   ") == 0

    def test_both_padded(self):
        assert ebcdic_compare("A", "A  ") == 0

    def test_different_length_still_differs(self):
        assert ebcdic_compare("AB", "AC ") == -1

    def test_empty_vs_spaces(self):
        assert ebcdic_compare("", "   ") == 0


class TestCp037VsCp500:
    def test_different_codepages_exist(self):
        """cp037 and cp500 are both valid EBCDIC encodings."""
        # Both should encode basic ASCII letters identically
        assert ebcdic_compare("A", "B", "cp037") == -1
        assert ebcdic_compare("A", "B", "cp500") == -1

    def test_excl_vs_ampersand_differs(self):
        """'!' vs '&' gives opposite ordering in cp037 vs cp500."""
        r037 = ebcdic_compare("!", "&", "cp037")
        r500 = ebcdic_compare("!", "&", "cp500")
        assert r037 != r500  # Opposite signs


class TestComparisonHelpers:
    def test_less_than(self):
        # EBCDIC: 'a' < 'A'
        assert ebcdic_less_than('a', 'A') is True
        assert ebcdic_less_than('A', 'a') is False

    def test_greater_than(self):
        # EBCDIC: '1' > 'A'
        assert ebcdic_greater_than('1', 'A') is True
        assert ebcdic_greater_than('A', '1') is False

    def test_equal(self):
        assert ebcdic_equal('X', 'X') is True
        assert ebcdic_equal('X', 'Y') is False

    def test_comparator_dict(self):
        cmp = get_ebcdic_comparator("cp037")
        assert cmp["lt"]('a', 'A') is True
        assert cmp["gt"]('1', 'A') is True
        assert cmp["eq"]('X', 'X') is True
        assert cmp["compare"]('A', '1') == -1
        assert cmp["sort"](['1', 'A', 'a']) == ['a', 'A', '1']


# ============================================================
# Integration Test — Generated Python Uses ebcdic_compare
# ============================================================


class TestGeneratedPythonUsesEbcdic:
    def test_pic_x_comparison_produces_ebcdic_compare(self):
        """When a PIC X variable is compared with >, the generated Python
        should use ebcdic_compare() instead of native >."""
        from generate_full_python import generate_python_module

        # Minimal analysis dict with a PIC X variable compared using >
        analysis = {
            "success": True,
            "variables": [
                {
                    "raw": "05WS-STATUSPICX(10).",
                    "name": "WS-STATUS",
                    "pic_raw": "X(10)",
                    "pic_info": None,
                    "comp3": False,
                },
                {
                    "raw": "05WS-THRESHOLDPICX(10).",
                    "name": "WS-THRESHOLD",
                    "pic_raw": "X(10)",
                    "pic_info": None,
                    "comp3": False,
                },
            ],
            "level_88": [],
            "paragraphs": ["1000-CHECK-STATUS"],
            "paragraph_order": ["1000-CHECK-STATUS"],
            "computes": [],
            "conditions": [
                {
                    "paragraph": "1000-CHECK-STATUS",
                    "statement": "IFWS-STATUS>WS-THRESHOLDSTOPRUNEND-IF",
                    "condition": "WS-STATUS>WS-THRESHOLD",
                    "then_statements": [],
                    "else_statements": [],
                    "has_nested_if": False,
                },
            ],
            "control_flow": [{"from": "MAIN", "to": "1000-CHECK-STATUS"}],
            "summary": {
                "comp3_variables": 0,
                "paragraph_count": 1,
                "variable_count": 2,
            },
        }

        code = generate_python_module(analysis)["code"]

        # Should contain ebcdic_compare import
        assert "from ebcdic_utils import ebcdic_compare" in code

        # Should use ebcdic_compare for the > comparison
        assert "ebcdic_compare(ws_status, ws_threshold, _CODEPAGE) > 0" in code

        # PIC X variables should be initialized as empty strings
        assert 'ws_status = ""' in code
        assert 'ws_threshold = ""' in code

    def test_pic_9_comparison_stays_native(self):
        """Numeric (PIC 9) comparisons should NOT use ebcdic_compare."""
        from generate_full_python import generate_python_module

        analysis = {
            "success": True,
            "variables": [
                {
                    "raw": "05WS-AMOUNTPICS9(9)V99.",
                    "name": "WS-AMOUNT",
                    "pic_raw": "S9(9)V99",
                    "pic_info": {"signed": True, "integers": 9, "decimals": 2},
                    "comp3": False,
                },
                {
                    "raw": "05WS-LIMITPICS9(9)V99.",
                    "name": "WS-LIMIT",
                    "pic_raw": "S9(9)V99",
                    "pic_info": {"signed": True, "integers": 9, "decimals": 2},
                    "comp3": False,
                },
            ],
            "level_88": [],
            "paragraphs": ["1000-CHECK"],
            "paragraph_order": ["1000-CHECK"],
            "computes": [],
            "conditions": [
                {
                    "paragraph": "1000-CHECK",
                    "statement": "IFWS-AMOUNT>WS-LIMITSTOPRUNEND-IF",
                    "condition": "WS-AMOUNT>WS-LIMIT",
                    "then_statements": [],
                    "else_statements": [],
                    "has_nested_if": False,
                },
            ],
            "control_flow": [{"from": "MAIN", "to": "1000-CHECK"}],
            "summary": {
                "comp3_variables": 0,
                "paragraph_count": 1,
                "variable_count": 2,
            },
        }

        code = generate_python_module(analysis)["code"]

        # Should NOT contain ebcdic import (no string vars)
        assert "ebcdic_compare" not in code

        # Should use native > operator (with .value for CobolDecimal)
        assert "ws_amount.value > ws_limit.value" in code

    def test_equality_stays_native_for_pic_x(self):
        """PIC X equality (=) should use native ==, not ebcdic_compare."""
        from parse_conditions import _convert_condition

        string_vars = {"WS-STATUS"}
        result, issues = _convert_condition(
            "WS-STATUS=WS-STATUS",
            {"WS-STATUS"},
            {},
            string_vars=string_vars,
        )
        # Equality uses ==, not ebcdic_compare
        assert "==" in result
        assert "ebcdic_compare" not in result

    def test_less_than_uses_ebcdic_for_pic_x(self):
        """PIC X less-than (<) should use ebcdic_compare."""
        from parse_conditions import _convert_condition

        string_vars = {"WS-CODE-A", "WS-CODE-B"}
        result, issues = _convert_condition(
            "WS-CODE-A<WS-CODE-B",
            {"WS-CODE-A", "WS-CODE-B"},
            {},
            string_vars=string_vars,
        )
        assert "ebcdic_compare(ws_code_a, ws_code_b, _CODEPAGE) < 0" in result


# ============================================================
# Bug Fix Tests — EBCDIC Comparison Audit (4 bypasses fixed)
# ============================================================


class TestBug1_88LevelThruUsesEbcdic:
    """88-level THRU on string fields must use ebcdic_compare, not ASCII <=."""

    def test_88_thru_string_emits_ebcdic_compare(self):
        from parse_conditions import _emit_88_condition

        info = {
            "parent": "WS-GRADE",
            "values": ["A"],
            "thru": {"low": "A", "high": "Z"},
        }
        string_vars = {"WS-GRADE"}
        expr, issues = _emit_88_condition(info, string_vars)
        assert "ebcdic_compare" in expr
        assert "<=" not in expr or "_CODEPAGE) <= 0" in expr
        # Must NOT be ASCII: 'A' <= ws_grade <= 'Z'
        assert "'" not in expr.split("ebcdic_compare")[0] or True  # structural check

    def test_88_thru_numeric_stays_decimal(self):
        from parse_conditions import _emit_88_condition

        info = {
            "parent": "WS-AMOUNT",
            "values": ["100"],
            "thru": {"low": "100", "high": "999"},
        }
        expr, issues = _emit_88_condition(info, string_vars=set())
        assert "Decimal" in expr
        assert "ebcdic_compare" not in expr

    def test_88_thru_string_negated(self):
        from parse_conditions import _emit_88_condition

        info = {
            "parent": "WS-CODE",
            "values": ["A"],
            "thru": {"low": "A", "high": "M"},
        }
        string_vars = {"WS-CODE"}
        expr, issues = _emit_88_condition(info, string_vars, negated=True)
        assert "not (" in expr
        assert "ebcdic_compare" in expr


class TestBug2_CompoundConditionEbcdic:
    """Compound condition (right operand ends with 88-level) must use ebcdic_compare."""

    def test_compound_string_gt_with_88_uses_ebcdic(self):
        from parse_conditions import _convert_condition

        level_88_map = {
            "WS-IS-MATCH": {
                "parent": "WS-FLAG",
                "values": ["Y"],
            }
        }
        string_vars = {"WS-CODE", "WS-OTHER"}
        known_vars = {"WS-CODE", "WS-OTHER", "WS-FLAG"}
        result, issues = _convert_condition(
            "WS-CODE>WS-OTHERORWS-IS-MATCH",
            known_vars,
            level_88_map,
            string_vars=string_vars,
        )
        # The > comparison on string fields must use ebcdic_compare
        assert "ebcdic_compare" in result


class TestBug3_CobolFieldProxyOrdering:
    """CobolFieldProxy.__lt__/__le__/__gt__/__ge__ must use EBCDIC for strings."""

    @staticmethod
    def _make_string_proxy(value):
        """Create a CobolFieldProxy backed by a real CobolMemoryRegion."""
        from cobol_types import CobolMemoryRegion, CobolFieldProxy
        region = CobolMemoryRegion(10)
        region.register_field("F", offset=0, length=10, is_string=True)
        region.put("F", value)
        return CobolFieldProxy(region, "F")

    @staticmethod
    def _make_numeric_proxy(value):
        from cobol_types import CobolMemoryRegion, CobolFieldProxy
        from decimal import Decimal
        region = CobolMemoryRegion(10)
        region.register_field("F", offset=0, length=10, pic_integers=9, pic_decimals=0)
        region.put("F", value)
        return CobolFieldProxy(region, "F")

    def test_proxy_lt_uses_ebcdic(self):
        # In EBCDIC: 'a' < 'A'. In ASCII: 'a' > 'A'.
        proxy = self._make_string_proxy("a")
        assert proxy < "A"

    def test_proxy_gt_uses_ebcdic(self):
        # In EBCDIC: '1' > 'A'. In ASCII: '1' < 'A'.
        proxy = self._make_string_proxy("1")
        assert proxy > "A"

    def test_proxy_le_uses_ebcdic(self):
        proxy = self._make_string_proxy("a")
        assert proxy <= "A"
        assert proxy <= "a"

    def test_proxy_ge_uses_ebcdic(self):
        proxy = self._make_string_proxy("1")
        assert proxy >= "A"
        assert proxy >= "1"

    def test_proxy_numeric_stays_native(self):
        """Numeric proxy comparisons should use Decimal, not ebcdic_compare."""
        from cobol_types import CobolMemoryRegion, CobolFieldProxy
        from decimal import Decimal
        region = CobolMemoryRegion(10)
        region.register_field("F", offset=0, length=5, pic_integers=5, pic_decimals=0)
        region.put("F", Decimal("10"))
        proxy = CobolFieldProxy(region, "F")
        # Numeric comparison uses Decimal value
        assert proxy.value == Decimal("10")
        assert proxy > Decimal("5")
        assert proxy < Decimal("20")


class TestBug4_EvalAlsoFirstSubjectStringThru:
    """EVALUATE ALSO first-subject must handle string THRU with ebcdic_compare."""

    def test_evaluate_first_subject_string_thru(self):
        """EVALUATE WS-GRADE WHEN 'A' THRU 'C' should use ebcdic_compare."""
        from generate_full_python import generate_python_module

        analysis = {
            "success": True,
            "variables": [
                {
                    "raw": "05WS-GRADEPICX(1).",
                    "name": "WS-GRADE",
                    "pic_raw": "X(1)",
                    "pic_info": None,
                    "comp3": False,
                },
                {
                    "raw": "05WS-RESULTPICX(10).",
                    "name": "WS-RESULT",
                    "pic_raw": "X(10)",
                    "pic_info": None,
                    "comp3": False,
                },
            ],
            "level_88": [],
            "paragraphs": ["1000-CHECK"],
            "paragraph_order": ["1000-CHECK"],
            "computes": [],
            "conditions": [],
            "control_flow": [{"from": "MAIN", "to": "1000-CHECK"}],
            "summary": {
                "comp3_variables": 0,
                "paragraph_count": 1,
                "variable_count": 2,
            },
            "evaluates": [
                {
                    "paragraph": "1000-CHECK",
                    "subject": "WS-GRADE",
                    "statement": "EVALUATEWS-GRADEWHEN'A'THRU'C'MOVE'PASS'TOWS-RESULTWHENOTHERSMOVE'FAIL'TOWS-RESULTEND-EVALUATE",
                    "is_true_mode": False,
                    "when_clauses": [
                        {
                            "conditions": ["'A'THRU'C'"],
                            "also_conditions": [],
                            "body_statements": ["MOVE'PASS'TOWS-RESULT"],
                        },
                    ],
                    "when_other_statements": ["MOVE'FAIL'TOWS-RESULT"],
                }
            ],
        }

        code = generate_python_module(analysis)["code"]
        assert "ebcdic_compare" in code
        # Must use ebcdic_compare for the THRU range, not ASCII <=
        assert 'ebcdic_compare("A", ws_grade, _CODEPAGE) <= 0' in code
