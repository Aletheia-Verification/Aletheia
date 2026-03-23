# CLAUDE.md Maintenance Checklist

Paste this at the start of a Claude Code session to keep CLAUDE.md current.

---

## Prompt (copy-paste this)

```
Run these checks and update CLAUDE.md if any number is stale:

1. Test count:
   "venv\Scripts\python.exe" -m pytest --co -q 2>&1 | tail -1
   Compare to the number in CLAUDE.md Testing section.

2. PVR:
   grep "PVR" pvr_report_*.md | tail -1
   Compare to any PVR claim in CLAUDE.md or landing page.

3. Python module count:
   ls *.py | wc -l
   Compare to Key Files table row count.

4. Corpus size:
   ls corpus/*.cbl | wc -l
   Compare to any corpus size claim.

5. Frontend page count:
   ls frontend/src/pages/*.jsx | wc -l
   Compare to endpoint/page documentation.

IF any number is stale → update CLAUDE.md.
IF a new .py module was added → add row to Key Files table.
IF a new endpoint was added → add row to Endpoints table.
IF a new construct is supported → update Construct Support Matrix.

Do NOT change architecture, rules, or protocol sections unless
explicitly asked. Only update numbers and tables.
```

---

## When to run
- Start of every session
- After adding new modules or endpoints
- After running PVR experiments
- Before any release or PR
