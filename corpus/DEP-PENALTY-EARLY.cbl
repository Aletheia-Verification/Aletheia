       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEP-PENALTY-EARLY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CD-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-PRINCIPAL           PIC S9(9)V99 COMP-3.
           05 WS-RATE                PIC S9(3)V9(6) COMP-3.
           05 WS-TERM-MONTHS         PIC 9(3).
           05 WS-MONTHS-HELD         PIC 9(3).
       01 WS-CD-TYPE                 PIC X(1).
           88 WS-SHORT-TERM          VALUE 'S'.
           88 WS-MEDIUM-TERM         VALUE 'M'.
           88 WS-LONG-TERM           VALUE 'L'.
       01 WS-PENALTY-DAYS            PIC 9(3).
       01 WS-PENALTY-AMT             PIC S9(7)V99 COMP-3.
       01 WS-ACCRUED-INT             PIC S9(7)V99 COMP-3.
       01 WS-NET-INT                 PIC S9(7)V99 COMP-3.
       01 WS-NET-PROCEEDS            PIC S9(9)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SET-PENALTY
           PERFORM 3000-CALC-PENALTY
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-PENALTY-AMT
           MOVE 0 TO WS-NET-INT.
       2000-SET-PENALTY.
           EVALUATE TRUE
               WHEN WS-SHORT-TERM
                   MOVE 90 TO WS-PENALTY-DAYS
               WHEN WS-MEDIUM-TERM
                   MOVE 180 TO WS-PENALTY-DAYS
               WHEN WS-LONG-TERM
                   MOVE 365 TO WS-PENALTY-DAYS
               WHEN OTHER
                   MOVE 180 TO WS-PENALTY-DAYS
           END-EVALUATE.
       3000-CALC-PENALTY.
           COMPUTE WS-ACCRUED-INT =
               WS-PRINCIPAL * WS-RATE * WS-MONTHS-HELD / 12
           COMPUTE WS-PENALTY-AMT =
               WS-PRINCIPAL * WS-RATE * WS-PENALTY-DAYS
               / 360
           COMPUTE WS-NET-INT = WS-ACCRUED-INT - WS-PENALTY-AMT
           IF WS-NET-INT < 0
               MOVE 0 TO WS-NET-INT
           END-IF
           COMPUTE WS-NET-PROCEEDS =
               WS-PRINCIPAL + WS-NET-INT.
       4000-DISPLAY-RESULTS.
           DISPLAY 'EARLY WITHDRAWAL PENALTY'
           DISPLAY '========================'
           DISPLAY 'ACCOUNT:     ' WS-ACCT-NUM
           DISPLAY 'PRINCIPAL:   ' WS-PRINCIPAL
           DISPLAY 'ACCRUED INT: ' WS-ACCRUED-INT
           DISPLAY 'PENALTY:     ' WS-PENALTY-AMT
           DISPLAY 'PROCEEDS:    ' WS-NET-PROCEEDS.
