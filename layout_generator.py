"""Auto-generate Shadow Diff layout JSON from COBOL analysis output.

Two paths:
  - FD-based: uses FILE SECTION record structures with actual storage byte lengths
  - WORKING-STORAGE fallback: uses display byte lengths for text-format flat files

All layout generation imported by core_logic.py — no duplication.
"""

import re
from cobol_analyzer_api import parse_pic_clause
from copybook_resolver import _pic_byte_length


def pic_to_layout_type(pic_raw: str, storage_type: str = "DISPLAY",
                       use_binary: bool = False) -> dict:
    """Convert PIC clause + storage type to shadow_diff field type.

    Args:
        pic_raw: Raw PIC clause (e.g. "S9(9)V99", "X(10)")
        storage_type: "DISPLAY", "COMP-3", or "COMP"
        use_binary: If True, emit "comp3" for COMP-3 fields (FD binary path).
                    If False, emit "decimal" even for COMP-3 (WS text path).
    """
    if not pic_raw:
        return {"type": "string"}

    upper = pic_raw.upper().strip()

    # String types: PIC X or PIC A
    if "X" in upper or "A" in upper:
        return {"type": "string"}

    # Numeric — get decimal count from parse_pic_clause
    pic_info = parse_pic_clause(pic_raw)
    decimals = pic_info.get("decimals", 0) if pic_info else 0

    # COMP-3 in binary file → "comp3" type for decode_comp3()
    if use_binary and storage_type == "COMP-3":
        result = {"type": "comp3"}
        if decimals > 0:
            result["decimals"] = decimals
        return result

    # Numeric with decimals → "decimal"
    if decimals > 0:
        return {"type": "decimal", "decimals": decimals}

    # Integer (no decimal places)
    return {"type": "integer"}


def display_byte_length(pic_raw: str, pic_info: dict | None = None) -> int:
    """Byte length in DISPLAY (text) representation for flat files.

    For text-format flat files where all fields are human-readable.
    COMP-3 S9(9)V99 → 12 display chars (sign + 9 digits + 2 decimals).
    """
    if not pic_raw:
        return 0

    upper = pic_raw.upper().strip()

    # String: X(n) or A(n)
    for char_type in ("X", "A"):
        if char_type in upper:
            m = re.search(rf'{char_type}\((\d+)\)', upper)
            if m:
                return int(m.group(1))
            return upper.count(char_type)

    # Numeric: count digits
    if pic_info is None:
        pic_info = parse_pic_clause(pic_raw)
    if not pic_info:
        return 0

    integers = pic_info.get("integers", 0)
    decimals = pic_info.get("decimals", 0)
    signed = pic_info.get("signed", False)

    # Display format: digits + sign indicator
    length = integers + decimals
    if signed:
        length += 1  # sign character
    return length


