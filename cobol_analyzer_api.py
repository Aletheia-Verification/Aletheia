import re
from decimal import Decimal
import networkx as nx
from antlr4 import CommonTokenStream, InputStream
from Cobol85Lexer import Cobol85Lexer
from Cobol85Parser import Cobol85Parser
from antlr4 import ParseTreeWalker
from Cobol85Listener import Cobol85Listener


# ── Numeric edited PIC detection ─────────────────────────────────

_EDIT_DIGIT_CHARS = frozenset('Z*$+-')


def _is_edited_pic(upper: str) -> bool:
    """Return True if PIC string contains numeric editing characters."""
    if any(c in upper for c in _EDIT_DIGIT_CHARS):
        return True
    if '.' in upper or ',' in upper:
        return True
    if ('B' in upper or '/' in upper) and '9' in upper:
        return True
    if upper.endswith('CR') or upper.endswith('DB'):
        return True
    return False


def _count_digit_positions(part):
    """Count digit positions: 9, Z, *, $, +, - each count as one."""
    return sum(
        int(m.group(1)) if m.group(1) else 1
        for m in re.finditer(r'[9Z*$+\-](?:\((\d+)\))?', part)
    )


def _parse_edited_pic(pic_raw, upper):
    """Parse a numeric edited PIC clause (Z, *, $, +, -, etc.)."""
    work = upper

    # Strip S prefix
    signed = work.startswith('S')
    if signed:
        work = work[1:]

    # Strip CR/DB suffix (implies signed)
    if work.endswith('CR') or work.endswith('DB'):
        signed = True
        work = work[:-2]

    # Floating +/- implies signed
    if not signed and ('+' in work or '-' in work):
        signed = True

    # Split at '.' (edited decimal point) or 'V' (implied decimal)
    if '.' in work:
        int_part, dec_part = work.split('.', 1)
    elif 'V' in work:
        int_part, dec_part = work.split('V', 1)
    else:
        int_part, dec_part = work, ''

    integers = _count_digit_positions(int_part)
    decimals = _count_digit_positions(dec_part) if dec_part else 0

    if integers == 0 and decimals == 0:
        return None

    max_str = '9' * integers + ('.' + '9' * decimals if decimals else '')
    max_val = Decimal(max_str) if integers > 0 else Decimal('0.' + '9' * decimals)

    return {
        "signed": signed,
        "integers": integers,
        "decimals": decimals,
        "p_leading": 0,
        "p_trailing": 0,
        "sign_position": "trailing",
        "sign_separate": False,
        "max_value": str(max_val),
        "min_value": str(-max_val if signed else Decimal('0')),
        "is_edited": True,
        "edit_pattern": pic_raw,
    }


def parse_pic_clause(pic_raw):
    """
    Parse a PIC clause string (from getText(), no spaces) into structured metadata.

    Examples:
        "S9(5)V99"   -> {signed:True,  integers:5,  decimals:2}
        "9(3)"       -> {signed:False, integers:3,  decimals:0}
        "S9(1)V9(8)" -> {signed:True,  integers:1,  decimals:8}
        "X(10)"      -> None  (string type)
        "PP999"      -> {integers:3, decimals:0, p_leading:2, p_trailing:0}
        "999PP"      -> {integers:3, decimals:0, p_leading:0, p_trailing:2}

    Returns dict or None (for string/unknown types).
    """
    upper = pic_raw.upper().strip()
    if not upper or 'X' in upper or 'A' in upper or 'N' in upper:
        return None  # Alphanumeric/Alphabetic/National — skip

    if _is_edited_pic(upper):
        return _parse_edited_pic(pic_raw, upper)

    signed = upper.startswith('S')
    if signed:
        upper = upper[1:]

    has_v = 'V' in upper
    int_part, dec_part = (upper.split('V', 1) if has_v else (upper, ''))

    def count_nines(part):
        return sum(
            int(m.group(1)) if m.group(1) else 1
            for m in re.finditer(r'9(?:\((\d+)\))?', part)
        )

    def count_p(part):
        return sum(
            int(m.group(1)) if m.group(1) else 1
            for m in re.finditer(r'P(?:\((\d+)\))?', part)
        )

    integers = count_nines(int_part)
    decimals = count_nines(dec_part) if dec_part else 0

    # PIC P scaling digits: implied decimal positions beyond stored digits
    p_leading = 0   # PIC PP999 or PIC 9VPP9 — extends decimal leftward
    p_trailing = 0  # PIC 999PP — extends integer rightward

    if has_v:
        # P in dec_part extends implied decimals: PIC 9V9PP or PIC VP(3)9
        p_leading = count_p(dec_part)
    elif 'P' in int_part:
        # No V: check if P is before or after 9 digits
        first_9 = int_part.find('9')
        first_p = int_part.find('P')
        if first_p >= 0 and (first_9 < 0 or first_p < first_9):
            # P before 9s: PIC PP999 (implied VPP999 — scale down)
            p_leading = count_p(int_part)
        elif first_p >= 0:
            # P after 9s: PIC 999PP (scale up)
            p_trailing = count_p(int_part)

    if integers == 0 and p_leading == 0 and p_trailing == 0:
        return None  # No digits at all — not a standard numeric

    max_str = '9' * integers + ('.' + '9' * decimals if decimals else '')
    max_val = Decimal(max_str) if integers > 0 else Decimal('0.' + '9' * decimals)
    return {
        "signed": signed,
        "integers": integers,
        "decimals": decimals,
        "p_leading": p_leading,
        "p_trailing": p_trailing,
        "sign_position": "trailing",
        "sign_separate": False,
        "max_value": str(max_val),
        "min_value": str(-max_val if signed else Decimal('0')),
        "is_edited": False,
    }


