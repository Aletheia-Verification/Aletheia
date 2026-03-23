       IDENTIFICATION DIVISION.
       PROGRAM-ID. TREAS-ZBA-TRANSFER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CONCENTRATION-ACCT.
           05 WS-CONC-NUM            PIC X(12).
           05 WS-CONC-BAL            PIC S9(11)V99 COMP-3.
       01 WS-ZBA-ACCT.
           05 WS-ZBA-NUM             PIC X(12).
           05 WS-ZBA-BAL             PIC S9(9)V99 COMP-3.
           05 WS-ZBA-TARGET          PIC S9(9)V99 COMP-3
               VALUE 0.
       01 WS-ZBA-TYPE                PIC X(1).
           88 WS-FUND-ZBA            VALUE 'F'.
           88 WS-SWEEP-ZBA           VALUE 'S'.
           88 WS-NO-ACTION           VALUE 'N'.
       01 WS-TRANSFER-FIELDS.
           05 WS-TRANSFER-AMT        PIC S9(9)V99 COMP-3.
           05 WS-TRANSFER-FEE        PIC S9(5)V99 COMP-3.
           05 WS-NET-TRANSFER        PIC S9(9)V99 COMP-3.
       01 WS-DAY-TYPE                PIC X(1).
           88 WS-BUSINESS-DAY        VALUE 'B'.
           88 WS-WEEKEND             VALUE 'W'.
           88 WS-HOLIDAY             VALUE 'H'.
       01 WS-PROCESS-FLAG            PIC X VALUE 'Y'.
           88 WS-CAN-PROCESS         VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-DAY-TYPE
           IF WS-CAN-PROCESS
               PERFORM 3000-DETERMINE-ACTION
               PERFORM 4000-EXECUTE-TRANSFER
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TRANSFER-AMT
           MOVE 0 TO WS-TRANSFER-FEE
           SET WS-NO-ACTION TO TRUE.
       2000-CHECK-DAY-TYPE.
           EVALUATE TRUE
               WHEN WS-BUSINESS-DAY
                   MOVE 'Y' TO WS-PROCESS-FLAG
               WHEN WS-WEEKEND
                   MOVE 'N' TO WS-PROCESS-FLAG
                   DISPLAY 'WEEKEND: NO ZBA PROCESSING'
               WHEN WS-HOLIDAY
                   MOVE 'N' TO WS-PROCESS-FLAG
                   DISPLAY 'HOLIDAY: NO ZBA PROCESSING'
               WHEN OTHER
                   MOVE 'Y' TO WS-PROCESS-FLAG
           END-EVALUATE.
       3000-DETERMINE-ACTION.
           IF WS-ZBA-BAL < WS-ZBA-TARGET
               SET WS-FUND-ZBA TO TRUE
               COMPUTE WS-TRANSFER-AMT =
                   WS-ZBA-TARGET - WS-ZBA-BAL
           ELSE
               IF WS-ZBA-BAL > WS-ZBA-TARGET
                   SET WS-SWEEP-ZBA TO TRUE
                   COMPUTE WS-TRANSFER-AMT =
                       WS-ZBA-BAL - WS-ZBA-TARGET
               ELSE
                   SET WS-NO-ACTION TO TRUE
               END-IF
           END-IF.
       4000-EXECUTE-TRANSFER.
           IF WS-FUND-ZBA
               IF WS-TRANSFER-AMT > WS-CONC-BAL
                   MOVE WS-CONC-BAL TO WS-TRANSFER-AMT
               END-IF
               SUBTRACT WS-TRANSFER-AMT FROM WS-CONC-BAL
               ADD WS-TRANSFER-AMT TO WS-ZBA-BAL
               DISPLAY 'FUNDED ZBA: ' WS-TRANSFER-AMT
           END-IF
           IF WS-SWEEP-ZBA
               SUBTRACT WS-TRANSFER-AMT FROM WS-ZBA-BAL
               ADD WS-TRANSFER-AMT TO WS-CONC-BAL
               DISPLAY 'SWEPT TO CONC: ' WS-TRANSFER-AMT
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'ZBA TRANSFER REPORT'
           DISPLAY '==================='
           DISPLAY 'CONCENTRATION: ' WS-CONC-NUM
           DISPLAY 'CONC BAL:      ' WS-CONC-BAL
           DISPLAY 'ZBA ACCT:      ' WS-ZBA-NUM
           DISPLAY 'ZBA BAL:       ' WS-ZBA-BAL
           DISPLAY 'TRANSFER:      ' WS-TRANSFER-AMT
           IF WS-FUND-ZBA
               DISPLAY 'ACTION: FUNDED ZBA'
           END-IF
           IF WS-SWEEP-ZBA
               DISPLAY 'ACTION: SWEPT TO CONCENTRATION'
           END-IF
           IF WS-NO-ACTION
               DISPLAY 'ACTION: NONE (AT TARGET)'
           END-IF.
