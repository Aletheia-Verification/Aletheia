"""
COPYBOOK Resolver for Enterprise COBOL
=======================================

Preprocesses COBOL source to expand COPY statements and resolve REDEFINES
clauses before ANTLR4 parsing.

Components:
    1. COPY Statement Detector
    2. Copybook Library (directory-based store)
    3. Source Preprocessor (expand + REPLACING)
    4. REDEFINES Resolver (memory map + byte offsets)
    6. FastAPI Endpoints (upload, list, delete, preprocess)
"""

import os
import re
import zipfile
import io
from datetime import datetime, timezone
from pathlib import Path

# ── Configuration ──────────────────────────────────────────────────

COPYBOOK_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "copybooks")
MAX_COPY_DEPTH = 10


# ── Exceptions ─────────────────────────────────────────────────────

class CopybookNotFoundError(Exception):
    """Raised when a copybook cannot be found in the library."""
    pass


class CircularCopyError(Exception):
    """Raised when circular COPY inclusion is detected."""
    pass


# ══════════════════════════════════════════════════════════════════
# COMPONENT 1 — COPY Statement Detector
# ══════════════════════════════════════════════════════════════════

# Matches: COPY name [OF library] [REPLACING ==old== BY ==new== ...].
COPY_PATTERN = re.compile(
    r'COPY\s+'
    r'([A-Za-z0-9][A-Za-z0-9\-]*)'          # copybook name
    r'(?:\s+OF\s+([A-Za-z0-9][A-Za-z0-9\-]*))?'  # optional OF library
    r'(?:\s+REPLACING\s+(.+?))?'             # optional REPLACING clause
    r'\s*\.',                                 # terminating period
    re.IGNORECASE | re.DOTALL
)

# Matches LEADING/TRAILING ==old== BY ==new== pairs (must be checked first)
REPLACING_PAIR_PREFIX = re.compile(
    r'(LEADING|TRAILING)\s+==\s*(.+?)\s*==\s+BY\s+==\s*(.+?)\s*==',
    re.IGNORECASE
)

# Matches individual ==old== BY ==new== pairs
REPLACING_PAIR = re.compile(
    r'==\s*(.+?)\s*==\s+BY\s+==\s*(.+?)\s*==',
    re.IGNORECASE
)


def detect_copy_statements(source: str) -> list:
    """Scan COBOL source for COPY statements.

    Returns list of dicts:
        {name, library, replacing, start, end, line_number}
    """
    results = []
    for match in COPY_PATTERN.finditer(source):
        name = match.group(1).upper()
        library = match.group(2).upper() if match.group(2) else None
        replacing_text = match.group(3)

        replacing = []
        if replacing_text:
            # Parse LEADING/TRAILING pairs first, track their spans
            prefix_spans = set()
            for pair in REPLACING_PAIR_PREFIX.finditer(replacing_text):
                replacing.append((pair.group(2), pair.group(3), pair.group(1).upper()))
                prefix_spans.add((pair.start(), pair.end()))
            # Parse regular pairs, skipping those inside LEADING/TRAILING
            for pair in REPLACING_PAIR.finditer(replacing_text):
                if any(pair.start() >= ps and pair.end() <= pe for ps, pe in prefix_spans):
                    continue
                replacing.append((pair.group(1), pair.group(2)))

        # Calculate line number
        line_number = source[:match.start()].count('\n') + 1

        results.append({
            "name": name,
            "library": library,
            "replacing": replacing if replacing else None,
            "start": match.start(),
            "end": match.end(),
            "line_number": line_number,
        })

    return results


# ══════════════════════════════════════════════════════════════════
# COMPONENT 2 — Copybook Library
# ══════════════════════════════════════════════════════════════════

def _ensure_copybook_dir():
    """Create copybook directory if it doesn't exist."""
    os.makedirs(COPYBOOK_DIR, exist_ok=True)


def _normalize_name(name: str) -> str:
    """Normalize copybook name: uppercase, no extension."""
    name = name.upper().strip()
    if name.endswith(".CPY"):
        name = name[:-4]
    return name