class FullAnalyzer(Cobol85Listener):
    def __init__(self):
        self.paragraphs = []
        self.sections = []
        self.variables = []
        self.performs = []
        self.computes = []
        self.conditions = []
        self.level_88s = []
        self.perform_varyings = []
        self.perform_times = []
        self.moves = []
        self.gotos = []
        self.stops = []
        self.exit_programs = []   # EXIT PROGRAM statements
        self.gobacks = []         # GOBACK statements
        self.evaluates = []
        self.arithmetics = []   # ADD, SUBTRACT, MULTIPLY, DIVIDE statements
        self.strings = []       # STRING statements
        self.unstrings = []     # UNSTRING statements
        self.inspects = []      # INSPECT statements
        self.initializes = []   # INITIALIZE statements
        self.displays = []      # DISPLAY statements
        self.perform_untils = []  # PERFORM ... UNTIL (without VARYING)
        self.sets = []          # SET condition-name TO TRUE statements
        self.file_descriptions = []  # FD entries: {name, line}
        self.file_controls = []      # SELECT: {file_name, text}
        self.file_operations = []    # OPEN/READ/WRITE/CLOSE: {verb, file_name|record_name, direction, paragraph, line, ...}
        self.file_statuses = []      # FILE STATUS IS: {file_name, status_variable}
        self._last_select_file = None  # tracks SELECT file name for FILE STATUS association
        self.sort_statements = []      # SORT statements
        self.sort_descriptions = []    # SD entries (sort work files)
        self.release_statements = []   # RELEASE statements (sort input)
        self.return_statements = []    # RETURN statements (sort output)
        self.search_statements = []    # SEARCH / SEARCH ALL statements
        self.call_statements = []      # CALL subprogram invocations
        self.cancel_statements = []    # CANCEL subprogram releases
        self.current_paragraph = None
        self.last_variable_name = None
        self.current_data_section = "WORKING"  # tracks WORKING vs LOCAL storage
        self.paragraph_lines = {}
        self.graph = nx.DiGraph()
        self.source_lines = []  # original source lines for getText() recovery
        self._parse_warnings = []
        self.accepts = []           # ACCEPT FROM DATE/TIME/DAY statements
        self.renames = []           # Level 66 RENAMES entries
        self._level_stack = []      # [(level, name)] — tracks group nesting for qualified names
        self.merge_statements = []  # MERGE statements
        self.program_ids = []       # PROGRAM-ID occurrences (>1 = nested)
        self.has_declaratives = False
        self.declarative_sections = []

    # ── PROGRAM-ID (nested program detection) ────────────────────

    def enterProgramIdParagraph(self, ctx):
        try:
            name = ctx.programName().getText() if ctx.programName() else "UNKNOWN"
            self.program_ids.append({
                "name": name,
                "line": ctx.start.line,
            })
        except Exception:
            pass

    # ── DECLARATIVES ──────────────────────────────────────────────

    def enterProcedureDeclaratives(self, ctx):
        self.has_declaratives = True

    def enterProcedureDeclarative(self, ctx):
        try:
            header = ctx.procedureSectionHeader()
            name = header.sectionName().getText() if header and header.sectionName() else "UNKNOWN"
            self.declarative_sections.append({
                "name": name,
                "line": ctx.start.line,
            })
        except Exception:
            pass

    # ── Paragraphs ───────────────────────────────────────────────

    def enterProcedureSection(self, ctx):
        try:
            name = ctx.procedureSectionHeader().sectionName().getText()
            self.sections.append(name)
        except Exception:
            pass

    def enterParagraph(self, ctx):
        name = ctx.paragraphName().getText()
        self.current_paragraph = name
        self.paragraphs.append(name)
        self.paragraph_lines[name] = ctx.start.line
        self.graph.add_node(name)

    # ── PERFORM ──────────────────────────────────────────────────

    def enterPerformStatement(self, ctx):
        if ctx.performProcedureStatement():
            proc = ctx.performProcedureStatement()
            if proc.procedureName():
                target = None
                for pn in proc.procedureName():
                    target = pn.getText()
                    self.performs.append({"from": self.current_paragraph, "to": target, "line": ctx.start.line, "statement": ctx.getText()})
                    self.graph.add_edge(self.current_paragraph, target)
                # Check for UNTIL or TIMES clause in procedure-level PERFORM
                if target and proc.performType():
                    pt = proc.performType()
                    if pt.performUntil():
                        until_ctx = pt.performUntil()
                        until_cond = until_ctx.condition().getText() if until_ctx.condition() else None
                        if until_cond:
                            self.perform_untils.append({
                                "paragraph": self.current_paragraph,
                                "target": target,
                                "until": until_cond,
                                "line": ctx.start.line,
                            })
                    elif pt.performTimes():
                        times_text = pt.performTimes().getText()  # e.g. "5TIMES"
                        count = times_text.upper().replace("TIMES", "").strip()
                        self.perform_times.append({
                            "paragraph": self.current_paragraph,
                            "target": target,
                            "count": count,
                            "line": ctx.start.line,
                            "statement": ctx.getText(),
                        })
        elif ctx.performInlineStatement():
            inl = ctx.performInlineStatement()
            pt = inl.performType() if inl else None
            if pt and pt.performTimes():
                times_text = pt.performTimes().getText()  # e.g. "3TIMES"
                count = times_text.upper().replace("TIMES", "").strip()
                self.perform_times.append({
                    "paragraph": self.current_paragraph,
                    "count": count,
                    "line": ctx.start.line,
                    "end_line": ctx.stop.line if ctx.stop else None,
                    "statement": ctx.getText(),
                })
            elif pt and pt.performUntil():
                until_ctx = pt.performUntil()
                until_cond = until_ctx.condition().getText() if until_ctx.condition() else None
                if until_cond:
                    self.perform_untils.append({
                        "paragraph": self.current_paragraph,
                        "target": None,
                        "until": until_cond,
                        "line": ctx.start.line,
                        "end_line": ctx.stop.line if ctx.stop else None,
                    })

    # ── PERFORM VARYING ──────────────────────────────────────────

    def enterPerformVaryingPhrase(self, ctx):
        try:
            varying_var = ctx.identifier().getText() if ctx.identifier() else None
            from_val = ctx.performFrom().getText() if ctx.performFrom() else None
            by_val = ctx.performBy().getText() if ctx.performBy() else None
            until_cond = ctx.performUntil().getText() if ctx.performUntil() else None

            # Strip keyword prefixes baked in by getText():
            # "FROM1" → "1", "BY1" → "1", "UNTILWS-I>5" → "WS-I>5"
            if from_val and from_val.upper().startswith("FROM"):
                from_val = from_val[4:]
            if by_val and by_val.upper().startswith("BY"):
                by_val = by_val[2:]
            if until_cond and until_cond.upper().startswith("UNTIL"):
                until_cond = until_cond[5:]

            # Detect paragraph-level PERFORM by walking up to performStatement
            target = None
            perform_ctx = ctx.parentCtx
            while perform_ctx and not hasattr(perform_ctx, 'performProcedureStatement'):
                perform_ctx = perform_ctx.parentCtx
            if perform_ctx and perform_ctx.performProcedureStatement():
                proc = perform_ctx.performProcedureStatement()
                if proc.procedureName():
                    target = proc.procedureName(0).getText()

            # For inline PERFORM VARYING, capture end_line from enclosing performStatement
            end_line = None
            if target is None and perform_ctx and hasattr(perform_ctx, 'stop') and perform_ctx.stop:
                end_line = perform_ctx.stop.line

            # Use parent performStatement's line (not VARYING keyword line)
            # so it matches the line recorded in self.performs
            perform_line = perform_ctx.start.line if perform_ctx and hasattr(perform_ctx, 'start') else ctx.start.line

            # Detect AFTER: parent of performVaryingPhrase inside an AFTER clause
            is_after = type(ctx.parentCtx).__name__ == "PerformAfterContext"

            # Detect WITH TEST AFTER (do-while semantics)
            test_after = False
            if perform_ctx:
                full_text = perform_ctx.getText().upper().replace(" ", "")
                test_after = "TESTAFTER" in full_text

            self.perform_varyings.append({
                "paragraph": self.current_paragraph,
                "variable": varying_var,
                "from": from_val,
                "by": by_val,
                "until": until_cond,
                "line": perform_line,
                "end_line": end_line,
                "target": target,
                "is_after": is_after,
                "test_after": test_after,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterPerformVaryingPhrase near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── COMPUTE ──────────────────────────────────────────────────

    @staticmethod
    def _extract_size_error(ctx):
        """Extract ON SIZE ERROR / NOT ON SIZE ERROR statement lists from an arithmetic ctx."""
        on_stmts = []
        not_on_stmts = []
        ose = ctx.onSizeErrorPhrase() if hasattr(ctx, 'onSizeErrorPhrase') else None
        nose = ctx.notOnSizeErrorPhrase() if hasattr(ctx, 'notOnSizeErrorPhrase') else None
        if ose:
            on_stmts = [s.getText() for s in (ose.statement() or [])]
        if nose:
            not_on_stmts = [s.getText() for s in (nose.statement() or [])]
        return on_stmts, not_on_stmts

    def enterComputeStatement(self, ctx):
        on_stmts, not_on_stmts = self._extract_size_error(ctx)
        self.computes.append({
            "paragraph": self.current_paragraph,
            "statement": ctx.getText(),
            "line": ctx.start.line,
            "on_size_error": on_stmts,
            "not_on_size_error": not_on_stmts,
        })

    # ── Standalone Arithmetic (ADD, SUBTRACT, MULTIPLY, DIVIDE) ──

    def _original_lines(self, ctx):
        """Extract original source text from source_lines using ctx line range."""
        if not self.source_lines:
            return ""
        start = ctx.start.line - 1
        stop = (ctx.stop.line if ctx.stop else ctx.start.line) - 1
        return " ".join(self.source_lines[start:stop + 1]).strip()

    def _fix_statement_text(self, stmt_ctx):
        """Fix getText() for known ANTLR grammar gaps (IBM extensions).

        MULTIPLY A BY <literal>: Format 1 only accepts identifiers after BY.
        IBM compilers allow literals. Recover from original source line.
        """
        text = stmt_ctx.getText()
        if text.upper().startswith("MULTIPLY") and text.upper().endswith("BY"):
            orig = self._original_lines(stmt_ctx)
            m = re.search(r'BY\s+(\d+\.?\d*)\s*$', orig, re.IGNORECASE)
            if m:
                text += m.group(1)
        return text

    def enterAddStatement(self, ctx):
        on_stmts, not_on_stmts = self._extract_size_error(ctx)
        self.arithmetics.append({
            "paragraph": self.current_paragraph,
            "verb": "ADD",
            "statement": ctx.getText(),
            "original": self._original_lines(ctx),
            "line": ctx.start.line,
            "on_size_error": on_stmts,
            "not_on_size_error": not_on_stmts,
        })

    def enterSubtractStatement(self, ctx):
        on_stmts, not_on_stmts = self._extract_size_error(ctx)
        self.arithmetics.append({
            "paragraph": self.current_paragraph,
            "verb": "SUBTRACT",
            "statement": ctx.getText(),
            "original": self._original_lines(ctx),
            "line": ctx.start.line,
            "on_size_error": on_stmts,
            "not_on_size_error": not_on_stmts,
        })

    def enterMultiplyStatement(self, ctx):
        on_stmts, not_on_stmts = self._extract_size_error(ctx)
        self.arithmetics.append({
            "paragraph": self.current_paragraph,
            "verb": "MULTIPLY",
            "statement": self._fix_statement_text(ctx),
            "original": self._original_lines(ctx),
            "line": ctx.start.line,
            "on_size_error": on_stmts,
            "not_on_size_error": not_on_stmts,
        })

    def enterDivideStatement(self, ctx):
        on_stmts, not_on_stmts = self._extract_size_error(ctx)
        self.arithmetics.append({
            "paragraph": self.current_paragraph,
            "verb": "DIVIDE",
            "statement": ctx.getText(),
            "original": self._original_lines(ctx),
            "line": ctx.start.line,
            "on_size_error": on_stmts,
            "not_on_size_error": not_on_stmts,
        })

    # ── MOVE ──────────────────────────────────────────────────────

    def enterMoveStatement(self, ctx):
        move_to = ctx.moveToStatement()
        move_corr = ctx.moveCorrespondingToStatement()

        if move_to:
            sending_area = move_to.moveToSendingArea()
            from_val = sending_area.getText() if sending_area else ""
            to_fields = [ident.getText() for ident in (move_to.identifier() or [])]
            self.moves.append({
                "paragraph": self.current_paragraph,
                "from": from_val,
                "to": to_fields,
                "corresponding": False,
                "statement": ctx.getText(),
                "line": ctx.start.line,
            })
        elif move_corr:
            sending_area = move_corr.moveCorrespondingToSendingArea()
            from_val = sending_area.getText() if sending_area else ""
            to_fields = [ident.getText() for ident in (move_corr.identifier() or [])]
            self.moves.append({
                "paragraph": self.current_paragraph,
                "from": from_val,
                "to": to_fields,
                "corresponding": True,
                "statement": ctx.getText(),
                "line": ctx.start.line,
            })

    # ── GO TO ────────────────────────────────────────────────────

    def enterGoToStatement(self, ctx):
        simple = ctx.goToStatementSimple()
        depending = ctx.goToDependingOnStatement()

        if simple:
            target = simple.procedureName().getText() if simple.procedureName() else ""
            self.gotos.append({
                "paragraph": self.current_paragraph,
                "targets": [target],
                "depending_on": None,
                "statement": ctx.getText(),
                "line": ctx.start.line,
            })
        elif depending:
            targets = [pn.getText() for pn in (depending.procedureName() or [])]
            dep_var = depending.identifier().getText() if depending.identifier() else None
            self.gotos.append({
                "paragraph": self.current_paragraph,
                "targets": targets,
                "depending_on": dep_var,
                "statement": ctx.getText(),
                "line": ctx.start.line,
            })

    # ── STOP ─────────────────────────────────────────────────────

    def enterStopStatement(self, ctx):
        self.stops.append({
            "paragraph": self.current_paragraph,
            "statement": ctx.getText(),
            "line": ctx.start.line,
        })

    # ── EXIT PROGRAM / GOBACK ───────────────────────────────────

    def enterExitStatement(self, ctx):
        # Only capture EXIT PROGRAM, not bare EXIT (paragraph exit)
        if ctx.PROGRAM():
            self.exit_programs.append({
                "paragraph": self.current_paragraph,
                "statement": ctx.getText(),
                "line": ctx.start.line,
            })

    def enterGobackStatement(self, ctx):
        self.gobacks.append({
            "paragraph": self.current_paragraph,
            "statement": ctx.getText(),
            "line": ctx.start.line,
        })

    # ── IF — structured AST walk ─────────────────────────────────

    def enterIfStatement(self, ctx):
        condition_text = ctx.condition().getText() if ctx.condition() else ""

        then_stmts = []
        if ctx.ifThen():
            for stmt in ctx.ifThen().statement():
                then_stmts.append(self._fix_statement_text(stmt))

        else_stmts = []
        if ctx.ifElse():
            for stmt in ctx.ifElse().statement():
                else_stmts.append(self._fix_statement_text(stmt))

        self.conditions.append({
            "paragraph": self.current_paragraph,
            "statement": ctx.getText(),
            "condition": condition_text,
            "then_statements": then_stmts,
            "else_statements": else_stmts,
            "has_nested_if": any("IF" in s.upper() for s in then_stmts + else_stmts),
            "line": ctx.start.line,
        })

    # ── EVALUATE ────────────────────────────────────────────────

    def enterEvaluateStatement(self, ctx):
        select_ctx = ctx.evaluateSelect()
        subject_text = select_ctx.getText() if select_ctx else ""

        # Extract ALSO subjects (parallel list)
        also_selects = ctx.evaluateAlsoSelect()
        has_also = len(also_selects) > 0
        also_subjects = []
        for also_sel in also_selects:
            sel = also_sel.evaluateSelect()
            also_subjects.append(sel.getText() if sel else "")

        when_clauses = []
        for phrase_ctx in ctx.evaluateWhenPhrase():
            conditions = []
            also_condition_values = []
            for when_ctx in phrase_ctx.evaluateWhen():
                cond_ctx = when_ctx.evaluateCondition()
                cond_text = cond_ctx.getText() if cond_ctx else ""
                # Extract ALSO conditions (parallel to conditions)
                also_conds = when_ctx.evaluateAlsoCondition()
                has_also = has_also or len(also_conds) > 0
                also_cond_texts = []
                for ac in also_conds:
                    ac_cond = ac.evaluateCondition()
                    also_cond_texts.append(ac_cond.getText() if ac_cond else "")
                # Append both in same iteration — indices MUST align
                conditions.append(cond_text)
                also_condition_values.append(also_cond_texts)

            body_stmts = [self._fix_statement_text(s) for s in phrase_ctx.statement()]
            when_clauses.append({
                "conditions": conditions,
                "also_conditions": also_condition_values,
                "body_statements": body_stmts,
            })

        when_other_stmts = []
        other_ctx = ctx.evaluateWhenOther()
        if other_ctx:
            when_other_stmts = [self._fix_statement_text(s) for s in other_ctx.statement()]

        self.evaluates.append({
            "paragraph": self.current_paragraph,
            "subject": subject_text,
            "has_also": has_also,
            "also_subjects": also_subjects,
            "when_clauses": when_clauses,
            "when_other_statements": when_other_stmts,
            "statement": ctx.getText(),
            "line": ctx.start.line,
        })

    # ── Data section tracking (WORKING-STORAGE vs LOCAL-STORAGE) ─

    def enterWorkingStorageSection(self, ctx):
        self.current_data_section = "WORKING"

    def enterLocalStorageSection(self, ctx):
        self.current_data_section = "LOCAL"

    # ── Variables (05-level) ─────────────────────────────────────

    def enterDataDescriptionEntryFormat1(self, ctx):
        text = ctx.getText()
        upper = text.upper()
        is_comp3 = "COMP-3" in upper or "COMPUTATIONAL-3" in upper or "PACKED-DECIMAL" in upper
        is_comp5 = ("COMP-5" in upper or "COMPUTATIONAL-5" in upper) and not is_comp3
        is_comp1 = ("COMP-1" in upper or "COMPUTATIONAL-1" in upper) and not is_comp3 and not is_comp5
        is_comp2 = ("COMP-2" in upper or "COMPUTATIONAL-2" in upper) and not is_comp3 and not is_comp5
        is_comp = ("COMP" in upper or "BINARY" in upper) and not is_comp3 and not is_comp1 and not is_comp2 and not is_comp5
        if is_comp3:
            storage_type = "COMP-3"
        elif is_comp5:
            storage_type = "COMP-5"
        elif is_comp1:
            storage_type = "COMP-1"
        elif is_comp2:
            storage_type = "COMP-2"
        elif is_comp:
            storage_type = "COMP"
        else:
            storage_type = "DISPLAY"

        # Extract variable name (lazy match stops before REDEFINES/PIC/VALUE/OCCURS/COMP/.)
        name_match = re.match(r'^\d{2}([A-Z][A-Z0-9\-]+?)(?:REDEFINES|PIC|VALUE|OCCURS|COMP|\.)', upper)
        name = name_match.group(1) if name_match else None
        if name:
            self.last_variable_name = name

        # Capture REDEFINES target (e.g. WS-DATE-STR REDEFINES WS-DATE-NUM)
        redefines_match = re.search(r'REDEFINES([A-Z][A-Z0-9\-]+?)(?:PIC|VALUE|OCCURS|COMP|\.)', upper)
        redefines_target = redefines_match.group(1) if redefines_match else None

        # Extract PIC clause (everything between PIC and the next keyword or statement end)
        # Includes edited PIC chars: Z, *, $, +, -, comma, period, B, 0, /
        pic_match = re.search(
            r'PIC([SX9ZVPA()\d*$+\-,./B]+?)(?=(?:COMP|VALUE|OCCURS|BLANK|JUSTIFIED|JUST|SIGN|GLOBAL|EXTERNAL|BINARY|PACKED-DECIMAL|DISPLAY|USAGE)|\.\s*$|\.(?:\s|$))',
            upper,
        )
        if not pic_match:
            # Fallback: simpler regex for common cases
            pic_match = re.search(r'PIC([SX9ZVP()\d]+?)(?=COMP|VALUE|OCCURS|\.)', upper)
        pic_raw = pic_match.group(1) if pic_match else ""
        pic_info = parse_pic_clause(pic_raw) if pic_raw else None

        # Detect OCCURS clause: try ODO (variable-length) first, then fixed
        odo_match = re.search(
            r'OCCURS\s*(\d+)\s*TO\s*(\d+)\s*(?:TIMES\s*)?DEPENDING\s*(?:ON)?\s*([A-Z][A-Z0-9\-]+?)(?:PIC|VALUE|ASCENDING|DESCENDING|INDEXED|COMP|\.)',
            upper
        )
        if odo_match:
            occurs_min = int(odo_match.group(1))
            occurs_max = int(odo_match.group(2))
            if occurs_min > occurs_max:
                occurs_min, occurs_max = occurs_max, occurs_min
            depending_on = odo_match.group(3).rstrip('.')
            # Validate COBOL identifier: starts with letter, contains letters/digits/hyphens
            if not re.match(r'^[A-Z][A-Z0-9\-]*$', depending_on):
                depending_on = None
            occurs_count = occurs_max  # allocate max capacity (IBM behavior)
        else:
            occurs_match = re.search(r'OCCURS\s*(\d+)', upper)
            occurs_count = int(occurs_match.group(1)) if occurs_match else 0
            occurs_min = 0
            occurs_max = 0
            depending_on = None

        # BLANK WHEN ZERO / JUSTIFIED RIGHT clauses
        no_spaces = upper.replace(" ", "")
        blank_when_zero = "BLANKWHENZERO" in no_spaces or "BLANKWHENZEROES" in no_spaces
        justified_right = "JUSTIFIEDRIGHT" in no_spaces or "JUSTRIGHT" in no_spaces

        # SIGN IS LEADING/TRAILING SEPARATE CHARACTER (IS is optional)
        sign_leading = "SIGNISLEADING" in no_spaces or "SIGNLEADING" in no_spaces
        sign_separate = "SEPARATE" in no_spaces
        sign_position = "leading" if sign_leading else "trailing"

        # GLOBAL / EXTERNAL clause detection
        is_global = "GLOBAL" in upper and name and name != "GLOBAL"
        is_external = "EXTERNAL" in upper and name and name != "EXTERNAL"

        # Extract level number and track parent group for qualified name resolution
        level_match = re.match(r'^(\d{2})', upper)
        level = int(level_match.group(1)) if level_match else 0

        # Pop stack until parent's level is strictly less than current
        while self._level_stack and self._level_stack[-1][0] >= level:
            self._level_stack.pop()

        parent_group = self._level_stack[-1][1] if self._level_stack else None

        # If this is a group item (no PIC, not 88-level), push onto stack
        if name and not pic_raw and level < 50:  # Groups are 01-49; exclude 66 (RENAMES), 77 (standalone), 88 (condition)
            self._level_stack.append((level, name))

        # Extract VALUE clause for non-88 variables
        initial_value = None
        try:
            dvc = ctx.dataValueClause()
            if dvc:
                val_text = dvc[0].getText() if isinstance(dvc, list) else dvc.getText()
                val_upper = val_text.upper()
                val_match = re.search(
                    r"VALUE\s*([-+]?(?:\d+(?:[.,]\d+)?|[.,]\d+)|'[^']*'|\"[^\"]*\"|ZEROS?|ZEROES|SPACES?|HIGH-VALUES?|LOW-VALUES?|QUOTES?|ALL\s*'[^']*')",
                    val_upper,
                )
                if val_match:
                    # Extract original-case value from the raw text
                    matched = val_match.group(1)
                    # For numeric literals, strip sign prefix
                    initial_value = matched.strip()
        except Exception:
            pass  # VALUE extraction is best-effort

        self.variables.append({
            "raw": text[:60],
            "name": name,
            "pic_raw": pic_raw,
            "pic_info": pic_info,
            "comp3": is_comp3,
            "comp1": is_comp1,
            "comp2": is_comp2,
            "storage_type": storage_type,
            "occurs": occurs_count,
            "occurs_min": occurs_min,
            "occurs_max": occurs_max,
            "depending_on": depending_on,
            "storage_section": self.current_data_section,
            "blank_when_zero": blank_when_zero,
            "justified_right": justified_right,
            "sign_position": sign_position,
            "sign_separate": sign_separate,
            "level": level,
            "parent_group": parent_group,
            "global_var": is_global,
            "external_var": is_external,
            "initial_value": initial_value,
            "redefines_target": redefines_target,
        })

    # ── 66-level RENAMES ────────────────────────────────────────

    def enterDataDescriptionEntryFormat2(self, ctx):
        """Detect level 66 RENAMES entries."""
        try:
            renames_name = ctx.dataName().getText() if ctx.dataName() else None
            renames_clause = ctx.dataRenamesClause()
            from_field = None
            thru_field = None
            if renames_clause:
                names = renames_clause.qualifiedDataName()
                from_field = names[0].getText() if len(names) > 0 else None
                thru_field = names[1].getText() if len(names) > 1 else None
            if renames_name and from_field:
                self.renames.append({
                    "name": renames_name,
                    "from_field": from_field,
                    "thru_field": thru_field,
                    "line": ctx.start.line,
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterDataDescriptionEntryFormat2 near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── 88-level conditions ──────────────────────────────────────

    def enterDataDescriptionEntryFormat3(self, ctx):
        try:
            cond_name = ctx.conditionName().getText() if ctx.conditionName() else None
            value_clause = ctx.dataValueClause().getText() if ctx.dataValueClause() else ""

            # Extract all values: VALUE 'A' 'B' 'C' or VALUE 1 THRU 5
            values = []
            thru = None
            vc_upper = value_clause.upper()

            # Strip leading VALUE/VALUES keyword
            vc_body = re.sub(r'^VALUE[S]?\s*', '', vc_upper).strip().rstrip(".")

            # Check for THRU/THROUGH pattern: VALUE x THRU y (ANTLR may strip spaces)
            thru_match = re.search(r'(.+?)(?:THRU|THROUGH)(.+)', vc_body, re.IGNORECASE)
            if thru_match:
                low = thru_match.group(1).strip().strip("'\"")
                high = thru_match.group(2).strip().strip("'\"")
                thru = {"low": low, "high": high}
                values = [low]
            else:
                # Extract all quoted strings: 'A' 'B' 'C'
                quoted = re.findall(r"'([^']*)'", value_clause)
                if quoted:
                    values = quoted
                else:
                    # Unquoted numeric values separated by whitespace
                    tokens = vc_body.split()
                    values = [t.strip(".") for t in tokens if t.strip(".")]

            # Backwards-compatible: keep "value" as first element
            value = values[0] if values else ""

            if cond_name:
                self.level_88s.append({
                    "name": cond_name,
                    "parent": self.last_variable_name or "UNKNOWN",
                    "value": value,
                    "values": values,
                    "thru": thru,
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterDataDescriptionEntryFormat3 near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── SET condition-name TO TRUE ────────────────────────────

    def enterSetStatement(self, ctx):
        try:
            text = ctx.getText().upper()
            # Only handle SET ... TO TRUE pattern
            if "TRUE" not in text:
                return
            for sto in (ctx.setToStatement() or []):
                # setTo targets (the condition names being set)
                targets = [t.getText() for t in (sto.setTo() or [])]
                # setToValue (should be TRUE)
                vals = [v.getText().upper() for v in (sto.setToValue() or [])]
                if "TRUE" in vals:
                    for t in targets:
                        self.sets.append({
                            "paragraph": self.current_paragraph,
                            "condition_name": t.upper(),
                            "statement": ctx.getText(),
                            "line": ctx.start.line,
                        })
        except Exception as e:
            self._parse_warnings.append(
                f"enterSetStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── FILE SECTION / FD / SELECT / OPEN / READ / WRITE ──────

    def enterFileDescriptionEntry(self, ctx):
        try:
            fn = ctx.fileName()
            name = fn.getText() if fn else None
            if name and ctx.FD():
                self.file_descriptions.append({
                    "name": name,
                    "line": ctx.start.line,
                })
            elif name and ctx.SD():
                self.sort_descriptions.append({
                    "name": name,
                    "line": ctx.start.line,
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterFileDescriptionEntry near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    def enterSelectClause(self, ctx):
        try:
            fn = ctx.fileName()
            name = fn.getText() if fn else None
            if name:
                self._last_select_file = name
                self.file_controls.append({
                    "file_name": name,
                    "text": ctx.getText(),
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterSelectClause near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    def enterFileStatusClause(self, ctx):
        try:
            qdn = ctx.qualifiedDataName(0)
            if qdn:
                status_var = qdn.getText()
                file_name = self._last_select_file
                self.file_statuses.append({
                    "file_name": file_name,
                    "status_variable": status_var,
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterFileStatusClause near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    def enterLinageClause(self, ctx):
        try:
            self._parse_warnings.append(
                f"LINAGE clause detected near line {ctx.start.line} — "
                f"complex print control not emitted"
            )
        except Exception:
            pass

    def enterOpenInput(self, ctx):
        try:
            fn = ctx.fileName()
            if fn:
                self.file_operations.append({
                    "verb": "OPEN",
                    "file_name": fn.getText(),
                    "direction": "INPUT",
                    "paragraph": self.current_paragraph,
                    "line": ctx.start.line,
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterOpenInput near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    def enterOpenOutput(self, ctx):
        try:
            fn = ctx.fileName()
            if fn:
                self.file_operations.append({
                    "verb": "OPEN",
                    "file_name": fn.getText(),
                    "direction": "OUTPUT",
                    "paragraph": self.current_paragraph,
                    "line": ctx.start.line,
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterOpenOutput near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    def enterOpenIOStatement(self, ctx):
        try:
            for fn in (ctx.fileName() or []):
                self.file_operations.append({
                    "verb": "OPEN",
                    "file_name": fn.getText(),
                    "direction": "IO",
                    "paragraph": self.current_paragraph,
                    "line": ctx.start.line,
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterOpenIOStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    def enterReadStatement(self, ctx):
        try:
            fn = ctx.fileName()
            if fn:
                into_target = None
                ri = ctx.readInto()
                if ri:
                    ident = ri.identifier()
                    if ident:
                        into_target = ident.getText()

                # KEY IS clause (indexed read)
                key_field = None
                rk = ctx.readKey()
                if rk:
                    qdn = rk.qualifiedDataName()
                    if qdn:
                        key_field = qdn.getText()

                at_end_stmts = []
                ae = ctx.atEndPhrase()
                if ae:
                    at_end_stmts = [s.getText() for s in (ae.statement() or [])]

                not_at_end_stmts = []
                nae = ctx.notAtEndPhrase()
                if nae:
                    not_at_end_stmts = [s.getText() for s in (nae.statement() or [])]

                # INVALID KEY / NOT INVALID KEY (indexed read)
                invalid_key_stmts = []
                ik = ctx.invalidKeyPhrase()
                if ik:
                    invalid_key_stmts = [s.getText() for s in (ik.statement() or [])]
                not_invalid_key_stmts = []
                nik = ctx.notInvalidKeyPhrase()
                if nik:
                    not_invalid_key_stmts = [s.getText() for s in (nik.statement() or [])]

                self.file_operations.append({
                    "verb": "READ",
                    "file_name": fn.getText(),
                    "direction": "INPUT",
                    "into": into_target,
                    "key_field": key_field,
                    "at_end": at_end_stmts,
                    "not_at_end": not_at_end_stmts,
                    "invalid_key": invalid_key_stmts,
                    "not_invalid_key": not_invalid_key_stmts,
                    "paragraph": self.current_paragraph,
                    "line": ctx.start.line,
                    "statement": ctx.getText(),
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterReadStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    def enterWriteStatement(self, ctx):
        try:
            rn = ctx.recordName()
            if rn:
                from_source = None
                wf = ctx.writeFromPhrase()
                if wf:
                    ident = wf.identifier()
                    if ident:
                        from_source = ident.getText()

                # Detect ADVANCING clause
                advancing = None
                advancing_type = None  # "BEFORE" or "AFTER"
                wa = ctx.writeAdvancingPhrase()
                if wa:
                    full = wa.getText().upper()
                    advancing_type = "BEFORE" if "BEFORE" in full else "AFTER"
                    if wa.writeAdvancingPage():
                        advancing = "PAGE"
                    elif wa.writeAdvancingLines():
                        lines_ctx = wa.writeAdvancingLines()
                        advancing = lines_ctx.identifier().getText() if lines_ctx.identifier() else (lines_ctx.literal().getText() if lines_ctx.literal() else "1")

                self.file_operations.append({
                    "verb": "WRITE",
                    "record_name": rn.getText(),
                    "from_source": from_source,
                    "advancing": advancing,
                    "advancing_type": advancing_type,
                    "direction": "OUTPUT",
                    "paragraph": self.current_paragraph,
                    "line": ctx.start.line,
                    "statement": ctx.getText(),
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterWriteStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    def enterCloseStatement(self, ctx):
        try:
            close_files = ctx.closeFile()
            if close_files:
                for cf in close_files:
                    fn = cf.fileName()
                    if fn:
                        self.file_operations.append({
                            "verb": "CLOSE",
                            "file_name": fn.getText(),
                            "direction": None,
                            "paragraph": self.current_paragraph,
                            "line": ctx.start.line,
                        })
        except Exception as e:
            self._parse_warnings.append(
                f"enterCloseStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── REWRITE ───────────────────────────────────────────────

    def enterRewriteStatement(self, ctx):
        try:
            rn = ctx.recordName()
            if rn:
                from_var = None
                if ctx.rewriteFrom():
                    ident = ctx.rewriteFrom().identifier()
                    if ident:
                        from_var = ident.getText()
                invalid_key_stmts = []
                ik = ctx.invalidKeyPhrase()
                if ik:
                    invalid_key_stmts = [s.getText() for s in (ik.statement() or [])]
                not_invalid_key_stmts = []
                nik = ctx.notInvalidKeyPhrase()
                if nik:
                    not_invalid_key_stmts = [s.getText() for s in (nik.statement() or [])]
                self.file_operations.append({
                    "verb": "REWRITE",
                    "record_name": rn.getText(),
                    "from_var": from_var,
                    "invalid_key": invalid_key_stmts,
                    "not_invalid_key": not_invalid_key_stmts,
                    "paragraph": self.current_paragraph,
                    "line": ctx.start.line,
                    "statement": ctx.getText(),
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterRewriteStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── SORT ──────────────────────────────────────────────────

    def enterSortStatement(self, ctx):
        try:
            sort_file = ctx.fileName().getText() if ctx.fileName() else None

            # Keys: list of {direction, fields}
            keys = []
            for key_clause in (ctx.sortOnKeyClause() or []):
                direction = "ASCENDING" if key_clause.ASCENDING() else "DESCENDING"
                field_names = []
                for qdn in (key_clause.qualifiedDataName() or []):
                    field_names.append(qdn.getText())
                keys.append({"direction": direction, "fields": field_names})

            # USING files
            using_files = []
            for su in (ctx.sortUsing() or []):
                for fn in (su.fileName() or []):
                    using_files.append(fn.getText())

            # GIVING files
            giving_files = []
            for gp in (ctx.sortGivingPhrase() or []):
                for sg in (gp.sortGiving() or []):
                    fn = sg.fileName()
                    if fn:
                        giving_files.append(fn.getText())

            # INPUT/OUTPUT PROCEDURE (stretch goal — flagged MANUAL REVIEW)
            input_proc = None
            if ctx.sortInputProcedurePhrase():
                ip = ctx.sortInputProcedurePhrase()
                input_proc = ip.procedureName().getText() if ip.procedureName() else None
            output_proc = None
            if ctx.sortOutputProcedurePhrase():
                op = ctx.sortOutputProcedurePhrase()
                output_proc = op.procedureName().getText() if op.procedureName() else None

            has_duplicates = "DUPLICATES" in ctx.getText().upper()

            self.sort_statements.append({
                "sort_file": sort_file,
                "keys": keys,
                "using": using_files,
                "giving": giving_files,
                "input_procedure": input_proc,
                "output_procedure": output_proc,
                "has_duplicates": has_duplicates,
                "paragraph": self.current_paragraph,
                "line": ctx.start.line,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterSortStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── MERGE ──────────────────────────────────────────────────

    def enterMergeStatement(self, ctx):
        try:
            merge_file = ctx.fileName().getText() if ctx.fileName() else None

            keys = []
            for key_clause in (ctx.mergeOnKeyClause() or []):
                key_text = key_clause.getText()
                ascending = "ASCENDING" in key_text.upper()
                field_names = []
                for qdn in (key_clause.qualifiedDataName() or []):
                    field_names.append(qdn.getText())
                keys.append({"direction": "ASCENDING" if ascending else "DESCENDING",
                             "fields": field_names})

            using_files = []
            for mu in (ctx.mergeUsing() or []):
                for fn in (mu.fileName() or []):
                    using_files.append(fn.getText())

            giving_files = []
            for gp in (ctx.mergeGivingPhrase() or []):
                for mg in (gp.mergeGiving() or []):
                    fn = mg.fileName()
                    if fn:
                        giving_files.append(fn.getText())

            output_proc = None
            if ctx.mergeOutputProcedurePhrase():
                op = ctx.mergeOutputProcedurePhrase()
                output_proc = op.procedureName().getText() if op.procedureName() else None

            self.merge_statements.append({
                "merge_file": merge_file,
                "keys": keys,
                "using": using_files,
                "giving": giving_files,
                "output_procedure": output_proc,
                "paragraph": self.current_paragraph,
                "line": ctx.start.line,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterMergeStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── SEARCH ─────────────────────────────────────────────────

    def enterSearchStatement(self, ctx):
        try:
            is_all = ctx.ALL() is not None
            table_name = ctx.qualifiedDataName().getText() if ctx.qualifiedDataName() else None

            # VARYING clause (index variable)
            varying = None
            if ctx.searchVarying():
                varying = ctx.searchVarying().qualifiedDataName().getText()

            # AT END body (raw text for generator)
            at_end_text = None
            if ctx.atEndPhrase():
                at_end_text = ctx.atEndPhrase().getText()

            # WHEN clauses
            whens = []
            for when_ctx in (ctx.searchWhen() or []):
                condition_text = when_ctx.condition().getText() if when_ctx.condition() else None
                body_stmts = []
                for stmt_ctx in (when_ctx.statement() or []):
                    body_stmts.append(stmt_ctx.getText())
                whens.append({
                    "condition": condition_text,
                    "body": body_stmts,
                })

            self.search_statements.append({
                "is_all": is_all,
                "table_name": table_name,
                "varying": varying,
                "at_end": at_end_text,
                "whens": whens,
                "paragraph": self.current_paragraph,
                "line": ctx.start.line,
                "statement": ctx.getText(),
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterSearchStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── CALL ────────────────────────────────────────────────────

    def enterCallStatement(self, ctx):
        try:
            text = ctx.getText()
            target = None
            is_dynamic = False

            # Target: ctx.literal() for CALL 'NAME', ctx.identifier() for CALL WS-VAR
            if ctx.literal():
                target = ctx.literal().getText().strip("'\"")
            elif ctx.identifier():
                target = ctx.identifier().getText()
                is_dynamic = True

            # USING parameters
            using_params = []
            if ctx.callUsingPhrase():
                for param_ctx in (ctx.callUsingPhrase().callUsingParameter() or []):
                    mode = "reference"  # default
                    names = []
                    if param_ctx.callByReferencePhrase():
                        mode = "reference"
                        for ref in (param_ctx.callByReferencePhrase().callByReference() or []):
                            if ref.identifier():
                                names.append(ref.identifier().getText())
                    elif param_ctx.callByValuePhrase():
                        mode = "value"
                        for val in (param_ctx.callByValuePhrase().callByValue() or []):
                            if val.identifier():
                                names.append(val.identifier().getText())
                    elif param_ctx.callByContentPhrase():
                        mode = "content"
                        for con in (param_ctx.callByContentPhrase().callByContent() or []):
                            if con.identifier():
                                names.append(con.identifier().getText())
                    for n in names:
                        using_params.append({"name": n, "mode": mode})

            self.call_statements.append({
                "target": target,
                "is_dynamic": is_dynamic,
                "using_params": using_params,
                "paragraph": self.current_paragraph,
                "line": ctx.start.line,
                "statement": text,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterCallStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── CANCEL ──────────────────────────────────────────────────

    def enterCancelStatement(self, ctx):
        try:
            text = ctx.getText()
            # cancelCall() children contain identifier() or literal()
            targets = []
            for cancel_call in (ctx.cancelCall() or []):
                if cancel_call.literal():
                    targets.append(cancel_call.literal().getText().strip("'\""))
                elif cancel_call.identifier():
                    targets.append(cancel_call.identifier().getText())
            self.cancel_statements.append({
                "targets": targets,
                "paragraph": self.current_paragraph,
                "line": ctx.start.line,
                "statement": text,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterCancelStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── RELEASE ──────────────────────────────────────────────────

    def enterReleaseStatement(self, ctx):
        try:
            record_name = ctx.recordName().getText() if ctx.recordName() else None
            from_var = None
            if ctx.qualifiedDataName():
                from_var = ctx.qualifiedDataName().getText()
            self.release_statements.append({
                "record_name": record_name,
                "from_var": from_var,
                "paragraph": self.current_paragraph,
                "line": ctx.start.line,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterReleaseStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── RETURN ───────────────────────────────────────────────────

    def enterReturnStatement(self, ctx):
        try:
            file_name = ctx.fileName().getText() if ctx.fileName() else None
            into_var = None
            if ctx.returnInto():
                into_var = ctx.returnInto().qualifiedDataName().getText()
            at_end = []
            if ctx.atEndPhrase():
                for s in (ctx.atEndPhrase().statement() or []):
                    at_end.append(s.getText())
            self.return_statements.append({
                "file_name": file_name,
                "into_var": into_var,
                "at_end": at_end,
                "paragraph": self.current_paragraph,
                "line": ctx.start.line,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterReturnStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── STRING ─────────────────────────────────────────────────

    def enterStringStatement(self, ctx):
        try:
            sources = []
            for sp in (ctx.stringSendingPhrase() or []):
                senders = [s.getText() for s in (sp.stringSending() or [])]
                delim_ctx = sp.stringDelimitedByPhrase()
                delim_is_size = False
                delim_value = None
                if delim_ctx:
                    delim_is_size = delim_ctx.SIZE() is not None
                    if not delim_is_size:
                        if delim_ctx.identifier():
                            delim_value = delim_ctx.identifier().getText()
                        elif delim_ctx.literal():
                            delim_value = delim_ctx.literal().getText()
                sources.append({
                    "senders": senders,
                    "delimited_by_size": delim_is_size,
                    "delimiter": delim_value,
                })

            into_ctx = ctx.stringIntoPhrase()
            target = into_ctx.identifier().getText() if into_ctx and into_ctx.identifier() else None

            ptr_phrase = ctx.stringWithPointerPhrase()
            has_pointer = ptr_phrase is not None
            pointer_var = None
            if ptr_phrase:
                ptr_name = ptr_phrase.qualifiedDataName()
                pointer_var = ptr_name.getText() if ptr_name else None

            overflow_stmts = []
            oof = ctx.onOverflowPhrase()
            if oof:
                overflow_stmts = [s.getText() for s in (oof.statement() or [])]
            not_overflow_stmts = []
            noof = ctx.notOnOverflowPhrase()
            if noof:
                not_overflow_stmts = [s.getText() for s in (noof.statement() or [])]

            self.strings.append({
                "paragraph": self.current_paragraph,
                "statement": ctx.getText(),
                "line": ctx.start.line,
                "sources": sources,
                "target": target,
                "has_pointer": has_pointer,
                "pointer_var": pointer_var,
                "has_overflow": oof is not None,
                "has_not_overflow": noof is not None,
                "on_overflow": overflow_stmts,
                "not_on_overflow": not_overflow_stmts,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterStringStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── UNSTRING ──────────────────────────────────────────────

    def enterUnstringStatement(self, ctx):
        try:
            sending_ctx = ctx.unstringSendingPhrase()
            source = sending_ctx.identifier().getText() if sending_ctx and sending_ctx.identifier() else None

            delimiter = None
            has_or = False
            delim_ctx = sending_ctx.unstringDelimitedByPhrase() if sending_ctx else None
            if delim_ctx:
                if delim_ctx.identifier():
                    delimiter = delim_ctx.identifier().getText()
                elif delim_ctx.literal():
                    delimiter = delim_ctx.literal().getText()

            or_phrases = sending_ctx.unstringOrAllPhrase() if sending_ctx else []
            has_or = len(or_phrases) > 0 if or_phrases else False
            or_delimiters = []
            if or_phrases:
                for op in or_phrases:
                    if op.identifier():
                        or_delimiters.append(op.identifier().getText())
                    elif op.literal():
                        or_delimiters.append(op.literal().getText())

            into_ctx = ctx.unstringIntoPhrase()
            targets = []
            if into_ctx:
                for ui in (into_ctx.unstringInto() or []):
                    delim_in_var = None
                    count_in_var = None
                    di = ui.unstringDelimiterIn()
                    if di and di.identifier():
                        delim_in_var = di.identifier().getText()
                    ci = ui.unstringCountIn()
                    if ci and ci.identifier():
                        count_in_var = ci.identifier().getText()
                    targets.append({
                        "name": ui.identifier().getText() if ui.identifier() else None,
                        "has_delimiter_in": di is not None,
                        "delimiter_in_var": delim_in_var,
                        "has_count_in": ci is not None,
                        "count_in_var": count_in_var,
                    })

            # POINTER variable
            pointer_ctx = ctx.unstringWithPointerPhrase()
            pointer_var = None
            if pointer_ctx and pointer_ctx.qualifiedDataName():
                pointer_var = pointer_ctx.qualifiedDataName().getText()

            # TALLYING variable
            tallying_ctx = ctx.unstringTallyingPhrase()
            tallying_var = None
            if tallying_ctx and tallying_ctx.qualifiedDataName():
                tallying_var = tallying_ctx.qualifiedDataName().getText()

            u_overflow_stmts = []
            u_oof = ctx.onOverflowPhrase()
            if u_oof:
                u_overflow_stmts = [s.getText() for s in (u_oof.statement() or [])]
            u_not_overflow_stmts = []
            u_noof = ctx.notOnOverflowPhrase()
            if u_noof:
                u_not_overflow_stmts = [s.getText() for s in (u_noof.statement() or [])]

            self.unstrings.append({
                "paragraph": self.current_paragraph,
                "statement": ctx.getText(),
                "line": ctx.start.line,
                "source": source,
                "delimiter": delimiter,
                "has_or": has_or,
                "or_delimiters": or_delimiters,
                "targets": targets,
                "has_pointer": ctx.unstringWithPointerPhrase() is not None,
                "pointer_var": pointer_var,
                "has_tallying": ctx.unstringTallyingPhrase() is not None,
                "tallying_var": tallying_var,
                "has_overflow": u_oof is not None,
                "on_overflow": u_overflow_stmts,
                "not_on_overflow": u_not_overflow_stmts,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterUnstringStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── INSPECT ───────────────────────────────────────────────

    def enterInspectStatement(self, ctx):
        try:
            field = ctx.identifier().getText() if ctx.identifier() else None
            variant = None
            tallying_details = None
            replacing_details = None

            if ctx.inspectTallyingPhrase():
                variant = "tallying"
                tp = ctx.inspectTallyingPhrase()
                tallying_details = []
                for for_ctx in (tp.inspectFor() or []):
                    counter = for_ctx.identifier().getText() if for_ctx.identifier() else None
                    has_characters = len(for_ctx.inspectCharacters() or []) > 0
                    tally_type = None
                    tally_value = None
                    has_before_after = False
                    for al in (for_ctx.inspectAllLeadings() or []):
                        tally_type = "ALL" if al.ALL() else "LEADING"
                        for ali in (al.inspectAllLeading() or []):
                            if ali.literal():
                                tally_value = ali.literal().getText()
                            elif ali.identifier():
                                tally_value = ali.identifier().getText()
                            if ali.inspectBeforeAfter():
                                has_before_after = len(ali.inspectBeforeAfter()) > 0
                    tallying_details.append({
                        "counter": counter,
                        "has_characters": has_characters,
                        "tally_type": tally_type,
                        "tally_value": tally_value,
                        "has_before_after": has_before_after,
                    })

            elif ctx.inspectReplacingPhrase():
                variant = "replacing"
                rp = ctx.inspectReplacingPhrase()
                has_characters = len(rp.inspectReplacingCharacters() or []) > 0
                replacing_details = {"has_characters": has_characters, "replacements": []}
                for ral in (rp.inspectReplacingAllLeadings() or []):
                    rep_type = "ALL" if ral.ALL() else ("FIRST" if ral.FIRST() else "LEADING")
                    for rali in (ral.inspectReplacingAllLeading() or []):
                        from_val = None
                        to_val = None
                        if rali.literal():
                            from_val = rali.literal().getText()
                        elif rali.identifier():
                            from_val = rali.identifier().getText()
                        by_ctx = rali.inspectBy()
                        if by_ctx:
                            if by_ctx.literal():
                                to_val = by_ctx.literal().getText()
                            elif by_ctx.identifier():
                                to_val = by_ctx.identifier().getText()
                        has_ba = len(rali.inspectBeforeAfter() or []) > 0
                        replacing_details["replacements"].append({
                            "type": rep_type,
                            "from": from_val,
                            "to": to_val,
                            "has_before_after": has_ba,
                        })

            elif ctx.inspectTallyingReplacingPhrase():
                variant = "tallying_replacing"
            elif ctx.inspectConvertingPhrase():
                variant = "converting"

            self.inspects.append({
                "paragraph": self.current_paragraph,
                "statement": ctx.getText(),
                "line": ctx.start.line,
                "field": field,
                "variant": variant,
                "tallying": tallying_details,
                "replacing": replacing_details,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterInspectStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )


    # ── INITIALIZE ──────────────────────────────────────────────

    def enterInitializeStatement(self, ctx):
        try:
            targets = [ident.getText() for ident in (ctx.identifier() or [])]
            self.initializes.append({
                "paragraph": self.current_paragraph,
                "statement": ctx.getText(),
                "line": ctx.start.line,
                "targets": targets,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterInitializeStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    # ── DISPLAY ────────────────────────────────────────────────

    def enterDisplayStatement(self, ctx):
        try:
            operands = []
            for op in (ctx.displayOperand() or []):
                operands.append(op.getText())
            self.displays.append({
                "paragraph": self.current_paragraph,
                "statement": ctx.getText(),
                "line": ctx.start.line,
                "operands": operands,
            })
        except Exception as e:
            self._parse_warnings.append(
                f"enterDisplayStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )

    def enterAcceptStatement(self, ctx):
        """Detect ACCEPT FROM DATE/TIME/DAY statements."""
        try:
            target = ctx.identifier().getText() if ctx.identifier() else None
            from_date_ctx = ctx.acceptFromDateStatement()
            accept_type = None
            if from_date_ctx:
                text = from_date_ctx.getText().upper()
                if "YYYYMMDD" in text:
                    accept_type = "DATE_YYYYMMDD"
                elif "YYYYDDD" in text:
                    accept_type = "DAY_YYYYDDD"
                elif "DAYOFWEEK" in text or "DAY-OF-WEEK" in text or "DAY_OF_WEEK" in text:
                    accept_type = "DAY_OF_WEEK"
                elif "DAY" in text:
                    accept_type = "DAY"
                elif "TIME" in text or "TIMER" in text:
                    accept_type = "TIME"
                elif "DATE" in text:
                    accept_type = "DATE"
            # Check for ENVIRONMENT in full statement text
            if not accept_type:
                full_text = ctx.getText().upper()
                if "ENVIRONMENTVALUE" in full_text or "ENVIRONMENT-VALUE" in full_text:
                    accept_type = "ENVIRONMENT_VALUE"
                elif "ENVIRONMENTNAME" in full_text or "ENVIRONMENT-NAME" in full_text or "ENVIRONMENT" in full_text:
                    accept_type = "ENVIRONMENT_NAME"
            if target and accept_type:
                self.accepts.append({
                    "paragraph": self.current_paragraph,
                    "target": target,
                    "type": accept_type,
                    "statement": ctx.getText(),
                    "line": ctx.start.line,
                })
        except Exception as e:
            self._parse_warnings.append(
                f"enterAcceptStatement near line "
                f"{ctx.start.line if hasattr(ctx, 'start') and ctx.start else '?'}: "
                f"{type(e).__name__}: {str(e)[:200]}"
            )


def strip_exec_blocks(cobol_source: str) -> tuple:
    """
    Strip EXEC SQL / EXEC CICS / EXEC SQLIMS blocks before ANTLR4 parsing.

    ANTLR4's COBOL85 grammar tokenizes these as line-level tokens but the
    parser cannot handle the embedded SQL/CICS syntax, producing dozens of
    spurious parse errors.  We replace each block with a CONTINUE statement
    (valid COBOL no-op) and record the external dependency for the report.

    Returns (cleaned_source, list_of_exec_dependency_dicts).
    """
    EXEC_PATTERN = re.compile(
        r'(\s*EXEC\s+(SQL|CICS|SQLIMS)\b)(.*?)(END-EXEC)',
        re.DOTALL | re.IGNORECASE,
    )

    dependencies = []

    def _replace(match):
        exec_type = match.group(2).upper()
        body = match.group(3).strip().replace('\n', ' ')
        # First keyword of the embedded statement (SELECT, INSERT, UPDATE, SEND, etc.)
        verb_match = re.match(r'(\w+)', body)
        verb = verb_match.group(1).upper() if verb_match else "UNKNOWN"

        dependencies.append({
            "type": f"EXEC {exec_type}",
            "verb": verb,
            "body_preview": body[:120],
            "flag": "EXTERNAL DEPENDENCY — REQUIRES MANUAL REVIEW",
        })
        # Replace with a COBOL CONTINUE (no-op) to keep paragraph flow valid
        return "           CONTINUE"

    cleaned = EXEC_PATTERN.sub(_replace, cobol_source)
    return cleaned, dependencies


def parse_cbl_process_options(source: str) -> tuple:
    """Parse CBL/PROCESS compiler option lines that appear before IDENTIFICATION DIVISION.

    IBM z/OS COBOL allows compiler options on CBL or PROCESS statements at the
    very top of the source file.  Example:
        CBL TRUNC(BIN),ARITH(EXTEND)
        PROCESS NUMPROC(PFD),DECIMAL-POINT IS COMMA

    Returns (options_dict, cleaned_source).
    options_dict keys (only present when detected):
        trunc_mode:    "STD" | "BIN" | "OPT"
        arith_mode:    "COMPAT" | "EXTEND"
        numproc:       "NOPFD" | "PFD" | "MIG"
        decimal_point: "COMMA" | "PERIOD"
    cleaned_source has the CBL/PROCESS lines removed so ANTLR4 doesn't choke.
    """
    options = {}
    lines = source.split("\n")
    cleaned = []
    past_header = False

    for line in lines:
        if past_header:
            cleaned.append(line)
            continue

        stripped = line.strip()
        upper = stripped.upper()

        # Detect start of real COBOL — stop scanning for CBL/PROCESS
        if upper.startswith("IDENTIFICATION") or upper.startswith("ID DIVISION"):
            past_header = True
            cleaned.append(line)
            continue

        # Match CBL or PROCESS statement
        cbl_match = re.match(r'^(CBL|PROCESS)\s+(.+)', upper)
        if cbl_match:
            option_str = cbl_match.group(2)

            # TRUNC(STD|BIN|OPT)
            trunc = re.search(r'TRUNC\s*\(\s*(STD|BIN|OPT)\s*\)', option_str)
            if trunc:
                options["trunc_mode"] = trunc.group(1)

            # ARITH(COMPAT|EXTEND)
            arith = re.search(r'ARITH\s*\(\s*(COMPAT|EXTEND)\s*\)', option_str)
            if arith:
                options["arith_mode"] = arith.group(1)

            # NUMPROC(NOPFD|PFD|MIG)
            numproc = re.search(r'NUMPROC\s*\(\s*(NOPFD|PFD|MIG)\s*\)', option_str)
            if numproc:
                options["numproc"] = numproc.group(1)

            # DECIMAL-POINT IS COMMA (can also appear as DECIMAL-POINT(COMMA))
            if "DECIMAL-POINT" in option_str and "COMMA" in option_str:
                options["decimal_point"] = "COMMA"

            # Strip the CBL/PROCESS line from source (replace with blank)
            cleaned.append("")
            continue

        # Blank lines or comments before IDENTIFICATION DIVISION — keep scanning
        cleaned.append(line)

    return options, "\n".join(cleaned)


def preprocess_cobol_source(source: str) -> str:
    """Clean raw COBOL source before ANTLR4 parsing.

    Strips comments (* in col 7), page breaks (/ in col 7),
    sequence numbers (cols 1-6), and identification area (after col 72).
    """
    out = []
    for line in source.split("\n"):
        if len(line) < 7:
            out.append(line)
            continue
        indicator = line[6]
        if indicator in ("*", "/"):
            out.append("")
            continue
        if line[:6].strip().isdigit():
            line = "      " + line[6:]
        if len(line) > 72:
            line = line[:72]
        out.append(line)
    return "\n".join(out)


def _preprocess_level_78(source: str) -> tuple:
    """Extract level 78 constants and substitute names with values.

    Level 78 syntax: 78  NAME  VALUE  literal.
    Returns (modified_source, list_of_constants).
    """
    LEVEL_78_RE = re.compile(
        r'^\s{6}\s+78\s+([A-Z][A-Z0-9-]*)\s+VALUE\s+(?:IS\s+)?'
        r"([+-]?\d+(?:\.\d+)?|'[^']*'|\"[^\"]*\"|ZEROS?|ZEROES|SPACES?)\s*\.?",
        re.IGNORECASE | re.MULTILINE,
    )
    constants = []
    for m in LEVEL_78_RE.finditer(source):
        name = m.group(1).upper()
        raw_value = m.group(2).strip()
        # Strip surrounding quotes for string values
        if (raw_value.startswith("'") and raw_value.endswith("'")) or \
           (raw_value.startswith('"') and raw_value.endswith('"')):
            raw_value = raw_value[1:-1]
        constants.append({
            "name": name,
            "value": raw_value,
            "line": source[:m.start()].count('\n') + 1,
        })

    if not constants:
        return source, []

    # Remove level 78 lines from source (would confuse ANTLR)
    source = LEVEL_78_RE.sub('', source)

    # Collision check: scan for variable declarations with the same name
    VAR_DECL_RE = re.compile(
        r'^\s{6}\s+\d{2}\s+([A-Z][A-Z0-9-]*)\s+PIC',
        re.IGNORECASE | re.MULTILINE,
    )
    declared_vars = {m.group(1).upper() for m in VAR_DECL_RE.finditer(source)}

    safe_constants = []
    warnings = []
    for const in constants:
        if const["name"] in declared_vars:
            warnings.append(
                f"Level 78 constant '{const['name']}' conflicts with "
                f"variable declaration — variable wins"
            )
            const["skipped"] = True
        else:
            safe_constants.append(const)

    # Substitute safe constant names with their values (whole-word only)
    for const in safe_constants:
        source = re.sub(
            r'\b' + re.escape(const["name"]) + r'\b',
            const["value"],
            source,
        )

    return source, constants


def analyze_cobol(cobol_source: str) -> dict:
    """
    Analyze COBOL source code and return structured JSON.
    """
    # Detect CBL/PROCESS compiler options before any preprocessing
    compiler_options_detected, cobol_source = parse_cbl_process_options(cobol_source)

    # Detect DECIMAL-POINT IS COMMA in SPECIAL-NAMES paragraph (if not already on CBL card)
    if "decimal_point" not in compiler_options_detected:
        if re.search(r'DECIMAL\s*-\s*POINT\s+IS\s+COMMA', cobol_source, re.IGNORECASE):
            compiler_options_detected["decimal_point"] = "COMMA"

    # DECIMAL-POINT IS COMMA: swap commas and periods in numeric literals
    # so ANTLR receives standard period-based decimals.
    if compiler_options_detected.get("decimal_point") == "COMMA":
        cobol_source = re.sub(r'(?<=\d),(?=\d)', '.', cobol_source)

    # Preprocess raw COBOL source (strip comments, seq numbers, col 73+)
    cobol_source = preprocess_cobol_source(cobol_source)

    # Preprocess EXEC SQL/CICS/SQLIMS blocks (must run BEFORE ANTLR4)
    exec_dependencies = []
    cobol_source, exec_dependencies = strip_exec_blocks(cobol_source)

    # Detect ALTER statements — runtime control flow mutation makes static
    # verification impossible.  This is a hard stop.
    ALTER_PATTERN = re.compile(
        r'^\s{6}\s+ALTER\s+(\S+)\s+TO\s+(?:PROCEED\s+TO\s+)?(\S+)',
        re.IGNORECASE | re.MULTILINE,
    )
    for m in ALTER_PATTERN.finditer(cobol_source):
        exec_dependencies.append({
            "type": "ALTER",
            "source_paragraph": m.group(1).strip('.'),
            "target_paragraph": m.group(2).strip('.'),
            "body_preview": m.group(0).strip(),
            "flag": "RUNTIME MUTATION DETECTED — ALTER statement modifies control flow at runtime. Static verification is not possible for this program.",
            "line": cobol_source[:m.start()].count('\n') + 1,
        })

    # Detect OCCURS DEPENDING ON — variable-length records that may break
    # fixed-width parsing assumptions in Shadow Diff.
    ODO_PATTERN = re.compile(
        r'^\s{6}\s+\d{2}\s+(\S+).*?OCCURS\s+\d+\s+TO\s+(\d+)\s+(?:TIMES\s+)?DEPENDING\s+ON\s+(\S+)',
        re.IGNORECASE | re.MULTILINE,
    )
    for m in ODO_PATTERN.finditer(cobol_source):
        exec_dependencies.append({
            "type": "ODO",
            "field_name": m.group(1).strip('.'),
            "max_occurs": int(m.group(2)),
            "depending_on": m.group(3).strip('.'),
            "body_preview": m.group(0).strip(),
            "flag": "VARIABLE-LENGTH RECORDS DETECTED — OCCURS DEPENDING ON requires dynamic record parsing. Fixed-width reader may produce incorrect results for this data structure.",
        })

    # Preprocess COPY statements (lazy — works without copybook_resolver)
    copy_issues = []
    try:
        from copybook_resolver import preprocess_source
        cobol_source, copy_issues = preprocess_source(cobol_source)
    except ImportError:
        pass

    # Preprocess level 78 constants (IBM order: COPY first, then level 78)
    cobol_source, level_78_constants = _preprocess_level_78(cobol_source)

    input_stream = InputStream(cobol_source)
    lexer = Cobol85Lexer(input_stream)
    token_stream = CommonTokenStream(lexer)
    parser = Cobol85Parser(token_stream)
    tree = parser.startRule()

    # Count syntax errors but DO NOT bail out — ANTLR4 error recovery means
    # the parse tree is still walkable and useful even with errors/warnings.
    parse_errors = parser.getNumberOfSyntaxErrors()

    analyzer = FullAnalyzer()
    analyzer.source_lines = cobol_source.splitlines()
    walker = ParseTreeWalker()
    walker.walk(analyzer, tree)

    # Assign ALTER entries to paragraphs using line numbers
    if analyzer.paragraph_lines:
        para_boundaries = sorted(analyzer.paragraph_lines.items(), key=lambda x: x[1])
        for dep in exec_dependencies:
            if dep["type"] == "ALTER" and "line" in dep:
                alter_line = dep["line"]
                for i, (pname, pline) in enumerate(para_boundaries):
                    next_line = para_boundaries[i + 1][1] if i + 1 < len(para_boundaries) else float('inf')
                    if pline <= alter_line < next_line:
                        dep["paragraph"] = pname
                        break

    # Detect cycles
    cycles = list(nx.simple_cycles(analyzer.graph))

    # Detect unreachable code
    unreachable = []
    if analyzer.paragraphs:
        entry = analyzer.paragraphs[0]
        reachable = set(nx.descendants(analyzer.graph, entry)) | {entry}
        unreachable = list(set(analyzer.paragraphs) - reachable)

    # success = True whenever we extracted any meaningful structure.
    # parse_errors > 0 means non-standard syntax was encountered but data
    # may still be complete (e.g. extra tokens at EOF, unrecognised chars).
    got_data = len(analyzer.paragraphs) > 0 or len(analyzer.variables) > 0

    result = {
        "success": got_data,
        "parse_errors": parse_errors,
        "parse_warning": (
            f"{parse_errors} syntax warning(s) — data extracted via error recovery"
            if parse_errors > 0 else None
        ),
        "summary": {
            "paragraphs": len(analyzer.paragraphs),
            "variables": len(analyzer.variables),
            "comp3_variables": sum(1 for v in analyzer.variables if v["comp3"]),
            "comp1_variables": sum(1 for v in analyzer.variables if v.get("comp1")),
            "comp2_variables": sum(1 for v in analyzer.variables if v.get("comp2")),
            "perform_calls": len(analyzer.performs),
            "compute_statements": len(analyzer.computes),
            "move_statements": len(analyzer.moves),
            "goto_statements": len(analyzer.gotos),
            "stop_statements": len(analyzer.stops),
            "exit_program_statements": len(analyzer.exit_programs),
            "goback_statements": len(analyzer.gobacks),
            "business_rules": len(analyzer.conditions),
            "evaluate_statements": len(analyzer.evaluates),
            "arithmetic_statements": len(analyzer.arithmetics),
            "perform_until_statements": len(analyzer.perform_untils),
            "string_statements": len(analyzer.strings),
            "unstring_statements": len(analyzer.unstrings),
            "inspect_statements": len(analyzer.inspects),
            "initialize_statements": len(analyzer.initializes),
            "display_statements": len(analyzer.displays),
            "set_statements": len(analyzer.sets),
            "search_statements": len(analyzer.search_statements),
            "call_statements": len(analyzer.call_statements),
            "cancel_statements": len(analyzer.cancel_statements),
            "merge_statements": len(analyzer.merge_statements),
            "nested_programs": len(analyzer.program_ids) - 1 if len(analyzer.program_ids) > 1 else 0,
            "cycles": len(cycles),
            "unreachable": len(unreachable)
        },
        "paragraphs": analyzer.paragraphs,
        "sections": analyzer.sections,
        "has_multiple_sections": len(analyzer.sections) > 1,
        "variables": analyzer.variables,
        "control_flow": analyzer.performs,
        "computes": analyzer.computes,
        "moves": analyzer.moves,
        "gotos": analyzer.gotos,
        "stops": analyzer.stops,
        "exit_programs": analyzer.exit_programs,
        "gobacks": analyzer.gobacks,
        "conditions": analyzer.conditions,
        "evaluates": analyzer.evaluates,
        "arithmetics": analyzer.arithmetics,
        "level_88": analyzer.level_88s,
        "perform_varyings": analyzer.perform_varyings,
        "perform_times": analyzer.perform_times,
        "perform_untils": analyzer.perform_untils,
        "strings": analyzer.strings,
        "unstrings": analyzer.unstrings,
        "inspects": analyzer.inspects,
        "initializes": analyzer.initializes,
        "displays": analyzer.displays,
        "accepts": analyzer.accepts,
        "renames": analyzer.renames,
        "level_78_constants": level_78_constants,
        "sets": analyzer.sets,
        "file_descriptions": analyzer.file_descriptions,
        "file_controls": analyzer.file_controls,
        "file_operations": analyzer.file_operations,
        "file_statuses": analyzer.file_statuses,
        "sort_statements": analyzer.sort_statements,
        "sort_descriptions": analyzer.sort_descriptions,
        "release_statements": analyzer.release_statements,
        "return_statements": analyzer.return_statements,
        "search_statements": analyzer.search_statements,
        "call_statements": analyzer.call_statements,
        "cancel_statements": analyzer.cancel_statements,
        "merge_statements": analyzer.merge_statements,
        "program_ids": analyzer.program_ids,
        "has_nested_programs": len(analyzer.program_ids) > 1,
        "has_declaratives": analyzer.has_declaratives,
        "declarative_sections": analyzer.declarative_sections,
        "paragraph_lines": analyzer.paragraph_lines,
        "cycles": cycles,
        "unreachable": unreachable,
        "copybook_issues": copy_issues,
        "exec_dependencies": exec_dependencies,
        "compiler_options_detected": compiler_options_detected,
        "parse_warnings": analyzer._parse_warnings,
    }

    # EXEC SQL/CICS deep analysis (lazy — works without exec_sql_parser)
    if exec_dependencies:
        try:
            from exec_sql_parser import analyze_exec_blocks
            result["exec_analysis"] = analyze_exec_blocks(
                exec_dependencies, analyzer.conditions, analyzer.variables,
            )
        except ImportError:
            result["exec_analysis"] = None
    else:
        result["exec_analysis"] = None

    # REDEFINES analysis (lazy — works without copybook_resolver)
    try:
        from copybook_resolver import resolve_redefines
        result["redefines"] = resolve_redefines(analyzer.variables)
    except ImportError:
        result["redefines"] = {
            "memory_map": [], "redefines_groups": [],
            "ambiguous_references": [],
        }

    return result

# Test it
if __name__ == "__main__":
    with open("DEMO_LOAN_INTEREST.cbl", "r") as f:
        test_cobol = f.read()
    result = analyze_cobol(test_cobol)
    import json
    print(json.dumps(result, indent=2))
