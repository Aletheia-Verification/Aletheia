       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-POLICY-RENEW.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POLICY.
           05 WS-POL-NUMBER        PIC X(12).
           05 WS-POL-TYPE          PIC X(2).
               88 POL-TERM         VALUE 'TL'.
               88 POL-WHOLE        VALUE 'WL'.
               88 POL-UNIVERSAL    VALUE 'UL'.
           05 WS-POL-STATUS        PIC X(1).
               88 STAT-ACTIVE      VALUE 'A'.
               88 STAT-LAPSED      VALUE 'L'.
               88 STAT-PENDING     VALUE 'P'.
           05 WS-POL-FACE-AMT     PIC S9(9)V99 COMP-3.
           05 WS-POL-PREMIUM      PIC S9(7)V99 COMP-3.
           05 WS-POL-START-DATE   PIC 9(8).
           05 WS-POL-RENEW-DATE   PIC 9(8).
           05 WS-INSURED-AGE       PIC 9(3).
           05 WS-HEALTH-CLASS      PIC X(2).
               88 HC-PREFERRED     VALUE 'PP'.
               88 HC-STANDARD      VALUE 'ST'.
               88 HC-SUBSTANDARD   VALUE 'SS'.
       01 WS-RENEWAL.
           05 WS-NEW-PREMIUM       PIC S9(7)V99 COMP-3.
           05 WS-AGE-FACTOR        PIC S9(1)V9(4) COMP-3.
           05 WS-HEALTH-FACTOR     PIC S9(1)V9(4) COMP-3.
           05 WS-LOYALTY-DISCOUNT  PIC S9(1)V9(4) COMP-3.
           05 WS-INFLATION-ADJ     PIC S9(1)V9(4) COMP-3
               VALUE 1.0300.
           05 WS-YEARS-ACTIVE      PIC 9(3).
       01 WS-CURRENT-DATE          PIC 9(8).
       01 WS-DAYS-UNTIL-RENEW      PIC S9(5) COMP-3.
       01 WS-NOTICE-TYPE           PIC X(12).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CHECK-ELIGIBILITY
           IF STAT-ACTIVE
               PERFORM 3000-CALC-NEW-PREMIUM
               PERFORM 4000-DETERMINE-NOTICE
           END-IF
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           COMPUTE WS-DAYS-UNTIL-RENEW =
               WS-POL-RENEW-DATE - WS-CURRENT-DATE.
       2000-CHECK-ELIGIBILITY.
           IF STAT-LAPSED
               DISPLAY 'POLICY LAPSED - CANNOT RENEW'
           END-IF
           IF STAT-PENDING
               DISPLAY 'POLICY PENDING - REVIEW REQUIRED'
           END-IF.
       3000-CALC-NEW-PREMIUM.
           IF WS-INSURED-AGE < 40
               MOVE 1.0000 TO WS-AGE-FACTOR
           ELSE
               IF WS-INSURED-AGE < 55
                   MOVE 1.1500 TO WS-AGE-FACTOR
               ELSE
                   IF WS-INSURED-AGE < 65
                       MOVE 1.3500 TO WS-AGE-FACTOR
                   ELSE
                       MOVE 1.7500 TO WS-AGE-FACTOR
                   END-IF
               END-IF
           END-IF
           EVALUATE TRUE
               WHEN HC-PREFERRED
                   MOVE 0.8500 TO WS-HEALTH-FACTOR
               WHEN HC-STANDARD
                   MOVE 1.0000 TO WS-HEALTH-FACTOR
               WHEN HC-SUBSTANDARD
                   MOVE 1.5000 TO WS-HEALTH-FACTOR
               WHEN OTHER
                   MOVE 1.2500 TO WS-HEALTH-FACTOR
           END-EVALUATE
           COMPUTE WS-YEARS-ACTIVE =
               (WS-CURRENT-DATE - WS-POL-START-DATE) / 10000
           IF WS-YEARS-ACTIVE >= 10
               MOVE 0.9000 TO WS-LOYALTY-DISCOUNT
           ELSE
               IF WS-YEARS-ACTIVE >= 5
                   MOVE 0.9500 TO WS-LOYALTY-DISCOUNT
               ELSE
                   MOVE 1.0000 TO WS-LOYALTY-DISCOUNT
               END-IF
           END-IF
           COMPUTE WS-NEW-PREMIUM =
               WS-POL-PREMIUM *
               WS-AGE-FACTOR *
               WS-HEALTH-FACTOR *
               WS-LOYALTY-DISCOUNT *
               WS-INFLATION-ADJ.
       4000-DETERMINE-NOTICE.
           IF WS-DAYS-UNTIL-RENEW > 60
               MOVE 'ADVANCE     ' TO WS-NOTICE-TYPE
           ELSE
               IF WS-DAYS-UNTIL-RENEW > 30
                   MOVE 'STANDARD    ' TO WS-NOTICE-TYPE
               ELSE
                   IF WS-DAYS-UNTIL-RENEW > 0
                       MOVE 'URGENT      ' TO WS-NOTICE-TYPE
                   ELSE
                       MOVE 'OVERDUE     ' TO WS-NOTICE-TYPE
                   END-IF
               END-IF
           END-IF.
       5000-OUTPUT.
           DISPLAY 'POLICY RENEWAL PROCESSING'
           DISPLAY '========================='
           DISPLAY 'POLICY:  ' WS-POL-NUMBER
           DISPLAY 'TYPE:    ' WS-POL-TYPE
           DISPLAY 'STATUS:  ' WS-POL-STATUS
           IF STAT-ACTIVE
               DISPLAY 'CURRENT PREMIUM: $' WS-POL-PREMIUM
               DISPLAY 'NEW PREMIUM:     $' WS-NEW-PREMIUM
               DISPLAY 'AGE FACTOR:      ' WS-AGE-FACTOR
               DISPLAY 'HEALTH FACTOR:   ' WS-HEALTH-FACTOR
               DISPLAY 'LOYALTY DISC:    ' WS-LOYALTY-DISCOUNT
               DISPLAY 'NOTICE TYPE:     ' WS-NOTICE-TYPE
               DISPLAY 'DAYS TO RENEW:   ' WS-DAYS-UNTIL-RENEW
           END-IF.