def _find_copybook_file(name: str, library: str = None) -> str:
    """Find copybook file path. Case-insensitive search.

    Returns absolute path or raises CopybookNotFoundError.
    """
    _ensure_copybook_dir()
    normalized = _normalize_name(name)

    # If library specified, look in subdirectory first
    if library:
        lib_dir = os.path.join(COPYBOOK_DIR, library.upper())
        if os.path.isdir(lib_dir):
            for fname in os.listdir(lib_dir):
                if _normalize_name(fname) == normalized:
                    return os.path.join(lib_dir, fname)

    # Search main directory
    for fname in os.listdir(COPYBOOK_DIR):
        fpath = os.path.join(COPYBOOK_DIR, fname)
        if os.path.isfile(fpath) and _normalize_name(fname) == normalized:
            return fpath

    raise CopybookNotFoundError(
        f"Copybook '{name}' not found in library"
        + (f" (library: {library})" if library else "")
    )


def store_copybook(name: str, content: str) -> str:
    """Save copybook to library. Returns normalized filename."""
    _ensure_copybook_dir()
    normalized = _normalize_name(name)
    filename = f"{normalized}.CPY"
    filepath = os.path.join(COPYBOOK_DIR, filename)
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)
    return filename


def load_copybook(name: str, library: str = None) -> str:
    """Load copybook content from library."""
    filepath = _find_copybook_file(name, library)
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()


def list_copybooks() -> list:
    """Return list of {name, size_bytes, modified} for all copybooks."""
    _ensure_copybook_dir()
    results = []
    for fname in sorted(os.listdir(COPYBOOK_DIR)):
        fpath = os.path.join(COPYBOOK_DIR, fname)
        if os.path.isfile(fpath):
            stat = os.stat(fpath)
            results.append({
                "name": _normalize_name(fname),
                "filename": fname,
                "size_bytes": stat.st_size,
                "modified": datetime.fromtimestamp(
                    stat.st_mtime, tz=timezone.utc
                ).isoformat(),
            })
    return results


def delete_copybook(name: str) -> bool:
    """Delete copybook from library. Returns True if it existed."""
    try:
        filepath = _find_copybook_file(name)
        os.remove(filepath)
        return True
    except CopybookNotFoundError:
        return False


def store_copybooks_from_zip(zip_bytes: bytes) -> list:
    """Extract .cpy files from ZIP archive, store each.

    Returns list of stored copybook names.
    """
    stored = []
    with zipfile.ZipFile(io.BytesIO(zip_bytes), "r") as zf:
        for info in zf.infolist():
            if info.is_dir():
                continue
            fname = os.path.basename(info.filename)
            if fname.upper().endswith(".CPY"):
                content = zf.read(info.filename).decode("utf-8")
                name = _normalize_name(fname)
                store_copybook(name, content)
                stored.append(name)
    return stored


# ══════════════════════════════════════════════════════════════════
# COMPONENT 3 — Source Preprocessor
# ══════════════════════════════════════════════════════════════════

def _apply_replacing(content: str, replacing: list) -> str:
    """Apply REPLACING substitutions to copybook content.

    Args:
        content: Copybook source text
        replacing: List of (old_text, new_text[, mode]) tuples.
            mode is None for exact, 'LEADING' for prefix, 'TRAILING' for suffix.
    """
    for item in replacing:
        if len(item) == 3:
            old_text, new_text, mode = item
        else:
            old_text, new_text = item
            mode = None
        if mode == "LEADING":
            # Match at start of identifier (no alphanumeric/hyphen before)
            pattern = r'(?<![A-Za-z0-9\-])' + re.escape(old_text)
            content = re.sub(pattern, new_text, content, flags=re.IGNORECASE)
        elif mode == "TRAILING":
            # Match at end of identifier (no alphanumeric/hyphen after)
            pattern = re.escape(old_text) + r'(?![A-Za-z0-9\-])'
            content = re.sub(pattern, new_text, content, flags=re.IGNORECASE)
        else:
            pattern = r'(?<![A-Za-z0-9\-])' + re.escape(old_text) + r'(?![A-Za-z0-9])'
            content = re.sub(pattern, new_text, content, flags=re.IGNORECASE)
    return content


