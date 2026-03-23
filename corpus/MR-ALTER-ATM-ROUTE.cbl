       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ALTER-ATM-ROUTE.
      *================================================================*
      * ATM Network Message Router (Legacy ALTER Pattern)              *
      * Uses ALTER GO TO for dynamic routing of ATM authorization      *
      * messages based on network and card type.                       *
      * INTENTIONAL: Uses ALTER to trigger MANUAL REVIEW.              *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Message Header ---
       01  WS-MSG-TYPE                PIC 9(4).
       01  WS-NETWORK-CODE            PIC X(4).
       01  WS-CARD-TYPE               PIC 9.
           88  WS-DEBIT-CARD          VALUE 1.
           88  WS-CREDIT-CARD         VALUE 2.
           88  WS-PREPAID-CARD        VALUE 3.
       01  WS-TXN-AMOUNT              PIC S9(9)V99 COMP-3.
      *--- Route Target ---
       01  WS-ROUTE-TARGET            PIC X(10).
       01  WS-ROUTE-ATTEMPTS          PIC S9(3) COMP-3.
       01  WS-MAX-ATTEMPTS            PIC S9(3) COMP-3.
      *--- Response Fields ---
       01  WS-RESPONSE-CODE           PIC X(3).
       01  WS-AUTH-CODE               PIC X(6).
       01  WS-RESPONSE-TIME           PIC S9(5) COMP-3.
      *--- Counters ---
       01  WS-ROUTED-CT               PIC S9(5) COMP-3.
       01  WS-FAILED-CT               PIC S9(5) COMP-3.
       01  WS-TIMEOUT-CT              PIC S9(3) COMP-3.
      *--- Processing Table ---
       01  WS-MSG-TABLE.
           05  WS-MSG-ENTRY OCCURS 5 TIMES.
               10  WS-M-NETWORK       PIC X(4).
               10  WS-M-CARD          PIC 9.
               10  WS-M-AMOUNT        PIC S9(9)V99 COMP-3.
               10  WS-M-RESULT        PIC X(10).
       01  WS-M-IDX                   PIC 9(3).
       01  WS-M-COUNT                 PIC 9(3).
      *--- Display ---
       01  WS-DISP-AMT                PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT                 PIC ZZ,ZZ9.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-MESSAGES
           PERFORM 3000-ROUTE-MESSAGES
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-ROUTED-CT
           MOVE 0 TO WS-FAILED-CT
           MOVE 0 TO WS-TIMEOUT-CT
           MOVE 3 TO WS-MAX-ATTEMPTS.

       2000-LOAD-MESSAGES.
           MOVE 4 TO WS-M-COUNT
           MOVE "VISA" TO WS-M-NETWORK(1)
           MOVE 1 TO WS-M-CARD(1)
           MOVE 200.00 TO WS-M-AMOUNT(1)
           MOVE "STAR" TO WS-M-NETWORK(2)
           MOVE 1 TO WS-M-CARD(2)
           MOVE 500.00 TO WS-M-AMOUNT(2)
           MOVE "MAST" TO WS-M-NETWORK(3)
           MOVE 2 TO WS-M-CARD(3)
           MOVE 150.00 TO WS-M-AMOUNT(3)
           MOVE "PLUS" TO WS-M-NETWORK(4)
           MOVE 3 TO WS-M-CARD(4)
           MOVE 100.00 TO WS-M-AMOUNT(4).

       3000-ROUTE-MESSAGES.
           PERFORM VARYING WS-M-IDX FROM 1 BY 1
               UNTIL WS-M-IDX > WS-M-COUNT
               MOVE WS-M-NETWORK(WS-M-IDX)
                   TO WS-NETWORK-CODE
               MOVE WS-M-CARD(WS-M-IDX)
                   TO WS-CARD-TYPE
               MOVE WS-M-AMOUNT(WS-M-IDX)
                   TO WS-TXN-AMOUNT
               ALTER 9000-ROUTE-EXIT TO PROCEED TO
                   9100-VISA-HANDLER
               IF WS-NETWORK-CODE = "VISA"
                   ALTER 9000-ROUTE-EXIT TO PROCEED TO
                       9100-VISA-HANDLER
               END-IF
               IF WS-NETWORK-CODE = "MAST"
                   ALTER 9000-ROUTE-EXIT TO PROCEED TO
                       9200-MC-HANDLER
               END-IF
               GO TO 9000-ROUTE-EXIT
           END-PERFORM.

       4000-DISPLAY-RESULTS.
           DISPLAY "========================================"
           DISPLAY "   ATM ROUTING SUMMARY"
           DISPLAY "========================================"
           MOVE WS-ROUTED-CT TO WS-DISP-CT
           DISPLAY "ROUTED:   " WS-DISP-CT
           MOVE WS-FAILED-CT TO WS-DISP-CT
           DISPLAY "FAILED:   " WS-DISP-CT
           PERFORM VARYING WS-M-IDX FROM 1 BY 1
               UNTIL WS-M-IDX > WS-M-COUNT
               MOVE WS-M-AMOUNT(WS-M-IDX) TO WS-DISP-AMT
               DISPLAY WS-M-NETWORK(WS-M-IDX) " "
                   WS-DISP-AMT " " WS-M-RESULT(WS-M-IDX)
           END-PERFORM
           DISPLAY "========================================".

       9000-ROUTE-EXIT.
           GO TO 9100-VISA-HANDLER.

       9100-VISA-HANDLER.
           MOVE "VISA-OK" TO WS-M-RESULT(WS-M-IDX)
           ADD 1 TO WS-ROUTED-CT.

       9200-MC-HANDLER.
           MOVE "MC-OK" TO WS-M-RESULT(WS-M-IDX)
           ADD 1 TO WS-ROUTED-CT.
