       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAX-AMT-CALC.
      *================================================================
      * Alternative Minimum Tax (AMT) Calculation
      * Computes AMT liability comparing tentative minimum tax
      * against regular tax with preference item add-backs.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TAXPAYER-DATA.
           05 WS-TIN                   PIC X(9).
           05 WS-FILING-STATUS         PIC X(1).
               88 WS-SINGLE            VALUE 'S'.
               88 WS-MFJ               VALUE 'M'.
               88 WS-MFS               VALUE 'F'.
           05 WS-REGULAR-TAXABLE       PIC S9(9)V99 COMP-3.
           05 WS-REGULAR-TAX           PIC S9(7)V99 COMP-3.
       01 WS-AMT-PREFERENCES.
           05 WS-SALT-ADDBACK          PIC S9(7)V99 COMP-3.
           05 WS-MISC-DEDUCTIONS       PIC S9(7)V99 COMP-3.
           05 WS-ISO-GAIN              PIC S9(9)V99 COMP-3.
           05 WS-DEPR-DIFFERENCE       PIC S9(7)V99 COMP-3.
           05 WS-TAX-EXEMPT-INT        PIC S9(7)V99 COMP-3.
           05 WS-NET-OPR-LOSS-ADJ      PIC S9(7)V99 COMP-3.
           05 WS-TOTAL-PREFERENCES     PIC S9(9)V99 COMP-3.
       01 WS-AMTI-FIELDS.
           05 WS-AMTI                  PIC S9(11)V99 COMP-3.
           05 WS-EXEMPTION-AMT         PIC S9(7)V99 COMP-3.
           05 WS-PHASE-OUT-THRESH      PIC S9(9)V99 COMP-3.
           05 WS-PHASE-OUT-AMT         PIC S9(7)V99 COMP-3.
           05 WS-NET-EXEMPTION         PIC S9(7)V99 COMP-3.
           05 WS-AMT-BASE              PIC S9(11)V99 COMP-3.
       01 WS-AMT-RATES.
           05 WS-AMT-RATE-LOW          PIC S9(1)V9(4) COMP-3
               VALUE 0.2600.
           05 WS-AMT-RATE-HIGH         PIC S9(1)V9(4) COMP-3
               VALUE 0.2800.
           05 WS-AMT-BREAKPOINT        PIC S9(9)V99 COMP-3
               VALUE 232600.00.
       01 WS-RESULT-FIELDS.
           05 WS-TENTATIVE-MIN-TAX     PIC S9(9)V99 COMP-3.
           05 WS-AMT-LIABILITY         PIC S9(7)V99 COMP-3.
           05 WS-TOTAL-TAX             PIC S9(9)V99 COMP-3.
       01 WS-IS-AMT-PAYER              PIC X(1).
           88 WS-OWES-AMT              VALUE 'Y'.
           88 WS-NO-AMT                VALUE 'N'.
       01 WS-WORK-FIELDS.
           05 WS-LOWER-PORTION         PIC S9(9)V99 COMP-3.
           05 WS-UPPER-PORTION         PIC S9(9)V99 COMP-3.
           05 WS-TEMP-TAX              PIC S9(9)V99 COMP-3.
       01 WS-DIVIDE-FIELDS.
           05 WS-EFFECTIVE-RATE        PIC S9(3)V9(4) COMP-3.
           05 WS-RATE-REMAINDER        PIC S9(1)V9(4) COMP-3.
       01 WS-PROCESS-DATE              PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SUM-PREFERENCES
           PERFORM 3000-CALC-AMTI
           PERFORM 4000-CALC-EXEMPTION
           PERFORM 5000-CALC-TENTATIVE-TAX
           PERFORM 6000-DETERMINE-AMT
           PERFORM 7000-DISPLAY-RESULT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-PREFERENCES
           MOVE 0 TO WS-AMT-LIABILITY
           SET WS-NO-AMT TO TRUE.
       2000-SUM-PREFERENCES.
           COMPUTE WS-TOTAL-PREFERENCES =
               WS-SALT-ADDBACK +
               WS-MISC-DEDUCTIONS +
               WS-ISO-GAIN +
               WS-DEPR-DIFFERENCE +
               WS-TAX-EXEMPT-INT +
               WS-NET-OPR-LOSS-ADJ.
       3000-CALC-AMTI.
           COMPUTE WS-AMTI =
               WS-REGULAR-TAXABLE + WS-TOTAL-PREFERENCES.
       4000-CALC-EXEMPTION.
           EVALUATE TRUE
               WHEN WS-SINGLE
                   MOVE 85700.00 TO WS-EXEMPTION-AMT
                   MOVE 609350.00 TO WS-PHASE-OUT-THRESH
               WHEN WS-MFJ
                   MOVE 133300.00 TO WS-EXEMPTION-AMT
                   MOVE 1218700.00 TO WS-PHASE-OUT-THRESH
               WHEN WS-MFS
                   MOVE 66650.00 TO WS-EXEMPTION-AMT
                   MOVE 609350.00 TO WS-PHASE-OUT-THRESH
               WHEN OTHER
                   MOVE 85700.00 TO WS-EXEMPTION-AMT
                   MOVE 609350.00 TO WS-PHASE-OUT-THRESH
           END-EVALUATE
           IF WS-AMTI > WS-PHASE-OUT-THRESH
               COMPUTE WS-PHASE-OUT-AMT =
                   (WS-AMTI - WS-PHASE-OUT-THRESH) * 0.25
               COMPUTE WS-NET-EXEMPTION =
                   WS-EXEMPTION-AMT - WS-PHASE-OUT-AMT
               IF WS-NET-EXEMPTION < 0
                   MOVE 0 TO WS-NET-EXEMPTION
               END-IF
           ELSE
               MOVE WS-EXEMPTION-AMT TO WS-NET-EXEMPTION
           END-IF
           COMPUTE WS-AMT-BASE =
               WS-AMTI - WS-NET-EXEMPTION
           IF WS-AMT-BASE < 0
               MOVE 0 TO WS-AMT-BASE
           END-IF.
       5000-CALC-TENTATIVE-TAX.
           IF WS-AMT-BASE <= WS-AMT-BREAKPOINT
               COMPUTE WS-TENTATIVE-MIN-TAX =
                   WS-AMT-BASE * WS-AMT-RATE-LOW
           ELSE
               COMPUTE WS-LOWER-PORTION =
                   WS-AMT-BREAKPOINT * WS-AMT-RATE-LOW
               COMPUTE WS-UPPER-PORTION =
                   (WS-AMT-BASE - WS-AMT-BREAKPOINT) *
                   WS-AMT-RATE-HIGH
               COMPUTE WS-TENTATIVE-MIN-TAX =
                   WS-LOWER-PORTION + WS-UPPER-PORTION
           END-IF.
       6000-DETERMINE-AMT.
           IF WS-TENTATIVE-MIN-TAX > WS-REGULAR-TAX
               SET WS-OWES-AMT TO TRUE
               COMPUTE WS-AMT-LIABILITY =
                   WS-TENTATIVE-MIN-TAX - WS-REGULAR-TAX
           ELSE
               SET WS-NO-AMT TO TRUE
               MOVE 0 TO WS-AMT-LIABILITY
           END-IF
           COMPUTE WS-TOTAL-TAX =
               WS-REGULAR-TAX + WS-AMT-LIABILITY
           IF WS-AMTI > 0
               DIVIDE WS-TOTAL-TAX BY WS-AMTI
                   GIVING WS-EFFECTIVE-RATE
                   REMAINDER WS-RATE-REMAINDER
               MULTIPLY WS-EFFECTIVE-RATE BY 100
                   GIVING WS-EFFECTIVE-RATE
           END-IF.
       7000-DISPLAY-RESULT.
           DISPLAY "AMT CALCULATION RESULT"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "TIN: " WS-TIN
           DISPLAY "REGULAR TAXABLE: "
               WS-REGULAR-TAXABLE
           DISPLAY "PREFERENCES: " WS-TOTAL-PREFERENCES
           DISPLAY "AMTI: " WS-AMTI
           DISPLAY "EXEMPTION: " WS-NET-EXEMPTION
           DISPLAY "AMT BASE: " WS-AMT-BASE
           DISPLAY "TENTATIVE MIN TAX: "
               WS-TENTATIVE-MIN-TAX
           DISPLAY "REGULAR TAX: " WS-REGULAR-TAX
           IF WS-OWES-AMT
               DISPLAY "AMT LIABILITY: " WS-AMT-LIABILITY
           ELSE
               DISPLAY "NO AMT OWED"
           END-IF
           DISPLAY "TOTAL TAX: " WS-TOTAL-TAX
           DISPLAY "EFFECTIVE RATE: "
               WS-EFFECTIVE-RATE "%".
