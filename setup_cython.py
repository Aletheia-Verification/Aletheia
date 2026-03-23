"""
setup_cython.py — Cython build configuration for Aletheia IP protection.

Compiles core .py files to .so shared objects.
Falls back to copying .py unchanged if Cython fails on a specific file.

Usage (inside Docker Stage 1):
    python setup_cython.py build_ext --inplace
    python setup_cython.py collect
"""

import os
import shutil
import sys
from setuptools import setup, Extension

# ── Files to compile ─────────────────────────────────────────────────

CORE_FILES = [
    "core_logic.py",
    "vault.py",
    "shadow_diff.py",
    "ebcdic_utils.py",
    "copybook_resolver.py",
    "cobol_analyzer_api.py",
    "generate_full_python.py",
    "parse_conditions.py",
    "compiler_config.py",
    "cobol_types.py",
    "exec_sql_parser.py",
    "dependency_crawler.py",
    "report_signing.py",
    "aletheia_cli.py",
    "abend_handler.py",
]

ANTLR_FILES = [
    "Cobol85Lexer.py",
    "Cobol85Parser.py",
    "Cobol85Listener.py",
]

ALL_FILES = CORE_FILES + ANTLR_FILES

# ── Collect mode ─────────────────────────────────────────────────────

if len(sys.argv) > 1 and sys.argv[1] == "collect":
    import sysconfig
    ext_suffix = sysconfig.get_config_var("EXT_SUFFIX")

    fallback_dir = "cython_fallback"
    os.makedirs(fallback_dir, exist_ok=True)

    compiled = []
    fallen_back = []

    for py_file in ALL_FILES:
        module_name = py_file.replace(".py", "")
        so_file = module_name + ext_suffix
        if os.path.exists(so_file):
            compiled.append(module_name)
        else:
            src = py_file
            if os.path.exists(src):
                shutil.copy2(src, os.path.join(fallback_dir, py_file))
            fallen_back.append(module_name)

    print(f"[Cython] Compiled: {len(compiled)}/{len(ALL_FILES)}")
    for m in compiled:
        print(f"  OK  {m}")
    if fallen_back:
        print(f"[Cython] Fallback (.py kept): {len(fallen_back)}")
        for m in fallen_back:
            print(f"  FALLBACK  {m}")

    sys.exit(0)

# ── Build mode ───────────────────────────────────────────────────────

try:
    from Cython.Build import cythonize
except ImportError:
    print("ERROR: Cython not installed. Run: pip install cython", file=sys.stderr)
    sys.exit(1)

extensions = []
for py_file in ALL_FILES:
    module_name = py_file.replace(".py", "")
    extensions.append(Extension(module_name, [py_file]))

# Attempt batch compilation first; fall back to per-file on failure
try:
    ext_modules = cythonize(
        extensions,
        compiler_directives={
            "language_level": "3",
            "boundscheck": False,
            "wraparound": False,
        },
        nthreads=os.cpu_count() or 4,
    )
except Exception:
    ext_modules = []
    for py_file in ALL_FILES:
        module_name = py_file.replace(".py", "")
        try:
            result = cythonize(
                [Extension(module_name, [py_file])],
                compiler_directives={"language_level": "3"},
                nthreads=1,
            )
            ext_modules.extend(result)
        except Exception as e:
            print(f"[Cython] SKIP {module_name}: {e}", file=sys.stderr)

setup(
    name="aletheia-compiled",
    ext_modules=ext_modules,
)
