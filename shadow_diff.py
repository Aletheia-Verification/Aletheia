"""
Shadow Diff Engine — Mainframe I/O Replay & Comparison

Takes real mainframe input/output data, feeds inputs through Aletheia's
generated Python, and compares outputs to what the mainframe actually
produced. Proves behavioral equivalence against reality, not just
internal consistency.

Components:
  1. Fixed-Width Reader (QSAM flat file parser)
  2. Execution Harness (generated Python runner)
  3. Comparator (field-by-field exact match)
  4. Verification Artifact (report generator)
  5. FastAPI Endpoints
  6. Demo Data Generator
"""

import hashlib
from itertools import zip_longest
import re
import io
import json
import logging
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import threading
import uuid
from datetime import datetime, timezone
from decimal import Decimal, ROUND_DOWN, getcontext
from pathlib import Path
from typing import Optional

from abend_handler import (
    S0C7DataException, validate_numeric_field, validate_string_field,
    decode_zoned_decimal,
)
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Auth — lazy proxy to core_logic.verify_token (same pattern as vault.py)
# ---------------------------------------------------------------------------

_verify_token = None


def _get_verify_token():
    global _verify_token
    if _verify_token is None:
        from core_logic import verify_token_optional
        _verify_token = verify_token_optional
    return _verify_token


async def _auth_dep(authorization: str = None):
    dep = _get_verify_token()
    # Re-use the real dependency; FastAPI calls it with the header
    from fastapi import Header
    return await dep(authorization=authorization)


# Proper Depends wrapper
from fastapi import Header as _Header


async def _shadow_auth(authorization: str = _Header(None)):
    fn = _get_verify_token()
    username = await fn(authorization=authorization)
    return username or "guest"


# ============================================================
# COMPONENT 1 — Fixed-Width Reader
# ============================================================

def decode_comp3(raw_bytes: bytes, decimals: int = 0, numproc: str = "NOPFD") -> Decimal:
    """Decode IBM COMP-3 (packed BCD) bytes to Decimal.

    Each byte holds two BCD digits (one per nibble), except the last
    byte whose low nibble is the sign indicator:
        0xC = positive, 0xD = negative, 0xF = unsigned positive.

    IBM dirty sign nibbles (NUMPROC(NOPFD) default):
        Positive: 0xA, 0xC, 0xE, 0xF
        Negative: 0xB, 0xD
    """
    if not raw_bytes:
        return Decimal("0")

    nibbles = []
    for b in raw_bytes:
        nibbles.append((b >> 4) & 0x0F)
        nibbles.append(b & 0x0F)

    sign_nibble = nibbles[-1]
    digit_nibbles = nibbles[:-1]

    digits_str = "".join(str(n) for n in digit_nibbles)

    if decimals > 0 and len(digits_str) > decimals:
        integer_part = digits_str[:-decimals]
        decimal_part = digits_str[-decimals:]
        num_str = f"{integer_part}.{decimal_part}"
    elif decimals > 0:
        num_str = f"0.{digits_str.zfill(decimals)}"
    else:
        num_str = digits_str

    result = Decimal(num_str)

    # IBM sign nibble: 0xB and 0xD are negative, all others positive
    if sign_nibble in (0x0B, 0x0D):
        result = -result

    return result


def detect_codepage(sample_record: bytes, fields: list[dict], default: str = "ascii") -> str:
    """Heuristic codepage detection — samples string field bytes only.

    Binary fields (comp, comp3, comp1, comp2) have high bytes that
    would confuse the heuristic, so only string field offsets are checked.
    If >30% of string-field bytes are above 0x7F and decode cleanly as
    CP037, returns 'cp037'. Otherwise returns ``default``.
    """
    if not sample_record:
        return default
    string_bytes = bytearray()
    for f in fields:
        if f["type"] == "string":
            start = f["start"]
            length = f["length"]
            string_bytes.extend(sample_record[start:start + length])
    if not string_bytes:
        return default
    high_byte_count = sum(1 for b in string_bytes if b > 0x7F)
    if high_byte_count > len(string_bytes) * 0.3:
        try:
            bytes(string_bytes).decode("cp037")
            return "cp037"
        except (UnicodeDecodeError, LookupError):
            pass
    return default


def parse_fixed_width_stream(layout: dict, data: bytes | str | Path):
    """Generator — yields one parsed record dict at a time.

    Streams line-by-line, never materialising the full file in memory.

    Args:
        layout: Dict with 'fields' list and 'record_length'.
                Each field: {name, start, length, type, decimals?}
                Types: string, integer, decimal, comp3
        data:   Raw file content (bytes or string), or a Path to
                stream from disk line-by-line.

    Yields:
        Dict per record, with field names as keys.
    """
    fields = layout["fields"]
    record_length = layout.get("record_length")
    codepage = layout.get("codepage", "ascii")

    # Auto-detect: sample string field bytes from first record
    if codepage == "auto" and not isinstance(data, str):
        if isinstance(data, Path):
            with open(data, "rb") as f:
                sample = f.read(record_length or 200)
        else:
            sample = data[:record_length or 200]
        codepage = detect_codepage(sample, fields)

    _encoding = "ascii" if isinstance(data, str) else (codepage or "ascii")

    # Open a byte stream from the appropriate source
    if isinstance(data, Path):
        source = open(data, "rb")
        close_source = True
    elif isinstance(data, bytes):
        source = io.BytesIO(data)
        close_source = True
    else:
        source = io.BytesIO(data.encode(_encoding))
        close_source = True

    try:
        def _iter_records():
            """Yield (text_line, raw_bytes) one record at a time."""
            if record_length:
                # Fixed-length records: read exactly record_length bytes
                while True:
                    raw = source.read(record_length)
                    if not raw:
                        break
                    # Skip optional record separator (newline)
                    sep = source.read(1)
                    if sep and sep not in (b"\n", b"\r"):
                        source.seek(-1, 1)
                    elif sep == b"\r":
                        sep2 = source.read(1)
                        if sep2 and sep2 != b"\n":
                            source.seek(-1, 1)
                    text = raw.decode(_encoding, errors="replace")
                    if text.strip():
                        yield text, raw
            else:
                # Newline-delimited records
                for raw_line in source:
                    raw_stripped = raw_line.rstrip(b"\r\n")
                    text = raw_stripped.decode(_encoding, errors="replace")
                    if text.strip():
                        yield text, raw_stripped

        for line_idx, (line, line_bytes) in enumerate(_iter_records()):
            record = {"_s0c7_abends": []}

            for field in fields:
                name = field["name"]
                start = field["start"]
                length = field["length"]
                ftype = field["type"]
                decimals = field.get("decimals", 0)

                # Warn on truncated records (field extends beyond record)
                if start + length > len(line_bytes):
                    record.setdefault("_warnings", []).append(
                        f"Field '{name}' at offset {start}+{length} exceeds "
                        f"record length {len(line_bytes)} — truncated"
                    )

                if ftype == "comp3":
                    raw = line_bytes[start:start + length]
                    record[name] = decode_comp3(raw, decimals)
                elif ftype == "string":
                    raw_str = line[start:start + length]
                    record[name] = validate_string_field(raw_str, length, name, line_idx)
                elif ftype in ("integer", "decimal"):
                    raw_str = line[start:start + length]
                    field_bytes = line_bytes[start:start + length]
                    signed_display = field.get("signed_display", False)
                    try:
                        if signed_display:
                            record[name] = decode_zoned_decimal(raw_str.strip(), decimals)
                        else:
                            record[name] = validate_numeric_field(
                                raw_str,
                                pic_integers=length - decimals,
                                pic_decimals=decimals,
                                field_name=name,
                                record_number=line_idx,
                                raw_bytes=field_bytes,
                            )
                    except S0C7DataException as exc:
                        record["_s0c7_abends"].append({
                            "field": name,
                            "message": str(exc),
                            "invalid_value": exc.invalid_value,
                        })
                        record[name] = None
                elif ftype in ("comp", "binary"):
                    raw = line_bytes[start:start + length]
                    signed = field.get("signed", True)
                    int_val = int.from_bytes(raw, byteorder="big", signed=signed)
                    if decimals:
                        record[name] = Decimal(int_val) / Decimal(10 ** decimals)
                    else:
                        record[name] = Decimal(int_val)
                elif ftype == "comp1":
                    raw = line_bytes[start:start + length]
                    from cobol_types import _decode_comp1
                    record[name] = _decode_comp1(raw)
                elif ftype == "comp2":
                    raw = line_bytes[start:start + length]
                    from cobol_types import _decode_comp2
                    record[name] = _decode_comp2(raw)
                else:
                    raise ValueError(f"Unknown field type: {ftype}")

            yield record
    finally:
        if close_source:
            source.close()


