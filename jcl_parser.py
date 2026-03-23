"""jcl_parser.py — IBM JCL Parser → Job Step DAG.

Parses JOB, EXEC, and DD statements from IBM JCL text and builds a
directed acyclic graph of job steps with dataset flow analysis.

Public API:
    parse_jcl(text) -> JobDAG
"""

import re
from dataclasses import dataclass, field


# ══════════════════════════════════════════════════════════════════════
# Data Classes
# ══════════════════════════════════════════════════════════════════════


@dataclass
class DDStatement:
    name: str
    dsn: str | None = None
    disp: tuple | None = None
    is_instream: bool = False
    instream_data: str = ""
    sysout: str | None = None


@dataclass
class JobStep:
    name: str
    program: str | None = None
    proc: str | None = None
    dd_statements: list = field(default_factory=list)
    cond: str | None = None
    line_number: int = 0


@dataclass
class JobDAG:
    job_name: str
    steps: list = field(default_factory=list)
    datasets: dict = field(default_factory=dict)
    dependencies: list = field(default_factory=list)

    def summary(self) -> str:
        """Human-readable summary of the job, its steps, and dataset flow."""
        lines = [f"JOB: {self.job_name}"]

        for step in self.steps:
            target = f"PGM={step.program}" if step.program else f"PROC={step.proc}"
            dd_parts = []
            for dd in step.dd_statements:
                if dd.dsn:
                    dd_parts.append(f"{dd.name}({dd.dsn})")
                elif dd.sysout:
                    dd_parts.append(f"{dd.name}(SYSOUT={dd.sysout})")
            dd_info = f"  [{', '.join(dd_parts)}]" if dd_parts else ""
            cond_info = f"  COND={step.cond}" if step.cond else ""
            lines.append(f"  {step.name} -> {target}{dd_info}{cond_info}")

        # Dataset flow
        creates_map = {}  # DSN → step that creates it
        reads_map = {}    # DSN → [steps that read it]
        _CREATES = {"NEW", "MOD"}
        _READS = {"SHR", "OLD"}

        for step in self.steps:
            for dd in step.dd_statements:
                if not dd.dsn:
                    continue
                if dd.disp and dd.disp[0] in _CREATES:
                    creates_map[dd.dsn] = step.name
                elif dd.disp and dd.disp[0] in _READS:
                    reads_map.setdefault(dd.dsn, []).append(step.name)

        flow_lines = []
        for dsn, creator in sorted(creates_map.items()):
            readers = reads_map.get(dsn, [])
            if readers:
                reader_str = ", ".join(readers)
                flow_lines.append(f"  {dsn}: {creator} (creates) -> {reader_str} (reads)")

        if flow_lines:
            lines.append("")
            lines.append("DATASET FLOW:")
            lines.extend(flow_lines)

        # Dependencies
        if self.dependencies:
            lines.append("")
            lines.append("DEPENDENCIES:")
            chain_parts = []
            seen = set()
            for src, dst in self.dependencies:
                if src not in seen:
                    chain_parts.append(src)
                    seen.add(src)
                if dst not in seen:
                    chain_parts.append(dst)
                    seen.add(dst)
            if chain_parts:
                lines.append("  " + " -> ".join(chain_parts))

        return "\n".join(lines)


# ══════════════════════════════════════════════════════════════════════
# Regex Patterns
# ══════════════════════════════════════════════════════════════════════

_JOB_RE = re.compile(r'^//([A-Z][A-Z0-9@#$]{0,7})\s+JOB\b', re.IGNORECASE)
_EXEC_RE = re.compile(r'^//([A-Z0-9@#$]*)\s+EXEC\s+(.*)', re.IGNORECASE)
_DD_RE = re.compile(r'^//([A-Z][A-Z0-9@#$.]{0,7})\s+DD\s+(.*)', re.IGNORECASE)
_DD_STAR_RE = re.compile(r'^//([A-Z][A-Z0-9@#$.]{0,7})\s+DD\s+\*', re.IGNORECASE)
_PGM_RE = re.compile(r'PGM=([A-Z0-9@#$]+)', re.IGNORECASE)
_PROC_EXPLICIT_RE = re.compile(r'PROC=([A-Z0-9@#$]+)', re.IGNORECASE)
_BARE_PROC_RE = re.compile(r'^([A-Z][A-Z0-9@#$]{0,7})$', re.IGNORECASE)
_DSN_RE = re.compile(r'DSN=([^\s,]+)', re.IGNORECASE)
_DISP_PAREN_RE = re.compile(r'DISP=\(([^)]*)\)', re.IGNORECASE)
_DISP_SIMPLE_RE = re.compile(r'DISP=([A-Z]+)', re.IGNORECASE)
_COND_PAREN_RE = re.compile(r'COND=\(([^)]*)\)', re.IGNORECASE)
_COND_SIMPLE_RE = re.compile(r'COND=([^,\s]+)', re.IGNORECASE)
_SYSOUT_RE = re.compile(r'SYSOUT=([A-Z*])', re.IGNORECASE)