def preprocess_source(source: str, depth: int = 0, seen: set = None, inline_copybooks: dict = None) -> tuple:
    """Expand all COPY statements in COBOL source.

    Args:
        source: COBOL source text
        depth: Current recursion depth (for circular detection)
        seen: Set of already-included copybook names (for circular detection)

    Returns:
        (expanded_source, issues_list)
    """
    if seen is None:
        seen = set()

    if depth > MAX_COPY_DEPTH:
        return source, [f"Maximum COPY depth ({MAX_COPY_DEPTH}) exceeded"]

    issues = []
    copy_stmts = detect_copy_statements(source)

    if not copy_stmts:
        return source, issues

    # Process in reverse order so positions remain valid
    result = source
    for stmt in reversed(copy_stmts):
        name = stmt["name"]

        # Circular inclusion check
        if name in seen:
            issues.append(f"Circular COPY detected: {name}")
            replacement = f"      * MANUAL REVIEW: Circular COPY {name} skipped"
            result = result[:stmt["start"]] + replacement + result[stmt["end"]:]
            continue

        # Check inline copybooks first, then disk
        _norm = _normalize_name(name)
        content = None
        if inline_copybooks:
            content = inline_copybooks.get(name) or inline_copybooks.get(_norm)
        if content is None:
            try:
                content = load_copybook(name, stmt["library"])
            except CopybookNotFoundError:
                issues.append(f"COPY {name} not found in library")
                replacement = f"      * MANUAL REVIEW: COPY {name} not resolved"
                result = result[:stmt["start"]] + replacement + result[stmt["end"]:]
                continue

        # Apply REPLACING if present
        if stmt["replacing"]:
            content = _apply_replacing(content, stmt["replacing"])

        # Recursively expand nested COPY statements
        new_seen = seen | {name}
        content, nested_issues = preprocess_source(content, depth + 1, new_seen, inline_copybooks)
        issues.extend(nested_issues)

        result = result[:stmt["start"]] + content + result[stmt["end"]:]

    return result, issues


# ══════════════════════════════════════════════════════════════════
# COMPONENT 4 — REDEFINES Resolver
# ══════════════════════════════════════════════════════════════════

# Matches: level-number NAME REDEFINES TARGET
# Note: \s* between tokens because ANTLR getText() strips spaces
# Lookahead stops target name before PIC/VALUE/COMP/period
REDEFINES_PATTERN = re.compile(
    r'(\d{2})\s*([A-Z][A-Z0-9\-]+?)\s*REDEFINES\s*([A-Z][A-Z0-9\-]+?)(?=PIC|VALUE|COMP|OCCURS|\.|\s)',
    re.IGNORECASE
)


def _pic_byte_length(pic_raw: str, is_comp3: bool = False,
                     is_comp: bool = False) -> int:
    """Calculate byte length from PIC clause.

    X(10) → 10
    9(5)V99 → 7 (display numeric)
    S9(9)V99 COMP-3 → 6 (packed decimal: ceil((9+2+1)/2))
    S9(5) COMP → 2 (halfword), S9(9) COMP → 4 (fullword)
    A(20) → 20
    """
    if not pic_raw:
        return 0

    upper = pic_raw.upper().strip()

    # Alphanumeric: X(n) or A(n)
    for char_type in ("X", "A"):
        if char_type in upper:
            m = re.search(rf'{char_type}\((\d+)\)', upper)
            if m:
                return int(m.group(1))
            return upper.count(char_type)

    # Numeric: count total digit positions
    total_digits = 0
    has_sign = upper.startswith("S")

    # Count 9s (both 9 and 9(n) forms)
    for m in re.finditer(r'9(?:\((\d+)\))?', upper):
        if m.group(1):
            total_digits += int(m.group(1))
        else:
            total_digits += 1

    if is_comp3:
        # COMP-3 packed decimal: ceil((total_digits + 1) / 2)
        # +1 for the sign nibble (always present in packed)
        return (total_digits + 1 + 1) // 2
    elif is_comp:
        # COMP/COMP-4 binary: halfword/fullword/doubleword
        if total_digits <= 4:
            return 2
        elif total_digits <= 9:
            return 4
        else:
            return 8
    else:
        # Display numeric: sign + digits
        return total_digits + (1 if has_sign else 0)