def parse_fixed_width(layout: dict, data: bytes | str | Path):
    """Parse mainframe-style fixed-width flat file — returns generator.

    Callers that need random access or len() should wrap with list().
    """
    return parse_fixed_width_stream(layout, data)


# ============================================================
# COMPONENT 2 — Execution Harness
# ============================================================

# ── Restricted builtins for exec sandbox ──────────────────────

import builtins as _builtins_mod

_ALLOWED_MODULES = frozenset({
    "decimal", "cobol_types", "compiler_config",
    "ebcdic_utils", "cobol_file_io",
})

_real_import = _builtins_mod.__import__


def _restricted_import(name, globals=None, locals=None, fromlist=(), level=0):
    """Import function that only allows whitelisted modules."""
    if name not in _ALLOWED_MODULES:
        raise ImportError(f"Import of '{name}' is not allowed in sandbox")
    return _real_import(name, globals, locals, fromlist, level)


def _make_safe_builtins():
    """Build a restricted __builtins__ dict for exec'd generated code.

    Removes dangerous builtins: eval, exec, compile, open, input,
    exit, quit, breakpoint, globals, locals, vars, dir.
    Also removes getattr/setattr/delattr to prevent dynamic dunder access.
    Replaces __import__ with a whitelist-only version.
    """
    safe = {k: v for k, v in vars(_builtins_mod).items()
            if k not in {
                'eval', 'exec', 'compile', 'open', 'input',
                'exit', 'quit', 'breakpoint',
                'globals', 'locals', 'vars', 'dir',
                'getattr', 'setattr', 'delattr',
                '__loader__', '__spec__',
            }}
    safe['__import__'] = _restricted_import
    return safe


_SAFE_BUILTINS = _make_safe_builtins()


# ── AST-level sandbox check (defense-in-depth) ──────────────────

import ast as _ast

_BLOCKED_ATTRS = frozenset({
    '__subclasses__', '__bases__', '__mro__', '__globals__',
    '__code__', '__func__', '__self__', '__module__',
    '__dict__', '__class__', '__import__',
})


def _check_generated_code(source: str):
    """Reject generated code that accesses dangerous dunder attributes."""
    try:
        tree = _ast.parse(source)
    except SyntaxError:
        return  # Will fail at exec anyway
    for node in _ast.walk(tree):
        if isinstance(node, _ast.Attribute) and node.attr in _BLOCKED_ATTRS:
            raise RuntimeError(f"Sandbox: blocked attribute access '{node.attr}'")

# ── Subprocess execution mode ──────────────────────────────────────────

_EXEC_MODE = os.environ.get("ALETHEIA_EXEC_MODE", "subprocess")

# Worker script executed in child process (JSON over stdin/stdout)
_SUBPROCESS_WORKER = r'''
import json, sys, os
from decimal import Decimal, getcontext

# Set precision to match parent
getcontext().prec = 31

# Add parent directory to path so imports resolve
_app_dir = os.environ.get("_ALETHEIA_APP_DIR", "")
if _app_dir and _app_dir not in sys.path:
    sys.path.insert(0, _app_dir)

def _make_safe_builtins():
    safe = dict(__builtins__) if isinstance(__builtins__, dict) else dict(vars(__builtins__))
    for name in ("eval", "exec", "compile", "open", "input", "exit", "quit",
                 "breakpoint", "globals", "locals", "vars", "dir",
                 "__loader__", "__spec__"):
        safe.pop(name, None)
    _allowed = frozenset({"decimal", "cobol_types", "compiler_config", "ebcdic_utils", "cobol_file_io"})
    _real_import = __builtins__.__import__ if hasattr(__builtins__, "__import__") else __import__
    def _safe_import(name, *args, **kwargs):
        if name not in _allowed:
            raise ImportError(f"Import '{name}' blocked by sandbox")
        return _real_import(name, *args, **kwargs)
    safe["__import__"] = _safe_import
    return safe

_SAFE = _make_safe_builtins()

def run():
    payload = json.loads(sys.stdin.read())
    source = payload["source"]
    record = payload["record"]
    output_fields = payload["output_fields"]
    constants = payload.get("constants") or {}
    input_mapping = payload.get("input_mapping") or {}
    trunc_mode = payload.get("trunc_mode", "STD")
    arith_mode = payload.get("arith_mode", "COMPAT")

    try:
        from compiler_config import set_config
        set_config(trunc_mode=trunc_mode, arith_mode=arith_mode)
    except ImportError:
        pass

    result = {}
    try:
        namespace = {"__builtins__": _SAFE}
        exec(source, namespace)

        _SAFE_TYPES = (Decimal, int, float, str, type(None))
        for k, v in constants.items():
            existing = namespace.get(k)
            if existing is not None and hasattr(existing, "store"):
                existing.store(Decimal(str(v)))
            else:
                namespace[k] = v

        for layout_name, python_name in input_mapping.items():
            if layout_name in record:
                value = record[layout_name]
                existing = namespace.get(python_name)
                # CobolDecimal targets: always use .store() (JSON makes everything strings)
                if existing is not None and hasattr(existing, "store"):
                    existing.store(Decimal(str(value)))
                elif isinstance(value, str):
                    # Try numeric first, fall back to string assignment
                    try:
                        namespace[python_name] = Decimal(value)
                    except Exception:
                        namespace[python_name] = value
                else:
                    namespace[python_name] = Decimal(str(value))

        namespace["main"]()

        for field in output_fields:
            val = namespace.get(field)
            if val is not None:
                raw = val.value if hasattr(val, "value") else val
                if isinstance(raw, Decimal) and raw == 0:
                    raw = Decimal("0")
                result[field] = str(raw)
            else:
                result[field] = None
    except Exception as e:
        result["_error"] = str(e)

    sys.stdout.write(json.dumps(result))
    sys.stdout.flush()

run()
'''

_worker_path = None  # lazily created temp file


def _get_worker_path():
    """Write the subprocess worker script to a temp file (once, reused)."""
    global _worker_path
    if _worker_path and os.path.exists(_worker_path):
        return _worker_path
    fd, path = tempfile.mkstemp(suffix=".py", prefix="aletheia_worker_")
    with os.fdopen(fd, "w") as f:
        f.write(_SUBPROCESS_WORKER)
    _worker_path = path
    return path