# Disposition classification (FIX 2)
_CREATES = frozenset({"NEW", "MOD"})
_READS = frozenset({"SHR", "OLD"})


# ══════════════════════════════════════════════════════════════════════
# Continuation Handling (FIX 3)
# ══════════════════════════════════════════════════════════════════════


def _join_continuations(text: str) -> list:
    """Pre-join JCL continuation lines.

    Two continuation signals:
    1. Col 72 is non-blank → next line starts at col 16
    2. Operand field ends with a comma → next line starts at col 16
    """
    raw_lines = text.split("\n")
    result = []
    i = 0

    while i < len(raw_lines):
        line = raw_lines[i]

        # Skip non-JCL lines (don't start with //) and comment lines (//* )
        if not line.startswith("//") or line.startswith("//*"):
            result.append(line)
            i += 1
            continue

        # Check for continuation
        merged = line
        while i + 1 < len(raw_lines):
            needs_continuation = False

            # Signal 1: col 72 non-blank (line is at least 72 chars and col 72 is non-blank)
            if len(merged) >= 72 and merged[71:72].strip():
                needs_continuation = True

            # Signal 2: operand field ends with comma
            stripped = merged.rstrip()
            if stripped.endswith(","):
                needs_continuation = True

            if not needs_continuation:
                break

            next_line = raw_lines[i + 1]
            # Continuation lines start with // and content at col 16
            if next_line.startswith("//"):
                # Strip the // prefix and take content from col 16 onward
                if len(next_line) > 15:
                    cont_content = next_line[15:].lstrip()
                else:
                    cont_content = next_line[2:].lstrip()
                # Trim merged to col 71 if it was a col-72 continuation
                if len(merged) >= 72:
                    merged = merged[:71].rstrip()
                merged = merged.rstrip() + cont_content
            else:
                break
            i += 1

        result.append(merged)
        i += 1

    return result


# ══════════════════════════════════════════════════════════════════════
# Parsing Helpers
# ══════════════════════════════════════════════════════════════════════


def _parse_disp(operands: str) -> tuple | None:
    """Parse DISP= from DD operand string.

    Handles: DISP=(NEW,CATLG,DELETE), DISP=(OLD,DELETE), DISP=SHR, DISP=(,CATLG)
    Returns tuple of (status, normal_disp, abnormal_disp) or None.
    """
    m = _DISP_PAREN_RE.search(operands)
    if m:
        parts = [p.strip().upper() for p in m.group(1).split(",")]
        status = parts[0] if len(parts) > 0 else ""
        normal = parts[1] if len(parts) > 1 else ""
        abnormal = parts[2] if len(parts) > 2 else ""
        return (status, normal, abnormal)

    m = _DISP_SIMPLE_RE.search(operands)
    if m:
        val = m.group(1).upper()
        return (val, "", "")

    return None


def _parse_dd(dd_name: str, operands: str) -> DDStatement:
    """Parse a DD statement's operand field into a DDStatement."""
    dsn_m = _DSN_RE.search(operands)
    dsn = dsn_m.group(1) if dsn_m else None

    disp = _parse_disp(operands)

    sysout_m = _SYSOUT_RE.search(operands)
    sysout = sysout_m.group(1).upper() if sysout_m else None

    return DDStatement(
        name=dd_name.upper(),
        dsn=dsn,
        disp=disp,
        sysout=sysout,
    )