def classify_variables(generated_python: str, analysis: dict) -> dict:
    """Classify variables as input/output/constant/intermediate.

    Scans generated Python for .store() and = assignment patterns.
    INITIALIZE-only targets (store(Decimal('0'))) are not considered
    "real" assignments — they're setup, not computation.

    Returns:
        {
            "inputs": set of COBOL names,
            "outputs": set of COBOL names,
            "constants": dict of {python_name: value_string},
            "intermediates": set of COBOL names,
        }
    """
    from generate_full_python import to_python_name

    # Build maps: python_name ↔ cobol_name
    py_to_cobol = {}
    cobol_to_py = {}

    for v in analysis.get("variables", []):
        name = v.get("name")
        if not name:
            continue
        raw = v.get("raw", "")
        level_match = re.match(r'^(\d{2})', raw.upper())
        level = int(level_match.group(1)) if level_match else 0
        if level == 88:
            continue
        pic_raw = v.get("pic_raw", "")
        if not pic_raw:
            continue  # group item
        py_name = to_python_name(name)
        py_to_cobol[py_name] = name
        cobol_to_py[name.upper()] = py_name

    # Scan generated Python for REAL assignment targets (not just INITIALIZE)
    # INITIALIZE emits: ws_xxx.store(Decimal('0'))
    # Real assignments have variable references in the expression
    real_targets = set()       # py_names that get computed values
    init_only_targets = set()  # py_names only set by INITIALIZE/literal MOVE
    str_targets = {}           # py_name → set of assigned string values

    # Build per-line analysis
    target_to_sources = {}  # target_py → set of source_py vars

    for line in generated_python.split('\n'):
        stripped = line.strip()

        # Pattern: ws_xxx.store(expr)
        store_match = re.match(r'(\w+)\.store\((.+)\)$', stripped)
        if store_match:
            target = store_match.group(1)
            expr = store_match.group(2)
            sources = set(re.findall(r'(\w+)\.value', expr))

            if sources:
                # Real computation — references other variables
                real_targets.add(target)
                if target not in target_to_sources:
                    target_to_sources[target] = set()
                target_to_sources[target].update(sources)
            else:
                # Literal assignment: store(Decimal('0')), store(Decimal('0.0025'))
                init_only_targets.add(target)

        # Pattern: ws_xxx = "..." (string assignment)
        str_match = re.match(r"(\w+)\s*=\s*['\"](.*)['\"]\s*$", stripped)
        if str_match:
            target = str_match.group(1)
            value = str_match.group(2)
            if target in py_to_cobol:
                if target not in str_targets:
                    str_targets[target] = set()
                str_targets[target].add(value)

    # Also detect string reads: ws_xxx == "Y" or ws_xxx in (...)
    string_reads = set()
    for match in re.finditer(r'(\w+)\s*==\s*["\']', generated_python):
        string_reads.add(match.group(1))
    for match in re.finditer(r'(\w+)\s+in\s+\(', generated_python):
        string_reads.add(match.group(1))

    # Variables that are sources for OTHER variables' computations
    sources_for_others = set()
    for target, sources in target_to_sources.items():
        for src in sources:
            if src != target:
                sources_for_others.add(src)
    # String variables used in conditions that affect computed targets
    sources_for_others.update(string_reads & set(py_to_cobol.keys()))

    # Detect constants: VALUE clause + only INITIALIZE targets (never computed)
    constants = {}
    value_vars = set()
    for v in analysis.get("variables", []):
        name = v.get("name")
        if not name:
            continue
        raw = v.get("raw", "")
        pic_raw = v.get("pic_raw", "")
        if not pic_raw:
            continue
        upper_raw = raw.upper()
        if "VALUE" not in upper_raw:
            continue
        py_name = to_python_name(name)
        if py_name in real_targets:
            continue  # gets computed — not a constant
        # Extract value (strip trailing COBOL period)
        val_m = re.search(r'VALUE\s*(-?[\d.]+)', raw, re.IGNORECASE)
        if val_m:
            val_str = val_m.group(1).rstrip('.')
            constants[py_name] = val_str
            value_vars.add(name.upper())

    # Literal-only setup: variables set by a SINGLE literal MOVE (e.g., MOVE 0.0025 TO X)
    # that are never computed from other variables. These are internal constants, not inputs.
    # Variables with MULTIPLE .store() calls are conditional outputs (value depends on
    # control flow), not setup — e.g., MOVE 12.50 TO WS-FEE inside IF.
    literal_setup = set()
    for target in init_only_targets:
        if target in real_targets:
            continue  # also computed — not literal-only
        if target not in py_to_cobol:
            continue
        cobol_upper = py_to_cobol[target].upper()
        if cobol_upper in value_vars:
            continue
        # Count .store() call sites for this variable
        store_lines = [line.strip() for line in generated_python.split('\n')
                       if line.strip().startswith(f'{target}.store(')]
        # Single store with non-zero literal → true constant setup
        # Multiple stores → conditional assignment, NOT setup
        if len(store_lines) == 1:
            m = re.match(rf'{re.escape(target)}\.store\(Decimal\([\'"](.+?)[\'"]\)\)$', store_lines[0])
            if m and m.group(1) != '0':
                literal_setup.add(target)

    # Dead variable detection: vars that only appear in declarations,
    # globals, and INITIALIZE (store(Decimal('0'))). Never read or computed.
    # Multi-store literal vars are conditional outputs — exempt from dead detection.
    dead_vars = set()
    for py_name in (init_only_targets - real_targets - literal_setup):
        if py_name not in py_to_cobol:
            continue
        # Multi-store = conditional output (e.g., MOVE 3 TO WS-TIER inside EVALUATE)
        store_count = sum(1 for line in generated_python.split('\n')
                          if line.strip().startswith(f'{py_name}.store('))
        if store_count > 1:
            continue  # conditional output, not dead
        # Check if this var is ever read (.value, ==, in ()) anywhere
        is_read = (py_name in sources_for_others or
                   py_name in string_reads)
        if not is_read:
            # Also check if it appears as source in any .store() expression
            appears_in_expr = False
            for line in generated_python.split('\n'):
                s = line.strip()
                if s.startswith(f'{py_name}.store('):
                    continue  # it's a target, not interesting
                if f'{py_name}.value' in s or f'{py_name} ==' in s:
                    appears_in_expr = True
                    break
            if not appears_in_expr:
                dead_vars.add(py_name)

    # Classify variables as input or output
    inputs = set()
    outputs = set()

    for py_name, cobol_name in py_to_cobol.items():
        cobol_upper = cobol_name.upper()
        if cobol_upper in value_vars:
            continue  # constant
        if py_name in literal_setup:
            continue  # internal setup (single MOVE literal, not VALUE clause)
        if py_name in dead_vars:
            continue  # never used — dead variable
        if py_name in str_targets and py_name not in real_targets:
            # Only exclude if there's a meaningful (non-empty) string assignment
            # Empty string "" is just PIC X initialization — variable is still an input
            if any(v.strip() for v in str_targets[py_name]):
                continue  # status message / computed string, not numeric I/O

        if py_name in real_targets:
            outputs.add(cobol_upper)
        elif py_name in init_only_targets:
            # Multi-store literal → conditional output (value depends on control flow)
            store_count = sum(1 for line in generated_python.split('\n')
                              if line.strip().startswith(f'{py_name}.store('))
            if store_count > 1:
                outputs.add(cobol_upper)
            else:
                inputs.add(cobol_upper)
        else:
            inputs.add(cobol_upper)

    return {
        "inputs": inputs,
        "outputs": outputs,
        "constants": constants,
        "intermediates": set(),  # all computed vars go to outputs
    }