def _subprocess_execute_one_record(
    source: str,
    record: dict,
    rec_idx: int,
    input_mapping: dict,
    output_fields: list[str],
    constants: dict | None = None,
    timeout_seconds: int = 5,
) -> dict:
    """Execute generated Python in an isolated subprocess.

    Same interface as _execute_one_record but with true process isolation.
    Uses subprocess.run with timeout — process.kill() on timeout.
    """
    result = {"_record_index": rec_idx}
    worker = _get_worker_path()

    # Serialize record values to JSON-safe types
    json_record = {}
    for k, v in record.items():
        if isinstance(v, Decimal):
            json_record[k] = str(v)
        else:
            json_record[k] = v

    json_constants = {}
    if constants:
        for k, v in constants.items():
            json_constants[k] = str(v) if isinstance(v, Decimal) else v

    # Get current compiler config
    trunc_mode = "STD"
    arith_mode = "COMPAT"
    try:
        from compiler_config import get_config
        cfg = get_config()
        trunc_mode = cfg.trunc_mode
        arith_mode = cfg.arith_mode
    except (ImportError, AttributeError):
        pass

    payload = json.dumps({
        "source": source,
        "record": json_record,
        "output_fields": output_fields,
        "constants": json_constants,
        "input_mapping": input_mapping,
        "trunc_mode": trunc_mode,
        "arith_mode": arith_mode,
    })

    app_dir = os.path.dirname(os.path.abspath(__file__))
    env = {**os.environ, "_ALETHEIA_APP_DIR": app_dir}

    try:
        proc = subprocess.run(
            [sys.executable, worker],
            input=payload,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
            env=env,
        )
        if proc.returncode != 0:
            stderr = proc.stderr.strip()
            result["_error"] = f"Subprocess error (exit {proc.returncode}): {stderr[:500]}"
            return result

        stdout = proc.stdout.strip()
        if not stdout:
            result["_error"] = "Subprocess produced no output"
            return result

        output = json.loads(stdout)
        result.update(output)

    except subprocess.TimeoutExpired:
        result["_error"] = f"Timeout after {timeout_seconds}s"
    except json.JSONDecodeError as e:
        result["_error"] = f"Invalid JSON from subprocess: {e}"
    except Exception as e:
        result["_error"] = f"Subprocess execution failed: {e}"

    return result


def _execute_one_record(
    source: str,
    record: dict,
    rec_idx: int,
    input_mapping: dict,
    output_fields: list[str],
    constants: dict | None = None,
    timeout_seconds: int = 5,
) -> dict:
    """Execute generated Python for a single input record.

    Returns a dict with output field values (as strings) and _record_index.
    Sets "_error" key if execution failed.
    """
    result = {"_record_index": rec_idx}

    try:
        # AST-level sandbox check + restricted builtins
        _check_generated_code(source)
        namespace = {"__builtins__": _SAFE_BUILTINS}
        exec(source, namespace)

        # Set constants — use .store() if variable is CobolDecimal
        # Defense-in-depth: only allow safe primitive types as constants
        _SAFE_CONST_TYPES = (Decimal, int, float, str, type(None))
        if constants:
            for k, v in constants.items():
                if not isinstance(v, _SAFE_CONST_TYPES):
                    result["_error"] = f"Unsafe constant type for '{k}': {type(v).__name__}"
                    return result
                existing = namespace.get(k)
                if existing is not None and hasattr(existing, 'store'):
                    existing.store(Decimal(str(v)))
                else:
                    namespace[k] = v

        # Set input values from record via mapping
        for layout_name, python_name in input_mapping.items():
            if layout_name in record:
                value = record[layout_name]
                existing = namespace.get(python_name)
                if isinstance(value, str):
                    # String values: direct assignment (PIC X fields)
                    namespace[python_name] = value
                elif existing is not None and hasattr(existing, 'store'):
                    # CobolDecimal: use .store() to preserve PIC truncation
                    existing.store(Decimal(str(value)))
                else:
                    namespace[python_name] = Decimal(str(value))

        # Execute with timeout
        exec_error = [None]

        def _run():
            try:
                namespace["main"]()
            except Exception as e:
                exec_error[0] = e

        thread = threading.Thread(target=_run, daemon=True)
        thread.start()
        thread.join(timeout=timeout_seconds)

        if thread.is_alive():
            logger.warning(
                "Exec timeout: record %d still running as orphan daemon thread "
                "(will be cleaned up on process exit)", rec_idx
            )
            result["_error"] = f"Timeout after {timeout_seconds}s"
            return result

        if exec_error[0]:
            result["_error"] = str(exec_error[0])
            return result

        # Capture outputs — unwrap CobolDecimal.value if needed
        for field in output_fields:
            val = namespace.get(field)
            if val is not None:
                raw = val.value if hasattr(val, 'value') else val
                # Fix zero exponential notation: 0E-8 → 0
                if isinstance(raw, Decimal) and raw == 0:
                    raw = Decimal('0')
                result[field] = str(raw)
            else:
                result[field] = None

    except Exception as e:
        result["_error"] = str(e)

    return result


def execute_generated_python(
    source: str,
    input_records,
    input_mapping: dict,
    output_fields: list[str],
    constants: dict | None = None,
    timeout_seconds: int = 5,
):
    """Execute Aletheia's generated Python against each input record.

    Args:
        source:         Generated Python code string.
        input_records:  Iterable of parsed records (list or generator).
        input_mapping:  Maps layout field names → Python variable names.
        output_fields:  Python variable names to capture after execution.
        constants:      Optional dict of constant overrides.
        timeout_seconds: Max seconds per record.

    Yields:
        Dicts with output field values (as strings for exact comparison),
        plus "_error" key if execution failed for a record.
    """
    exec_fn = _subprocess_execute_one_record if _EXEC_MODE == "subprocess" else _execute_one_record
    for rec_idx, record in enumerate(input_records):
        yield exec_fn(
            source, record, rec_idx, input_mapping,
            output_fields, constants, timeout_seconds,
        )


def execute_io_program(
    source: str,
    input_streams: dict,
    output_file_name: str,
    output_fields: list[str],
    constants: dict | None = None,
    timeout_seconds: int = 30,
):
    """Execute a file I/O COBOL program — single main() call processes all records.

    Args:
        source:           Generated Python code string.
        input_streams:    dict mapping file_name → iterator of record dicts.
        output_file_name: File name to collect output records from.
        output_fields:    Python variable names in output records.
        constants:        Optional dict of constant overrides.
        timeout_seconds:  Max seconds for entire program execution.

    Yields:
        Dicts with output field values (as strings for exact comparison).
    """
    from cobol_file_io import CobolFileManager, StreamBackend

    output_collector = []
    backend = StreamBackend(
        input_streams=input_streams,
        output_collectors={output_file_name: output_collector},
    )

    try:
        _check_generated_code(source)
        namespace = {"__builtins__": _SAFE_BUILTINS}
        exec(source, namespace)

        # Set constants
        if constants:
            for k, v in constants.items():
                existing = namespace.get(k)
                if existing is not None and hasattr(existing, 'store'):
                    existing.store(Decimal(str(v)))
                else:
                    namespace[k] = v

        # Build CobolFileManager from _FILE_META in generated code
        file_meta = namespace.get("_FILE_META", {})
        mgr = CobolFileManager(file_meta, namespace, backend)

        # Inject I/O functions into namespace
        namespace["_io_open"] = mgr.open
        namespace["_io_read"] = mgr.read
        namespace["_io_write"] = mgr.write
        namespace["_io_close"] = mgr.close
        namespace["_io_populate"] = mgr.populate
        namespace["_io_write_record"] = mgr.write_record
        namespace["_io_rewrite"] = mgr.rewrite
        namespace["_io_read_by_key"] = mgr.read_by_key

        # Execute main() once — program's own loop processes all records
        exec_error = [None]

        def _run():
            try:
                namespace["main"]()
            except Exception as e:
                exec_error[0] = e

        thread = threading.Thread(target=_run, daemon=True)
        thread.start()
        thread.join(timeout=timeout_seconds)

        if thread.is_alive():
            logger.warning(
                "I/O program exec timeout: still running as orphan daemon thread "
                "(will be cleaned up on process exit)"
            )
            yield {"_record_index": 0, "_error": f"Timeout after {timeout_seconds}s"}
            return

        if exec_error[0]:
            yield {"_record_index": 0, "_error": str(exec_error[0])}
            return

        # Yield output records collected by the backend
        for rec_idx, output_record in enumerate(output_collector):
            result = {"_record_index": rec_idx}
            for field in output_fields:
                # Map output field names from record dict
                val = output_record.get(field)
                if val is not None:
                    result[field] = str(val)
                else:
                    result[field] = None
            yield result

    except Exception as e:
        yield {"_record_index": 0, "_error": str(e)}


