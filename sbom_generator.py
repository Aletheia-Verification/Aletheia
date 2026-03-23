"""sbom_generator.py — CycloneDX 1.4 SBOM Generator for COBOL Program Analysis.

Consumes Aletheia analysis output (program name, copybooks, CALLed subprograms,
EXEC SQL dependencies, dead code report) and emits a valid CycloneDX 1.4 JSON
Software Bill of Materials.

Public API:
    generate_sbom(analysis_result, timestamp=None) -> dict
    validate_sbom(sbom) -> bool
"""

import json
import re
import uuid
from datetime import datetime, timezone


ALETHEIA_VERSION = "3.2.0"

_NAMESPACE = uuid.NAMESPACE_URL

# SQL keywords that should never be treated as table names
_SQL_KEYWORD_BLACKLIST = frozenset({
    "WHERE", "SET", "VALUES", "SELECT", "FROM", "JOIN", "ON", "AND", "OR",
    "NOT", "NULL", "INTO", "AS", "IN", "IS", "BY", "ORDER", "GROUP",
    "HAVING", "UNION", "ALL", "DISTINCT", "BETWEEN", "LIKE", "EXISTS",
    "CASE", "WHEN", "THEN", "ELSE", "END", "WITH", "INNER", "LEFT",
    "RIGHT", "OUTER", "CROSS", "NATURAL", "USING", "LIMIT", "OFFSET",
    "FETCH", "FOR", "UPDATE", "DELETE", "INSERT", "CREATE", "DROP",
    "ALTER", "TABLE", "INDEX", "VIEW", "CURSOR", "DECLARE", "OPEN",
    "CLOSE", "COMMIT", "ROLLBACK", "INCLUDE",
})

# Patterns to extract table names from SQL body_preview
_FROM_TABLE = re.compile(r'\bFROM\s+([A-Z][A-Z0-9_.\-]*)', re.IGNORECASE)
_INTO_TABLE = re.compile(r'\bINTO\s+([A-Z][A-Z0-9_.\-]*)', re.IGNORECASE)
_UPDATE_TABLE = re.compile(r'\bUPDATE\s+([A-Z][A-Z0-9_.\-]*)', re.IGNORECASE)
_DELETE_TABLE = re.compile(r'\bDELETE\s+FROM\s+([A-Z][A-Z0-9_.\-]*)', re.IGNORECASE)


def _extract_db2_tables(exec_deps: list) -> list:
    """Extract unique DB2 table names from EXEC SQL dependencies.

    Filters out SQL keywords and common false positives.
    """
    tables = set()
    for dep in exec_deps:
        if dep.get("type") != "EXEC SQL":
            continue
        body = dep.get("body_preview", "")
        verb = dep.get("verb", "").upper()

        if verb == "SELECT":
            for m in _FROM_TABLE.finditer(body):
                tables.add(m.group(1).upper())
        elif verb == "INSERT":
            for m in _INTO_TABLE.finditer(body):
                tables.add(m.group(1).upper())
        elif verb == "UPDATE":
            for m in _UPDATE_TABLE.finditer(body):
                tables.add(m.group(1).upper())
        elif verb == "DELETE":
            for m in _DELETE_TABLE.finditer(body):
                tables.add(m.group(1).upper())

    return sorted(t for t in tables if t not in _SQL_KEYWORD_BLACKLIST)


