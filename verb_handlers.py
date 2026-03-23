"""
verb_handlers.py — Shared COBOL verb → Python emitters

Single source of truth for verb translation logic used by both
generate_full_python.py (structured dict input) and
parse_conditions.py (getText() blob input, inside IF/EVALUATE branches).

Each handler returns (code_string, issues_list).
"""

from parse_conditions import to_python_name, _resolve_value, _is_string_operand, _resolve_subscripted_name


# ── Trivial verbs (one-liners) ────────────────────────────────────

def emit_stop_run(indent="    "):
    return f"{indent}return  # STOP RUN", []


def emit_exit_program(indent="    "):
    return f"{indent}return  # EXIT PROGRAM", []


def emit_goback(indent="    "):
    return f"{indent}return  # GOBACK", []


def emit_simple_perform(target_para, indent="    "):
    """PERFORM paragraph-name → para_xxx() call."""
    py_target = "para_" + to_python_name(target_para)
    return f"{indent}{py_target}()", []


def emit_goto(target_para, indent="    "):
    """GO TO paragraph-name → para_xxx() call + return."""
    py_target = "para_" + to_python_name(target_para)
    code = f"{indent}{py_target}()  # GO TO {target_para}\n{indent}return"
    return code, []


# ── Medium verbs ──────────────────────────────────────────────────

import os as _os
_accept_date = _os.environ.get("ALETHEIA_ACCEPT_DATE", "")  # e.g. "20260322"
if len(_accept_date) >= 8 and _accept_date.isdigit():
    _ACCEPT_PLACEHOLDERS = {
        "DATE": repr(_accept_date[2:8]),          # YYMMDD
        "DATE_YYYYMMDD": repr(_accept_date[:8]),  # YYYYMMDD
        "TIME": "'12000000'",                     # noon placeholder
        "DAY": repr(_accept_date[2:4] + "001"),   # YY + day-of-year (approx)
        "DAY_YYYYDDD": repr(_accept_date[:4] + "001"),
        "DAY_OF_WEEK": "'1'",                     # Monday placeholder
    }
else:
    _ACCEPT_PLACEHOLDERS = {
        "DATE": "'000000'",
        "DATE_YYYYMMDD": "'00000000'",
        "TIME": "'00000000'",
        "DAY": "'00000'",
        "DAY_YYYYDDD": "'0000000'",
        "DAY_OF_WEEK": "'0'",
    }


def emit_display(operands, known_vars, string_vars, indent="    ", edited_vars=None):
    """DISPLAY operand-list → print(...).

    operands: list of raw COBOL operand strings (variable names or string literals).
    edited_vars: optional set of uppercase COBOL names with edited PIC (use to_edited_display()).
    """
    if not operands:
        return f"{indent}print()", []
    parts = []
    for op in operands:
        op_upper = op.upper()
        matched_var = next((v for v in known_vars if v.upper() == op_upper), None)
        if matched_var:
            if _is_string_operand(matched_var, string_vars):
                parts.append(to_python_name(matched_var))
            elif edited_vars and matched_var.upper() in edited_vars:
                parts.append(f"{to_python_name(matched_var)}.to_edited_display()")
            else:
                parts.append(f"{to_python_name(matched_var)}.value")
        elif op.startswith("'") or op.startswith('"'):
            parts.append(op)
        else:
            parts.append(f"'{op}'")
    return f"{indent}print({', '.join(parts)})", []


def emit_initialize_single(target_name, is_string, indent="    "):
    """INITIALIZE single variable → reset to SPACES or Decimal('0')."""
    py_name = to_python_name(target_name)
    if is_string:
        return f"{indent}{py_name} = ' '", []
    else:
        return f"{indent}{py_name}.store(Decimal('0'))", []