# ============================================================
# COMPONENT 3 — Comparator
# ============================================================

MAX_MISMATCH_DETAILS = 10_000


def _extract_numeric_from_edited(display_str: str) -> Decimal:
    """Strip edit characters from a numeric edited display string.

    Handles: spaces, commas, $, *, +, -, /, CR, DB.
    Returns the numeric Decimal value.
    """
    cleaned = str(display_str).strip()
    if not cleaned:
        return Decimal('0')
    negative = False
    if cleaned.endswith('CR') or cleaned.endswith('DB'):
        negative = True
        cleaned = cleaned[:-2]
    if '-' in cleaned:
        negative = True
    digits = re.sub(r'[^0-9.]', '', cleaned)
    if not digits or digits == '.':
        return Decimal('0')
    result = Decimal(digits)
    return -result if negative else result


def _compare_one_record(
    i: int,
    a_rec: dict,
    m_rec: dict,
    output_fields: list[str],
    edited_fields: set | None = None,
) -> list[dict]:
    """Compare a single pair of records. Returns list of mismatch dicts (empty if match).

    edited_fields: optional set of field names with numeric edited PICs.
    For edited fields, values are compared by extracted numeric value
    rather than exact string/decimal match (display format varies by platform).
    """
    details = []
    if edited_fields is None:
        edited_fields = set()

    # S0C7 abends from input parsing
    s0c7_list = a_rec.get("_s0c7_abends", [])
    if s0c7_list:
        for abend in s0c7_list:
            details.append({
                "record": i,
                "field": abend["field"],
                "aletheia_value": abend["invalid_value"],
                "mainframe_value": "N/A",
                "difference": "S0C7_ABEND",
            })
        return details

    if "_error" in a_rec:
        details.append({
            "record": i,
            "field": "_execution_error",
            "aletheia_value": a_rec["_error"],
            "mainframe_value": "N/A",
            "difference": "EXECUTION_ERROR",
        })
        return details

    for field in output_fields:
        a_val = a_rec.get(field)
        m_val = m_rec.get(field)

        if a_val is None and m_val is None:
            continue

        if a_val is None or m_val is None:
            details.append({
                "record": i,
                "field": field,
                "aletheia_value": str(a_val),
                "mainframe_value": str(m_val),
                "difference": "MISSING_VALUE",
            })
            continue

        # Edited fields: extract numeric value, compare numerically
        if field in edited_fields:
            try:
                a_dec = _extract_numeric_from_edited(a_val)
                m_dec = _extract_numeric_from_edited(m_val)
                if a_dec != m_dec:
                    details.append({
                        "record": i,
                        "field": field,
                        "aletheia_value": str(a_val),
                        "mainframe_value": str(m_val),
                        "difference": str(abs(a_dec - m_dec)),
                    })
            except Exception:
                if str(a_val).strip() != str(m_val).strip():
                    details.append({
                        "record": i,
                        "field": field,
                        "aletheia_value": str(a_val),
                        "mainframe_value": str(m_val),
                        "difference": "STRING_MISMATCH",
                    })
            continue

        try:
            a_dec = Decimal(str(a_val))
            m_dec = Decimal(str(m_val))
            if a_dec != m_dec:
                details.append({
                    "record": i,
                    "field": field,
                    "aletheia_value": str(a_dec),
                    "mainframe_value": str(m_dec),
                    "difference": str(abs(a_dec - m_dec)),
                })
        except Exception:
            if str(a_val).strip() != str(m_val).strip():
                details.append({
                    "record": i,
                    "field": field,
                    "aletheia_value": str(a_val),
                    "mainframe_value": str(m_val),
                    "difference": "STRING_MISMATCH",
                })

    return details


def compare_outputs(
    aletheia_outputs,
    mainframe_outputs,
    output_fields: list[str],
    edited_fields: set | None = None,
) -> dict:
    """Compare Aletheia outputs against mainframe historical outputs.

    Accepts lists or iterables. Exact match required — no epsilon tolerance.
    Mismatch details capped at MAX_MISMATCH_DETAILS (10,000) to prevent
    memory blowup on large drifted datasets.

    Returns:
        {
            "total_records": int,
            "matches": int,
            "mismatches": int,
            "mismatch_details": [...],
            "mismatch_details_capped": bool,
        }
    """
    total = 0
    mismatch_record_count = 0
    mismatch_details = []
    capped = False
    s0c7_count = 0
    s0c7_details = []

    for i, (a_rec, m_rec) in enumerate(zip_longest(aletheia_outputs, mainframe_outputs)):
        total += 1
        if a_rec is None or m_rec is None:
            mismatch_record_count += 1
            side = "output" if a_rec is None else "input"
            entry = {
                "record": i,
                "field": "*",
                "expected": "PRESENT" if m_rec is not None else "MISSING",
                "actual": "PRESENT" if a_rec is not None else "MISSING",
                "difference": f"Record missing from {side}",
            }
            if len(mismatch_details) < MAX_MISMATCH_DETAILS:
                mismatch_details.append(entry)
            else:
                capped = True
            continue
        details = _compare_one_record(i, a_rec, m_rec, output_fields, edited_fields)
        if details:
            mismatch_record_count += 1
            for d in details:
                if d.get("difference") == "S0C7_ABEND":
                    s0c7_count += 1
                    if len(s0c7_details) < 100:
                        s0c7_details.append(d)
            if len(mismatch_details) < MAX_MISMATCH_DETAILS:
                remaining = MAX_MISMATCH_DETAILS - len(mismatch_details)
                mismatch_details.extend(details[:remaining])
                if len(details) > remaining:
                    capped = True
            else:
                capped = True

    result = {
        "total_records": total,
        "matches": total - mismatch_record_count,
        "mismatches": mismatch_record_count,
        "mismatch_details": mismatch_details,
        "mismatch_details_capped": capped,
        "s0c7_abends": s0c7_count,
        "s0c7_details": s0c7_details,
    }
    if any(d.get("difference", "").startswith("Record missing") for d in mismatch_details):
        result["record_count_mismatch"] = True
    return result


# ============================================================
# Streaming Pipeline — read one, execute one, compare one
# ============================================================