def resolve_redefines(variables: list) -> dict:
    """Analyze REDEFINES relationships in variable list.

    Args:
        variables: List of variable dicts from cobol_analyzer_api
                   Each has: raw, name, pic_raw, pic_info, comp3,
                   storage_type (optional)

    Returns:
        {
            "memory_map": [...],
            "redefines_groups": [...],
            "ambiguous_references": [...],
        }
    """
    memory_map = []
    redefines_groups = {}  # base_name → [overlay_names]
    name_to_entry = {}     # name → memory_map entry
    filler_counter = 0     # Unique FILLER naming

    current_offset = 0

    # First pass: extract level numbers and build entries
    entries_with_levels = []
    for var in variables:
        raw = var.get("raw", "")
        name = var.get("name")
        pic_raw = var.get("pic_raw", "")
        is_comp3 = var.get("comp3", False)
        storage_type = var.get("storage_type", "DISPLAY")
        is_comp = storage_type == "COMP"

        # Handle FILLER: assign unique names for offset tracking
        if name and name.upper() == "FILLER":
            filler_counter += 1
            name = f"FILLER-{filler_counter}"

        if not name:
            continue

        # Extract level number from raw text
        level_match = re.match(r'^(\d{2})', raw.upper())
        level = int(level_match.group(1)) if level_match else 0

        byte_length = _pic_byte_length(pic_raw, is_comp3, is_comp)

        entries_with_levels.append({
            "name": name.upper(),
            "level": level,
            "pic_raw": pic_raw,
            "byte_length": byte_length,
            "raw": raw,
            "storage_type": storage_type,
        })

    # Second pass: compute group item byte lengths (sum of children)
    for idx, entry in enumerate(entries_with_levels):
        if entry["pic_raw"] or entry["level"] == 88:
            continue  # Has PIC or is condition — not a group
        # Group item: sum children's byte lengths
        group_size = 0
        for j in range(idx + 1, len(entries_with_levels)):
            child = entries_with_levels[j]
            if child["level"] <= entry["level"]:
                break  # End of group
            if child["level"] == 88:
                continue  # Skip conditions
            if child["pic_raw"]:
                group_size += child["byte_length"]
        entry["byte_length"] = group_size

    # Third pass: assign offsets and detect REDEFINES
    for entry in entries_with_levels:
        name = entry["name"]
        byte_length = entry["byte_length"]
        raw = entry["raw"]
        pic_raw = entry["pic_raw"]
        storage_type = entry["storage_type"]

        redef_match = REDEFINES_PATTERN.search(raw)

        if redef_match:
            redefines_target = redef_match.group(3).upper()
            target_entry = name_to_entry.get(redefines_target)
            if target_entry is None:
                raise ValueError(
                    f"REDEFINES target '{redefines_target}' not found "
                    f"(forward references are not allowed in standard COBOL)"
                )
            offset = target_entry["offset"]

            map_entry = {
                "name": name,
                "offset": offset,
                "length": byte_length,
                "type": pic_raw,
                "storage_type": storage_type,
                "redefines": redefines_target,
            }
            memory_map.append(map_entry)
            name_to_entry[name] = map_entry

            if redefines_target not in redefines_groups:
                redefines_groups[redefines_target] = []
            redefines_groups[redefines_target].append(name)
        else:
            map_entry = {
                "name": name,
                "offset": current_offset,
                "length": byte_length,
                "type": pic_raw,
                "storage_type": storage_type,
            }
            memory_map.append(map_entry)
            name_to_entry[name] = map_entry
            current_offset += byte_length

    # Detect ambiguous references: variables in REDEFINES groups
    # where base and overlay have different types (e.g., X vs 9)
    ambiguous = []
    for base, overlays in redefines_groups.items():
        base_entry = name_to_entry.get(base)
        if not base_entry:
            continue
        base_is_string = "X" in base_entry.get("type", "").upper() or \
                         "A" in base_entry.get("type", "").upper()
        for overlay_name in overlays:
            overlay_entry = name_to_entry.get(overlay_name)
            if not overlay_entry:
                continue
            overlay_is_string = "X" in overlay_entry.get("type", "").upper() or \
                                "A" in overlay_entry.get("type", "").upper()
            if base_is_string != overlay_is_string:
                ambiguous.append({
                    "base": base,
                    "overlay": overlay_name,
                    "base_type": base_entry["type"],
                    "overlay_type": overlay_entry["type"],
                    "reason": "Type mismatch in REDEFINES (string vs numeric)",
                })

    return {
        "memory_map": memory_map,
        "redefines_groups": [
            {"base": base, "overlays": overlays}
            for base, overlays in redefines_groups.items()
        ],
        "ambiguous_references": ambiguous,
    }


