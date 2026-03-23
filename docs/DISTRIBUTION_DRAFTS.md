# ALETHEIA Distribution Drafts

Prepared 2026-03-18. Post when target metrics confirmed.

---

## 1. Show HN Drafts

---

### Version A: Technical Depth

**Title:** Show HN: I'm 15 and built a deterministic COBOL verification engine

**Body:**

I've been building Aletheia for the past few months. It's a behavioral verification engine for COBOL-to-Python migration — not a transpiler, not an AI translator. It proves that migrated code behaves identically to the mainframe original.

**How it works:**

1. ANTLR4 parses the COBOL source into a structured AST
2. A deterministic generator emits Python with exact IBM arithmetic (Decimal precision, TRUNC(STD), COMP-3 packed decimal)
3. Shadow Diff compares the generated Python's output against real mainframe data, field by field, with zero epsilon tolerance
4. Verdict is binary: VERIFIED or REQUIRES_MANUAL_REVIEW. No confidence scores.

**Current state:**

- 94.3% Program Verification Rate on 459 banking COBOL programs (avg 243 lines, 8-15 constructs per program)
- 1006+ tests across 29 files, zero failures
- 50-entry semantic regression corpus with exact Decimal match
- 30+ COBOL constructs fully emitted (EVALUATE/WHEN, PERFORM VARYING, STRING/UNSTRING, INSPECT, SEARCH/SEARCH ALL, OCCURS tables, 12 FUNCTION intrinsics, file I/O with abstract backends)
- Air-gapped Docker deployment (Cython-compiled, non-root, zero external calls)
- LLM (GPT-4o) used only for formatting explanations — never touches the verification pipeline

**What it doesn't do:**

- The remaining 5.7% of programs hit constructs I haven't implemented yet (EVALUATE ALSO, complex INSPECT patterns, OCCURS DEPENDING ON generator wiring). They get flagged REQUIRES_MANUAL_REVIEW — never garbage output.
- It doesn't translate COBOL to production Python. It generates a verification model that proves behavioral equivalence.
- It doesn't replace human review for the hard cases. It eliminates the easy 94.3% so engineers can focus on what actually needs attention.

**Why this matters:**

Banks spend millions testing COBOL migrations manually. Most "AI translators" claim high accuracy but have no way to prove it. Aletheia doesn't translate — it verifies. The difference is: translation can be wrong and look right. Verification is either proven correct or explicitly flagged.

Built with Python, FastAPI, ANTLR4, React. Solo developer. YC S26 applicant.

[Link to demo / GitHub]

---

### Version B: Pain Point

**Title:** Show HN: Banks spend $2.8M testing COBOL migrations. I automated the proof

**Body:**

The average large bank spends $2-4M per application on COBOL migration testing. Most of that goes to manually verifying that the new system produces the same outputs as the mainframe. Line by line. Field by field. For thousands of test cases.

I built Aletheia to automate the proof.

**It's not a translator.** It's a verification engine. Feed it COBOL source and mainframe output data. It parses the COBOL deterministically (ANTLR4, not AI), generates a Python verification model with exact IBM arithmetic, then compares outputs field-by-field against the real mainframe data. Zero tolerance — either every field matches or it flags exactly which ones don't and why.

**Current metrics:**

- 94.3% of programs verified automatically on a corpus of 459 banking banking programs
- 1006+ automated tests, zero failures
- Binary verdicts: VERIFIED or REQUIRES_MANUAL_REVIEW. No percentages. No "95% confident."
- Shadow Diff catches drift down to a single penny in a single field across thousands of records
- Runs air-gapped — no data leaves the bank's network

**Honest limitations:**