def run_streaming_pipeline(
    source: str,
    input_stream,
    mainframe_stream,
    input_mapping: dict,
    output_fields: list[str],
    constants: dict | None = None,
    timeout_seconds: int = 5,
    edited_fields: set | None = None,
) -> dict:
    """Full streaming Shadow Diff pipeline.

    Processes one record at a time: parse → execute → compare → discard.
    Maintains only running counts and a capped mismatch list.

    Args:
        source:           Generated Python code string.
        input_stream:     Iterable of parsed input record dicts (generator OK).
        mainframe_stream: Iterable of parsed mainframe output dicts (generator OK).
        input_mapping:    Maps layout field names → Python variable names.
        output_fields:    Python variable names to capture after execution.
        constants:        Optional dict of constant overrides.
        timeout_seconds:  Max seconds per record.

    Returns:
        Comparison dict (same shape as compare_outputs).
    """
    total = 0
    mismatch_record_count = 0
    mismatch_details = []
    capped = False
    s0c7_count = 0
    s0c7_details = []

    for rec_idx, (input_rec, expected_rec) in enumerate(
        zip_longest(input_stream, mainframe_stream)
    ):
        total += 1
        if input_rec is None or expected_rec is None:
            mismatch_record_count += 1
            side = "output" if input_rec is None else "input"
            entry = {
                "record": rec_idx,
                "field": "*",
                "expected": "PRESENT" if expected_rec is not None else "MISSING",
                "actual": "PRESENT" if input_rec is not None else "MISSING",
                "difference": f"Record missing from {side}",
            }
            if len(mismatch_details) < MAX_MISMATCH_DETAILS:
                mismatch_details.append(entry)
            else:
                capped = True
            continue

        # Execute one
        a_rec = _execute_one_record(
            source, input_rec, rec_idx, input_mapping,
            output_fields, constants, timeout_seconds,
        )

        # Propagate S0C7 abends from input parsing to execution result
        if input_rec.get("_s0c7_abends"):
            a_rec["_s0c7_abends"] = input_rec["_s0c7_abends"]

        # Compare one
        details = _compare_one_record(rec_idx, a_rec, expected_rec, output_fields, edited_fields)

        if details:
            mismatch_record_count += 1
            for d in details:
                if d.get("difference") == "S0C7_ABEND":
                    s0c7_count += 1
                    if len(s0c7_details) < 100:
                        s0c7_details.append(d)
            if len(mismatch_details) < MAX_MISMATCH_DETAILS:
                remaining = MAX_MISMATCH_DETAILS - len(mismatch_details)
                mismatch_details.extend(details[:remaining])
                if len(details) > remaining:
                    capped = True
            else:
                capped = True

        # input_rec, a_rec, expected_rec are now discardable

    result = {
        "total_records": total,
        "matches": total - mismatch_record_count,
        "mismatches": mismatch_record_count,
        "mismatch_details": mismatch_details,
        "mismatch_details_capped": capped,
        "s0c7_abends": s0c7_count,
        "s0c7_details": s0c7_details,
    }
    if any(d.get("difference", "").startswith("Record missing") for d in mismatch_details):
        result["record_count_mismatch"] = True
    return result


def streaming_compare(
    source: str,
    input_stream,
    mainframe_stream,
    input_mapping: dict,
    output_fields: list[str],
    constants: dict | None = None,
    timeout_seconds: int = 5,
    progress_callback=None,
    edited_fields: set | None = None,
):
    """Streaming Shadow Diff generator — yields one event per record.

    Constant memory: never holds more than 2 records simultaneously.
    Yields event dicts as comparison proceeds:

        {"type": "match",           "record": idx}
        {"type": "drift",           "record": idx, "details": [...]}
        {"type": "error",           "record": idx, "error": str}
        {"type": "length_mismatch", "record": idx, "side": "input"|"output"}
        {"type": "complete",        "total": N, "matches": M,
                                    "mismatches": D, "s0c7_abends": S}

    Args:
        source:            Generated Python code string.
        input_stream:      Iterable of parsed input record dicts (generator OK).
        mainframe_stream:  Iterable of parsed mainframe output dicts (generator OK).
        input_mapping:     Maps layout field names → Python variable names.
        output_fields:     Python variable names to capture after execution.
        constants:         Optional dict of constant overrides.
        timeout_seconds:   Max seconds per record.
        progress_callback: Optional callable(records_compared, matches, mismatches)
                           invoked after each record.
    """
    total = 0
    matches = 0
    mismatches = 0
    s0c7_count = 0

    for rec_idx, (input_rec, expected_rec) in enumerate(
        zip_longest(input_stream, mainframe_stream)
    ):
        total += 1

        # Record count mismatch — one stream exhausted before the other
        if input_rec is None or expected_rec is None:
            mismatches += 1
            side = "output" if input_rec is None else "input"
            yield {
                "type": "length_mismatch",
                "record": rec_idx,
                "side": side,
            }
            if progress_callback:
                progress_callback(total, matches, mismatches)
            continue

        # Execute one record
        a_rec = _execute_one_record(
            source, input_rec, rec_idx, input_mapping,
            output_fields, constants, timeout_seconds,
        )

        # Propagate S0C7 abends from input parsing
        if input_rec.get("_s0c7_abends"):
            a_rec["_s0c7_abends"] = input_rec["_s0c7_abends"]

        # Compare one record
        details = _compare_one_record(rec_idx, a_rec, expected_rec, output_fields, edited_fields)

        if details:
            mismatches += 1
            for d in details:
                if d.get("difference") == "S0C7_ABEND":
                    s0c7_count += 1
            # Check if this was an execution error
            if any(d.get("difference", "").startswith("EXECUTION_ERROR") for d in details):
                yield {
                    "type": "error",
                    "record": rec_idx,
                    "error": details[0].get("actual", "unknown"),
                }
            else:
                yield {"type": "drift", "record": rec_idx, "details": details}
        else:
            matches += 1
            yield {"type": "match", "record": rec_idx}

        if progress_callback:
            progress_callback(total, matches, mismatches)

        # input_rec, a_rec, expected_rec are now discardable

    yield {
        "type": "complete",
        "total": total,
        "matches": matches,
        "mismatches": mismatches,
        "s0c7_abends": s0c7_count,
    }


# ============================================================
# COMPONENT 4 — Verification Artifact
# ============================================================

def generate_report(
    comparison: dict,
    input_file_hash: str,
    output_file_hash: str,
    layout_name: str = "",
    layout: dict | None = None,
) -> dict:
    """Generate verification artifact from comparison results."""
    mismatch_count = comparison["mismatches"]

    if mismatch_count == 0:
        verdict = "SHADOW DIFF: ZERO DRIFT CONFIRMED"
    else:
        verdict = f"SHADOW DIFF: DRIFT DETECTED \u2014 {mismatch_count} RECORDS"

    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # Human-readable text
    lines = [
        "=" * 60,
        "SHADOW DIFF VERIFICATION REPORT",
        "=" * 60,
        f"Timestamp    : {timestamp}",
        f"Layout       : {layout_name}",
        f"Total Records: {comparison['total_records']}",
        f"Matches      : {comparison['matches']}",
        f"Mismatches   : {comparison['mismatches']}",
        f"S0C7 Abends  : {comparison.get('s0c7_abends', 0)}",
        f"Input Hash   : {input_file_hash}",
        f"Output Hash  : {output_file_hash}",
        "-" * 60,
        f"VERDICT: {verdict}",
        "-" * 60,
    ]

    if comparison["mismatch_details"]:
        lines.append("")
        lines.append("MISMATCH LOG:")
        for m in comparison["mismatch_details"]:
            lines.append(
                f"  Record {m['record']:>6d} | {m['field']:<20s} | "
                f"Aletheia: {m['aletheia_value']:<16s} | "
                f"Mainframe: {m['mainframe_value']:<16s} | "
                f"Diff: {m['difference']}"
            )

    human_readable = "\n".join(lines)

    return {
        "verdict": verdict,
        "timestamp": timestamp,
        "layout_name": layout_name,
        "total_records": comparison["total_records"],
        "matches": comparison["matches"],
        "mismatches": comparison["mismatches"],
        "input_file_hash": input_file_hash,
        "output_file_hash": output_file_hash,
        "mismatch_log": comparison["mismatch_details"],
        "diagnosed_mismatches": diagnose_drift(comparison["mismatch_details"], layout or {}),
        "s0c7_abends": comparison.get("s0c7_abends", 0),
        "s0c7_details": comparison.get("s0c7_details", []),
        "human_readable": human_readable,
    }


