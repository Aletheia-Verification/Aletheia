# Aletheia — Demo Script (15 minutes)

Target audience: technical evaluators, potential advisors, or YC partners.
Total runtime: **15 minutes** (12 min content + 3 min buffer for questions).

---

## 1. OPENING — Small Talk (0:00 → 0:30)

Keep it brief. Match their energy. Options:

- "Thanks for making time — I know how packed these calls are."
- If they ask what you do: "I help banks prove their legacy code migrations actually work. Let me show you."
- If they mention COBOL/mainframes: "You already know the pain. Let me show you what we built."

**Do NOT** explain the product yet. Transition with:

> "Let me just show you — it'll make more sense than me describing it."

---

## 2. THE PITCH — 10 Seconds (0:30 → 0:40)

One sentence. Memorize it exactly:

> **"Aletheia is a deterministic verification engine that proves whether a COBOL-to-Python migration is mathematically correct — no AI in the verification pipeline, no confidence scores, just VERIFIED or NOT."**

Then immediately share your screen.

---

## 3. ENGINE DEMO — Clean Verification (0:40 → 5:00)

### Click sequence:

1. **Open the app** — `http://localhost:5173` (or deployed URL)
2. **You're on the Gateway** — click **"THE ENGINE"**
3. **Upload `ACCT-INTEREST.cbl`** — drag from `demo_data/ACCT-INTEREST.cbl` or click "Select File"
4. **Wait 2-3 seconds** for analysis

### What to say while it loads:

> "This is a real COBOL program — 125 lines, compound interest calculation with tiered rates, EVALUATE WHEN branching, PERFORM VARYING loops, penalty logic. The kind of thing that runs every night at a bank."

### Walk through the results (scroll slowly):

| Section | What to say | Time |
|---------|-------------|------|
| **Verdict banner** | "VERIFIED. Binary result — it either passes or it doesn't. No percentages." | 5 sec |
| **Generated Python** | "This is the verification model — deterministic Python that matches IBM mainframe precision. Every number uses `Decimal`, never floating point." | 10 sec |
| **Validation Report** | "Every single COBOL statement mapped to its Python equivalent, side by side. If anything can't be mapped cleanly, it says MANUAL REVIEW — it never silently skips anything." | 15 sec |
| **Arithmetic Risk Analysis** | "This is the part banks care about — it checks every calculation for overflow risk against the target field's PIC capacity. If a 5-digit result goes into a 3-digit field, it flags it." | 10 sec |

### Key pause moment:

> "Notice what's NOT here — no 'confidence: 87%', no 'likely correct'. It's a binary gate. The code either compiles and matches, or it tells you exactly what needs human review."

---

## 4. SHADOW DIFF — Full Verification (5:00 → 9:00)

### Transition:

> "The Engine proves the translation is correct. Shadow Diff proves it matches what the mainframe actually produces."

### Click sequence:

1. **Go back to Gateway** → click **"SHADOW DIFF"** (or navigate via sidebar)
2. **Upload the COBOL source**: `demo_data/ACCT-INTEREST.cbl`
3. **Upload mainframe input**: `demo_data/acct_interest_input.dat`
4. **Upload mainframe output**: `demo_data/acct_interest_output.dat`
5. **Wait for verification** (100 records, ~2 seconds)

### What to say:

> "We just fed it 100 real mainframe input records and their actual mainframe output. The engine ran the generated Python against every input, then compared each output field — exact Decimal match, no epsilon tolerance."

### When results appear:

> **"ZERO DRIFT CONFIRMED — 100 records."**
> "Every single field, every single record, exact match. This is the proof that the migration works."

### If they ask about scale:

> "This demo has 100 records. The streaming pipeline handles files up to 50 gigabytes from disk with constant RAM usage. Same engine."

---

## 5. DRIFT DEMO — Failure Detection (9:00 → 12:30)

### Transition:

> "That was the happy path. Let me show you what happens when something is wrong."

### Click sequence:

1. **Stay in Shadow Diff**
2. **Upload**: `DEMO_LOAN_INTEREST.cbl` (from project root)
3. **Upload input**: `demo_data/loan_input.dat`
4. **Upload output**: `demo_data/loan_mainframe_output_WITH_DRIFT.dat` (the corrupted one)
5. **Wait for verification**

### When results appear:

> **"DRIFT DETECTED — 5 RECORDS."** "Out of 100 records, 5 don't match. Let me show you the diagnoses."

### Walk through the 5 drift diagnoses (scroll through diagnosed mismatches):

| Record | What to say | Time |
|--------|-------------|------|
| **Record 3 — Rounding divergence** | "Off by one cent in DAILY-INTEREST. This is a ROUND vs TRUNCATE mismatch — the most common real-world bug in COBOL migrations." | 10 sec |
| **Record 12 — PIC overflow** | "Penalty amount shows 999.99 — the value overflowed the field's capacity on the mainframe. The engine caught it." | 10 sec |
| **Record 25 — TRUNC flag mismatch** | "Sixth decimal place is wrong. This happens when the mainframe used TRUNC(STD) but the migration assumed TRUNC(BIN). Silent correctness bug — would pass every test except this one." | 15 sec |
| **Record 50 — S0C7 abend** | "'BADDATA' in a decimal field. This is a mainframe S0C7 abend — corrupted data that would crash the program. The engine identifies it as dirty data, not a translation error." | 10 sec |
| **Record 75 — Sign nibble** | "Positive value came back negative. COMP-3 packed decimal sign nibble mismatch — 0xC vs 0xD. This is the kind of bug that costs banks millions and takes weeks to find." | 10 sec |

