# Aletheia Demo Video Script

**Duration:** 3:00
**Format:** Screen recording with voiceover, no face cam
**Resolution:** 1920x1080, dark browser chrome, system font off
**Music:** Low ambient drone, cuts at 0:45 and 2:45

---

## ACT 1: THE HOOK (0:00 - 0:15)

### Shot 1 — Black screen, white text fade-in
**On screen:** `$2.8M` (large, centered, mono font)
**VO:** "Banks spend two point eight million dollars *per application* testing COBOL migrations."

### Shot 2 — Text dissolves, replaced by:
**On screen:** `ALETHEIA` (tracked wide, silver on black, 1-second hold)
**VO:** "I built a tool that proves correctness automatically."

---

## ACT 2: THE PROBLEM (0:15 - 0:45)

### Shot 3 — Split screen: left = COBOL code scrolling, right = Java code scrolling
**VO:** "Every year, banks convert billions of lines of COBOL to Java or Python. The translation looks right. The unit tests pass. But nobody can *prove* the new code matches the old code."

### Shot 4 — Red "DRIFT DETECTED" banner flashes across screen
**VO:** "A one-cent rounding error in a loan calculation. Multiplied by ten million accounts. That's a hundred thousand dollar loss *per month* that nobody catches until production."

### Shot 5 — Cut to Aletheia login screen. Clean, white, navy logo.
**VO:** "Aletheia is a deterministic behavioral verification engine. No AI guesswork. Mathematical proof."

---

## ACT 3: THE ENGINE (0:45 - 1:30)

### Shot 6 — Click "Analyze" in sidebar (Ctrl+2). Empty Analyze page appears.
**VO:** "Let me show you."

### Shot 7 — Click "Load Demo" button. DEMO_LOAN_INTEREST.cbl loads into the code editor. 180 lines of COBOL visible. Scroll briefly to show COMPUTE statements.
**VO:** "This is a real loan interest calculation. COMP-3 packed decimals, nested IF/EVALUATE, PERFORM VARYING loops."

### Shot 8 — Click "Analyze" button. Processing animation: "Parsing... Generating... Verifying... Finalizing..." (4-stage progress, ~3 seconds)
**VO:** "Aletheia parses it with a real ANTLR4 grammar. No regex hacks. Then generates a Python verification model that matches IBM mainframe arithmetic exactly."

### Shot 9 — Results appear. Green "VERIFIED" banner at top. Zoom into the validation table.
**UI action:** Scroll down slowly through the validation table. Each row: COBOL statement | Python equivalent | green checkmark.
**VO:** "Every single COBOL statement mapped to Python. Every arithmetic operation verified. Zero manual review flags."

### Shot 10 — Scroll to Arithmetic Risk section. Color-coded table: green "safe", yellow "warn".
**VO:** "The arithmetic risk matrix flags any operation that could overflow or lose precision. Green means safe. Yellow means *check your PIC clause*."

### Shot 11 — Scroll to Dead Code section. Shows "0% dead code" with paragraph reachability graph.
**VO:** "Dead code analysis. Paragraph-level reachability. If code can't be reached, we flag it."

### Shot 12 — Click "PDF (Executive)" button. PDF downloads. Brief flash of the cover page: "BEHAVIORAL VERIFICATION REPORT" with Aletheia branding.
**VO:** "One click. Attach the PDF to your compliance deliverable. Done."

---

## ACT 4: THE PORTFOLIO (1:30 - 2:15)

### Shot 13 — Click "Portfolio" in sidebar (Ctrl+5). Empty portfolio page.
**VO:** "But banks don't migrate one program. They migrate hundreds."

### Shot 14 — Click "Upload Programs". File picker opens. Select 10 .cbl files from corpus/. Upload starts.
**VO:** "Upload ten programs. Aletheia analyzes them all."

### Shot 15 — Heatmap appears. 8 green cells, 1 yellow, 1 red. Summary bar: "Total: 10, Green: 8, Yellow: 1, Red: 1".
**UI action:** Hover over a green cell — tooltip shows "VERIFIED, 12 constructs, 0 MR flags". Click the red cell — expands to show which constructs triggered manual review.
**VO:** "Instant portfolio risk heatmap. Green means verified. Red means the program uses constructs we flag for human review. ALTER statements. Embedded SQL. Things a machine shouldn't guess about."