def _strip_ws_prefix(name: str) -> str:
    """Strip WS- prefix from COBOL variable names for layout field names."""
    upper = name.upper()
    if upper.startswith("WS-"):
        return name[3:]
    return name


def generate_layout(analysis: dict, generated_python: str,
                    program_name: str | None = None) -> dict:
    """Auto-generate Shadow Diff layout from COBOL analysis.

    Routes to FD-based or WORKING-STORAGE fallback path.
    """
    if analysis.get("file_descriptions"):
        return _generate_layout_from_fd(analysis, generated_python, program_name)
    return _generate_layout_from_ws(analysis, generated_python, program_name)


def _generate_layout_from_ws(analysis: dict, generated_python: str,
                             program_name: str | None = None) -> dict:
    """WORKING-STORAGE fallback: text-format flat files.

    All fields use display byte lengths. No "comp3" type — files are text.
    """
    from generate_full_python import to_python_name

    classification = classify_variables(generated_python, analysis)
    memory_map = analysis.get("redefines", {}).get("memory_map", [])

    # Build lookup: COBOL name → memory_map entry
    mm_lookup = {}
    for entry in memory_map:
        mm_lookup[entry["name"].upper()] = entry

    # Build variable info lookup
    var_lookup = {}
    for v in analysis.get("variables", []):
        name = v.get("name")
        if name:
            var_lookup[name.upper()] = v

    # Input fields — ordered by memory_map offset
    input_fields = []
    input_mapping = {}
    current_offset = 0

    input_names_ordered = []
    for entry in memory_map:
        name_upper = entry["name"].upper()
        if name_upper in classification["inputs"]:
            input_names_ordered.append(name_upper)

    for cobol_name in input_names_ordered:
        v = var_lookup.get(cobol_name, {})
        pic_raw = v.get("pic_raw", "")
        if not pic_raw:
            continue
        pic_info = v.get("pic_info")
        storage_type = v.get("storage_type", "DISPLAY")

        # Text flat file: use display type (not comp3) and display length
        field_type = pic_to_layout_type(pic_raw, storage_type, use_binary=False)
        length = display_byte_length(pic_raw, pic_info)

        short_name = _strip_ws_prefix(cobol_name)
        if not short_name:
            continue  # skip parser artifacts (e.g. truncated "WS-" names)
        py_name = to_python_name(cobol_name)

        field = {"name": short_name, "start": current_offset, "length": length}
        field.update(field_type)
        if pic_info and pic_info.get("is_edited"):
            field["is_edited"] = True
            field["pic_raw"] = pic_raw
        input_fields.append(field)
        input_mapping[short_name] = py_name
        current_offset += length

    # Output fields
    output_fields_list = []
    output_layout_fields = []
    output_field_mapping = {}
    out_offset = 0

    output_names_ordered = []
    for entry in memory_map:
        name_upper = entry["name"].upper()
        if name_upper in classification["outputs"]:
            output_names_ordered.append(name_upper)

    for cobol_name in output_names_ordered:
        v = var_lookup.get(cobol_name, {})
        pic_raw = v.get("pic_raw", "")
        if not pic_raw:
            continue
        pic_info = v.get("pic_info")
        storage_type = v.get("storage_type", "DISPLAY")

        py_name = to_python_name(cobol_name)
        output_fields_list.append(py_name)

        field_type = pic_to_layout_type(pic_raw, storage_type, use_binary=False)
        short_name = _strip_ws_prefix(cobol_name)

        # Output width=40: matches mainframe SYSPRINT column width convention
        if field_type["type"] in ("decimal", "integer"):
            out_length = 40
        else:
            out_length = display_byte_length(pic_raw, pic_info)

        out_field = {"name": short_name, "start": out_offset, "length": out_length}
        out_field.update(field_type)
        if pic_info and pic_info.get("is_edited"):
            out_field["is_edited"] = True
            out_field["pic_raw"] = pic_raw
        output_layout_fields.append(out_field)
        output_field_mapping[short_name] = py_name
        out_offset += out_length

    return {
        "name": program_name or "",
        "fields": input_fields,
        "record_length": None,
        "input_mapping": input_mapping,
        "output_fields": output_fields_list,
        "constants": classification["constants"],
        "output_layout": {
            "fields": output_layout_fields,
            "record_length": None,
            "field_mapping": output_field_mapping,
        },
    }


