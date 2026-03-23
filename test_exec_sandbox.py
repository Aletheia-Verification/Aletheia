"""Tests for exec() sandbox — restricted builtins in generated code execution."""

import os
os.environ["USE_IN_MEMORY_DB"] = "1"

import pytest
from decimal import Decimal
from shadow_diff import _SAFE_BUILTINS


class TestExecSandbox:
    def test_restricted_import_blocked(self):
        """exec'd code with import os → ImportError."""
        code = "import os\nresult = os.getcwd()"
        namespace = {"__builtins__": _SAFE_BUILTINS}
        with pytest.raises(ImportError, match="not allowed"):
            exec(code, namespace)

    def test_restricted_open_blocked(self):
        """exec'd code with open() → NameError."""
        code = "f = open('test.txt', 'r')"
        namespace = {"__builtins__": _SAFE_BUILTINS}
        with pytest.raises(NameError):
            exec(code, namespace)

    def test_restricted_eval_blocked(self):
        """exec'd code with eval() → NameError."""
        code = "x = eval('1 + 1')"
        namespace = {"__builtins__": _SAFE_BUILTINS}
        with pytest.raises(NameError):
            exec(code, namespace)

    def test_safe_builtins_work(self):
        """len, str, range, list, print still available."""
        code = "x = len(list(range(5)))\ny = str(x)"
        namespace = {"__builtins__": _SAFE_BUILTINS}
        exec(code, namespace)
        assert namespace["x"] == 5
        assert namespace["y"] == "5"

    def test_whitelisted_imports_work(self):
        """decimal and cobol_types imports succeed in sandbox."""
        code = "from decimal import Decimal\nx = Decimal('3.14')"
        namespace = {"__builtins__": _SAFE_BUILTINS}
        exec(code, namespace)
        assert namespace["x"] == Decimal("3.14")

    def test_cobol_types_import_works(self):
        """cobol_types import succeeds in sandbox."""
        code = "from cobol_types import CobolDecimal\nx = CobolDecimal('42', pic_integers=5)"
        namespace = {"__builtins__": _SAFE_BUILTINS}
        exec(code, namespace)
        assert namespace["x"].value == Decimal("42")