- 5.7% of programs still need manual review (complex constructs I haven't automated yet)
- This is verification, not production migration — you still need someone to write the target system
- Solo developer, pre-revenue

The value proposition is simple: if you're spending $2.8M on migration testing and 94.3% of your programs can be verified in seconds instead of weeks, that's real money.

15 years old. Building alone. YC S26 applicant.

[Link to demo]

---

### Version C: Contrarian

**Title:** Show HN: Every AI COBOL translator claims it works. I built the tool that proves it

**Body:**

There are now dozens of companies claiming they can translate COBOL to Java/Python/whatever using LLMs. They all demo well. They all claim high accuracy. None of them can prove it.

Here's the problem: translation accuracy is unmeasurable without a verification oracle. If you translate 10,000 lines of COBOL with an LLM and it "looks right," how do you know it handles the edge case where a COMP-3 packed decimal overflows during a chained COMPUTE with TRUNC(STD) truncation? You don't. You find out in production. At a bank.

I built Aletheia to be that oracle.

**It doesn't translate COBOL.** It takes COBOL source, deterministically generates a Python verification model (ANTLR4 parser, Decimal arithmetic, IBM-matching precision), and compares its outputs against real mainframe data. Field by field. Zero tolerance. No AI in the verification loop.

**The results are binary:** VERIFIED means every output field matches the mainframe exactly. REQUIRES_MANUAL_REVIEW means something couldn't be verified — and it tells you exactly what and why. There is no "96% confident" middle ground. Either you have proof or you don't.

**Numbers:**

- 94.3% PVR on 459 banking programs (avg 243 lines, 8-15 constructs each)
- 1006+ tests, zero failures, 50-entry semantic regression corpus
- 30+ COBOL constructs fully supported, including the ones LLMs consistently get wrong (COMP-3 overflow, EBCDIC string ordering, TRUNC mode interactions, signed decimal truncation)
- Runs air-gapped. No data leaves your network. No LLM touches the verification path.

**What I'm not claiming:**

- I can't verify 100% of programs. 5.7% hit constructs I haven't implemented yet. They get flagged, not faked.
- This doesn't replace translators. It audits them. You still need something to produce the target code. Aletheia proves whether that code is correct.
- I'm a solo 15-year-old developer. This is pre-revenue, pre-team. The code is the credential.

YC S26 applicant. The verification engine is the product.

[Link to demo]

---

## 2. LinkedIn Profile

---

### Headline

Founder, Aletheia | Deterministic COBOL Verification Engine | YC S26

### About (200 words)

I'm building Aletheia, a behavioral verification engine for COBOL-to-Python legacy system migration.

Banks run trillions of dollars in daily transactions on COBOL mainframes. When they migrate, the critical question isn't "does the new code look right?" — it's "does it produce exactly the same results?" Down to the penny, across every field, for every record.

Aletheia answers that question deterministically. No AI in the verification loop. The engine parses COBOL with ANTLR4, generates Python verification models with exact IBM arithmetic (Decimal precision, COMP-3 packed decimal, TRUNC mode compliance), and compares outputs against real mainframe data field by field. Zero tolerance.

The verdict is binary: VERIFIED or REQUIRES_MANUAL_REVIEW. No confidence scores. No percentages. Either you have mathematical proof of behavioral equivalence, or you know exactly what needs human attention.

Current state: 94.3% Program Verification Rate on 459 banking banking programs. 1006+ automated tests, zero failures. Air-gapped Docker deployment for regulated environments.

I'm 15. I build alone. The work is the resume.

Applying to Y Combinator S26.

### First Post

**Announcing Aletheia: Deterministic Behavioral Verification for COBOL Migration**

After months of building, I'm sharing what I've been working on.

Aletheia is a verification engine for COBOL-to-Python migration. Not a translator — a proof system. It answers one question: "Does the migrated code produce exactly the same results as the mainframe?"

The pipeline:
- ANTLR4 parser extracts COBOL logic deterministically
- Python generator emits verification models with IBM-matching Decimal arithmetic
- Shadow Diff compares outputs against mainframe data, field by field, zero tolerance

The verdict is always binary: VERIFIED or REQUIRES_MANUAL_REVIEW. No confidence scores. No "close enough."

Where we are:
- 94.3% of programs verified automatically across 459 banking banking COBOL programs
- 1006+ tests, zero failures
- 30+ COBOL constructs supported (EVALUATE/WHEN, PERFORM VARYING, STRING/UNSTRING, COMP-3, EBCDIC ordering, file I/O)
- Air-gapped deployment — no data leaves the network
- Docker with Cython IP protection

Where we're honest:
- 5.7% of programs still require manual review for unsupported constructs
- This is pre-revenue, solo-built
- Verification, not production migration

The thesis: every AI COBOL translator needs an oracle to prove it works. Aletheia is that oracle.

YC S26 applicant. More to share soon.

---

## 3. YC S26 Reapplication

---

### Company name
Aletheia

### Company URL
[TBD]

### One-liner
Deterministic behavioral verification engine that proves COBOL migration correctness — down to the penny.

### What does your company do?
Aletheia verifies that migrated COBOL systems produce exactly the same results as the mainframe original. We don't translate COBOL — we prove that translations are correct.

The engine parses COBOL source with ANTLR4 (no AI), generates Python verification models with exact IBM arithmetic (Decimal precision, COMP-3 packed decimal, TRUNC/ARITH mode compliance), and compares outputs against real mainframe data field by field. Zero tolerance. The verdict is binary: VERIFIED or REQUIRES_MANUAL_REVIEW.

Banks and insurers spend $2-4M per application on migration testing. Most of that is manual comparison of old vs. new outputs. Aletheia automates the proof for 94.3% of programs in seconds.

### How far along are you?
- Working product: full pipeline from COBOL source to verification verdict
- 94.3% Program Verification Rate on 459 banking banking COBOL programs (avg 243 lines, 8-15 constructs per program)
- 1006+ automated tests across 29 files, zero failures
- 50-entry semantic regression corpus with exact Decimal match verification
- Shadow Diff engine: field-by-field mainframe comparison, streaming pipeline (handles 50GB files, constant RAM)
- Air-gapped Docker deployment with Cython IP protection
- React frontend with 9 pages (Dashboard, Analyze, Verify, Portfolio, Compiler Matrix, Dead Code, SBOM, JCL, Reports)
- CLI for headless CI/CD integration (Jenkins/GitLab/GitHub Actions gatekeeper image)
- Pre-revenue. Solo developer. No funding.

### Why did you pick this idea to work on?
I spent time studying how banks actually handle COBOL migration and realized the bottleneck isn't translation — it's trust. Every bank I researched had the same problem: they could get code translated (by consultants, by AI tools, by hand), but they couldn't prove the translation was correct without months of manual testing.

The existing AI COBOL translators all claim high accuracy, but accuracy is unmeasurable without a verification oracle. If you translate COBOL with an LLM and it "looks right," you don't know if it handles COMP-3 overflow with TRUNC(STD) truncation correctly. You find out in production. At a bank. That's a $200B problem (estimated global COBOL modernization spend) with no verification layer.

I decided to build the verification layer because it's a well-defined problem that rewards precision engineering over scale. One person can build a correct verification engine. One person cannot build a correct COBOL-to-Java transpiler for every dialect.

### What do you understand about your business that other companies in the space don't?

Three things:

**1. Verification is harder to fake than translation.** Every AI COBOL tool demos well on simple programs. The hard part is proving correctness on the constructs LLMs consistently get wrong: COMP-3 overflow behavior, TRUNC mode interactions, EBCDIC string ordering, signed decimal truncation at PIC boundaries. Aletheia handles these deterministically because the parser and generator are deterministic — no LLM in the verification path.

**2. Binary verdicts create trust that percentages never will.** Bank compliance officers don't want "97% confident." They want proof. VERIFIED or REQUIRES_MANUAL_REVIEW. When we flag something, we say exactly what and why. When we verify, it's mathematical — every field, every record, zero tolerance.

**3. The 94.3% that's easy is where the money is.** The remaining 5.7% of programs that need manual review are genuinely hard (EVALUATE ALSO, complex INSPECT patterns, variable-length records). But the 94.3% that can be verified automatically is what banks currently spend millions testing by hand. Automating the easy majority is the business; being honest about the hard minority is what builds trust.

### Who writes code, or does other technical work on your product?
Solo founder. I write all the code — backend (Python/FastAPI), parser (ANTLR4), generator, arithmetic engine, frontend (React), tests, Docker deployment, CLI. 1006+ tests, all written by me. 15 years old.

### How do or will you make money?
Per-verification pricing for banks and system integrators:
- Per-program verification fee (analyze + verify + report)
- Enterprise license with daily analysis limits and feature flags (license system already built with RSA-PSS signing)
- CI/CD gatekeeper image for continuous verification in migration pipelines (Docker image already built)
- Volume pricing for portfolio-scale verification (200+ programs)

Initial target: system integrators (Accenture, TCS, Infosys, Deloitte) who do COBOL migration projects and need to prove correctness to their bank clients. They have the budget and the immediate pain point.

### How will you get your first 10 customers?
1. **Direct outreach to SI migration teams.** System integrators running active COBOL migration projects at banks. They're spending months on manual verification right now. I'll offer to verify their next batch of programs for free to prove the tool works on their actual codebase.
2. **Open-source verification reports.** Publish anonymized verification reports showing Shadow Diff catching real drift (we have demo data with intentional mismatches). Technical credibility for the engineering teams who evaluate tools.
3. **Show HN / technical community.** COBOL migration is a surprisingly active topic on HN. The contrarian angle (verification, not translation) and the age factor will generate discussion.
4. **Bank modernization conferences.** COBOL modernization is a recurring topic at banking technology conferences. Present Aletheia as the verification layer that sits between any translator and production.

### What is something surprising you have learned about your market?
Banks don't actually want AI to translate their COBOL. They want proof that whatever translates it — human, AI, or hybrid — produced correct output. The translation method is negotiable. The correctness proof is not.

Every bank CTO I've read about says some version of: "We can get the code translated. We can't get it verified fast enough." The verification bottleneck, not the translation bottleneck, is what delays migrations by years and inflates costs by millions.

The other surprise: COBOL programs are far more consistent than people think. 94.3% of banking COBOL uses the same 30 constructs in predictable patterns. The "COBOL is infinitely complex" narrative is overstated. The hard 5.7% is genuinely hard, but the easy 94.3% is genuinely easy — if you have the right parser.

### Anything else you want to tell us?
I'm 15. I've been building Aletheia solo for months. No team, no funding, no CS degree, no internship. The code is the credential.

What I've built is a working verification engine with 1006+ tests, 94.3% PVR on real-scale programs, and deployment-ready Docker packaging. It's not a prototype — it handles COMP-3 packed decimal, EBCDIC string ordering, compiler-specific TRUNC modes, file I/O with abstract backends, and dozens of other constructs that matter for real banking COBOL.

What I haven't built is a sales pipeline. I need help turning a working technical product into a business. That's why I'm applying to YC.

The name means "truth" in Greek. The product delivers it.