# ══════════════════════════════════════════════════════════════════
# COMPONENT 6 — FastAPI Endpoints
# ══════════════════════════════════════════════════════════════════

try:
    from fastapi import APIRouter, Depends, Header, HTTPException, UploadFile, File
    from fastapi.responses import JSONResponse
    from pydantic import BaseModel
    FASTAPI_AVAILABLE = True
except ImportError:
    FASTAPI_AVAILABLE = False

if FASTAPI_AVAILABLE:

    copybook_router = APIRouter()

    async def _copybook_auth(authorization: str = Header(None)) -> str:
        """Proxy to core_logic.verify_token, imported lazily."""
        from core_logic import verify_token
        return await verify_token(authorization)

    class PreprocessRequest(BaseModel):
        source: str
        copybooks: dict[str, str] | None = None  # {name: content} inline copybooks

    @copybook_router.post("/upload")
    async def upload_copybook(
        file: UploadFile = File(...),
        username: str = None,
        auth: str = Depends(_copybook_auth),
    ):
        """Upload a single copybook (.cpy) file."""
        content = await file.read()
        text = content.decode("utf-8")
        name = _normalize_name(file.filename or "UNKNOWN")
        filename = store_copybook(name, text)
        return {"status": "stored", "name": name, "filename": filename}

    @copybook_router.post("/upload-zip")
    async def upload_copybook_zip(
        file: UploadFile = File(...),
        username: str = None,
        auth: str = Depends(_copybook_auth),
    ):
        """Upload a ZIP archive containing copybook files."""
        content = await file.read()
        stored = store_copybooks_from_zip(content)
        return {"status": "stored", "count": len(stored), "copybooks": stored}

    @copybook_router.get("/list")
    async def list_copybooks_endpoint(auth: str = Depends(_copybook_auth)):
        """List all copybooks in the library."""
        return {"copybooks": list_copybooks()}

    @copybook_router.delete("/{name}")
    async def delete_copybook_endpoint(name: str, auth: str = Depends(_copybook_auth)):
        """Delete a copybook from the library."""
        existed = delete_copybook(name)
        if not existed:
            raise HTTPException(status_code=404, detail=f"Copybook '{name}' not found")
        return {"status": "deleted", "name": name.upper()}

    @copybook_router.get("/{name}")
    async def get_copybook(name: str, auth: str = Depends(_copybook_auth)):
        """Get copybook content."""
        try:
            content = load_copybook(name)
            return {"name": _normalize_name(name), "content": content}
        except CopybookNotFoundError:
            raise HTTPException(status_code=404, detail=f"Copybook '{name}' not found")

    @copybook_router.post("/preprocess")
    async def preprocess_endpoint(request: PreprocessRequest, auth: str = Depends(_copybook_auth)):
        """Preprocess COBOL source — expand all COPY statements."""
        expanded, issues = preprocess_source(request.source, inline_copybooks=request.copybooks)
        return {
            "expanded_source": expanded,
            "issues": issues,
            "copy_statements_found": len(detect_copy_statements(request.source)),
        }
