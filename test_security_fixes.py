"""
test_security_fixes.py — Phase 3 security regression tests.
Verifies removal of hardcoded JWT secret, admin backdoor, and copybook auth.
"""

import unittest
import os


class TestNoHardcodedJwtSecret(unittest.TestCase):

    def test_no_hardcoded_jwt_secret(self):
        """core_logic.py must not contain the old hardcoded JWT secret."""
        with open("core_logic.py", "r", encoding="utf-8") as f:
            source = f.read()
        self.assertNotIn("alethia-beyond-secret-key-2024", source)

    def test_no_production_key_fallback(self):
        """docker-compose.yml must not have a default JWT key."""
        with open("docker-compose.yml", "r", encoding="utf-8") as f:
            source = f.read()
        self.assertNotIn("aletheia-production-key", source)


class TestNoAdminBackdoor(unittest.TestCase):

    def test_no_admin123_in_core_logic(self):
        """core_logic.py must not contain plaintext admin123 backdoor."""
        with open("core_logic.py", "r", encoding="utf-8") as f:
            source = f.read()
        # Should not have the plaintext password check
        # (hashed references in test files are OK)
        lines = source.split("\n")
        for i, line in enumerate(lines):
            if "admin123" in line and "password_hasher" not in line.lower():
                # Allow comments explaining the removal, but not active code
                stripped = line.strip()
                if not stripped.startswith("#"):
                    self.fail(f"Found admin123 backdoor at line {i+1}: {line.strip()}")


class TestCopybookAuthRequired(unittest.TestCase):

    def test_all_endpoints_have_auth(self):
        """All 6 copybook endpoints must have Depends(_copybook_auth)."""
        with open("copybook_resolver.py", "r", encoding="utf-8") as f:
            source = f.read()
        # Count occurrences of the auth dependency
        count = source.count("Depends(_copybook_auth)")
        self.assertEqual(count, 6, f"Expected 6 auth-protected endpoints, found {count}")


class TestC1PicPScaling(unittest.TestCase):
    """C1: PIC P fields must store/retrieve correctly after descale→truncate→rescale."""

    def test_pic_pp999_normal(self):
        from decimal import Decimal
        from cobol_types import CobolDecimal
        from compiler_config import set_config
        set_config(trunc_mode='STD', arith_mode='COMPAT')
        d = CobolDecimal('0', pic_integers=0, pic_decimals=3, is_signed=False, is_comp=False, p_leading=2)
        d.store(Decimal('0.00567'))
        self.assertEqual(d.value, Decimal('0.00567000'))

    def test_pic_pp999_overflow(self):
        from decimal import Decimal
        from cobol_types import CobolDecimal
        from compiler_config import set_config
        set_config(trunc_mode='STD', arith_mode='COMPAT')
        d = CobolDecimal('0', pic_integers=0, pic_decimals=3, is_signed=False, is_comp=False, p_leading=2)
        d.store(Decimal('0.01234'))
        self.assertEqual(d.value, Decimal('0.00234000'))

    def test_pic_999pp_normal(self):
        from decimal import Decimal
        from cobol_types import CobolDecimal
        from compiler_config import set_config
        set_config(trunc_mode='STD', arith_mode='COMPAT')
        d = CobolDecimal('0', pic_integers=3, pic_decimals=0, is_signed=False, is_comp=False, p_trailing=2)
        d.store(Decimal('12300'))
        self.assertEqual(d.value, Decimal('12300'))


class TestC2UnsafeConstantRejected(unittest.TestCase):
    """C2: exec() constants must reject non-primitive types."""

    def test_callable_constant_rejected(self):
        from shadow_diff import _execute_one_record
        result = _execute_one_record(
            source="def main(): pass",
            record={},
            rec_idx=0,
            input_mapping={},
            output_fields=[],
            constants={"evil": lambda: None},  # callable — unsafe
        )
        self.assertIn("_error", result)
        self.assertIn("Unsafe constant type", result["_error"])


class TestC3IsApprovedNotHardcoded(unittest.TestCase):
    """C3: Login must return actual is_approved status, not hardcoded True."""

    def test_no_hardcoded_is_approved_in_login(self):
        with open("core_logic.py", "r", encoding="utf-8") as f:
            source = f.read()
        # Find all is_approved lines — none should be "True" with bypass comment
        for i, line in enumerate(source.split("\n")):
            if '"is_approved": True' in line and "Bypass" in line:
                self.fail(f"Found hardcoded is_approved bypass at line {i+1}: {line.strip()}")


class TestC6Level77NotGroupParent(unittest.TestCase):
    """C6: Level 77 standalone items must not be treated as group parents."""

    def test_level_77_excluded_from_stack(self):
        from cobol_analyzer_api import analyze_cobol
        source = (
            "       IDENTIFICATION DIVISION.\n"
            "       PROGRAM-ID. LVL77.\n"
            "       DATA DIVISION.\n"
            "       WORKING-STORAGE SECTION.\n"
            "       77  WS-STANDALONE  PIC 9(5).\n"
            "       01  WS-GROUP.\n"
            "           05  WS-CHILD   PIC 9(3).\n"
            "       PROCEDURE DIVISION.\n"
            "       MAIN-PARA.\n"
            "           STOP RUN.\n"
        )
        analysis = analyze_cobol(source)
        # WS-CHILD's parent should be WS-GROUP, NOT WS-STANDALONE
        for v in analysis["variables"]:
            if v.get("name") == "WS-CHILD":
                self.assertEqual(v.get("parent_group"), "WS-GROUP",
                                 f"WS-CHILD parent is {v.get('parent_group')}, expected WS-GROUP")
                return
        self.fail("WS-CHILD not found in variables")


if __name__ == "__main__":
    unittest.main()
