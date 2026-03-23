       IDENTIFICATION DIVISION.
       PROGRAM-ID. BATCH-INTEREST-POST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-TABLE.
           05 WS-ACCT OCCURS 30 TIMES.
               10 WS-AC-NUM       PIC X(12).
               10 WS-AC-TYPE      PIC X(2).
                   88 AC-CHECKING VALUE 'CK'.
                   88 AC-SAVINGS  VALUE 'SV'.
                   88 AC-MMA      VALUE 'MM'.
                   88 AC-CD       VALUE 'CD'.
               10 WS-AC-BALANCE   PIC S9(11)V99 COMP-3.
               10 WS-AC-RATE      PIC S9(2)V9(6) COMP-3.
               10 WS-AC-ACCRUED   PIC S9(7)V99 COMP-3.
               10 WS-AC-POSTED    PIC S9(7)V99 COMP-3.
               10 WS-AC-DAY-COUNT PIC 9(1).
                   88 DC-360      VALUE 0.
                   88 DC-365      VALUE 1.
       01 WS-ACCT-COUNT          PIC 99 VALUE 30.
       01 WS-IDX                 PIC 99.
       01 WS-DAILY-RATE          PIC S9(1)V9(8) COMP-3.
       01 WS-DAILY-INT           PIC S9(7)V99 COMP-3.
       01 WS-DIVISOR             PIC 9(3).
       01 WS-TOTAL-ACCRUED       PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-POSTED        PIC S9(9)V99 COMP-3.
       01 WS-POST-FLAG           PIC X VALUE 'N'.
           88 IS-MONTH-END       VALUE 'Y'.
       01 WS-CURRENT-DATE        PIC 9(8).
       01 WS-CURRENT-DAY         PIC 9(2).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-ACCRUE-ALL
           IF IS-MONTH-END
               PERFORM 3000-POST-ALL
           END-IF
           PERFORM 4000-REPORT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE WS-CURRENT-DATE(7:2) TO WS-CURRENT-DAY
           MOVE 0 TO WS-TOTAL-ACCRUED
           MOVE 0 TO WS-TOTAL-POSTED
           IF WS-CURRENT-DAY = 28
               OR WS-CURRENT-DAY = 30
               OR WS-CURRENT-DAY = 31
               MOVE 'Y' TO WS-POST-FLAG
           END-IF.
       2000-ACCRUE-ALL.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ACCT-COUNT
               IF DC-360(WS-IDX)
                   MOVE 360 TO WS-DIVISOR
               ELSE
                   MOVE 365 TO WS-DIVISOR
               END-IF
               COMPUTE WS-DAILY-RATE =
                   WS-AC-RATE(WS-IDX) / WS-DIVISOR
               COMPUTE WS-DAILY-INT =
                   WS-AC-BALANCE(WS-IDX) * WS-DAILY-RATE
               ADD WS-DAILY-INT TO WS-AC-ACCRUED(WS-IDX)
               ADD WS-DAILY-INT TO WS-TOTAL-ACCRUED
           END-PERFORM.
       3000-POST-ALL.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-ACCT-COUNT
               IF WS-AC-ACCRUED(WS-IDX) > 0
                   ADD WS-AC-ACCRUED(WS-IDX) TO
                       WS-AC-BALANCE(WS-IDX)
                   MOVE WS-AC-ACCRUED(WS-IDX) TO
                       WS-AC-POSTED(WS-IDX)
                   ADD WS-AC-ACCRUED(WS-IDX) TO
                       WS-TOTAL-POSTED
                   MOVE 0 TO WS-AC-ACCRUED(WS-IDX)
               END-IF
           END-PERFORM.
       4000-REPORT.
           DISPLAY 'INTEREST ACCRUAL/POSTING'
           DISPLAY '========================'
           DISPLAY 'DATE:     ' WS-CURRENT-DATE
           DISPLAY 'ACCOUNTS: ' WS-ACCT-COUNT
           DISPLAY 'ACCRUED:  $' WS-TOTAL-ACCRUED
           IF IS-MONTH-END
               DISPLAY 'POSTED:   $' WS-TOTAL-POSTED
               DISPLAY 'STATUS: MONTH-END POST'
           ELSE
               DISPLAY 'STATUS: DAILY ACCRUAL ONLY'
           END-IF.