def emit_set_true(cond_name, level_88_map, string_vars, indent="    ", subscript=None):
    """SET condition-name TO TRUE → assign first value of 88-level to parent."""
    info_88 = level_88_map.get(cond_name)
    if not info_88:
        return None, []
    parent = info_88["parent"]
    py_parent = to_python_name(parent)
    first_val = (info_88.get("values") or [info_88["value"]])[0]
    # Apply subscript for SET WS-FLAG(IDX) TO TRUE
    if subscript:
        if subscript.isdigit():
            idx_expr = str(int(subscript) - 1)
        else:
            idx_py = to_python_name(subscript)
            idx_expr = f"int({idx_py}.value) - 1"
        py_target = f"{py_parent}[{idx_expr}]"
    else:
        py_target = py_parent
    if _is_string_operand(parent, string_vars):
        return f'{indent}{py_target} = "{first_val}"', []
    else:
        return f"{indent}{py_target}.store(Decimal('{first_val}'))", []


def emit_accept(target_py, accept_type, is_string, indent="    "):
    """ACCEPT target FROM type → deterministic placeholder assignment."""
    # ACCEPT FROM ENVIRONMENT-NAME: store current field value as env var name
    if accept_type == "ENVIRONMENT_NAME":
        if is_string:
            return f"{indent}_env_name = str({target_py})\n{indent}{target_py} = _env_name  # ACCEPT FROM ENVIRONMENT-NAME", []
        else:
            return f"{indent}_env_name = str({target_py}.value)\n{indent}{target_py}.store(Decimal(_env_name))  # ACCEPT FROM ENVIRONMENT-NAME", []
    # ACCEPT FROM ENVIRONMENT-VALUE: read env var named by _env_name
    if accept_type == "ENVIRONMENT_VALUE":
        if is_string:
            return f"{indent}{target_py} = _os.environ.get(_env_name, '')  # ACCEPT FROM ENVIRONMENT-VALUE", []
        else:
            return f"{indent}{target_py}.store(Decimal(_os.environ.get(_env_name, '0')))  # ACCEPT FROM ENVIRONMENT-VALUE", []
    placeholder = _ACCEPT_PLACEHOLDERS.get(accept_type, "'00000000'")
    if is_string:
        return f"{indent}{target_py} = {placeholder}  # ACCEPT FROM {accept_type} — placeholder", []
    else:
        return f"{indent}{target_py}.store(Decimal({placeholder}))  # ACCEPT FROM {accept_type} — placeholder", []


# ── MOVE (shared core) ───────────────────────────────────────────

def emit_move_single(source_py, target_py, is_string_target, indent="    ",
                     pic_length=0, justified_right=False):
    """MOVE source TO target (single pair, already resolved to Python expressions).

    pic_length: if > 0 and target is string, truncate + pad to PIC length.
    justified_right: if True, right-justify instead of left-justify.
    """
    if is_string_target:
        if pic_length > 0:
            pad_fn = "rjust" if justified_right else "ljust"
            return f"{indent}{target_py} = str({source_py})[:{pic_length}].{pad_fn}({pic_length})", []
        return f"{indent}{target_py} = {source_py}", []
    else:
        return f"{indent}{target_py}.store({source_py})", []


# ── I/O verbs ────────────────────────────────────────────────────

def emit_file_open(file_name, mode, indent="    "):
    """OPEN INPUT/OUTPUT/I-O → _io_open() call."""
    return f"{indent}_io_open('{file_name}', '{mode}')", []


def emit_file_read(file_name, indent="    "):
    """READ file → _io_read() call."""
    return f"{indent}_record = _io_read('{file_name}')", []


def emit_file_write(record_name, indent="    "):
    """WRITE record → _io_write() call."""
    return f"{indent}_io_write('{record_name}')", []


def emit_file_close(file_name, indent="    "):
    """CLOSE file → _io_close() call."""
    return f"{indent}_io_close('{file_name}')", []


def emit_file_rewrite(record_name, indent="    "):
    """REWRITE record → _io_rewrite() call."""
    return f"{indent}_io_rewrite('{record_name}')", []
