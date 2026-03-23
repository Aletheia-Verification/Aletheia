       IDENTIFICATION DIVISION.
       PROGRAM-ID. CARD-BLOCK-REISSUE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CARD-DATA.
           05 WS-OLD-PAN          PIC X(16).
           05 WS-NEW-PAN          PIC X(16).
           05 WS-CARD-STATUS      PIC X(1).
               88 CS-ACTIVE       VALUE 'A'.
               88 CS-BLOCKED      VALUE 'B'.
               88 CS-REISSUED     VALUE 'R'.
           05 WS-BLOCK-REASON     PIC X(2).
               88 BR-LOST         VALUE 'LS'.
               88 BR-STOLEN       VALUE 'ST'.
               88 BR-COMPROMISED  VALUE 'CP'.
               88 BR-DAMAGED      VALUE 'DM'.
               88 BR-EXPIRED      VALUE 'EX'.
           05 WS-CARD-BALANCE     PIC S9(7)V99 COMP-3.
           05 WS-CARD-LIMIT       PIC S9(7)V99 COMP-3.
       01 WS-CUST-INFO.
           05 WS-CUST-ID          PIC X(10).
           05 WS-CUST-NAME        PIC X(30).
           05 WS-SHIP-ADDRESS     PIC X(50).
       01 WS-REISSUE-FLAGS.
           05 WS-INSTANT-REISSUE  PIC X VALUE 'N'.
               88 CAN-INSTANT     VALUE 'Y'.
           05 WS-TRANSFER-BAL     PIC X VALUE 'Y'.
               88 DO-TRANSFER     VALUE 'Y'.
           05 WS-FRAUD-ALERT      PIC X VALUE 'N'.
               88 SET-FRAUD-ALERT VALUE 'Y'.
       01 WS-SHIP-METHOD          PIC X(8).
       01 WS-EXPECTED-DELIVERY    PIC 9(8).
       01 WS-CURRENT-DATE         PIC 9(8).
       01 WS-DELIVERY-DAYS        PIC 9(2).
       01 WS-RESULT-MSG           PIC X(40).
       01 WS-AUDIT-LINE           PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-BLOCK-CARD
           PERFORM 2000-DETERMINE-REISSUE
           PERFORM 3000-PROCESS-REISSUE
           PERFORM 4000-AUDIT
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-BLOCK-CARD.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           IF CS-ACTIVE
               MOVE 'B' TO WS-CARD-STATUS
           END-IF
           IF BR-STOLEN OR BR-COMPROMISED
               MOVE 'Y' TO WS-FRAUD-ALERT
           END-IF.
       2000-DETERMINE-REISSUE.
           EVALUATE TRUE
               WHEN BR-LOST
                   MOVE 'STANDARD' TO WS-SHIP-METHOD
                   MOVE 7 TO WS-DELIVERY-DAYS
               WHEN BR-STOLEN
                   MOVE 'EXPRESS ' TO WS-SHIP-METHOD
                   MOVE 2 TO WS-DELIVERY-DAYS
               WHEN BR-COMPROMISED
                   MOVE 'EXPRESS ' TO WS-SHIP-METHOD
                   MOVE 2 TO WS-DELIVERY-DAYS
                   MOVE 'Y' TO WS-INSTANT-REISSUE
               WHEN BR-DAMAGED
                   MOVE 'STANDARD' TO WS-SHIP-METHOD
                   MOVE 7 TO WS-DELIVERY-DAYS
               WHEN BR-EXPIRED
                   MOVE 'STANDARD' TO WS-SHIP-METHOD
                   MOVE 10 TO WS-DELIVERY-DAYS
               WHEN OTHER
                   MOVE 'STANDARD' TO WS-SHIP-METHOD
                   MOVE 10 TO WS-DELIVERY-DAYS
           END-EVALUATE
           COMPUTE WS-EXPECTED-DELIVERY =
               WS-CURRENT-DATE + WS-DELIVERY-DAYS.
       3000-PROCESS-REISSUE.
           MOVE 'R' TO WS-CARD-STATUS
           IF DO-TRANSFER
               DISPLAY 'BALANCE TRANSFERRED TO NEW CARD'
           END-IF
           IF SET-FRAUD-ALERT
               DISPLAY 'FRAUD ALERT SET ON ACCOUNT'
           END-IF
           IF CAN-INSTANT
               MOVE 'VIRTUAL CARD ISSUED IMMEDIATELY'
                   TO WS-RESULT-MSG
           ELSE
               MOVE 'NEW CARD SHIPPED' TO WS-RESULT-MSG
           END-IF.
       4000-AUDIT.
           STRING 'REISSUE OLD=' DELIMITED BY SIZE
               WS-OLD-PAN DELIMITED BY SIZE
               ' RSN=' DELIMITED BY SIZE
               WS-BLOCK-REASON DELIMITED BY SIZE
               INTO WS-AUDIT-LINE
           END-STRING.
       5000-OUTPUT.
           DISPLAY 'CARD BLOCK AND REISSUE'
           DISPLAY '======================'
           DISPLAY 'OLD PAN:   ' WS-OLD-PAN
           DISPLAY 'NEW PAN:   ' WS-NEW-PAN
           DISPLAY 'REASON:    ' WS-BLOCK-REASON
           DISPLAY 'CUSTOMER:  ' WS-CUST-NAME
           DISPLAY 'BALANCE:   $' WS-CARD-BALANCE
           DISPLAY 'SHIPPING:  ' WS-SHIP-METHOD
           DISPLAY 'DELIVERY:  ' WS-EXPECTED-DELIVERY
           DISPLAY 'RESULT:    ' WS-RESULT-MSG
           IF SET-FRAUD-ALERT
               DISPLAY 'FRAUD ALERT ACTIVE'
           END-IF.
