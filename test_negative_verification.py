"""
test_negative_verification.py — Negative verification tests for Shadow Diff.

5 tests that intentionally provide WRONG output and assert Shadow Diff
detects the mismatch. Guards against bugs that would make compare_outputs()
silently return zero drift.

Run with:
    pytest test_negative_verification.py -v
"""

from decimal import Decimal

import pytest

from shadow_diff import compare_outputs, generate_report


class TestNegativePennyOff:
    """Numeric mismatch: off by one penny."""

    def test_neg_penny_off(self):
        aletheia = [{"interest": "575.00"}]
        mainframe = [{"interest": "575.01"}]
        result = compare_outputs(aletheia, mainframe, ["interest"])

        assert result["mismatches"] == 1
        assert result["matches"] == 0
        assert len(result["mismatch_details"]) == 1

        detail = result["mismatch_details"][0]
        assert detail["record"] == 0
        assert detail["field"] == "interest"
        assert detail["aletheia_value"] == "575.00"
        assert detail["mainframe_value"] == "575.01"
        assert Decimal(detail["difference"]) == Decimal("0.01")


class TestNegativeWrongString:
    """String mismatch: APPROVED vs DECLINED."""

    def test_neg_wrong_string(self):
        aletheia = [{"status": "APPROVED"}]
        mainframe = [{"status": "DECLINED"}]
        result = compare_outputs(aletheia, mainframe, ["status"])

        assert result["mismatches"] == 1
        detail = result["mismatch_details"][0]
        assert detail["field"] == "status"
        assert detail["difference"] == "STRING_MISMATCH"
        assert detail["aletheia_value"] == "APPROVED"
        assert detail["mainframe_value"] == "DECLINED"


class TestNegativeMissingRecord:
    """Record count mismatch: 3 aletheia records vs 2 mainframe records."""

    def test_neg_missing_record(self):
        aletheia = [{"amt": "100"}, {"amt": "200"}, {"amt": "300"}]
        mainframe = [{"amt": "100"}, {"amt": "200"}]
        result = compare_outputs(aletheia, mainframe, ["amt"])

        assert result["mismatches"] >= 1
        assert result.get("record_count_mismatch") is True
        missing_details = [
            d for d in result["mismatch_details"]
            if "Record missing" in d.get("difference", "")
        ]
        assert len(missing_details) >= 1


class TestNegativeWrongAmount:
    """Large numeric mismatch: 1000 vs 9999."""

    def test_neg_wrong_amount(self):
        aletheia = [{"amount": "1000.00"}]
        mainframe = [{"amount": "9999.00"}]
        result = compare_outputs(aletheia, mainframe, ["amount"])

        assert result["mismatches"] == 1
        detail = result["mismatch_details"][0]
        assert detail["field"] == "amount"
        assert Decimal(detail["difference"]) == Decimal("8999")


class TestNegativeCorrectPasses:
    """Regression guard: correct output produces zero drift."""

    def test_neg_correct_passes(self):
        aletheia = [{"interest": "575.00", "status": "APPROVED"}]
        mainframe = [{"interest": "575.00", "status": "APPROVED"}]
        result = compare_outputs(aletheia, mainframe, ["interest", "status"])

        assert result["mismatches"] == 0
        assert result["matches"] == 1
        assert result["mismatch_details"] == []

        report = generate_report(result, "sha256:test_a", "sha256:test_b", "TEST")
        assert "ZERO DRIFT CONFIRMED" in report["verdict"]