def _parse_exec(operands: str, step_name: str, line_number: int) -> JobStep:
    """Parse an EXEC statement's operand field into a JobStep.

    FIX 1: PROC detection uses strict logic:
    1. Try explicit PGM=
    2. Try explicit PROC=
    3. Only if neither found, try bare proc name (single token, max 8 chars)
    """
    program = None
    proc = None

    pgm_m = _PGM_RE.search(operands)
    if pgm_m:
        program = pgm_m.group(1).upper()
    else:
        proc_m = _PROC_EXPLICIT_RE.search(operands)
        if proc_m:
            proc = proc_m.group(1).upper()
        else:
            # Bare proc name: first token on the operand field, max 8 chars
            first_token = operands.split(",")[0].strip()
            bare_m = _BARE_PROC_RE.match(first_token)
            if bare_m:
                proc = bare_m.group(1).upper()

    cond = None
    cond_m = _COND_PAREN_RE.search(operands)
    if cond_m:
        cond = "(" + cond_m.group(1) + ")"
    else:
        cond_m = _COND_SIMPLE_RE.search(operands)
        if cond_m:
            cond = cond_m.group(1)

    return JobStep(
        name=step_name.upper() if step_name else f"STEP{line_number}",
        program=program,
        proc=proc,
        cond=cond,
        line_number=line_number,
    )


# ══════════════════════════════════════════════════════════════════════
# Main Parser
# ══════════════════════════════════════════════════════════════════════


def parse_jcl(text: str) -> JobDAG:
    """Parse JCL text into a JobDAG structure.

    Args:
        text: Raw JCL source text.

    Returns:
        JobDAG with steps, datasets, and dependencies.
    """
    lines = _join_continuations(text)
    job_name = "UNKNOWN"
    steps = []
    current_step = None

    i = 0
    while i < len(lines):
        line = lines[i]

        # Skip comments and blank lines
        if line.startswith("//*") or not line.strip():
            i += 1
            continue

        # JOB statement
        job_m = _JOB_RE.match(line)
        if job_m:
            job_name = job_m.group(1).upper()
            i += 1
            continue

        # EXEC statement
        exec_m = _EXEC_RE.match(line)
        if exec_m:
            step_name = exec_m.group(1)
            operands = exec_m.group(2)
            current_step = _parse_exec(operands, step_name, i + 1)
            steps.append(current_step)
            i += 1
            continue

        # DD * (inline data) — must check before general DD
        star_m = _DD_STAR_RE.match(line)
        if star_m and current_step is not None:
            dd_name = star_m.group(1)
            # Collect instream data until /* or next // statement
            instream_lines = []
            i += 1
            while i < len(lines):
                data_line = lines[i]
                if data_line.strip() == "/*" or data_line.startswith("//"):
                    if data_line.strip() == "/*":
                        i += 1  # consume the delimiter
                    break
                instream_lines.append(data_line)
                i += 1
            dd = DDStatement(
                name=dd_name.upper(),
                is_instream=True,
                instream_data="\n".join(instream_lines),
            )
            current_step.dd_statements.append(dd)
            continue

        # DD statement (general)
        dd_m = _DD_RE.match(line)
        if dd_m and current_step is not None:
            dd_name = dd_m.group(1)
            operands = dd_m.group(2)
            dd = _parse_dd(dd_name, operands)
            current_step.dd_statements.append(dd)
            i += 1
            continue

        i += 1

    # ── Build datasets map ────────────────────────────────────────
    datasets = {}
    for step in steps:
        for dd in step.dd_statements:
            if dd.dsn:
                datasets.setdefault(dd.dsn, []).append(step.name)

    # ── Build dependencies ────────────────────────────────────────
    dependencies = []

    # Default sequential ordering
    for j in range(len(steps) - 1):
        dependencies.append((steps[j].name, steps[j + 1].name))

    # Dataset handoff edges (creator → reader)
    creates_map = {}  # DSN → step name
    for step in steps:
        for dd in step.dd_statements:
            if dd.dsn and dd.disp and dd.disp[0] in _CREATES:
                creates_map[dd.dsn] = step.name

    for step in steps:
        for dd in step.dd_statements:
            if dd.dsn and dd.disp and dd.disp[0] in _READS:
                creator = creates_map.get(dd.dsn)
                if creator and creator != step.name:
                    edge = (creator, step.name)
                    if edge not in dependencies:
                        dependencies.append(edge)

    # Deduplicate edges while preserving insertion order
    dependencies = list(dict.fromkeys(dependencies))

    return JobDAG(
        job_name=job_name,
        steps=steps,
        datasets=datasets,
        dependencies=dependencies,
    )
