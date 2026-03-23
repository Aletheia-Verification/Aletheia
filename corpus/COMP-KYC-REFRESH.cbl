       IDENTIFICATION DIVISION.
       PROGRAM-ID. COMP-KYC-REFRESH.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CUSTOMER.
           05 WS-CUST-ID          PIC X(12).
           05 WS-CUST-NAME        PIC X(40).
           05 WS-CUST-TYPE        PIC X(1).
               88 CT-INDIVIDUAL   VALUE 'I'.
               88 CT-BUSINESS     VALUE 'B'.
               88 CT-TRUST        VALUE 'T'.
           05 WS-RISK-RATING      PIC 9.
               88 RISK-LOW        VALUE 1.
               88 RISK-MEDIUM     VALUE 2.
               88 RISK-HIGH       VALUE 3.
           05 WS-LAST-REVIEW      PIC 9(8).
           05 WS-ID-TYPE          PIC X(2).
           05 WS-ID-EXPIRY        PIC 9(8).
           05 WS-BENEFICIAL-OWNER PIC X VALUE 'N'.
               88 HAS-BO          VALUE 'Y'.
       01 WS-REVIEW-SCHEDULE.
           05 WS-LOW-RISK-MO      PIC 9(2) VALUE 36.
           05 WS-MED-RISK-MO      PIC 9(2) VALUE 24.
           05 WS-HIGH-RISK-MO     PIC 9(2) VALUE 12.
       01 WS-CURRENT-DATE         PIC 9(8).
       01 WS-MONTHS-SINCE-REVIEW  PIC 9(3).
       01 WS-REVIEW-DUE           PIC X VALUE 'N'.
           88 IS-DUE              VALUE 'Y'.
       01 WS-ID-EXPIRED           PIC X VALUE 'N'.
           88 ID-IS-EXPIRED       VALUE 'Y'.
       01 WS-ACTIONS-NEEDED       PIC 9.
       01 WS-ACTION-TABLE.
           05 WS-ACTION OCCURS 5 TIMES PIC X(30).
       01 WS-ACT-IDX              PIC 9.
       01 WS-PRIORITY             PIC X(8).
       01 WS-DAYS-OVERDUE         PIC S9(5) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CHECK-REVIEW-DUE
           PERFORM 3000-CHECK-ID-EXPIRY
           PERFORM 4000-CHECK-BO-STATUS
           PERFORM 5000-SET-PRIORITY
           PERFORM 6000-OUTPUT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-ACTIONS-NEEDED
           MOVE 1 TO WS-ACT-IDX
           MOVE 'N' TO WS-REVIEW-DUE
           MOVE 'N' TO WS-ID-EXPIRED.
       2000-CHECK-REVIEW-DUE.
           COMPUTE WS-MONTHS-SINCE-REVIEW =
               (WS-CURRENT-DATE - WS-LAST-REVIEW) / 100
           EVALUATE TRUE
               WHEN RISK-LOW
                   IF WS-MONTHS-SINCE-REVIEW >=
                       WS-LOW-RISK-MO
                       MOVE 'Y' TO WS-REVIEW-DUE
                   END-IF
               WHEN RISK-MEDIUM
                   IF WS-MONTHS-SINCE-REVIEW >=
                       WS-MED-RISK-MO
                       MOVE 'Y' TO WS-REVIEW-DUE
                   END-IF
               WHEN RISK-HIGH
                   IF WS-MONTHS-SINCE-REVIEW >=
                       WS-HIGH-RISK-MO
                       MOVE 'Y' TO WS-REVIEW-DUE
                   END-IF
           END-EVALUATE
           IF IS-DUE
               MOVE 'PERIODIC REVIEW DUE'
                   TO WS-ACTION(WS-ACT-IDX)
               ADD 1 TO WS-ACTIONS-NEEDED
               ADD 1 TO WS-ACT-IDX
           END-IF.
       3000-CHECK-ID-EXPIRY.
           IF WS-ID-EXPIRY < WS-CURRENT-DATE
               MOVE 'Y' TO WS-ID-EXPIRED
               MOVE 'COLLECT VALID ID'
                   TO WS-ACTION(WS-ACT-IDX)
               ADD 1 TO WS-ACTIONS-NEEDED
               ADD 1 TO WS-ACT-IDX
           ELSE
               COMPUTE WS-DAYS-OVERDUE =
                   WS-ID-EXPIRY - WS-CURRENT-DATE
               IF WS-DAYS-OVERDUE < 90
                   MOVE 'ID EXPIRING SOON'
                       TO WS-ACTION(WS-ACT-IDX)
                   ADD 1 TO WS-ACTIONS-NEEDED
                   ADD 1 TO WS-ACT-IDX
               END-IF
           END-IF.
       4000-CHECK-BO-STATUS.
           IF CT-BUSINESS OR CT-TRUST
               IF NOT HAS-BO
                   MOVE 'COLLECT BENEFICIAL OWNER'
                       TO WS-ACTION(WS-ACT-IDX)
                   ADD 1 TO WS-ACTIONS-NEEDED
                   ADD 1 TO WS-ACT-IDX
               END-IF
           END-IF.
       5000-SET-PRIORITY.
           IF WS-ACTIONS-NEEDED >= 3
               MOVE 'CRITICAL' TO WS-PRIORITY
           ELSE
               IF WS-ACTIONS-NEEDED >= 2
                   MOVE 'HIGH    ' TO WS-PRIORITY
               ELSE
                   IF WS-ACTIONS-NEEDED >= 1
                       MOVE 'MEDIUM  ' TO WS-PRIORITY
                   ELSE
                       MOVE 'NONE    ' TO WS-PRIORITY
                   END-IF
               END-IF
           END-IF
           IF RISK-HIGH
               IF WS-ACTIONS-NEEDED > 0
                   MOVE 'CRITICAL' TO WS-PRIORITY
               END-IF
           END-IF.
       6000-OUTPUT.
           DISPLAY 'KYC REFRESH ASSESSMENT'
           DISPLAY '======================'
           DISPLAY 'CUSTOMER: ' WS-CUST-ID
           DISPLAY 'NAME:     ' WS-CUST-NAME
           DISPLAY 'TYPE:     ' WS-CUST-TYPE
           DISPLAY 'RISK:     ' WS-RISK-RATING
           DISPLAY 'MONTHS:   ' WS-MONTHS-SINCE-REVIEW
           DISPLAY 'PRIORITY: ' WS-PRIORITY
           DISPLAY 'ACTIONS:  ' WS-ACTIONS-NEEDED
           PERFORM VARYING WS-ACT-IDX FROM 1 BY 1
               UNTIL WS-ACT-IDX > WS-ACTIONS-NEEDED
               DISPLAY '  - ' WS-ACTION(WS-ACT-IDX)
           END-PERFORM.