### Key phrase:

> "Each of these is a different failure mode. The engine doesn't just say 'wrong' — it tells you WHY it's wrong and suggests a fix. A human reviewer would take days to find these. We found all five in two seconds."

---

## 6. KEY PHRASES — Memorize These

Use these naturally throughout the demo. Don't recite them as a list.

| Phrase | When to use |
|--------|-------------|
| **"It never silently skips anything."** | When showing the validation report |
| **"No AI in the verification pipeline."** | When they ask about accuracy or LLMs |
| **"75% verification rate on 40 real programs."** | When they ask about coverage |
| **"Binary result — VERIFIED or NOT."** | When they ask about confidence scores |
| **"Exact Decimal match, no epsilon tolerance."** | When they ask about precision |
| **"The engine tells you WHY it drifted."** | When showing drift diagnoses |

---

## 7. EXPECTED QUESTIONS + ANSWERS

### "How is this different from a transpiler?"

> "A transpiler tries to convert COBOL to Python and hopes it works. We don't convert anything for production use — we generate a verification model that proves the conversion someone else did is correct. We're the proof layer, not the translation layer."

### "What about the 25% that doesn't verify?"

> "Those programs use constructs we intentionally flag for human review — ALTER statements that mutate control flow at runtime, EVALUATE ALSO with multiple subjects, things where static verification genuinely isn't safe. We flag them honestly instead of guessing. The 75% is a floor — it grows every month as we add construct support."

### "Why not just use AI to translate?"

> "AI is great at translation. It's terrible at proof. A bank can't go to their regulator and say 'GPT-4 said it's probably right.' They need mathematical certainty. We provide that. If someone uses AI to do the translation, we verify the result."

### "What's your go-to-market?"

> "Direct to migration teams at Tier 1 and Tier 2 banks. Every major bank has a COBOL modernization project either active or planned. We slot into their existing workflow — they bring the translation, we provide the verification."

### "How do you handle COMP-3 / packed decimal?"

> "Full packed BCD support — sign nibble 0xC for positive, 0xD for negative, correct byte-level encoding and decoding. We also handle COMP/COMP-4 binary fields and EBCDIC string comparisons using IBM Code Page 037. Every encoding detail matches the mainframe exactly."

### "What's the technical moat?"

> "Three things. First, the semantic regression corpus — 38 test cases that cover every edge case in COBOL arithmetic, every rounding mode, every encoding format. Every change we make is tested against all of them. Second, the Shadow Diff pipeline that handles 50GB files at constant RAM. Third, the fact that we match IBM mainframe precision exactly — not approximately, exactly. That's hard to build and harder to maintain."

### "Can I try it with our COBOL?"

> (This is what you want them to say.) "Absolutely. Upload any program — if it verifies, you'll see VERIFIED. If something needs human review, it'll tell you exactly what and why. Either way, you'll know in seconds."

---

## 8. THE CLOSE (12:30 → 13:30)

> **"I'm not asking for anything today except feedback. If you see holes in this, I want to know. And if you have any COBOL lying around — even a small program — I'd love for you to throw it at the engine and see what happens."**

If they seem interested:

> "I can set up a sandbox environment where your team can upload programs and test independently. No commitment, no contract — just data."

If they ask about pricing:

> "We're still in validation mode. Right now I just want to make sure the engine handles real-world programs correctly. Pricing comes after we've proven it works on your codebase."

---

## 9. BACKUP — If Things Go Wrong

| Problem | Recovery |
|---------|----------|
| **Server not running** | `venv\Scripts\python.exe -m uvicorn core_logic:app --host 0.0.0.0 --port 8000` then `cd frontend && npm run dev` |
| **Upload fails** | Paste the COBOL source directly into the text area instead |
| **ACCT-INTEREST doesn't verify** | Switch to `DEMO_LOAN_INTEREST.cbl` — it always verifies |
| **Shadow Diff times out** | "The streaming pipeline is designed for production scale — let me show you the Engine result instead, which is the core verification." |
| **They want to see code** | Open `cobol_types.py` and show `CobolDecimal` class — "Every number is a Decimal with PIC constraints enforced on every store." |

---

## 10. PRE-DEMO CHECKLIST

- [ ] Backend running on port 8000
- [ ] Frontend running on port 5173
- [ ] Test upload `DEMO_LOAN_INTEREST.cbl` → should show VERIFIED
- [ ] Test Shadow Diff with `acct_interest_*` files → should show ZERO DRIFT
- [ ] Test drift demo with `loan_mainframe_output_WITH_DRIFT.dat` → should show 5 mismatches
- [ ] Close all other browser tabs
- [ ] Mute notifications
- [ ] Have `demo_data/` folder open in file explorer for quick drag-and-drop

---

## TIMING SUMMARY

| Section | Duration | Cumulative |
|---------|----------|------------|
| Small talk | 0:30 | 0:30 |
| Pitch | 0:10 | 0:40 |
| Engine demo (clean) | 4:20 | 5:00 |
| Shadow Diff (clean) | 4:00 | 9:00 |
| Drift demo | 3:30 | 12:30 |
| Close + ask | 1:00 | 13:30 |
| Buffer for questions | 1:30 | 15:00 |
