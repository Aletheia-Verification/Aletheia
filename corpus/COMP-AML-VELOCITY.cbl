       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMP-AML-VELOCITY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-HISTORY.
           05 WS-TXN-REC OCCURS 30 TIMES.
               10 WS-TXN-DATE     PIC 9(8).
               10 WS-TXN-AMT      PIC S9(9)V99 COMP-3.
               10 WS-TXN-TYPE     PIC X(2).
               10 WS-TXN-CHANNEL  PIC X(3).
                   88 CHAN-BRANCH  VALUE 'BRN'.
                   88 CHAN-ATM     VALUE 'ATM'.
                   88 CHAN-ONLINE  VALUE 'ONL'.
                   88 CHAN-MOBILE  VALUE 'MOB'.
               10 WS-TXN-COUNTRY  PIC X(2).
       01 WS-TXN-COUNT            PIC 99 VALUE 30.
       01 WS-IDX                  PIC 99.
       01 WS-JDX                  PIC 99.
       01 WS-VELOCITY-CHECKS.
           05 WS-24HR-COUNT       PIC 9(3).
           05 WS-24HR-TOTAL       PIC S9(11)V99 COMP-3.
           05 WS-7DAY-COUNT       PIC 9(4).
           05 WS-7DAY-TOTAL       PIC S9(11)V99 COMP-3.
           05 WS-ATM-24HR-COUNT   PIC 9(3).
           05 WS-FOREIGN-COUNT    PIC 9(3).
           05 WS-ROUND-AMT-COUNT  PIC 9(3).
       01 WS-THRESHOLDS.
           05 WS-MAX-24HR-COUNT   PIC 9(3) VALUE 10.
           05 WS-MAX-24HR-TOTAL   PIC S9(11)V99 COMP-3
               VALUE 50000.00.
           05 WS-MAX-ATM-24HR     PIC 9(3) VALUE 5.
           05 WS-CTR-THRESHOLD    PIC S9(7)V99 COMP-3
               VALUE 10000.00.
       01 WS-ALERT-LEVEL          PIC 9.
           88 ALERT-NONE           VALUE 0.
           88 ALERT-LOW            VALUE 1.
           88 ALERT-MEDIUM         VALUE 2.
           88 ALERT-HIGH           VALUE 3.
       01 WS-ALERT-REASONS.
           05 WS-REASON OCCURS 5 TIMES PIC X(30).
       01 WS-REASON-IDX           PIC 9.
       01 WS-ACCT-ID              PIC X(12).
       01 WS-CUST-NAME            PIC X(30).
       01 WS-CHECK-DATE           PIC 9(8).
       01 WS-DATE-DIFF            PIC 9(5).
       01 WS-REMAINDER-AMT        PIC S9(5)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-ANALYZE-VELOCITY
           PERFORM 3000-DETERMINE-ALERT
           PERFORM 4000-OUTPUT-ALERT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-24HR-COUNT
           MOVE 0 TO WS-24HR-TOTAL
           MOVE 0 TO WS-7DAY-COUNT
           MOVE 0 TO WS-7DAY-TOTAL
           MOVE 0 TO WS-ATM-24HR-COUNT
           MOVE 0 TO WS-FOREIGN-COUNT
           MOVE 0 TO WS-ROUND-AMT-COUNT
           MOVE 0 TO WS-ALERT-LEVEL
           MOVE 1 TO WS-REASON-IDX
           ACCEPT WS-CHECK-DATE FROM DATE YYYYMMDD.
       2000-ANALYZE-VELOCITY.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-TXN-COUNT
               COMPUTE WS-DATE-DIFF =
                   WS-CHECK-DATE - WS-TXN-DATE(WS-IDX)
               IF WS-DATE-DIFF <= 1
                   ADD 1 TO WS-24HR-COUNT
                   ADD WS-TXN-AMT(WS-IDX) TO WS-24HR-TOTAL
                   IF CHAN-ATM(WS-IDX)
                       ADD 1 TO WS-ATM-24HR-COUNT
                   END-IF
               END-IF
               IF WS-DATE-DIFF <= 7
                   ADD 1 TO WS-7DAY-COUNT
                   ADD WS-TXN-AMT(WS-IDX) TO WS-7DAY-TOTAL
               END-IF
               IF WS-TXN-COUNTRY(WS-IDX) NOT = 'US'
                   ADD 1 TO WS-FOREIGN-COUNT
               END-IF
               DIVIDE WS-TXN-AMT(WS-IDX) BY 1000
                   GIVING WS-REMAINDER-AMT
                   REMAINDER WS-REMAINDER-AMT
               IF WS-REMAINDER-AMT = 0
                   ADD 1 TO WS-ROUND-AMT-COUNT
               END-IF
           END-PERFORM.
       3000-DETERMINE-ALERT.
           IF WS-24HR-COUNT > WS-MAX-24HR-COUNT
               ADD 1 TO WS-ALERT-LEVEL
               MOVE 'HIGH 24HR TXN COUNT' TO
                   WS-REASON(WS-REASON-IDX)
               ADD 1 TO WS-REASON-IDX
           END-IF
           IF WS-24HR-TOTAL > WS-MAX-24HR-TOTAL
               ADD 1 TO WS-ALERT-LEVEL
               MOVE 'HIGH 24HR TOTAL AMOUNT' TO
                   WS-REASON(WS-REASON-IDX)
               ADD 1 TO WS-REASON-IDX
           END-IF
           IF WS-ATM-24HR-COUNT > WS-MAX-ATM-24HR
               ADD 1 TO WS-ALERT-LEVEL
               MOVE 'EXCESSIVE ATM USAGE' TO
                   WS-REASON(WS-REASON-IDX)
               ADD 1 TO WS-REASON-IDX
           END-IF
           IF WS-ROUND-AMT-COUNT > 3
               ADD 1 TO WS-ALERT-LEVEL
               IF WS-REASON-IDX <= 5
                   MOVE 'STRUCTURING PATTERN' TO
                       WS-REASON(WS-REASON-IDX)
                   ADD 1 TO WS-REASON-IDX
               END-IF
           END-IF.
       4000-OUTPUT-ALERT.
           DISPLAY 'AML VELOCITY CHECK REPORT'
           DISPLAY '========================='
           DISPLAY 'ACCOUNT: ' WS-ACCT-ID
           DISPLAY 'CUSTOMER: ' WS-CUST-NAME
           DISPLAY '24HR TXN COUNT:  ' WS-24HR-COUNT
           DISPLAY '24HR TOTAL:      $' WS-24HR-TOTAL
           DISPLAY '7-DAY COUNT:     ' WS-7DAY-COUNT
           DISPLAY '7-DAY TOTAL:     $' WS-7DAY-TOTAL
           DISPLAY 'ATM 24HR COUNT:  ' WS-ATM-24HR-COUNT
           DISPLAY 'FOREIGN TXN:     ' WS-FOREIGN-COUNT
           DISPLAY 'ROUND AMOUNTS:   ' WS-ROUND-AMT-COUNT
           EVALUATE TRUE
               WHEN ALERT-HIGH
                   DISPLAY 'ALERT: *** HIGH ***'
               WHEN ALERT-MEDIUM
                   DISPLAY 'ALERT: ** MEDIUM **'
               WHEN ALERT-LOW
                   DISPLAY 'ALERT: * LOW *'
               WHEN ALERT-NONE
                   DISPLAY 'ALERT: NONE'
           END-EVALUATE
           PERFORM VARYING WS-JDX FROM 1 BY 1
               UNTIL WS-JDX >= WS-REASON-IDX
               DISPLAY '  REASON: ' WS-REASON(WS-JDX)
           END-PERFORM.