def generate_sbom(analysis_result: dict, timestamp: datetime = None) -> dict:
    """Generate a CycloneDX 1.4 SBOM from Aletheia analysis output.

    Args:
        analysis_result: dict with keys:
            program_name (str), copybooks (list[str]), calls (list[dict]),
            exec_dependencies (list[dict]), dead_code (dict)
        timestamp: optional datetime for deterministic output (defaults to utcnow)

    Returns:
        JSON-serializable dict conforming to CycloneDX 1.4 spec.
    """
    if timestamp is None:
        timestamp = datetime.now(timezone.utc)

    program_name = analysis_result.get("program_name", "UNKNOWN")
    copybooks = analysis_result.get("copybooks", [])
    calls = analysis_result.get("calls", [])
    exec_deps = analysis_result.get("exec_dependencies", [])
    dead_code = analysis_result.get("dead_code", {})

    # ── Build components ──────────────────────────────────────────
    components = []

    for cb in sorted(copybooks):
        ref = f"copybook-{cb.lower()}"
        components.append({
            "type": "library",
            "bom-ref": ref,
            "group": "copybook",
            "name": cb,
            "purl": f"pkg:cobol-copybook/{cb}",
        })

    static_calls = sorted(
        {c["target"] for c in calls if c.get("type") == "static"},
    )
    for target in static_calls:
        ref = f"subprogram-{target.lower()}"
        components.append({
            "type": "library",
            "bom-ref": ref,
            "group": "subprogram",
            "name": target,
            "purl": f"pkg:cobol-subprogram/{target}",
        })

    db2_tables = _extract_db2_tables(exec_deps)
    for table in db2_tables:
        ref = f"db2-table-{table.lower()}"
        components.append({
            "type": "data",
            "bom-ref": ref,
            "group": "db2-table",
            "name": table,
        })

    # ── Deterministic serialNumber (FIX 1) ────────────────────────
    component_names = sorted(c["name"] for c in components)
    unreachable = dead_code.get("unreachable_paragraphs", [])
    dead_paragraph_names = sorted(
        p["name"] for p in unreachable
    ) if unreachable else []
    serial_seed = (
        program_name + "|"
        + ",".join(sorted(component_names)) + "|"
        + ",".join(sorted(dead_paragraph_names))
    )
    serial_number = f"urn:uuid:{uuid.uuid5(_NAMESPACE, serial_seed)}"

    # ── Main program component + properties ───────────────────────
    main_ref = f"program-{program_name.lower()}"
    main_properties = []

    if unreachable:
        main_properties.append({
            "name": "aletheia:dead_code",
            "value": "true",
        })
        main_properties.append({
            "name": "aletheia:dead_percentage",
            "value": str(dead_code.get("dead_percentage", 0.0)),
        })
        dead_names = ",".join(p["name"] for p in unreachable)
        main_properties.append({
            "name": "aletheia:dead_paragraphs",
            "value": dead_names,
        })

    # FIX 3 — Dynamic calls leave a trace
    has_dynamic = any(c.get("type") == "dynamic" for c in calls)
    if has_dynamic:
        main_properties.append({
            "name": "aletheia:dynamic_calls",
            "value": "true",
        })
        main_properties.append({
            "name": "aletheia:dynamic_calls_note",
            "value": "dependency list may be incomplete",
        })

    # DB2 extraction marker when EXEC SQL dependencies exist
    if exec_deps:
        main_properties.append({
            "name": "aletheia:db2_extraction",
            "value": "partial_preview_only",
        })

    main_component = {
        "type": "application",
        "bom-ref": main_ref,
        "name": program_name,
    }
    if main_properties:
        main_component["properties"] = main_properties

    # ── Dependencies ──────────────────────────────────────────────
    dependencies = [{
        "ref": main_ref,
        "dependsOn": [c["bom-ref"] for c in components],
    }]

    # ── Assemble SBOM ─────────────────────────────────────────────
    sbom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.4",
        "version": 1,
        "serialNumber": serial_number,
        "metadata": {
            "timestamp": timestamp.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "tools": [{
                "vendor": "Aletheia",
                "name": "Aletheia Behavioral Verification Engine",
                "version": ALETHEIA_VERSION,
            }],
            "component": main_component,
        },
        "components": components,
        "dependencies": dependencies,
    }

    return sbom


def validate_sbom(sbom: dict) -> bool:
    """Validate a CycloneDX 1.4 SBOM dict against structural rules.

    Checks required keys, types, component shapes, and dependency shapes.
    No external schema download needed — hardcoded structural validation.

    Returns True if valid, False otherwise.
    """
    # Top-level required keys
    required_top = {"bomFormat", "specVersion", "version", "serialNumber",
                    "metadata", "components", "dependencies"}
    if not required_top.issubset(sbom.keys()):
        return False

    # FIX 4 — bomFormat value must be "CycloneDX"
    if sbom.get("bomFormat") != "CycloneDX":
        return False

    if sbom.get("specVersion") != "1.4":
        return False

    if not isinstance(sbom.get("version"), int):
        return False

    if not isinstance(sbom.get("serialNumber"), str):
        return False

    # Metadata
    meta = sbom.get("metadata")
    if not isinstance(meta, dict):
        return False
    if "timestamp" not in meta:
        return False

    # Components
    components = sbom.get("components")
    if not isinstance(components, list):
        return False
    for comp in components:
        if not isinstance(comp, dict):
            return False
        if "type" not in comp or "name" not in comp or "bom-ref" not in comp:
            return False

    # Dependencies
    deps = sbom.get("dependencies")
    if not isinstance(deps, list):
        return False
    for dep in deps:
        if not isinstance(dep, dict):
            return False
        if "ref" not in dep:
            return False
        if not isinstance(dep.get("dependsOn"), list):
            return False

    return True
