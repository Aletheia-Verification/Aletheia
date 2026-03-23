# ALETHEIA — Classified Technical Document

**Classification: INTERNAL — FOR STUDY ONLY**
**Version: 1.0 | March 2026**
**Prepared for: Hector Gras**

---

> *"The question is not whether the Python code looks right.*
> *The question is whether it behaves identically to the mainframe."*

---

# Table of Contents

1. [What Aletheia Is](#part-1-what-aletheia-is)
2. [COBOL Crash Course](#part-2-cobol-crash-course)
3. [The Pipeline Deep Dive](#part-3-the-pipeline-deep-dive)
4. [The Supporting Modules](#part-4-the-supporting-modules)
5. [Every Fix and Why](#part-5-every-fix-and-why)
6. [The Audit Results](#part-6-the-audit-results)
7. [The Business](#part-7-the-business)
8. [Glossary](#part-8-glossary)

---

# Part 1: What Aletheia Is

## The $3 Trillion Problem

Banks run on COBOL. Not a little bit — almost all of it. Here are the numbers:

- **220 billion lines** of COBOL code are running in production today
- **95%** of ATM transactions touch COBOL
- **80%** of in-person payment processing runs on COBOL
- **$3 trillion** in daily commerce flows through COBOL systems
- The average COBOL programmer is **over 55 years old** and retiring

These systems were written in the 1960s through 1990s. They run on IBM mainframes — refrigerator-sized computers that cost $10 million each. Banks want to move to modern cloud infrastructure (Python, Java, Kubernetes), but they can't just rewrite 220 billion lines of code.

Why? Because COBOL handles money. And money demands perfection.

If you migrate a banking system and introduce a 1-cent rounding error on each of 1 billion daily transactions, that's **$10 million per day** in unexplained discrepancies. Regulators shut the bank down. Customers sue. The migration team gets fired.

This is why every large COBOL migration attempt in history has either failed spectacularly (like the UK's TSB bank in 2018, which lost access to 1.9 million accounts) or taken 5-10 years to complete.

## The Insight: Verify, Don't Translate

Every other company in this space tries to **translate** COBOL to Python using AI. They feed the COBOL into GPT-4 or a fine-tuned model and get Python code out. The code looks reasonable. It might even pass some tests. But it has subtle precision bugs — the kind that surface after processing 10 million real transactions.

Aletheia takes a fundamentally different approach. We don't care if the Python "looks" right. We care if it **behaves identically** to the mainframe.

The process:

1. Parse the COBOL using a formal grammar (no AI involved)
2. Generate Python deterministically from the parse tree (no AI involved)
3. Feed the same real input data to both the mainframe and the Python
4. Compare every output field to the exact penny
5. If they match perfectly: **VERIFIED**. If even one field differs: **DRIFT DETECTED**.

No confidence scores. No percentages. No "probably correct." Binary verdict: it matches, or it doesn't.

## The Pipeline

```
┌──────────┐    ┌───────────┐    ┌──────────────┐    ┌──────────────┐
│  COBOL   │───>│  ANTLR4   │───>│   PYTHON     │───>│  SHADOW      │
│  SOURCE  │    │  PARSER   │    │  GENERATOR   │    │  DIFF        │
│  (.cbl)  │    │           │    │              │    │  ENGINE      │
└──────────┘    └───────────┘    └──────────────┘    └──────┬───────┘
                     │                  │                     │
                     ▼                  ▼                     ▼
              ┌─────────────┐   ┌─────────────┐   ┌─────────────────┐
              │ Analysis    │   │ Python      │   │ VERIFIED        │
              │ Dict        │   │ Module      │   │ or              │
              │ (structured │   │ (executable │   │ DRIFT DETECTED  │
              │  data)      │   │  code)      │   │ (with causes)   │
              └─────────────┘   └─────────────┘   └─────────────────┘
```

The key insight is that **AI is never in the correctness path**. The parser uses a formal ANTLR4 grammar (same technology that powers Java and Kotlin compilers). The generator is a deterministic rule-based transformer. The comparator does exact decimal matching.

GPT-4o is only used for one thing: formatting human-readable explanations after the verification is complete. It can't affect the VERIFIED/DRIFT verdict.

## Why This Matters

```
  Competitors (AI Translation):        Aletheia (Behavioral Verification):
  ┌────────┐     ┌─────────┐           ┌────────┐     ┌───────────┐
  │ COBOL  │────>│ AI/LLM  │──> Python │ COBOL  │────>│ PARSER +  │──> Python
  └────────┘     └─────────┘    (hope   └────────┘     │ GENERATOR │    (proven
                                 it's                   └───────────┘     match)
                                 right)                      │
                                          ┌─────────┐       ▼
                                          │MAINFRAME│──>┌──────────┐
                                          │ OUTPUT  │   │ COMPARE  │──> PROOF
                                          └─────────┘──>└──────────┘
```

Banks don't need another translation tool. They need **proof that the migration is safe**. That's what Aletheia provides.

---

# Part 2: COBOL Crash Course

Before you can understand how Aletheia works, you need to understand what COBOL looks like and why it's hard to work with. This section teaches you enough COBOL to read every example in this document.

## What COBOL Looks Like

COBOL was designed in 1959 by a team led by Grace Hopper. It was intentionally designed to read like English, so that business managers could understand the programs. Every COBOL program has four sections (called "DIVISIONS"):

```
┌─────────────────────────────────────────────────┐
│ IDENTIFICATION DIVISION.                         │  ← "Who am I?"
│   PROGRAM-ID. LOAN-INTEREST-CALC.                │     (program name)
├─────────────────────────────────────────────────┤
│ ENVIRONMENT DIVISION.                            │  ← "What external
│   SELECT LOAN-FILE ASSIGN TO 'LOANS.DAT'        │     files do I use?"
├─────────────────────────────────────────────────┤
│ DATA DIVISION.                                   │  ← "What variables
│   WORKING-STORAGE SECTION.                       │     do I have?"
│   01 WS-AMOUNT PIC S9(9)V99 COMP-3.             │
│   01 WS-RATE   PIC 9V9(4).                      │
├─────────────────────────────────────────────────┤
│ PROCEDURE DIVISION.                              │  ← "What do I DO?"
│   COMPUTE WS-INTEREST = WS-AMOUNT * WS-RATE     │     (the logic)
│   DISPLAY WS-INTEREST                            │
│   STOP RUN.                                      │
└─────────────────────────────────────────────────┘
```

Here's Aletheia's primary test file — a real loan interest calculator:

```cobol
IDENTIFICATION DIVISION.
   PROGRAM-ID. LOAN-INTEREST-CALC.

   DATA DIVISION.
   WORKING-STORAGE SECTION.

   01 WS-ACCOUNT-DATA.
      05 WS-ACCOUNT-NUM        PIC X(10).
      05 WS-PRINCIPAL-BAL      PIC S9(9)V99 COMP-3.
      05 WS-ANNUAL-RATE        PIC S9(3)V9(6) COMP-3.
      05 WS-DAYS-IN-YEAR       PIC 9(3) VALUE 365.
      05 WS-ACCRUED-INT        PIC S9(9)V99 COMP-3.

   01 WS-ACCOUNT-FLAGS.
      05 WS-VIP-FLAG           PIC X(1).
         88 IS-VIP-ACCOUNT     VALUE 'Y'.
         88 IS-STANDARD        VALUE 'N'.
      05 WS-RATE-DISCOUNT      PIC S9(1)V9(4) COMP-3.

   PROCEDURE DIVISION.

   0000-MAIN-PROCESS.
       PERFORM 1000-INIT-CALCULATION
       PERFORM 2000-COMPUTE-DAILY-RATE
       PERFORM 3000-APPLY-VIP-DISCOUNT
       PERFORM 4000-CALCULATE-INTEREST
       PERFORM 5000-CHECK-LATE-PENALTY
       PERFORM 6000-FINALIZE-AMOUNT
       STOP RUN.
```

Let's break down every piece of this.

## DATA DIVISION: PIC Clauses (The Memory Ruler)

In Python, you write `x = 42` and Python figures out that x is an integer. COBOL is the opposite — you must declare exactly how much memory each variable gets, down to the digit.

The **PIC clause** (short for "PICTURE") is how COBOL declares the size and type of every variable. Think of it as a ruler that measures exactly how many digits the variable can hold:

```
PIC S9(5)V99  means:

  S         9(5)           V          99
  │         │              │          │
  sign      5 integer      decimal    2 decimal
  (+/-)     digits         point      digits
                           (implied,
                            not stored)

  This variable can hold: -99999.99 to +99999.99
  And NOTHING bigger. If you try to store 100000.00, it wraps around.
```

Here's a reference table:

| PIC Clause | Type | Can Hold | Example Value |
|---|---|---|---|
| `PIC 9(5)` | Unsigned integer | 0 to 99999 | `12345` |
| `PIC S9(5)` | Signed integer | -99999 to +99999 | `-12345` |
| `PIC S9(5)V99` | Signed decimal | -99999.99 to +99999.99 | `-12345.67` |
| `PIC X(10)` | Text string | 10 characters | `"HELLO     "` |
| `PIC 9(3) VALUE 365` | With default | 0 to 999, starts at 365 | `365` |
| `PIC S9(1)V9(4)` | Small decimal | -9.9999 to +9.9999 | `0.0025` |

**Critical insight**: The `V` in a PIC clause is an *implied* decimal point. It's never stored in memory — the program just knows that the last 2 digits are decimal places. The number `-12345.67` is stored as the digits `1234567` with the sign embedded.

## Levels and Groups (Nested Data Structures)

COBOL uses level numbers to create nested structures, like folders within folders:

```
01 WS-CUSTOMER.                     ← GROUP (level 01, contains everything below)
   05 WS-NAME        PIC X(20).     ← FIELD (level 05, 20-char text)
   05 WS-ACCOUNT.                   ← SUB-GROUP (level 05, contains 10-level items)
      10 WS-ACCT-NUM  PIC 9(8).     ← FIELD (level 10, 8-digit number)
      10 WS-ACCT-TYPE PIC X(1).     ← FIELD (level 10, 1 character)
   05 WS-BALANCE     PIC S9(9)V99.  ← FIELD (level 05, signed decimal)
```

Think of it like a folder structure:

```
📁 WS-CUSTOMER (group — all 30 bytes)
 ├── 📄 WS-NAME (20 bytes)
 ├── 📁 WS-ACCOUNT (sub-group — 9 bytes)
 │    ├── 📄 WS-ACCT-NUM (8 bytes)
 │    └── 📄 WS-ACCT-TYPE (1 byte)
 └── 📄 WS-BALANCE (11 bytes)
```

**Level 88** is special — it's not a variable at all. It's a named condition (like a boolean test):

```cobol
01 WS-VIP-FLAG       PIC X(1).
   88 IS-VIP-ACCOUNT  VALUE 'Y'.     ← means: WS-VIP-FLAG == 'Y'
   88 IS-STANDARD     VALUE 'N'.     ← means: WS-VIP-FLAG == 'N'
```

When the COBOL says `IF IS-VIP-ACCOUNT`, it really means `IF WS-VIP-FLAG = 'Y'`. The 88-level is just syntactic sugar — a named test on its parent.

## PROCEDURE DIVISION: How COBOL Programs Execute

COBOL organizes code into **paragraphs** (like functions). The main entry point calls other paragraphs using `PERFORM`:

```cobol
0000-MAIN-PROCESS.
    PERFORM 1000-INIT-CALCULATION      ← Call a paragraph (like a function call)
    PERFORM 2000-COMPUTE-DAILY-RATE
    PERFORM 3000-APPLY-VIP-DISCOUNT
    STOP RUN.                          ← End the program

2000-COMPUTE-DAILY-RATE.
    COMPUTE WS-DAILY-RATE =            ← Compute with full precision
       WS-ANNUAL-RATE / WS-DAYS-IN-YEAR.

3000-APPLY-VIP-DISCOUNT.
    IF IS-VIP-ACCOUNT                  ← 88-level condition test
       COMPUTE WS-DAILY-RATE =
          WS-DAILY-RATE - WS-RATE-DISCOUNT
       IF WS-DAILY-RATE < 0
          MOVE 0 TO WS-DAILY-RATE      ← Floor at zero
       END-IF
    END-IF.
```

Key COBOL verbs:
- **PERFORM**: Call a paragraph (like calling a function)
- **COMPUTE**: Do math with full precision, then truncate on store
- **MOVE**: Copy a value from one variable to another
- **IF / ELSE / END-IF**: Conditional logic
- **EVALUATE / WHEN / WHEN OTHER**: Like a switch statement
- **ADD / SUBTRACT / MULTIPLY / DIVIDE**: Explicit arithmetic
- **GO TO**: Jump to a paragraph (dangerous, but used everywhere in old code)
- **STOP RUN**: End the program
- **DISPLAY**: Print to the console

## Data Types: DISPLAY vs COMP vs COMP-3

This is where COBOL gets tricky. The same number can be stored in completely different byte formats depending on the storage type:

### DISPLAY (default — human-readable)

One byte per digit, using EBCDIC encoding. The sign is embedded in the last byte using a technique called "overpunch":

```
Value: -12345  in PIC S9(5) DISPLAY

┌──────┬──────┬──────┬──────┬──────┐
│  F1  │  F2  │  F3  │  F4  │  D5  │  = 5 bytes
└──────┴──────┴──────┴──────┴──────┘
  '1'    '2'    '3'    '4'   '-5'
                              ↑
                         D = negative sign
                         F = positive/unsigned
                         C = positive (explicit)
```

The last byte encodes both the digit AND the sign. `F5` means positive 5, `D5` means negative 5. This encoding is called "zoned decimal" or "overpunch."

### COMP-3 (Packed Decimal — the important one)

Two digits per byte, with the sign in the last half-byte (nibble). This is how most numeric fields are stored on mainframes because it saves space:

```
Value: +12345.67  in PIC S9(5)V99 COMP-3

Step 1: Remove the implied decimal point → 1234567
Step 2: Pack two digits per byte, sign in last nibble

┌──────────┬──────────┬──────────┬──────────┐
│   01     │   23     │   45     │  67  C   │  = 4 bytes
│ (0)(1)   │ (2)(3)   │ (4)(5)   │ (6)(7)↑  │
└──────────┴──────────┴──────────┴─────────┘
                                       │
                               C = positive (0x0C)
                               D = negative (0x0D)
                               F = unsigned  (0x0F)

DISPLAY stores 12345.67 in 7 bytes (one per digit)
COMP-3  stores 12345.67 in 4 bytes (saves 43%!)
```

Aletheia's COMP-3 decoder (from `shadow_diff.py`) processes this byte-by-byte:

```python
def decode_comp3(raw_bytes: bytes, decimals: int = 0) -> Decimal:
    """Decode IBM COMP-3 (packed BCD) bytes to Decimal."""
    if not raw_bytes:
        return Decimal("0")

    nibbles = []
    for b in raw_bytes:
        nibbles.append((b >> 4) & 0x0F)   # high nibble (first digit)
        nibbles.append(b & 0x0F)           # low nibble  (second digit)

    sign_nibble = nibbles[-1]               # last nibble is the sign
    digit_nibbles = nibbles[:-1]            # everything else is digits

    digits_str = "".join(str(n) for n in digit_nibbles)

    if decimals > 0 and len(digits_str) > decimals:
        integer_part = digits_str[:-decimals]
        decimal_part = digits_str[-decimals:]
        num_str = f"{integer_part}.{decimal_part}"
    elif decimals > 0:
        num_str = f"0.{digits_str.zfill(decimals)}"
    else:
        num_str = digits_str

    result = Decimal(num_str)

    if sign_nibble == 0x0D:       # 0x0D = negative
        result = -result

    return result
```

### COMP / COMP-4 (Pure Binary)

Stored as big-endian binary integers, just like how computers normally store numbers:

```
PIC S9(4)  COMP → 2 bytes (halfword, max 32,767)
PIC S9(9)  COMP → 4 bytes (fullword, max 2,147,483,647)
PIC S9(18) COMP → 8 bytes (doubleword)

Value: 12345 in PIC S9(9) COMP:
┌──────────┬──────────┬──────────┬──────────┐
│    00    │    00    │    30    │    39    │  = 4 bytes
└──────────┴──────────┴──────────┴──────────┘
= 0x00003039 = 12345 in big-endian binary
```

## EBCDIC: Why String Comparison Is Broken

Mainframes don't use ASCII. They use EBCDIC (Extended Binary Coded Decimal Interchange Code), which was invented by IBM in 1963. The critical difference is the **collating sequence** — the order characters are sorted in:

```
ASCII  (what Python uses natively):   EBCDIC (what mainframes use):
┌──────────────────────────────┐      ┌──────────────────────────────┐
│ space  (0x20)  LOWEST        │      │ space  (0x40)  LOWEST        │
│ '0'-'9' (0x30-0x39)         │      │ 'a'-'z' (0x81-0xA9)         │
│ 'A'-'Z' (0x41-0x5A)         │      │ 'A'-'Z' (0xC1-0xE9)         │
│ 'a'-'z' (0x61-0x7A)  HIGHEST│      │ '0'-'9' (0xF0-0xF9)  HIGHEST│
└──────────────────────────────┘      └──────────────────────────────┘
```

This means:
- In ASCII: `'9' > 'Z'` is **FALSE** (0x39 < 0x5A)
- In EBCDIC: `'9' > 'Z'` is **TRUE** (0xF9 > 0xE9)
- In ASCII: `'a' < 'A'` is **FALSE** (0x61 > 0x41)
- In EBCDIC: `'a' < 'A'` is **TRUE** (0x81 < 0xC1)

If you generate Python that uses normal Python string comparison (`if name_a > name_b`), you get WRONG answers for any string comparison that involves mixed case or digits. The Shadow Diff engine would catch this as DRIFT.

Aletheia solves this with `ebcdic_compare()` — a function that encodes both strings to EBCDIC bytes before comparing:

```python
def ebcdic_compare(a: str, b: str, codepage: str = "cp037") -> int:
    """Compare two strings using EBCDIC byte ordering."""
    max_len = max(len(a), len(b))
    a_bytes = a.ljust(max_len).encode(codepage)  # pad shorter string with spaces
    b_bytes = b.ljust(max_len).encode(codepage)
    if a_bytes < b_bytes:
        return -1
    if a_bytes > b_bytes:
        return 1
    return 0
```

Notice the `.ljust(max_len)` — in COBOL, when you compare strings of different lengths, the shorter one is padded with spaces. This matches mainframe behavior.

## REDEFINES: One Memory, Two Views

REDEFINES lets two variables share the exact same bytes in memory. It's like a C `union` — different interpretations of the same raw data:

```cobol
01 WS-DATE.
   05 WS-DATE-TEXT    PIC X(8).          ← "20260317" (text view)
01 WS-DATE-PARTS REDEFINES WS-DATE.
   05 WS-YEAR         PIC 9(4).          ← 2026
   05 WS-MONTH        PIC 9(2).          ← 03
   05 WS-DAY          PIC 9(2).          ← 17

Memory (same 8 bytes, two different views):
┌────┬────┬────┬────┬────┬────┬────┬────┐
│ '2'│ '0'│ '2'│ '6'│ '0'│ '3'│ '1'│ '7'│
└────┴────┴────┴────┴────┴────┴────┴────┘
├──── WS-DATE-TEXT (all 8 bytes) ────────┤
├── WS-YEAR ──┤├─ MONTH ─┤├── DAY ──┤
```

Write to WS-DATE-TEXT and WS-YEAR/WS-MONTH/WS-DAY automatically change, because they're reading the same memory. This is heavily used in banking COBOL and is extremely tricky to replicate in Python (Aletheia uses `CobolMemoryRegion` — a shared byte buffer).

## Compiler Options: TRUNC Mode

IBM mainframes have compiler flags that change how arithmetic works. The most important one is **TRUNC** (truncation mode):

```
When you do: COMPUTE WS-RESULT = BIG-NUMBER * BIG-NUMBER
             and the result doesn't fit in WS-RESULT's PIC...

┌──────── What TRUNC mode? ─────────┐
│                                    │
▼                ▼                   ▼
STD              BIN                 OPT
(Standard)       (Binary)            (Optimized)
│                │                   │
│ Mod PIC cap    │ Is it COMP?       │ No truncation
│ (wrap around)  │  YES: keep full   │ (trust the
│                │  NO:  mod PIC     │  programmer)
│                │                   │
▼                ▼                   ▼
S9(3): max 999   S9(4) COMP:        Result passes
1500 → 500       max 32767          through as-is
(1500 mod 1000)  (full halfword)    ⚠️ DANGEROUS
```

**TRUNC(STD)** is the IBM default. If a number overflows the PIC capacity, it wraps around using modular arithmetic. This is not a bug — it's intentional mainframe behavior that every bank relies on. If Aletheia doesn't replicate this wrapping, the Shadow Diff shows drift.

## Why COBOL Is Hard to Migrate

Now you understand enough to see why migration is treacherous:

1. **Truncation on store, not during computation**: COBOL does math with full precision, but truncates (chops off excess digits) only when storing the result. Most Python programmers would truncate during computation, giving different results.

2. **COMP-3 packed decimal**: There's no Python equivalent. You need a custom class that packs/unpacks nibbles.

3. **EBCDIC collating sequence**: Python string comparison gives wrong answers for any program that sorts or compares strings.

4. **Fixed-point arithmetic**: COBOL never uses floating-point. Everything is `Decimal` with explicit precision. Using Python `float` anywhere would introduce rounding errors.

5. **REDEFINES**: Two variables sharing memory means changing one changes the other. Python doesn't have this concept natively.

6. **PIC-based overflow wrapping**: `PIC 9(3)` holding the value 1500 wraps to 500. This is correct mainframe behavior that must be replicated exactly.

7. **Zoned decimal overpunch**: The sign of a number is embedded in the last digit byte. Parsing this wrong gives wrong results.

---

# Part 3: The Pipeline Deep Dive

This section explains every module in Aletheia's pipeline — what it does, what goes in, what comes out, the key design decisions, and the known limitations.

## Module 1: ANTLR Parser (`cobol_analyzer_api.py`, ~1,900 lines)

### What It Does

Takes raw COBOL source code and produces a structured analysis dictionary. Uses the ANTLR4 COBOL85 formal grammar — the same kind of parser technology that powers Java and Kotlin compilers.

### How It Works

```
INPUT                          PROCESS                      OUTPUT
┌──────────────────┐   ┌─────────────────────┐   ┌──────────────────────┐
│ COBOL source     │   │ 1. Lexer splits     │   │ analysis dict:       │
│ (raw text)       │──>│    into tokens      │──>│  variables: [...]    │
│                  │   │ 2. Parser builds    │   │  paragraphs: [...]   │
│                  │   │    parse tree       │   │  computes: [...]     │
│                  │   │ 3. FullAnalyzer     │   │  level_88: [...]     │
│                  │   │    walks tree and   │   │  file_operations: [] │
│                  │   │    fires listeners  │   │  control_flow: [...]  │
└──────────────────┘   └─────────────────────┘   └──────────────────────┘
```

The parser uses the **Listener pattern**. Instead of manually walking the tree, ANTLR4 automatically fires callback methods for every node type it encounters:

- `enterComputeStatement()` fires for every COMPUTE
- `enterIfStatement()` fires for every IF
- `enterMoveStatement()` fires for every MOVE
- `enterPerformStatement()` fires for every PERFORM
- ... and dozens more

The `FullAnalyzer` class implements all these listeners and collects everything into a single analysis dictionary.

### Key Function: parse_pic_clause()

This function converts a PIC string into structured metadata:

```python
def parse_pic_clause(pic_raw):
    """
    Parse a PIC clause string into structured metadata.
    Examples:
        "S9(5)V99"   -> {signed:True,  integers:5,  decimals:2}
        "9(3)"       -> {signed:False, integers:3,  decimals:0}
        "X(10)"      -> None  (string type — no arithmetic analysis)
    """
    upper = pic_raw.upper().strip()
    if not upper or 'X' in upper or 'Z' in upper:
        return None  # String type — skip arithmetic analysis

    signed = upper.startswith('S')
    if signed:
        upper = upper[1:]

    int_part, dec_part = (upper.split('V', 1) if 'V' in upper else (upper, ''))

    def count_nines(part):
        return sum(
            int(m.group(1)) if m.group(1) else 1
            for m in re.finditer(r'9(?:\((\d+)\))?', part)
        )

    integers = count_nines(int_part)
    decimals = count_nines(dec_part) if dec_part else 0

    max_str = '9' * integers + ('.' + '9' * decimals if decimals else '')
    max_val = Decimal(max_str)
    return {
        "signed": signed,
        "integers": integers,
        "decimals": decimals,
        "max_value": str(max_val),
    }
```

So `PIC S9(5)V99` becomes `{signed: True, integers: 5, decimals: 2, max_value: "99999.99"}`.

### The Analysis Dict (Output Structure)

The parser produces a dictionary with everything the generator needs:

| Key | What It Contains |
|---|---|
| `variables` | Every variable declaration: name, PIC, storage type, section |
| `paragraphs` | List of paragraph names |
| `paragraphs_full` | Full paragraph contents with every statement |
| `computes` | Every COMPUTE statement with its text and paragraph |
| `level_88` | Every 88-level condition: name, parent, value |
| `performs` | Every PERFORM statement: target paragraph, type (THRU, VARYING, etc.) |
| `moves` | Every MOVE statement |
| `arithmetics` | ADD, SUBTRACT, MULTIPLY, DIVIDE statements |
| `conditions` | IF/EVALUATE structures (nested) |
| `file_operations` | OPEN, READ, WRITE, CLOSE, REWRITE, SORT |
| `control_flow` | GO TO, STOP RUN, EXIT statements |
| `strings` | STRING/UNSTRING/INSPECT statements |
| `displays` | DISPLAY statements |
| `sort_statements` | SORT with USING/GIVING or INPUT/OUTPUT PROCEDURE |
| `release_statements` | RELEASE (for SORT INPUT PROCEDURE) |
| `return_statements` | RETURN (for SORT OUTPUT PROCEDURE) |

### Design Decisions

**Why Listener, not Visitor?** COBOL has hundreds of grammar rules (the ANTLR4 grammar file is over 10,000 lines). With a Listener, ANTLR automatically calls the right method for every node — you don't need to write traversal code. With a Visitor, you'd need to manually visit every child, which is error-prone for such a complex grammar.

**Why not just use regex?** COBOL has deeply nested structures (IF inside EVALUATE inside PERFORM THRU ranges). Regex can't handle nesting — you need a proper parser. ANTLR4 is the industry standard.

### Limitations

If the parser encounters a construct it doesn't recognize, it logs a `parse_warning` and continues. The generator will later emit `# MANUAL REVIEW` for anything it can't safely handle. Nothing is silently skipped — every unrecognized construct is tracked.

---

## Module 2: Code Generator (`generate_full_python.py`, ~3,900 lines)

### What It Does

Takes the analysis dictionary from the parser and emits a complete, executable Python module. This is the largest file in Aletheia (3,900 lines) because it handles every COBOL construct.

### How It Works

```
INPUT                          PROCESS                       OUTPUT
┌──────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ analysis dict    │   │ 1. Build var_info    │   │ Python module:       │
│ (from parser)    │──>│ 2. Build 88-level map│──>│  - imports           │
│                  │   │ 3. Emit variables    │   │  - CobolDecimal vars │
│ + compiler       │   │ 4. Emit paragraphs   │   │  - paragraph funcs   │
│   config         │   │ 5. Emit main()       │   │  - main() function   │
│ (TRUNC mode)     │   │ 6. Emit validation   │   │  - validation report │
└──────────────────┘   └──────────────────────┘   └──────────────────────┘
```

### COBOL → Python Transformation (The Key Concept)

This is the heart of Aletheia. Here's how a COBOL variable declaration becomes Python:

```
COBOL:                                  PYTHON:
┌────────────────────────────────┐      ┌─────────────────────────────────────┐
│ 05 WS-PRINCIPAL-BAL            │      │ ws_principal_bal = CobolDecimal(    │
│    PIC S9(9)V99 COMP-3.       │ ──>  │     '0',                            │
│                                │      │     pic_integers=9,                 │
│                                │      │     pic_decimals=2,                 │
│                                │      │     is_signed=True,                 │
│                                │      │     is_comp=True)                   │
└────────────────────────────────┘      └─────────────────────────────────────┘
```

And here's how a COMPUTE becomes Python:

```
COBOL:                                  PYTHON:
┌────────────────────────────────┐      ┌─────────────────────────────────────┐
│ COMPUTE WS-DAILY-RATE =       │      │ _temp = ws_annual_rate.value        │
│    WS-ANNUAL-RATE /           │ ──>  │         / ws_days_in_year.value     │
│    WS-DAYS-IN-YEAR.           │      │ ws_daily_rate.store(_temp)          │
└────────────────────────────────┘      └─────────────────────────────────────┘
```

Notice the critical pattern: **compute with full precision** using `.value` (raw Decimal), then **truncate on store** using `.store()`. This matches exactly how IBM mainframes work — arithmetic happens at maximum precision, truncation only happens when the result is stored in the target variable.

### Arithmetic Risk Analysis

The generator analyzes every arithmetic operation for overflow risk:

| Operation | Result Digits | Risk Level | Example |
|---|---|---|---|
| ADD / SUB | max(A, B) + 1 | SAFE if result fits PIC | 5-digit + 5-digit = 6 digits max |
| MULTIPLY | A + B | WARN if close to PIC | 5-digit × 3-digit = 8 digits max |
| DIVIDE | unbounded | CRITICAL | denominator could approach 0 |

Each operation is classified as **SAFE** (result always fits), **WARN** (could overflow under certain inputs), or **CRITICAL** (overflow is likely or unbounded).

### The Side-by-Side Validation Report

Every generated Python module includes a comment block at the end that shows the COBOL → Python mapping for every statement:

```python
# ═══════════════════════════════════════════════════════════════
# SIDE-BY-SIDE VALIDATION REPORT
# ═══════════════════════════════════════════════════════════════
# COBOL Statement                          Python Equivalent              Status
# ────────────────────────────────────── ──────────────────────────────── ──────
# COMPUTE WS-DAILY-RATE = WS-ANNUAL-RAT ws_daily_rate.store(ws_annual_r [OK]
# IF IS-VIP-ACCOUNT                      if ws_vip_flag == 'Y':          [OK]
# MOVE 0 TO WS-DAILY-RATE               ws_daily_rate.store(Decimal('0' [OK]
# ADD WS-DAILY-INTEREST TO WS-ACCRUED-I ws_accrued_int.store(ws_accrued [OK]
```

This lets a human auditor quickly verify that every COBOL statement has a corresponding Python implementation.

### What Triggers MANUAL REVIEW

When the generator encounters a construct it can't safely emit as Python, it writes a comment instead of generating wrong code:

```python
# MANUAL REVIEW: ALTER — dynamic paragraph modification not supported
# MANUAL REVIEW: EXEC SQL SELECT INTO :WS-BALANCE — external system coupling
```

This is a **hard architectural decision**: it's better to flag something for human review than to generate code that might be wrong. A bank losing money because of a subtle bug is far worse than a bank needing to manually handle 6 programs out of 100.

### Return Format

```python
generate_python_module(analysis, compiler_config) -> {
    "code": str,              # Complete Python module text
    "emit_counts": {          # How many of each statement type were emitted
        "move": 12, "compute": 5, "add_sub": 3,
        "perform": 8, "io": 4, ...
    },
    "compiler_warnings": [],  # Warnings about TRUNC mode, etc.
    "db2_tainted_fields": [], # Fields populated by EXEC SQL
}
```

---

## Module 3: Parse Conditions (`parse_conditions.py`, ~1,700 lines)

### What It Does

Converts COBOL IF/ELSE and EVALUATE/WHEN conditions into Python boolean expressions. This is where 88-level conditions, EBCDIC comparisons, and array subscript access get resolved.

### How It Works

The ANTLR parser gives us the raw condition text (e.g., `WS-AMT>100ANDIS-VIP-ACCOUNT`). This module breaks that apart and generates the Python equivalent.

| COBOL Condition | Python Output | What Happened |
|---|---|---|
| `IF WS-AMT > 100` | `if ws_amt.value > Decimal('100'):` | Numeric comparison uses `.value` |
| `IF WS-FLAG = 'Y'` | `if ws_flag == 'Y':` | String comparison, no `.value` |
| `IF IS-VIP-ACCOUNT` | `if ws_vip_flag == 'Y':` | 88-level expanded to parent test |
| `IF WS-TBL(WS-IDX) < 50` | `if ws_tbl[int(ws_idx.value)-1].value < Decimal('50'):` | 1-indexed → 0-indexed |
| `IF WS-NAME > WS-OTHER` | `if ebcdic_compare(ws_name, ws_other) > 0:` | EBCDIC-aware string ordering |
| `IF WS-AMT IS NUMERIC` | `if isinstance(ws_amt.value, Decimal):` | Class condition test |

### Key Design Decision: Longest-Match-First

When resolving variable names in a condition, the module sorts known variables by length (longest first). This prevents `WS-FOO` from matching inside `WS-FOO-BAR`. Without this, `IF WS-FOO-BAR > 10` would incorrectly resolve as `ws_foo` followed by garbage.

### How EVALUATE Is Handled

COBOL's `EVALUATE` is like a switch statement, but more powerful:

```cobol
EVALUATE TRUE                         →  Python:
  WHEN WS-BALANCE > 100000                if ws_balance.value > Decimal('100000'):
    PERFORM HIGH-VALUE-PROCESS                high_value_process()
  WHEN WS-BALANCE > 10000                 elif ws_balance.value > Decimal('10000'):
    PERFORM MED-VALUE-PROCESS                 med_value_process()
  WHEN OTHER                               else:
    PERFORM LOW-VALUE-PROCESS                 low_value_process()
END-EVALUATE
```

---

## Module 4: COBOL Types (`cobol_types.py`, ~690 lines)

### What It Does

This is the precision engine — the most important module for correctness. `CobolDecimal` wraps Python's `Decimal` to enforce PIC-based truncation rules exactly as IBM mainframes do.

### The Core Class: CobolDecimal

```python
class CobolDecimal:
    def __init__(self, value='0', pic_integers=1, pic_decimals=0,
                 is_signed=False, is_comp=False):
        self.pic_integers = pic_integers
        self.pic_decimals = pic_decimals
        self.is_signed = is_signed
        self.is_comp = is_comp
        self._scale = Decimal(10) ** -pic_decimals if pic_decimals > 0 else Decimal(1)
        self._max_int = Decimal(10) ** pic_integers
        self.value = Decimal('0')
        self.store(value)
```

The `.store()` method is the critical method — it applies PIC truncation:

```python
def store(self, value):
    # Convert to Decimal regardless of input type
    raw = Decimal(str(value))
    # Apply truncation (the important part)
    self.value = self._apply_truncation(raw)
```

And `_apply_truncation()` implements the TRUNC mode logic:

```python
def _apply_truncation(self, raw):
    config = get_config()  # Get current TRUNC mode

    # Step 1: Quantize to PIC decimal places (ALWAYS, all modes)
    raw = raw.quantize(self._scale, rounding=ROUND_DOWN)

    # Step 2: Mode-specific integer truncation
    if config.trunc_mode == "OPT":
        # Compiler trusts programmer — no integer truncation
        return raw

    if config.trunc_mode == "BIN" and self.is_comp:
        # COMP items keep full binary range — no mod truncation
        return raw

    # TRUNC(STD) — standard: mod to PIC capacity
    if abs(raw) >= self._max_int:
        sign = Decimal('-1') if raw < 0 else Decimal('1')
        integer_part = abs(raw) // 1
        decimal_part = abs(raw) % 1
        truncated_int = integer_part % self._max_int  # THE MOD OPERATION
        raw = sign * (truncated_int + decimal_part)

    return raw
```

### Worked Example: Truncation in Action

```
PIC S9(3)V99, TRUNC(STD):

Input value: 123456.789
  Step 1: Quantize to 2 decimal places → 123456.78 (ROUND_DOWN, not ROUND_HALF_UP!)
  Step 2: TRUNC(STD) → 123456.78 mod 1000 = 456.78
  Step 3: Signed field, positive input → +456.78

Output: 456.78

This is CORRECT mainframe behavior. On a real IBM mainframe,
storing 123456.789 into PIC S9(3)V99 gives exactly 456.78.
If Aletheia gave any other answer, Shadow Diff would catch it.
```

### Why ROUND_DOWN, Not ROUND_HALF_UP?

COBOL's default rounding is **truncation** (chop off extra digits), not banker's rounding. `123.456` stored in PIC V99 becomes `123.45`, not `123.46`. The `ROUNDED` keyword explicitly enables rounding, but it's opt-in, not the default.

### CobolMemoryRegion: REDEFINES Support

For REDEFINES (where multiple variables share the same memory), Aletheia uses a shared byte buffer:

```python
class CobolMemoryRegion:
    """Byte-backed shared storage for REDEFINES groups."""
    def __init__(self, size):
        self._buffer = bytearray(size)

    def register_field(self, name, offset, length, ...):
        # Register where each variable lives in the buffer

    def get(self, name):
        # Decode bytes at (offset, length) → Decimal or string

    def put(self, name, value):
        # Encode value → bytes at (offset, length)
```

When you write to one field, any overlapping field automatically "sees" the new value because they share the same bytes — exactly like on a mainframe.

---

## Module 5: Shadow Diff (`shadow_diff.py`, ~1,357 lines)

### What It Does

The proof engine. Takes real mainframe input/output data, feeds inputs through the generated Python, and compares every output field against the mainframe's actual output. No epsilon tolerance — exact `Decimal` match required.

### Architecture

```
┌──────────────┐                          ┌──────────────┐
│ MAINFRAME    │    ┌──────────────┐      │ MAINFRAME    │
│ INPUT FILE   │───>│ PARSE FIXED  │      │ OUTPUT FILE  │
│ (flat file)  │    │ WIDTH STREAM │      │ (flat file)  │
└──────────────┘    └──────┬───────┘      └──────┬───────┘
                           │                      │
                    ┌──────▼───────┐        ┌─────▼────────┐
                    │  Input       │        │  Expected     │
                    │  Records     │        │  Output       │
                    │  (generator) │        │  Records      │
                    └──────┬───────┘        └──────┬────────┘
                           │                       │
                    ┌──────▼───────┐               │
                    │  EXECUTE     │               │
                    │  GENERATED   │               │
                    │  PYTHON      │               │
                    └──────┬───────┘               │
                           │                       │
                    ┌──────▼───────────────────────▼──┐
                    │  COMPARE FIELD BY FIELD           │
                    │  (exact Decimal match — no        │
                    │   epsilon tolerance whatsoever)    │
                    └──────────────┬───────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │  ZERO DRIFT CONFIRMED            │
                    │  or                               │
                    │  DRIFT DETECTED — N RECORDS       │
                    │  + diagnose_drift() root causes   │
                    └──────────────────────────────────┘
```

### The Streaming Pipeline (50 GB on a Laptop)

The critical design decision: everything is a **Python generator**. `parse_fixed_width_stream()` yields one record at a time. `execute_generated_python()` yields one result at a time. The comparator processes one pair at a time.

This means the system never loads the entire file into memory. A 50 GB file uses the same amount of RAM as a 50 KB file — only one record is in memory at any given moment.

```python
def run_streaming_pipeline(source, input_stream, mainframe_stream, ...):
    """Full pipeline - constant RAM regardless of file size."""
    for aletheia_rec, mainframe_rec in zip(
        execute_generated_python(source, input_records, ...),
        parse_fixed_width_stream(mainframe_layout, mainframe_data)
    ):
        mismatches = compare_one_record(aletheia_rec, mainframe_rec)
        # Process and discard — never accumulate in memory
```

### diagnose_drift(): Root Cause Analysis

When drift is detected, Aletheia doesn't just say "these don't match." It analyzes the pattern and suggests a root cause:

| Mismatch Pattern | Likely Cause | Suggested Fix |
|---|---|---|
| Difference is exactly 1 in last decimal | Rounding divergence | Check ROUNDED keyword usage |
| Comp-3 field, sign differs | Sign nibble mismatch | Verify COMP-3 decoder |
| Numeric off by factor of 10^n | Decimal position error | Check PIC V placement |
| String fields differ | EBCDIC collation | Verify ebcdic_compare() codepage |
| All zeros vs expected value | S0C7 abend | Check input data for non-numeric content |

---

## Module 6: File I/O (`cobol_file_io.py`, ~338 lines)

### What It Does

Provides an abstract I/O layer so generated Python can read/write files in two different contexts: testing (in-memory) and production (real disk files).

### The Two-Backend Architecture

```
Generated Python calls:           CobolFileManager routes to backend:
┌──────────────────────┐          ┌──────────────────────────────┐
│ _io_open('FILE','r') │─────────>│ backend.open('FILE','r')     │
│ _io_read('FILE')     │─────────>│ backend.read('FILE')         │
│ _io_write('REC')     │─────────>│ backend.write('FILE', data)  │
│ _io_rewrite('REC')   │─────────>│ backend.rewrite('FILE', ...) │
│ _io_close('FILE')    │─────────>│ backend.close('FILE')        │
└──────────────────────┘          └─────────────┬────────────────┘
                                                 │
                                  ┌──────────────┼──────────────┐
                                  ▼                              ▼
                        ┌─────────────────┐           ┌─────────────────┐
                        │  StreamBackend  │           │ RealFileBackend │
                        │  (in-memory)    │           │  (disk files)   │
                        │                 │           │                 │
                        │ For Shadow Diff │           │ For CLI batch   │
                        │ and unit tests  │           │ and production  │
                        └─────────────────┘           └─────────────────┘
```

This mirrors how IBM mainframes actually work. On a mainframe, JCL (Job Control Language) assigns logical file names to physical datasets. The COBOL program never knows where the data actually lives — it just says `READ LOAN-FILE`. The OS handles the routing.

In Aletheia, `CobolFileManager` plays the role of the OS: it takes the logical file name and routes it to whatever backend is configured.

---

## Module 7: EBCDIC Utils (`ebcdic_utils.py`, 102 lines)

### What It Does

Provides EBCDIC-aware string comparison functions. The entire module is only 102 lines — clean enough to understand completely.

Python's standard library already supports EBCDIC encoding via the `codecs` module:

```python
"A".encode("cp037")  # → b'\xc1' (EBCDIC byte for 'A')
"A".encode("ascii")  # → b'\x41' (ASCII byte for 'A')
```

The key function pads shorter strings with spaces (COBOL behavior), encodes both to EBCDIC bytes, and compares:

```python
def ebcdic_compare(a, b, codepage="cp037"):
    max_len = max(len(a), len(b))
    a_bytes = a.ljust(max_len).encode(codepage)
    b_bytes = b.ljust(max_len).encode(codepage)
    if a_bytes < b_bytes: return -1
    if a_bytes > b_bytes: return 1
    return 0
```

The generated Python uses this for every PIC X comparison:
- `IF WS-NAME > WS-OTHER` → `if ebcdic_compare(ws_name, ws_other) > 0:`
- Numeric comparisons (PIC 9) use normal Python `>` on `.value`

---

## Module 8: Copybook Resolver (`copybook_resolver.py`, ~567 lines)

### What It Does

Preprocesses COBOL source before ANTLR parsing — expands `COPY` statements (like `#include` in C), applies text substitutions, and maps REDEFINES byte offsets.

### Before → After

```
BEFORE:                                 AFTER:
┌────────────────────────────────┐      ┌────────────────────────────────┐
│ WORKING-STORAGE SECTION.       │      │ WORKING-STORAGE SECTION.       │
│   COPY PAYROLL                 │      │   05 WS-NEW-SALARY             │
│     REPLACING                  │ ──>  │      PIC S9(9)V99.             │
│     ==WS-OLD== BY ==WS-NEW==. │      │   05 WS-NEW-DEPT               │
│                                │      │      PIC X(10).                │
│   01 WS-BONUS PIC 9(5).       │      │   01 WS-BONUS PIC 9(5).        │
└────────────────────────────────┘      └────────────────────────────────┘
```

The `REPLACING` clause does text substitution: everywhere `WS-OLD` appears in the copybook, it gets replaced with `WS-NEW`.

### Safety Features

- **Circular detection**: If COPYBOOK-A includes COPYBOOK-B which includes COPYBOOK-A, it stops after 10 levels and emits `* MANUAL REVIEW: Circular COPY`
- **Missing copybooks**: Not fatal — emits `* MANUAL REVIEW: COPY not resolved` and continues
- **Reverse processing**: COPY statements are expanded in reverse order so string positions stay valid

---

## Module 9: Layout Generator (`layout_generator.py`, ~578 lines)

### What It Does

Auto-generates Shadow Diff layout JSON from the COBOL DATA DIVISION. The layout tells Shadow Diff how to parse the flat file — field names, byte offsets, lengths, and types.

### Two Paths

| Path | When Used | How Fields Are Measured |
|---|---|---|
| **FD-based** (binary) | When the program has File Description entries | Actual storage bytes (COMP-3 = packed, COMP = binary) |
| **WORKING-STORAGE fallback** (text) | When no FD entries found | Display representation bytes (one byte per digit) |

### Variable Classification

The generator doesn't just look at the DATA DIVISION — it also scans the generated Python to classify each variable:

- **Input**: Variable is read but never computed (populated from file)
- **Output**: Variable has real computations (result of arithmetic)
- **Constant**: Has a VALUE clause and is never modified
- **Dead**: Never read or computed (pruned from layout)

This classification determines which fields appear in the input vs. output side of the Shadow Diff layout.

---

# Part 4: The Supporting Modules

These modules extend the core pipeline with additional capabilities.

## Dead Code Analyzer (`dead_code_analyzer.py`, 160 lines)

Finds unreachable paragraphs using breadth-first search (BFS) from the program entry point:

```
INPUT: paragraphs + control flow       OUTPUT: reachable / unreachable
┌──────────────────────────────┐       ┌──────────────────────────────┐
│ PARA-A: PERFORM PARA-B       │       │ PARA-A: REACHABLE            │
│ PARA-B: GO TO PARA-D         │ BFS → │ PARA-B: REACHABLE            │
│ PARA-C: DISPLAY 'HELLO'      │       │ PARA-C: DEAD CODE            │
│ PARA-D: STOP RUN             │       │ PARA-D: REACHABLE            │
└──────────────────────────────┘       └──────────────────────────────┘
```

The algorithm builds a graph of paragraph calls (PERFORM → target, GO TO → target, fall-through to next paragraph) and does BFS from the first paragraph. Any paragraph not visited is dead code.

**ALTER safety**: If the program contains any ALTER statement (which dynamically changes where GO TO jumps), the analyzer conservatively marks ALL paragraphs as reachable. ALTER makes static analysis impossible because the jump target changes at runtime.

## Abend Handler (`abend_handler.py`, 283 lines)

Emulates IBM S0C7 Data Exception — the mainframe crash that happens when you try to do arithmetic on non-numeric data. On a real mainframe, this crashes the entire program. In Aletheia, it raises a `S0C7DataException` Python exception so the error can be caught and reported.

Also handles **zoned decimal overpunch** decoding:
- Positive: `{ = 0, A = 1, B = 2, ... I = 9`
- Negative: `} = 0, J = 1, K = 2, ... R = 9`
- Example: The text `"12L"` means the number `-123` (L = negative 3)

## EXEC SQL Parser (`exec_sql_parser.py`, 313 lines)

Parses EXEC SQL and EXEC CICS blocks (embedded database/transaction commands in COBOL). Classifies variables into three categories:

| Category | Meaning | Example |
|---|---|---|
| **TAINTED** | Populated by an external source (database query result) | `SELECT balance INTO :WS-BALANCE` |
| **USED** | Sent to an external source (query parameter) | `WHERE acct_num = :WS-ACCT-NUM` |
| **CONTROL** | Drives program flow (SQLCODE return code) | `IF SQLCODE = 0` |

This classification tells the generator which variables have external dependencies and may need manual verification.

## Dependency Crawler (`dependency_crawler.py`, 734 lines)

When a COBOL program calls another program with `CALL 'SUB-PROGRAM'`, the dependency crawler detects these calls, builds a dependency tree, and orchestrates multi-program batch analysis.

```
  MAIN calls SUB-A, SUB-B
  SUB-A calls SUB-C
  SUB-B calls SUB-C

  Dependency Tree:             Analysis Order (leaves first):
       MAIN                     1. SUB-C  (no dependencies)
      /    \                    2. SUB-A  (depends on SUB-C)
   SUB-A   SUB-B                3. SUB-B  (depends on SUB-C)
      \    /                    4. MAIN   (depends on A, B)
      SUB-C
```

Programs are analyzed in **topological order** (leaves first) so that when we analyze MAIN, we already know the results for SUB-A, SUB-B, and SUB-C.

The batch verdict is an **AND-gate**: all programs must pass for the batch to be VERIFIED.

## Report Signing (`report_signing.py`, 272 lines)

Every verification result is cryptographically signed to prevent tampering. The signing chain works like a mini-blockchain:

```
Record 1               Record 2               Record 3
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│ cobol_hash   │       │ cobol_hash   │       │ cobol_hash   │
│ python_hash  │       │ python_hash  │       │ python_hash  │
│ report_hash  │       │ report_hash  │       │ report_hash  │
│ prev: "000"  │──────>│ prev: hash1  │──────>│ prev: hash2  │
│ chain: hash1 │       │ chain: hash2 │       │ chain: hash3 │
│ sig: RSA-PSS │       │ sig: RSA-PSS │       │ sig: RSA-PSS │
└──────────────┘       └──────────────┘       └──────────────┘
```

Each record's `prev_hash` points to the previous record's `chain_hash`. If anyone tampers with Record 2 (changes the verdict, modifies the Python code, etc.), `hash2` changes, and Record 3's `prev_hash` no longer matches — the chain is broken.

The RSA-PSS signature proves that the record was created by Aletheia and hasn't been modified since signing.

## Vault (`vault.py`, 362 lines)

Append-only SQLite audit trail. Every `/engine/analyze` result is stored with:
- File hash (SHA-256 of COBOL source)
- Verification status
- Generated Python code
- Full report JSON
- Cryptographic chain hash and signature

The `/vault/verify-chain` endpoint walks the entire vault in order, re-verifying every chain link and signature. This is the compliance audit — it proves that no record has been tampered with since creation.

## JCL Parser (`jcl_parser.py`, 402 lines)

Parses IBM Job Control Language into a directed acyclic graph (DAG) of job steps. JCL is the "orchestration language" of mainframes — it tells the system which programs to run, in what order, and which datasets they read/write.

The parser extracts:
- `EXEC` steps (which program to run)
- `DD` statements (which datasets to use)
- `DISP` (disposition — create, read, modify, delete)
- Dataset flow analysis (which step produces data that another step consumes)

## SBOM Generator (`sbom_generator.py`, 270 lines)

Generates a CycloneDX 1.4 Software Bill of Materials — a structured inventory of everything the COBOL program depends on (copybooks, called subprograms, DB2 tables). Uses deterministic UUID-5 hashing so the same program always produces the same SBOM identifier.

## Poison Pill Generator (`poison_pill_generator.py`, 241 lines)

Generates edge-case input records to stress-test the generated Python:

| Pill | Value | What It Tests |
|---|---|---|
| `max_value` | 99999.99 | Boundary behavior |
| `zero` | 0.00 | Division by zero? Initialization? |
| `negative_max` | -99999.99 | Sign handling |
| `overflow` | 100000.00 | One digit beyond PIC capacity |
| `half_cent` | 0.005 | Rounding boundary (truncate or round?) |

## Compiler Config (`compiler_config.py`, 66 lines)

The smallest but most elegant module. Uses Python's `contextvars` to store compiler settings (TRUNC mode, ARITH mode) in a way that's isolated per-request in async FastAPI:

```python
from contextvars import ContextVar
from dataclasses import dataclass

@dataclass
class CompilerConfig:
    trunc_mode: str = "STD"        # STD | BIN | OPT
    arith_mode: str = "COMPAT"     # COMPAT (18 digits) | EXTEND (31 digits)
    decimal_point: str = "PERIOD"  # PERIOD | COMMA
    currency_sign: str = "$"

_config_var: ContextVar[CompilerConfig] = ContextVar(
    "compiler_config", default=CompilerConfig()
)

def get_config() -> CompilerConfig:
    return _config_var.get()
```

Why `ContextVar` instead of a global variable? Because FastAPI handles multiple requests concurrently. If Request A sets TRUNC=BIN and Request B sets TRUNC=STD, a global variable would cause them to interfere with each other. `ContextVar` gives each request its own isolated copy.

## License Manager (`license_manager.py`, 294 lines)

Validates RSA-PSS signed license files. Two modes:

```
┌──────────────┐    ┌────────────────┐    ┌──────────────┐
│ license.json │───>│ RSA-PSS Verify │───>│ VALID or     │
│ license.sig  │    │ (embedded      │    │ INVALID      │
└──────────────┘    │  public key)   │    └──────┬───────┘
                    └────────────────┘           │
                                      ┌──────────▼──────────┐
                                      │ strict: 403 BLOCKED  │
                                      │ grace:  50 free      │
                                      │         analyses     │
                                      └──────────────────────┘
```

---

# Part 5: Every Fix and Why

This section documents the major fixes shipped in Aletheia, organized by category. Each fix follows the format: what was broken, why it mattered, and how it was fixed.

## Arithmetic Fixes

### Fix: Truncation on Store (Not During Computation)

**What was broken**: Early versions truncated intermediate arithmetic results, causing precision loss in chained computations.

**Why it matters**: COBOL COMPUTE does full-precision arithmetic, truncating only when storing to the target variable. If you truncate intermediates, a multi-step calculation like `A * B / C + D` gives different results.

**How it was fixed**: All arithmetic in generated Python uses raw `Decimal` values (`.value` property). Truncation only happens in `.store()`:

```python
# CORRECT (what Aletheia does):
_temp = ws_a.value * ws_b.value / ws_c.value + ws_d.value  # full precision
ws_result.store(_temp)  # truncate HERE

# WRONG (what early versions did):
_t1 = ws_a.value * ws_b.value
ws_temp1.store(_t1)  # truncated too early!
_t2 = ws_temp1.value / ws_c.value  # now working with truncated value
```

### Fix: Multi-Target ADD / SUBTRACT

**What was broken**: `ADD A TO B C` was only adding A to B, ignoring C.

**Why it matters**: COBOL's `ADD A TO B C` means "add A to both B and C." It's a shorthand that processes multiple targets.

```
BEFORE (broken):                       AFTER (fixed):
┌────────────────────────────────┐     ┌────────────────────────────────┐
│ ADD A TO B C                   │     │ ADD A TO B C                   │
│                                │     │                                │
│ b.store(a.value + b.value)     │     │ b.store(a.value + b.value)     │
│ # C is untouched!              │     │ c.store(a.value + c.value)     │
└────────────────────────────────┘     └────────────────────────────────┘
```

### Fix: DIVIDE with REMAINDER

**What was broken**: `DIVIDE A INTO B GIVING C REMAINDER D` wasn't populating the remainder variable.

**Why it matters**: Banking applications use DIVIDE REMAINDER for things like allocating cents across accounts (e.g., splitting $100.00 among 3 accounts: $33.33, $33.33, $33.34).

**How it was fixed**: The generator now emits both the quotient and remainder:

```python
# DIVIDE A INTO B GIVING C REMAINDER D
_quotient = ws_b.value // ws_a.value
ws_c.store(_quotient)
_remainder = ws_b.value - (_quotient * ws_a.value)
ws_d.store(_remainder)
```

### Fix: ON SIZE ERROR / NOT ON SIZE ERROR

**What was broken**: ON SIZE ERROR (COBOL's overflow handler) was being ignored.

**Why it matters**: Banks use ON SIZE ERROR to handle overflow conditions — if a calculation produces a result too large for the target field, execute error-handling logic instead of storing garbage.

**How it was fixed**: The generator now checks overflow before storing:

```python
# COMPUTE WS-RESULT = WS-A * WS-B ON SIZE ERROR PERFORM ERROR-HANDLER
_ose_val = ws_a.value * ws_b.value
if ws_result.check_overflow(_ose_val):
    error_handler()  # ON SIZE ERROR path
else:
    ws_result.store(_ose_val)
    # NOT ON SIZE ERROR path (if specified)
```

### Fix: COMP-3 Overflow Wrapping

**What was broken**: When a COMP-3 field overflowed, the result wasn't wrapping correctly.

**Why it matters**: `PIC S9(5)V99` can hold max 99999.99. Storing 100000.00 should wrap to 00000.00 (that's 100000 mod 100000 = 0). This is correct mainframe behavior.

**How it was fixed**: The `_apply_truncation` method uses modular arithmetic: `integer_part % self._max_int`.

## String Handling Fixes

### Fix: EBCDIC String Comparison

**What was broken**: PIC X string comparisons used Python's default ASCII ordering.

**Why it matters**: In EBCDIC, `'9' > 'Z'` is TRUE. In ASCII, it's FALSE. Any COBOL program that compares strings gives wrong results without EBCDIC correction.

**How it was fixed**: The generator detects PIC X variables and emits `ebcdic_compare()` instead of Python `>` / `<` / `==`.

### Fix: SPACES Padding on MOVE

**What was broken**: Moving a short string to a longer PIC X field didn't pad with spaces.

**Why it matters**: In COBOL, `MOVE "AB" TO WS-FIELD` (where WS-FIELD is PIC X(10)) stores `"AB        "` (padded with 8 spaces). Programs that later compare this field expect the padding.

### Fix: STRING DELIMITED BY SIZE

**What was broken**: The STRING verb (concatenation) wasn't supported.

**Why it matters**: COBOL uses `STRING A DELIMITED BY SIZE B DELIMITED BY SIZE INTO C` to concatenate strings — it's the COBOL equivalent of `C = A + B`.

### Fix: INITIALIZE Mixed Groups

**What was broken**: INITIALIZE was setting everything to zero.

**Why it matters**: COBOL's INITIALIZE sets numeric fields to 0 and alphanumeric fields to spaces. A mixed group (containing both types) needs both treatments.

## Control Flow Fixes

### Fix: PERFORM THRU Range

**What was broken**: `PERFORM PARA-A THRU PARA-C` was only executing PARA-A and PARA-C, skipping PARA-B.

**Why it matters**: PERFORM THRU executes all paragraphs from A through C in order, including every paragraph in between. Old COBOL programs heavily rely on this for sequential processing.

### Fix: PERFORM VARYING (Loop)

**What was broken**: PERFORM VARYING (COBOL's for-loop) wasn't generating the correct loop structure.

**Why it matters**: `PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > 100` is COBOL's way of writing a for-loop. The init, increment, and termination condition must all be correct.

**How it was fixed**: The generator emits a while-loop with proper initialization:

```python
# PERFORM VARYING WS-IDX FROM 1 BY 1 UNTIL WS-IDX > 100
ws_idx.store(Decimal('1'))  # FROM 1
while not (ws_idx.value > Decimal('100')):  # UNTIL
    para_body()
    ws_idx.store(ws_idx.value + Decimal('1'))  # BY 1
```

### Fix: SET condition-name TO TRUE

**What was broken**: `SET IS-VIP-ACCOUNT TO TRUE` was being ignored.

**Why it matters**: This is COBOL's way of setting the parent variable to the 88-level's value. `SET IS-VIP-ACCOUNT TO TRUE` means `MOVE 'Y' TO WS-VIP-FLAG`.

### Fix: Nested EVALUATE Inside IF

**What was broken**: EVALUATE statements inside IF branches were being emitted twice — once by the IF handler and once by the EVALUATE handler.

**Why it matters**: Double-emission means the logic runs twice, potentially producing wrong results or side effects.

**How it was fixed**: The generator tracks which statements appear in branches (`statements_in_branches` set) and skips them in the top-level emission.

## File I/O Fixes

### Fix: SORT INPUT/OUTPUT PROCEDURE

**What was broken**: SORT with INPUT PROCEDURE / OUTPUT PROCEDURE was flagged as MANUAL REVIEW.

**Why it matters**: This is COBOL's way of preprocessing records before sorting and postprocessing after. The INPUT PROCEDURE uses RELEASE to feed records into the sort buffer; the OUTPUT PROCEDURE uses RETURN to retrieve sorted records.

**How it was fixed**: The generator now emits:
1. Call the input procedure (which calls RELEASE to fill `_sort_buffer`)
2. Sort the buffer by the specified keys
3. Create an iterator from the sorted buffer
4. Call the output procedure (which calls RETURN to retrieve records one at a time)

### Fix: READ KEY IS + REWRITE + OPEN I-O

**What was broken**: READ with KEY IS (indexed file lookup), REWRITE (update in place), and OPEN I-O (read-write mode) inside IF branches were all flagged as MANUAL REVIEW.

**Why it matters**: These are standard indexed file operations. Without them, any program that reads a record by key, modifies it, and writes it back gets flagged.

**How it was fixed**: Added file I/O verb detection to the branch handler (`_convert_single_statement` in parse_conditions.py) so these verbs are recognized even inside IF branches.

### Fix: AT END / NOT AT END Patterns

**What was broken**: The AT END handler (executed when reaching end-of-file) wasn't being emitted.

**Why it matters**: Almost every COBOL file-reading loop uses AT END to detect when there's no more data:

```cobol
READ LOAN-FILE
  AT END
    SET END-OF-FILE TO TRUE
  NOT AT END
    PERFORM PROCESS-RECORD
END-READ
```

## Security Fixes

### Fix: JWT Token Hardening

Tokens now expire after 7 days (down from no expiry), include `iat` (issued-at) claims, and are validated against both signature and expiry on every request.

### Fix: Docker Two-Stage Build

Production Docker images compile all Python to `.so` (binary) via Cython. The source code is not present in the final image, preventing reverse engineering of the verification logic.

### Fix: Input Validation

File uploads are limited to 10 MB. Shadow Diff uploads are chunked (8 MB per chunk) with a 50 GB total limit and disk space pre-checks.

---

# Part 6: The Audit Results

## Test Suite (597 Tests, Zero Failures)

| Test File | Tests | What It Covers |
|---|---|---|
| `test_core_logic.py` | 59 | API endpoints, auth, analysis pipeline |
| `test_generator_edge_cases.py` | 54 | Generator edge cases across all constructs |
| `test_generator_fixes.py` | 48 | Specific bug fix regressions |
| `test_shadow_diff.py` | 40 | Shadow Diff comparison, streaming, COMP-3 |
| `test_file_io.py` | 26 | File I/O backends, manager, integration |
| `test_ebcdic.py` | 26 | EBCDIC encoding/decoding, comparison |
| `test_layout_generator.py` | 24 | Layout auto-generation from DATA DIVISION |
| `test_copybook.py` | 22 | COPY expansion, REPLACING, REDEFINES |
| `test_abend.py` | 20 | S0C7 emulation, zoned decimal |
| `test_dead_code.py` | 20 | Paragraph reachability analysis |
| `test_dependency.py` | 20 | Multi-program CALL detection, batch |
| `test_license.py` | 20 | License validation, grace mode, features |
| `test_signing.py` | 19 | RSA-PSS signing, chain verification |
| `test_integration.py` | 18 | Full pipeline end-to-end |
| `test_cobol_types.py` | 18 | CobolDecimal truncation, TRUNC modes |
| `test_parse_conditions.py` | 16 | IF/EVALUATE condition conversion |
| `test_exec_sql.py` | 13 | SQL/CICS parsing, taint classification |
| `test_cli.py` | 12 | CLI interface, batch mode |
| `test_sort.py` | 13 | SORT USING/GIVING, INPUT/OUTPUT PROC |
| `test_integration_stress.py` | 9 | Stress tests for large programs |
| `test_endpoints_new.py` | 5 | New API endpoint coverage |
| `test_negative_verification.py` | 5 | Shadow Diff mismatch detection |
| `test_cli_verify.py` | 4 | CLI verification mode |
| `test_security_fixes.py` | 4 | Security hardening tests |
| `test_resilience_fixes.py` | 2 | Error recovery tests |
| `semantic_corpus/run_corpus.py` | 50 | Behavioral execution verification |
| **TOTAL** | **597** | |

## Semantic Regression Corpus (50 Behavioral Tests)

The semantic corpus is the highest-quality test suite. Each entry is a real COBOL program paired with expected output values. The runner:

1. Parses the COBOL
2. Generates Python
3. Executes the Python with specified inputs
4. Compares outputs to expected values with **exact Decimal match** (no epsilon)

Example entry (`trunc_std_modulo`):

```cobol
IDENTIFICATION DIVISION.
PROGRAM-ID. TRUNC-STD-MODULO.
DATA DIVISION.
WORKING-STORAGE SECTION.
01  WS-BIG         PIC S9(5).
01  WS-SMALL       PIC 9(3).
PROCEDURE DIVISION.
0000-MAIN.
    MOVE WS-BIG TO WS-SMALL.
    STOP RUN.
```

```json
{
  "inputs": { "WS-BIG": "1234" },
  "expected_outputs": { "WS-SMALL": "234" },
  "trunc_mode": "STD",
  "notes": "PIC 9(3) max_int=1000. 1234 mod 1000 = 234."
}
```

Categories: precision (12), rounding (5), sign (5), string (7), control_flow (11), size_error (5), decimal_point (2).

## Production Verification Rate (PVR)

PVR measures what percentage of COBOL programs Aletheia can fully verify without human intervention:

```
PVR Progress (100 programs):
┌──────────────────────────────────────────────────────────┐
│ March 1:    ███████████████░░░░░░░░░░  75%  (40 progs)   │
│ March 10:   ██████████████████░░░░░░░  88%               │
│ March 14:   ████████████████████░░░░░  92%               │
│ March 17:   █████████████████████░░░░  94%  (100 progs)  │
│ March 22:   ██████████████████████░░░  94.3% (459 progs) │
│                                                           │
│ Remaining: 26 programs with ALTER/EXEC SQL/ANTLR limits  │
└──────────────────────────────────────────────────────────┘
```

**94 out of 100 programs** verify cleanly. The remaining 6 contain the ALTER verb — a COBOL statement that dynamically modifies which paragraph a GO TO jumps to. This is fundamentally incompatible with static analysis, so Aletheia intentionally flags these for manual review. This is a design choice, not a limitation.

## Construct Support Matrix (Current State)

### Fully Supported (Emits Clean Python)

| Construct | Example | Status |
|---|---|---|
| MOVE / COMPUTE / ADD / SUB / MUL / DIV | `COMPUTE A = B * C` | Fully emitted |
| IF / ELSE / END-IF (nested) | `IF A > B ... END-IF` | Fully emitted |
| EVALUATE TRUE / EVALUATE var / WHEN / WHEN OTHER | `EVALUATE TRUE ...` | Fully emitted |
| **EVALUATE ALSO** (multi-subject) | `EVALUATE A ALSO B` | Fully emitted |
| PERFORM / PERFORM THRU / VARYING / TIMES | `PERFORM A THRU B` | Fully emitted |
| STRING DELIMITED BY SIZE | `STRING A B INTO C` | Fully emitted |
| **STRING with POINTER + non-SIZE delimiters** | `STRING ... POINTER ...` | Fully emitted |
| UNSTRING DELIMITED BY | `UNSTRING A DELIMITED BY ' '` | Fully emitted |
| **UNSTRING with OR / DELIMITER IN / COUNT IN** | complex UNSTRING | Fully emitted |
| **INSPECT TALLYING / REPLACING / CONVERTING** | `INSPECT TALLYING ALL` | Fully emitted |
| DISPLAY / GO TO / STOP RUN / INITIALIZE | `DISPLAY WS-A` | Fully emitted |
| IS NUMERIC / IS ALPHABETIC | `IF A IS NUMERIC` | Fully emitted |
| COMP-3, COMP/COMP-4, COMP-5 | All binary storage types | Fully emitted |
| 88-level conditions (single + multi-value) | `88 IS-VIP VALUE 'Y'` | Fully emitted |
| EBCDIC-aware string ordering | PIC X comparisons | Fully emitted |
| COPY / REPLACING / REDEFINES | Copybook preprocessor | Fully emitted |
| EXEC SQL/CICS detection + taint analysis | `EXEC SQL SELECT...` | Detected, flagged |
| CALL dependency tree resolution | `CALL 'SUB-PROG'` | Fully emitted |
| OCCURS fixed-count tables + subscripts | `OCCURS 10 TIMES` | Fully emitted |
| DECIMAL-POINT IS COMMA | European decimal notation | Fully emitted |
| File I/O: OPEN / READ / WRITE / CLOSE | Sequential file access | Fully emitted |
| FILE STATUS variable updates | Status "00" / "10" / "23" | Fully emitted |
| **SORT INPUT/OUTPUT PROCEDURE** | RELEASE / RETURN pattern | Fully emitted |
| **READ KEY IS** (indexed lookup) | `READ F KEY IS K` | Fully emitted |
| **REWRITE** (update in place) | `REWRITE REC` | Fully emitted |
| **OPEN I-O** (read-write mode) | `OPEN I-O FILE` | Fully emitted |
| **GO TO DEPENDING ON** | Conditional jump table | Fully emitted |
| **MOVE CORRESPONDING** | Group-level field matching | Fully emitted |
| **Reference modification** | `WS-FIELD(1:3)` | Fully emitted |

### MANUAL REVIEW (Intentional Hard Stops)

| Construct | Why | Count in Corpus |
|---|---|---|
| **ALTER** | Dynamically modifies GO TO targets at runtime — static analysis impossible | 6 programs |
| EXEC SQL host variable execution | External system coupling — behavior unknown without database | Flagged, not blocked |
| GO TO inside PERFORM THRU | Complex control flow interaction — conservative approach | Rare |

---

# Part 7: The Business

## The Market

The COBOL modernization market is estimated at **$3 trillion** in total addressable market (TAM). This number comes from the sheer volume of COBOL code in production:

- 220 billion lines running at banks, insurance companies, and government agencies
- Average migration cost: $5-15 per line of code
- Average COBOL programmer salary: $100,000+/year (and they're all retiring)
- Regulatory pressure: DORA (EU), Basel III, and SOX all push banks toward modern infrastructure

This isn't a market that's going away. Every major bank will need to modernize eventually, and they can't afford to get it wrong.

## The Competition

Every competitor in this space does the same thing: they try to **translate** COBOL to a modern language using AI. The big players:

- **IBM watsonx Code Assistant for Z**: IBM's own tool. Uses AI to suggest Java translations. But even IBM acknowledges that the translations need manual verification.
- **Micro Focus Visual COBOL**: Runs COBOL on .NET/JVM. Not really migration — it's wrapping COBOL in modern infrastructure.
- **Modernization consultancies** (Accenture, Cognizant, TCS): Throw hundreds of developers at the problem. Takes 5-10 years per bank. Costs hundreds of millions.

The fundamental problem with all of these: they produce code that **looks** right but has no proof it **behaves** identically to the original.

```
┌──────────────────────────────────────────────────────┐
│              TRANSLATES CODE                          │
│   IBM watsonx                                         │
│   Micro Focus                   Aletheia              │
│   Consultancies                 VERIFIES BEHAVIOR     │
│                                                       │
│   (They guess it's right)       (We PROVE it's right) │
└──────────────────────────────────────────────────────┘
```

Aletheia doesn't compete with translators. We complement them. Use whatever tool you want to produce the Python — then use Aletheia to **prove it works**.

## Pricing

Per-program verification pricing. Each COBOL program analyzed costs a fixed fee. Volume discounts for batch processing (100+ programs). Annual license with:
- Feature flags (Shadow Diff, batch analysis, etc.)
- Daily analysis quotas
- RSA-PSS signed license files (air-gap compatible)

## The Monopoly Playbook

Verification is a **trust product**. Once a bank verifies 1,000 programs through Aletheia:

1. **The audit trail is locked in**: 1,000 signed verification records in the Vault, with chain-of-custody hashes. You can't move this to another tool.
2. **The compliance documentation references Aletheia**: Regulators have seen the reports. Switching tools means re-explaining everything.
3. **The team knows the workflow**: Engineers are trained on the Engine, the Shadow Diff, the Vault.
4. **Historical comparison baseline**: Future program changes need to be re-verified against the same baseline.

Every additional program verified increases the switching cost.

## Validation

- **597 tests**, zero failures
- **50 semantic regression entries** with exact Decimal match
- **PVR 94.3%** on 459-program corpus (433 VERIFIED, 26 MANUAL REVIEW)
- **YC Spring 2026 applicant**
- Real code, real precision, real mainframe emulation

---

# Part 8: Glossary

| Term | Definition |
|---|---|
| **ANTLR4** | Parser generator. Takes a grammar file and generates a lexer + parser in Python/Java/etc. Aletheia uses the COBOL85 grammar. |
| **BCD** | Binary-Coded Decimal. Encoding where each decimal digit is stored in 4 bits (one nibble). Used by COMP-3. |
| **COBOL** | Common Business-Oriented Language. Created 1959. Still runs most banking systems. |
| **COMP** | Computational — COBOL storage type for binary integers. Also called COMP-4. |
| **COMP-3** | Packed decimal storage. Two digits per byte, sign in last nibble. Most common numeric storage on mainframes. |
| **COMP-4** | Same as COMP. Pure binary storage. |
| **COMP-5** | Native binary — like COMP but uses the full binary range regardless of PIC. |
| **CobolDecimal** | Aletheia's Python class that wraps `Decimal` with PIC-based truncation. The precision engine. |
| **Copybook** | Reusable COBOL code fragment included via COPY statement. Like a header file in C. |
| **CycloneDX** | SBOM (Software Bill of Materials) standard. Aletheia generates CycloneDX 1.4 format. |
| **DD** | Data Definition — JCL statement that maps a logical file name to a physical dataset. |
| **DISPLAY** | Default COBOL storage type. One byte per digit, human-readable. |
| **EBCDIC** | Extended Binary Coded Decimal Interchange Code. IBM's character encoding. Different collating sequence from ASCII. |
| **FD** | File Description — COBOL's way of declaring the structure of a data file. |
| **JCL** | Job Control Language. IBM mainframe scripting language that orchestrates batch jobs. |
| **LINKAGE SECTION** | COBOL's way of declaring parameters received from a calling program. |
| **MANUAL REVIEW** | Aletheia's signal that a construct couldn't be safely converted to Python. Never generates wrong code — flags for human review instead. |
| **Nibble** | Half a byte (4 bits). Can hold values 0-15. COMP-3 uses one nibble per digit. |
| **Overpunch** | EBCDIC encoding where the sign of a number is embedded in the last byte's zone bits. `D5` = negative 5, `F5` = positive 5. |
| **PIC** | PICTURE clause. COBOL's way of declaring a variable's type, size, and precision. `PIC S9(5)V99` = signed, 5 integer digits, 2 decimal places. |
| **PVR** | Production Verification Rate. Percentage of COBOL programs that verify cleanly without human intervention. Currently 94.3% on 459 programs. |
| **QSAM** | Queued Sequential Access Method. IBM mainframe file access method for sequential (flat) files. |
| **REDEFINES** | COBOL clause that makes two variables share the same memory bytes. Like a C `union`. |
| **RSA-PSS** | RSA Probabilistic Signature Scheme. Cryptographic signature algorithm used for report signing. |
| **S0C7** | System Completion Code 0C7. IBM mainframe abend (abnormal end / crash) caused by non-numeric data in a numeric field. |
| **SBOM** | Software Bill of Materials. Inventory of all dependencies in a program. |
| **Shadow Diff** | Aletheia's comparison engine. Feeds same inputs to generated Python and compares against real mainframe output. |
| **TRUNC** | Truncation mode. IBM compiler flag: STD (mod PIC), BIN (full binary for COMP), OPT (no truncation). |
| **Vault** | Aletheia's append-only audit trail. SQLite database with chain-of-custody hashing and RSA-PSS signatures. |
| **VSAM** | Virtual Storage Access Method. IBM mainframe file system for indexed (keyed) and relative record files. |
| **Zoned Decimal** | Same as DISPLAY format. One byte per digit with the sign in the last byte's zone bits. |

---

**End of Document**

*Aletheia: Behavioral Verification Engine*
*1006 tests. 94.3% PVR on 459 programs. Zero tolerance for drift.*