def diagnose_drift(mismatch_log: list[dict], layout: dict) -> list[dict]:
    """Enrich each mismatch entry with root-cause diagnosis.

    Returns a NEW list — does not mutate the input.  Each enriched entry
    gets three additional keys:

        magnitude     — abs numeric difference (Decimal), or None if
                        one/both values are non-numeric.
        likely_cause  — human-readable hypothesis for the drift.
        suggested_fix — concrete remediation step.

    The diagnosis is heuristic, based on field type from the layout and
    the pattern of the difference string already computed by the
    comparator.
    """
    # Build a quick field-type lookup from layout
    field_types: dict[str, str] = {}
    for f in layout.get("fields", []):
        field_types[f["name"]] = f.get("type", "string")
    output_layout = layout.get("output_layout", {})
    for f in output_layout.get("fields", []):
        field_types[f["name"]] = f.get("type", "string")

    enriched = []
    for entry in mismatch_log:
        diag = dict(entry)  # shallow copy

        diff_str = entry.get("difference", "")
        a_val = entry.get("aletheia_value", "")
        m_val = entry.get("mainframe_value", "")
        field = entry.get("field", "")
        ftype = field_types.get(field, "unknown")

        # ── Magnitude ──────────────────────────────────────────
        magnitude = None
        try:
            magnitude = abs(Decimal(str(a_val)) - Decimal(str(m_val)))
        except Exception:
            pass
        diag["magnitude"] = magnitude

        # ── Likely cause + suggested fix ───────────────────────
        cause = "UNKNOWN DIVERGENCE"
        fix = "Investigate field-level logic manually."

        if diff_str == "S0C7_ABEND":
            cause = "S0C7 DATA EXCEPTION — non-numeric data in numeric field"
            fix = "Inspect source data for corruption. Validate input file encoding."

        elif diff_str == "EXECUTION_ERROR":
            cause = "Python execution error during record processing"
            fix = "Check generated Python for runtime errors on this record's input values."

        elif diff_str == "MISSING_VALUE":
            cause = "Field present in one output but absent in the other"
            fix = "Verify output_layout field_mapping covers all expected output fields."

        elif diff_str == "STRING_MISMATCH":
            if str(m_val) in ("None", ""):
                cause = "S0C7 abend — non-numeric data in numeric field"
                fix = "Inspect source data encoding. Possible EBCDIC dirty data or packed decimal corruption."
            else:
                cause = "EBCDIC/ASCII collation or encoding difference"
                fix = "Check if field uses EBCDIC comparison. Verify code page (CP037 vs CP500)."

        elif ftype == "comp3" and magnitude is not None:
            # COMP-3 fields: sign nibble is the usual suspect
            if magnitude == abs(Decimal(a_val)) + abs(Decimal(m_val)):
                cause = "COMP-3 sign nibble mismatch — sign is flipped"
                fix = "Verify packed decimal sign handling. Check if unsigned COMP-3 is treated as signed."
            elif magnitude < Decimal("0.01"):
                cause = "Rounding divergence on packed decimal field"
                fix = "Verify TRUNC compiler flag matches source system. Check ROUND vs TRUNCATE semantics."
            else:
                cause = "COMP-3 value divergence"
                fix = "Verify packed decimal byte layout. Check for REDEFINES overlay on this field."

        elif magnitude is not None:
            # Numeric field — classify by magnitude pattern
            a_dec = None
            m_dec = None
            try:
                a_dec = Decimal(str(a_val))
                m_dec = Decimal(str(m_val))
            except Exception:
                pass

            if magnitude == 0:
                # Shouldn't reach here (comparator wouldn't flag it),
                # but guard anyway.
                cause = "Display format difference — values are numerically equal"
                fix = "Check PIC display formatting. Likely a leading-zero or sign display issue."

            elif a_dec is not None and m_dec is not None and a_dec != 0 and m_dec != 0 and a_dec == -m_dec:
                cause = "COMP-3 sign nibble mismatch — sign reversal detected"
                fix = "Verify packed decimal sign nibble handling (C=positive, D=negative). Check COMP-3 encoding in copybook."

            elif magnitude < Decimal("0.015"):
                # Sub-cent difference → rounding
                cause = "Rounding divergence — sub-cent difference"
                fix = "Verify TRUNC compiler flag matches source system. Check ROUND vs TRUNCATE semantics."

            elif magnitude > Decimal("100"):
                cause = "PIC precision overflow — value exceeds field capacity"
                fix = "Check PIC clause digit allocation. Target field may be too small for computed result."

            elif str(magnitude).rstrip('0').endswith('.'):
                # Whole-number difference → likely truncation
                int_mag = int(magnitude)
                pic_boundary = any(
                    int_mag == 10 ** n for n in range(1, 16)
                )
                if pic_boundary:
                    cause = f"Decimal truncation — PIC precision exceeded (overflow by 10^{len(str(int_mag)) - 1})"
                    fix = "Check PIC integer digits. Verify TRUNC(STD) vs TRUNC(OPT) setting."
                else:
                    cause = "Integer-level value divergence"
                    fix = "Inspect COMPUTE statement logic. Check for intermediate overflow."
            else:
                cause = "Numeric value divergence"
                fix = "Compare COMPUTE precision. Verify intermediate result handling."

        diag["likely_cause"] = cause
        diag["suggested_fix"] = fix
        enriched.append(diag)

    return enriched


# ============================================================
# COMPONENT 5 — FastAPI Endpoints + SQLite Storage
# ============================================================

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "vault.db")

# ── Per-user session isolation ───────────────────────────────────


class ShadowDiffSession:
    """Per-user state for Shadow Diff uploads and runs.

    Isolates layout and data storage so concurrent requests
    from different users don't corrupt each other.
    """
    def __init__(self):
        self.layouts: dict[str, dict] = {}
        self.uploaded_data: dict[str, dict] = {}


# Default session for backward compatibility (single-user / test mode)
_default_session = ShadowDiffSession()

# Module-level aliases — existing code and tests keep working
_layouts = _default_session.layouts
_uploaded_data = _default_session.uploaded_data

# Per-user sessions for production multi-user isolation
_user_sessions: dict[str, ShadowDiffSession] = {}


def get_session(username: str) -> ShadowDiffSession:
    """Get or create a session for the given user."""
    if username not in _user_sessions:
        _user_sessions[username] = ShadowDiffSession()
    return _user_sessions[username]

MAX_UPLOAD_SIZE = 50 * 1024 * 1024 * 1024  # 50 GB
_UPLOAD_CHUNK_SIZE = 8 * 1024 * 1024  # 8 MB chunks
_UPLOAD_DIR = os.path.join(tempfile.gettempdir(), "aletheia_uploads")


def _init_shadow_diff_table():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS shadow_diff_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            username TEXT NOT NULL,
            layout_name TEXT,
            total_records INTEGER,
            matches INTEGER,
            mismatches INTEGER,
            verdict TEXT,
            input_file_hash TEXT,
            output_file_hash TEXT,
            full_report_json TEXT
        )
    """)
    conn.commit()
    conn.close()


_init_shadow_diff_table()


def save_report(report: dict, username: str) -> int:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.execute(
        """INSERT INTO shadow_diff_results
           (timestamp, username, layout_name, total_records, matches,
            mismatches, verdict, input_file_hash, output_file_hash, full_report_json)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            report["timestamp"],
            username,
            report.get("layout_name", ""),
            report["total_records"],
            report["matches"],
            report["mismatches"],
            report["verdict"],
            report["input_file_hash"],
            report["output_file_hash"],
            json.dumps(report, default=str),
        ),
    )
    conn.commit()
    row_id = cur.lastrowid
    conn.close()
    return row_id


def _get_report(report_id: int) -> dict | None:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    row = conn.execute(
        "SELECT * FROM shadow_diff_results WHERE id = ?", (report_id,)
    ).fetchone()
    conn.close()
    if row:
        return dict(row)
    return None


