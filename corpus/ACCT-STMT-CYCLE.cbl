       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-STMT-CYCLE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-ACCT-OPEN-DATE      PIC 9(8).
           05 WS-CURRENT-DATE        PIC 9(8).
           05 WS-LAST-STMT-DATE      PIC 9(8).
       01 WS-CYCLE-TYPE              PIC X(1).
           88 WS-MONTHLY             VALUE 'M'.
           88 WS-QUARTERLY           VALUE 'Q'.
           88 WS-ANNUAL              VALUE 'A'.
       01 WS-CYCLE-DAY               PIC 9(2).
       01 WS-STMT-TABLE.
           05 WS-STMT-ENTRY OCCURS 12.
               10 WS-STMT-MONTH      PIC 9(2).
               10 WS-STMT-DUE        PIC 9(8).
               10 WS-STMT-STATUS     PIC X(1).
       01 WS-STMT-IDX                PIC 9(2).
       01 WS-GENERATED-COUNT         PIC 9(2).
       01 WS-NEXT-STMT-DATE          PIC 9(8).
       01 WS-DAYS-TO-NEXT            PIC 9(3).
       01 WS-OVERDUE-FLAG            PIC X VALUE 'N'.
           88 WS-IS-OVERDUE          VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-CYCLE
           PERFORM 3000-GENERATE-SCHEDULE
           PERFORM 4000-CHECK-OVERDUE
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-GENERATED-COUNT
           MOVE 'N' TO WS-OVERDUE-FLAG.
       2000-DETERMINE-CYCLE.
           EVALUATE TRUE
               WHEN WS-MONTHLY
                   MOVE 1 TO WS-CYCLE-DAY
               WHEN WS-QUARTERLY
                   MOVE 1 TO WS-CYCLE-DAY
               WHEN WS-ANNUAL
                   MOVE 1 TO WS-CYCLE-DAY
               WHEN OTHER
                   SET WS-MONTHLY TO TRUE
           END-EVALUATE.
       3000-GENERATE-SCHEDULE.
           PERFORM VARYING WS-STMT-IDX FROM 1 BY 1
               UNTIL WS-STMT-IDX > 12
               MOVE WS-STMT-IDX TO
                   WS-STMT-MONTH(WS-STMT-IDX)
               IF WS-MONTHLY
                   MOVE WS-CURRENT-DATE TO
                       WS-STMT-DUE(WS-STMT-IDX)
                   MOVE 'S' TO WS-STMT-STATUS(WS-STMT-IDX)
                   ADD 1 TO WS-GENERATED-COUNT
               ELSE
                   IF WS-QUARTERLY
                       EVALUATE WS-STMT-IDX
                           WHEN 3
                               MOVE 'S' TO
                                  WS-STMT-STATUS(WS-STMT-IDX)
                               ADD 1 TO WS-GENERATED-COUNT
                           WHEN 6
                               MOVE 'S' TO
                                  WS-STMT-STATUS(WS-STMT-IDX)
                               ADD 1 TO WS-GENERATED-COUNT
                           WHEN 9
                               MOVE 'S' TO
                                  WS-STMT-STATUS(WS-STMT-IDX)
                               ADD 1 TO WS-GENERATED-COUNT
                           WHEN 12
                               MOVE 'S' TO
                                  WS-STMT-STATUS(WS-STMT-IDX)
                               ADD 1 TO WS-GENERATED-COUNT
                           WHEN OTHER
                               MOVE 'N' TO
                                  WS-STMT-STATUS(WS-STMT-IDX)
                       END-EVALUATE
                   ELSE
                       IF WS-STMT-IDX = 12
                           MOVE 'S' TO
                               WS-STMT-STATUS(WS-STMT-IDX)
                           ADD 1 TO WS-GENERATED-COUNT
                       ELSE
                           MOVE 'N' TO
                               WS-STMT-STATUS(WS-STMT-IDX)
                       END-IF
                   END-IF
               END-IF
           END-PERFORM.
       4000-CHECK-OVERDUE.
           IF WS-CURRENT-DATE > WS-LAST-STMT-DATE
               COMPUTE WS-DAYS-TO-NEXT =
                   WS-CURRENT-DATE - WS-LAST-STMT-DATE
               IF WS-MONTHLY
                   IF WS-DAYS-TO-NEXT > 35
                       MOVE 'Y' TO WS-OVERDUE-FLAG
                   END-IF
               END-IF
               IF WS-QUARTERLY
                   IF WS-DAYS-TO-NEXT > 95
                       MOVE 'Y' TO WS-OVERDUE-FLAG
                   END-IF
               END-IF
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'STATEMENT CYCLE REPORT'
           DISPLAY '======================'
           DISPLAY 'ACCOUNT:        ' WS-ACCT-NUM
           DISPLAY 'CYCLE TYPE:     ' WS-CYCLE-TYPE
           DISPLAY 'STATEMENTS:     ' WS-GENERATED-COUNT
           DISPLAY 'LAST STMT DATE: ' WS-LAST-STMT-DATE
           IF WS-IS-OVERDUE
               DISPLAY 'STATUS: OVERDUE'
           ELSE
               DISPLAY 'STATUS: CURRENT'
           END-IF
           PERFORM VARYING WS-STMT-IDX FROM 1 BY 1
               UNTIL WS-STMT-IDX > 12
               IF WS-STMT-STATUS(WS-STMT-IDX) = 'S'
                   DISPLAY '  MONTH '
                       WS-STMT-MONTH(WS-STMT-IDX)
                       ' SCHEDULED'
               END-IF
           END-PERFORM.
