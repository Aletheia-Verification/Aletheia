       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-SUBROGATION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CLAIM-INFO.
           05 WS-CLAIM-ID         PIC X(12).
           05 WS-POLICY-NUM       PIC X(12).
           05 WS-LOSS-AMT         PIC S9(9)V99 COMP-3.
           05 WS-PAID-AMT         PIC S9(9)V99 COMP-3.
           05 WS-DEDUCTIBLE       PIC S9(7)V99 COMP-3.
           05 WS-LOSS-DATE        PIC 9(8).
           05 WS-FAULT-PCT        PIC 9(3).
       01 WS-THIRD-PARTY.
           05 WS-TP-NAME          PIC X(30).
           05 WS-TP-INSURER       PIC X(20).
           05 WS-TP-POLICY        PIC X(12).
           05 WS-TP-FAULT-PCT     PIC 9(3).
       01 WS-SUBRO-CALC.
           05 WS-RECOVERY-AMT     PIC S9(9)V99 COMP-3.
           05 WS-NET-RECOVERY     PIC S9(9)V99 COMP-3.
           05 WS-LEGAL-COSTS      PIC S9(7)V99 COMP-3.
           05 WS-DEDUCT-REFUND    PIC S9(7)V99 COMP-3.
           05 WS-COMPANY-SHARE    PIC S9(9)V99 COMP-3.
       01 WS-SUBRO-STATUS         PIC X(12).
       01 WS-PURSUIT-FLAG         PIC X VALUE 'N'.
           88 WORTH-PURSUING      VALUE 'Y'.
       01 WS-MIN-RECOVERY         PIC S9(5)V99 COMP-3
           VALUE 500.00.
       01 WS-LEGAL-RATE           PIC S9(1)V99 COMP-3
           VALUE 0.33.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-CALC-RECOVERY
           PERFORM 2000-ASSESS-VIABILITY
           PERFORM 3000-ALLOCATE-RECOVERY
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-CALC-RECOVERY.
           COMPUTE WS-RECOVERY-AMT =
               WS-PAID-AMT * WS-TP-FAULT-PCT / 100
           COMPUTE WS-LEGAL-COSTS =
               WS-RECOVERY-AMT * WS-LEGAL-RATE
           COMPUTE WS-NET-RECOVERY =
               WS-RECOVERY-AMT - WS-LEGAL-COSTS.
       2000-ASSESS-VIABILITY.
           IF WS-NET-RECOVERY > WS-MIN-RECOVERY
               IF WS-TP-FAULT-PCT >= 50
                   MOVE 'Y' TO WS-PURSUIT-FLAG
                   MOVE 'PURSUE      ' TO WS-SUBRO-STATUS
               ELSE
                   IF WS-NET-RECOVERY > 5000.00
                       MOVE 'Y' TO WS-PURSUIT-FLAG
                       MOVE 'PURSUE      ' TO WS-SUBRO-STATUS
                   ELSE
                       MOVE 'REVIEW      ' TO WS-SUBRO-STATUS
                   END-IF
               END-IF
           ELSE
               MOVE 'NOT VIABLE  ' TO WS-SUBRO-STATUS
           END-IF.
       3000-ALLOCATE-RECOVERY.
           IF WORTH-PURSUING
               IF WS-NET-RECOVERY > WS-DEDUCTIBLE
                   MOVE WS-DEDUCTIBLE TO WS-DEDUCT-REFUND
                   COMPUTE WS-COMPANY-SHARE =
                       WS-NET-RECOVERY - WS-DEDUCTIBLE
               ELSE
                   MOVE WS-NET-RECOVERY TO WS-DEDUCT-REFUND
                   MOVE 0 TO WS-COMPANY-SHARE
               END-IF
           ELSE
               MOVE 0 TO WS-DEDUCT-REFUND
               MOVE 0 TO WS-COMPANY-SHARE
           END-IF.
       4000-OUTPUT.
           DISPLAY 'SUBROGATION ANALYSIS'
           DISPLAY '===================='
           DISPLAY 'CLAIM:        ' WS-CLAIM-ID
           DISPLAY 'LOSS AMOUNT:  $' WS-LOSS-AMT
           DISPLAY 'PAID AMOUNT:  $' WS-PAID-AMT
           DISPLAY 'TP FAULT:     ' WS-TP-FAULT-PCT '%'
           DISPLAY 'RECOVERY:     $' WS-RECOVERY-AMT
           DISPLAY 'LEGAL COSTS:  $' WS-LEGAL-COSTS
           DISPLAY 'NET RECOVERY: $' WS-NET-RECOVERY
           DISPLAY 'STATUS:       ' WS-SUBRO-STATUS
           IF WORTH-PURSUING
               DISPLAY 'DEDUCT REFUND:$' WS-DEDUCT-REFUND
               DISPLAY 'COMPANY SHARE:$' WS-COMPANY-SHARE
           END-IF.