# --- Router ---

shadow_diff_router = APIRouter()


class LayoutUpload(BaseModel):
    name: str
    fields: list[dict]
    record_length: int | None = None
    input_mapping: dict | None = None
    output_fields: list[str] | None = None
    constants: dict | None = None
    output_layout: dict | None = None
    codepage: str | None = None


@shadow_diff_router.post("/upload-layout")
async def upload_layout(layout: LayoutUpload, username: str = Depends(_shadow_auth)):
    """Upload a layout definition for fixed-width file parsing."""
    session = get_session(username)
    layout_dict = layout.model_dump()
    session.layouts[layout.name] = layout_dict
    return {"status": "stored", "name": layout.name, "field_count": len(layout.fields)}


@shadow_diff_router.post("/upload-mainframe-data")
async def upload_mainframe_data(
    layout_name: str,
    input_file: UploadFile = File(...),
    output_file: UploadFile = File(...),
    username: str = Depends(_shadow_auth),
):
    """Upload mainframe input and output flat files.

    Reads in chunks (8 MB) to avoid loading entire files into RAM.
    Enforces a 50 GB per-file limit (HTTP 413 on exceed).
    Checks available disk space before accepting (HTTP 507 if insufficient).
    Stores files to a temp directory on disk instead of in-memory dict.
    """
    os.makedirs(_UPLOAD_DIR, exist_ok=True)

    # Check disk space — need room for both files (2x MAX_UPLOAD_SIZE worst case)
    required_bytes = 2 * MAX_UPLOAD_SIZE
    disk_usage = shutil.disk_usage(_UPLOAD_DIR)
    if disk_usage.free < required_bytes:
        required_gb = required_bytes / (1024 ** 3)
        available_gb = disk_usage.free / (1024 ** 3)
        raise HTTPException(
            507,
            f"Insufficient disk space. Required: {required_gb:.1f} GB, "
            f"Available: {available_gb:.1f} GB",
        )

    async def _save_chunked(upload: UploadFile, prefix: str) -> tuple[str, str, int]:
        """Save uploaded file to disk in chunks. Returns (path, sha256_hash, size)."""
        hasher = hashlib.sha256()
        file_path = os.path.join(_UPLOAD_DIR, f"{prefix}_{username}_{layout_name}_{uuid.uuid4().hex[:8]}")
        total_read = 0
        with open(file_path, "wb") as f:
            while True:
                chunk = await upload.read(_UPLOAD_CHUNK_SIZE)
                if not chunk:
                    break
                total_read += len(chunk)
                if total_read > MAX_UPLOAD_SIZE:
                    f.close()
                    os.remove(file_path)
                    raise HTTPException(
                        413,
                        f"File exceeds maximum size of {MAX_UPLOAD_SIZE // (1024 ** 3)} GB",
                    )
                hasher.update(chunk)
                f.write(chunk)
        return file_path, f"sha256:{hasher.hexdigest()}", total_read

    input_path, input_hash, input_size = await _save_chunked(input_file, "input")
    output_path, output_hash, output_size = await _save_chunked(output_file, "output")

    session = get_session(username)
    session.uploaded_data[layout_name] = {
        "input_path": input_path,
        "output_path": output_path,
        "input_hash": input_hash,
        "output_hash": output_hash,
    }

    return {
        "status": "stored",
        "layout_name": layout_name,
        "input_size": input_size,
        "output_size": output_size,
    }


class RunRequest(BaseModel):
    layout_name: str
    generated_python: str
    input_mapping: dict | None = None
    output_fields: list[str] | None = None
    constants: dict | None = None
    codepage: str | None = None  # Override layout codepage (e.g., "cp037", "auto")


@shadow_diff_router.post("/run")
async def run_shadow_diff(req: RunRequest, username: str = Depends(_shadow_auth)):
    """Run the full Shadow Diff pipeline."""
    session = get_session(username)

    # Validate layout exists
    if req.layout_name not in session.layouts:
        raise HTTPException(404, f"Layout '{req.layout_name}' not found. Upload it first.")
    layout = session.layouts[req.layout_name]

    # Validate data exists
    if req.layout_name not in session.uploaded_data:
        raise HTTPException(404, f"Mainframe data for '{req.layout_name}' not found. Upload it first.")
    data = session.uploaded_data[req.layout_name]

    # Resolve mappings — request overrides > layout defaults
    input_mapping = req.input_mapping or layout.get("input_mapping")
    output_fields = req.output_fields or layout.get("output_fields")
    if not input_mapping:
        raise HTTPException(400, "input_mapping required (in layout or request body)")
    # If output_fields is empty, derive from input_mapping values (Python variable names)
    if not output_fields and input_mapping:
        output_fields = list(input_mapping.values())
    if not output_fields:
        raise HTTPException(400, "output_fields required (in layout or request body)")

    # Parse constants — convert string values to Decimal where possible
    constants = req.constants or layout.get("constants") or {}
    parsed_constants = {}
    for k, v in constants.items():
        try:
            parsed_constants[k] = Decimal(str(v))
        except Exception:
            parsed_constants[k] = v

    # --- STREAMING PIPELINE ---

    # Resolve effective codepage: request override > layout > default
    effective_codepage = req.codepage or layout.get("codepage", "ascii")

    # 1. Build streaming input parser
    input_layout = {
        "fields": [f for f in layout["fields"] if f["name"] in input_mapping],
        "record_length": layout.get("record_length"),
        "codepage": effective_codepage,
    }

    # 2. Build streaming mainframe output parser
    #    Fall back to input layout when output_layout is missing or has no fields
    output_layout_def = layout.get("output_layout")
    if not output_layout_def or not output_layout_def.get("fields"):
        output_layout_def = input_layout.copy()
    if "codepage" not in output_layout_def:
        output_layout_def["codepage"] = effective_codepage

    output_mapping = output_layout_def.get("field_mapping") or input_mapping

    def _mainframe_stream():
        """Generator that parses and maps mainframe output records one at a time."""
        for rec in parse_fixed_width_stream(output_layout_def, Path(data["output_path"])):
            mapped = {}
            for cobol_name, python_name in output_mapping.items():
                if cobol_name in rec:
                    mapped[python_name] = str(rec[cobol_name])
            yield mapped

    # 3. Extract edited field names from output layout for numeric comparison
    edited_fields_set = set()
    for f in output_layout_def.get("fields", []):
        if f.get("is_edited"):
            py_name = output_mapping.get(f["name"])
            if py_name:
                edited_fields_set.add(py_name)

    # 4. Run streaming pipeline: parse → execute → compare, one record at a time
    comparison = run_streaming_pipeline(
        source=req.generated_python,
        input_stream=parse_fixed_width_stream(input_layout, Path(data["input_path"])),
        mainframe_stream=_mainframe_stream(),
        input_mapping=input_mapping,
        output_fields=output_fields,
        constants=parsed_constants,
        edited_fields=edited_fields_set or None,
    )

    # 5. Generate report
    report = generate_report(
        comparison,
        input_file_hash=data["input_hash"],
        output_file_hash=data["output_hash"],
        layout_name=req.layout_name,
    )

    # 6. Convert Decimals to strings for JSON serialization
    def _dec_to_str(obj):
        if isinstance(obj, dict):
            return {k: _dec_to_str(v) for k, v in obj.items()}
        if isinstance(obj, list):
            return [_dec_to_str(v) for v in obj]
        if isinstance(obj, Decimal):
            return str(obj)
        return obj
    report = _dec_to_str(report)

    # 7. Save to vault.db
    report_id = save_report(report, username)
    report["id"] = report_id

    return report