def _generate_layout_from_fd(analysis: dict, generated_python: str,
                             program_name: str | None = None) -> dict:
    """FD-based path: binary mainframe files with actual storage byte lengths.

    Uses _pic_byte_length() for packed COMP-3 fields.
    """
    from generate_full_python import to_python_name

    file_descriptions = analysis.get("file_descriptions", [])
    file_operations = analysis.get("file_operations", [])
    memory_map = analysis.get("redefines", {}).get("memory_map", [])

    # Determine input/output files from OPEN/READ/WRITE operations
    input_files = set()
    output_files = set()
    output_records = set()
    for op in file_operations:
        fn = op.get("file_name", "").upper()
        rn = op.get("record_name", "").upper()
        direction = op.get("direction", "")
        if direction == "INPUT" and fn:
            input_files.add(fn)
        elif direction == "OUTPUT":
            if fn:
                output_files.add(fn)
            if rn:
                output_records.add(rn)

    # Match FD names to input/output direction
    fd_names = {fd["name"].upper() for fd in file_descriptions}
    input_fd_names = input_files & fd_names
    output_fd_names = output_files & fd_names

    if not input_fd_names and not output_fd_names:
        # No FD matched I/O operations — fall back to WS
        return _generate_layout_from_ws(analysis, generated_python, program_name)

    # Build variable info lookup
    var_lookup = {}
    for v in analysis.get("variables", []):
        name = v.get("name")
        if name:
            var_lookup[name.upper()] = v

    # Find FD record fields from memory_map
    # Collect known WS 01-level names to skip them when looking for FD records
    ws_names = set()
    for v in analysis.get("variables", []):
        raw = v.get("raw", "")
        if re.match(r'^01', raw) and v.get("name", "").upper().startswith("WS-"):
            ws_names.add(v["name"].upper())

    def _get_fd_record_fields(fd_name: str) -> list:
        """Get elementary fields belonging to an FD's record structure."""
        fields = []
        in_fd = False
        fd_level = None
        for entry in memory_map:
            name_upper = entry["name"].upper()
            v = var_lookup.get(name_upper, {})
            raw = v.get("raw", "")
            level_match = re.match(r'^(\d{2})', raw.upper())
            level = int(level_match.group(1)) if level_match else 0
            if not in_fd:
                if level == 1 and not v.get("pic_raw") and name_upper not in ws_names:
                    in_fd = True
                    fd_level = level
                    continue
            else:
                pic_raw = v.get("pic_raw", "")
                if level <= fd_level:
                    break  # End of this FD's record
                if level == 88:
                    continue
                if pic_raw:
                    fields.append(entry)
        return fields

    # Build input layout from first input FD
    input_fields = []
    input_mapping = {}
    if input_fd_names:
        fd_name = sorted(input_fd_names)[0]
        fd_record_fields = _get_fd_record_fields(fd_name)
        current_offset = 0
        for entry in fd_record_fields:
            name_upper = entry["name"].upper()
            v = var_lookup.get(name_upper, {})
            pic_raw = v.get("pic_raw", "")
            storage_type = v.get("storage_type", "DISPLAY")
            is_comp3 = v.get("comp3", False)
            is_comp = storage_type == "COMP"

            # FD binary path: actual storage byte lengths
            length = _pic_byte_length(pic_raw, is_comp3, is_comp)
            field_type = pic_to_layout_type(pic_raw, storage_type, use_binary=True)

            short_name = _strip_ws_prefix(name_upper)
            py_name = to_python_name(name_upper)

            field = {"name": short_name, "start": current_offset, "length": length}
            field.update(field_type)
            pic_info = v.get("pic_info")
            if pic_info and pic_info.get("is_edited"):
                field["is_edited"] = True
                field["pic_raw"] = pic_raw
            input_fields.append(field)
            input_mapping[short_name] = py_name
            current_offset += length

    # Build output layout from first output FD
    output_layout_fields = []
    output_field_mapping = {}
    out_offset = 0
    if output_fd_names:
        fd_name = sorted(output_fd_names)[0]
        fd_record_fields = _get_fd_record_fields(fd_name)
        for entry in fd_record_fields:
            name_upper = entry["name"].upper()
            v = var_lookup.get(name_upper, {})
            pic_raw = v.get("pic_raw", "")
            storage_type = v.get("storage_type", "DISPLAY")
            is_comp3 = v.get("comp3", False)
            is_comp = storage_type == "COMP"

            length = _pic_byte_length(pic_raw, is_comp3, is_comp)
            field_type = pic_to_layout_type(pic_raw, storage_type, use_binary=True)

            short_name = _strip_ws_prefix(name_upper)
            py_name = to_python_name(name_upper)

            out_field = {"name": short_name, "start": out_offset, "length": length}
            out_field.update(field_type)
            pic_info = v.get("pic_info")
            if pic_info and pic_info.get("is_edited"):
                out_field["is_edited"] = True
                out_field["pic_raw"] = pic_raw
            output_layout_fields.append(out_field)
            output_field_mapping[short_name] = py_name
            out_offset += length

    # Output fields: all output FD fields + WS outputs
    classification = classify_variables(generated_python, analysis)
    output_fields_list = list(output_field_mapping.values())
    for cobol_name in classification["outputs"]:
        py_name = to_python_name(cobol_name)
        if py_name not in output_fields_list:
            output_fields_list.append(py_name)

    return {
        "name": program_name or "",
        "fields": input_fields,
        "record_length": None,
        "input_mapping": input_mapping,
        "output_fields": output_fields_list,
        "constants": classification["constants"],
        "output_layout": {
            "fields": output_layout_fields,
            "record_length": None,
            "field_mapping": output_field_mapping,
        },
    }