### Shot 16 — Click "Compiler Matrix" in sidebar (Ctrl+6). Paste the red program's COBOL. Click analyze.
**VO:** "The compiler matrix shows you exactly which IBM compiler options affect this program. TRUNC mode. ARITH mode. If your JCL uses different settings than what we defaulted, you'll know."

### Shot 17 — Results: table showing "TRUNC: STD (detected)", "ARITH: COMPAT (defaulted)", "DECIMAL-POINT: PERIOD (defaulted)".
**VO:** "No ambiguity. No guessing."

---

## ACT 5: THE SHADOW DIFF (2:15 - 2:45)

### Shot 18 — Click "Verify" in sidebar (Ctrl+3). Shadow Diff upload page.
**VO:** "Here's the real proof. Shadow Diff."

### Shot 19 — Upload three files: layout JSON, mainframe input .dat, mainframe output .dat. Click "Run Verification".
**UI action:** Processing animation: "Parsing Input Records... Executing Verification Model... Comparing Outputs... Generating Report..."
**VO:** "We feed real mainframe input through the generated Python, and compare the output to what the mainframe *actually produced*. Field by field. Record by record."

### Shot 20 — Results: "DRIFT DETECTED - 1 RECORD". 99 green, 1 red. Expand the red record.
**UI action:** Click the mismatch row. Details show: "Field: WS-INTEREST, Mainframe: 125.75, Aletheia: 125.74, Magnitude: 0.01, Root Cause: ROUND_HALF_UP vs ROUND_DOWN"
**VO:** "One cent. Record fifty-three. The rounding mode in the COMPUTE clause doesn't match. *That's* the bug your unit tests would never catch. Aletheia catches it in two seconds."

### Shot 21 — Click "Export PDF (Engineer)". PDF downloads with full mismatch log, root cause analysis, cryptographic fingerprints.
**VO:** "Full forensic report. SHA-256 fingerprinted. RSA signed."

---

## ACT 6: THE CLOSE (2:45 - 3:00)

### Shot 22 — Cut to black. Stats appear one by one (typed, mono font):
```
1006+ tests. Zero failures.
94.3% PVR on 459 banking COBOL programs.
50GB streaming. Constant memory.
Air-gapped. No cloud dependency.
```
**VO:** "Seven hundred tests. Eighty-four percent parse-verify rate on two hundred programs. Streams fifty-gigabyte files with constant memory. Runs fully air-gapped."

### Shot 23 — Aletheia logo fades in, centered. Below it:
```
aletheia.dev
```
**VO:** "Aletheia. Try it free."

### Shot 24 — Hold 2 seconds. Fade to black.

---

## PRODUCTION NOTES

### Before Recording
- [ ] Fresh browser, incognito mode, no extensions visible
- [ ] Resolution: 1920x1080, 100% zoom
- [ ] Aletheia running locally on port 5173 (frontend) + 8000 (backend)
- [ ] Pre-load: DEMO_LOAN_INTEREST.cbl in clipboard for quick paste
- [ ] Pre-upload: 10 corpus programs ready in a folder
- [ ] Demo data: loan_mainframe_output_WITH_DRIFT.dat (has the 1-cent mismatch)
- [ ] Close all notifications, Do Not Disturb on

### Voiceover Style
- Calm, measured, institutional. Not startup-hyper.
- Pace: ~150 words/minute (slower than conversational)
- No filler words. No "um" or "so basically".
- Emphasis words: *prove*, *exactly*, *every single*, *automatically*

### Edit Cuts
- Hard cuts between shots (no transitions, no wipes)
- Zoom into UI elements where noted (post-production)
- Green/red color pops should be vivid (boost saturation 10%)
- Black backgrounds between acts: 0.5s fade

### Music
- Ambient drone, no melody. Think: server room hum meets piano sustain.
- Volume: barely audible under voice (-20dB)
- Music out at 2:45, silence for the stats reveal