@shadow_diff_router.get("/report/{report_id}")
async def get_report(report_id: int, username: str = Depends(_shadow_auth)):
    """Retrieve a stored Shadow Diff report."""
    row = _get_report(report_id)
    if not row:
        raise HTTPException(404, f"Report {report_id} not found")

    result = dict(row)
    # Parse stored JSON back
    if result.get("full_report_json"):
        result["report"] = json.loads(result["full_report_json"])
    return result


@shadow_diff_router.get("/reports")
async def list_reports(username: str = Depends(_shadow_auth)):
    """List all Shadow Diff reports."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        """SELECT id, timestamp, username, layout_name, total_records,
                  matches, mismatches, verdict
           FROM shadow_diff_results ORDER BY id DESC"""
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


# ============================================================
# COMPONENT 6 — Demo Data Generator
# ============================================================

def generate_demo_data(output_dir: str | None = None) -> dict:
    """Generate 100 test records for DEMO_LOAN_INTEREST.cbl.

    Creates:
      - loan_layout.json  (layout + mappings)
      - loan_input.dat    (100 fixed-width input records)
      - loan_mainframe_output.dat (100 fixed-width output records)

    Returns dict with file paths and summary.
    """
    if output_dir is None:
        output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "demo_data")
    os.makedirs(output_dir, exist_ok=True)

    # Generate Python live from DEMO_LOAN_INTEREST.cbl
    from cobol_analyzer_api import analyze_cobol
    from generate_full_python import generate_python_module

    cobol_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "DEMO_LOAN_INTEREST.cbl"
    )
    with open(cobol_path, "r") as f:
        cobol_source = f.read()
    analysis = analyze_cobol(cobol_source)
    generated_source = generate_python_module(analysis)["code"]

    getcontext().prec = 31

    # --- Generate 100 diverse input records ---
    import random
    rng = random.Random(42)  # Deterministic seed

    input_records = []
    for i in range(100):
        account_num = f"ACC{i+1:07d}"

        # Realistic ranges
        principal = Decimal(str(rng.randint(100000, 50000000))) / Decimal("100")  # $1,000 — $500,000
        annual_rate = Decimal(str(rng.randint(350000, 1200000))) / Decimal("100000000")  # 0.003500 — 0.012000
        # Normalize to 6 decimal places like the COBOL PIC S9(3)V9(6)
        annual_rate = annual_rate.quantize(Decimal("0.000001"))
        days_overdue = rng.randint(0, 45)
        vip_flag = "Y" if rng.random() < 0.2 else "N"

        input_records.append({
            "ACCOUNT-NUM": account_num,
            "PRINCIPAL-BAL": principal,
            "ANNUAL-RATE": annual_rate,
            "DAYS-OVERDUE": Decimal(str(days_overdue)),
            "VIP-FLAG": vip_flag,
        })

    # --- Execute generated Python for each record to get correct outputs ---
    input_mapping = {
        "ACCOUNT-NUM": "ws_account_num",
        "PRINCIPAL-BAL": "ws_principal_bal",
        "ANNUAL-RATE": "ws_annual_rate",
        "DAYS-OVERDUE": "ws_days_overdue",
        "VIP-FLAG": "ws_vip_flag",
    }

    output_fields = [
        "ws_daily_rate",
        "ws_daily_interest",
        "ws_penalty_amount",
        "ws_accrued_int",
    ]

    constants = {
        "ws_days_in_year": Decimal("365"),
        "ws_grace_period": Decimal("15"),
        "ws_max_penalty_pct": Decimal("0.05"),
    }

    aletheia_outputs = list(execute_generated_python(
        source=generated_source,
        input_records=input_records,
        input_mapping=input_mapping,
        output_fields=output_fields,
        constants=constants,
    ))

    # --- Write input .dat file ---
    # Format: ACCOUNT-NUM(10) PRINCIPAL-BAL(12) ANNUAL-RATE(10) DAYS-OVERDUE(3) VIP-FLAG(1) = 36 chars
    input_lines = []
    for rec in input_records:
        line = (
            f"{rec['ACCOUNT-NUM']:<10s}"
            f"{str(rec['PRINCIPAL-BAL']):>12s}"
            f"{str(rec['ANNUAL-RATE']):>10s}"
            f"{str(rec['DAYS-OVERDUE']):>3s}"
            f"{rec['VIP-FLAG']:1s}"
        )
        input_lines.append(line)

    input_dat_path = os.path.join(output_dir, "loan_input.dat")
    with open(input_dat_path, "w", newline="") as f:
        f.write("\n".join(input_lines))

    # --- Write output .dat file (mainframe expected outputs) ---
    # Decimal(31) values can be 35+ chars, so use 40-char columns
    # Format: DAILY-RATE(40) DAILY-INTEREST(40) PENALTY-AMOUNT(40) ACCRUED-INT(40) = 160 chars
    output_lines = []
    for out_rec in aletheia_outputs:
        line = (
            f"{out_rec.get('ws_daily_rate', '0'):>40s}"
            f"{out_rec.get('ws_daily_interest', '0'):>40s}"
            f"{out_rec.get('ws_penalty_amount', '0'):>40s}"
            f"{out_rec.get('ws_accrued_int', '0'):>40s}"
        )
        output_lines.append(line)

    output_dat_path = os.path.join(output_dir, "loan_mainframe_output.dat")
    with open(output_dat_path, "w", newline="") as f:
        f.write("\n".join(output_lines))

    # --- Write layout JSON ---
    layout = {
        "name": "DEMO_LOAN_INTEREST",
        "fields": [
            {"name": "ACCOUNT-NUM", "start": 0, "length": 10, "type": "string"},
            {"name": "PRINCIPAL-BAL", "start": 10, "length": 12, "type": "decimal", "decimals": 2},
            {"name": "ANNUAL-RATE", "start": 22, "length": 10, "type": "decimal", "decimals": 6},
            {"name": "DAYS-OVERDUE", "start": 32, "length": 3, "type": "integer"},
            {"name": "VIP-FLAG", "start": 35, "length": 1, "type": "string"},
        ],
        "record_length": None,  # newline-delimited
        "input_mapping": input_mapping,
        "output_fields": output_fields,
        "constants": {k: str(v) for k, v in constants.items()},
        "output_layout": {
            "fields": [
                {"name": "DAILY-RATE", "start": 0, "length": 40, "type": "decimal", "decimals": 8},
                {"name": "DAILY-INTEREST", "start": 40, "length": 40, "type": "decimal", "decimals": 2},
                {"name": "PENALTY-AMOUNT", "start": 80, "length": 40, "type": "decimal", "decimals": 2},
                {"name": "ACCRUED-INT", "start": 120, "length": 40, "type": "decimal", "decimals": 2},
            ],
            "record_length": None,
            "field_mapping": {
                "DAILY-RATE": "ws_daily_rate",
                "DAILY-INTEREST": "ws_daily_interest",
                "PENALTY-AMOUNT": "ws_penalty_amount",
                "ACCRUED-INT": "ws_accrued_int",
            },
        },
    }

    layout_path = os.path.join(output_dir, "loan_layout.json")
    with open(layout_path, "w") as f:
        json.dump(layout, f, indent=2)

    return {
        "layout_path": layout_path,
        "input_dat_path": input_dat_path,
        "output_dat_path": output_dat_path,
        "record_count": len(input_records),
        "output_count": len(aletheia_outputs),
        "errors": [r for r in aletheia_outputs if "_error" in r],
    }


# ============================================================
# CLI entry point for demo data generation
# ============================================================

if __name__ == "__main__":
    result = generate_demo_data()
    print(f"Generated {result['record_count']} input records")
    print(f"Generated {result['output_count']} output records")
    print(f"Errors: {len(result['errors'])}")
    print(f"Layout: {result['layout_path']}")
    print(f"Input:  {result['input_dat_path']}")
    print(f"Output: {result['output_dat_path']}")
