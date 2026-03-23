       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVALUATE-TEST.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-ACCOUNT-TYPE        PIC X(1).
       01  WS-BALANCE             PIC S9(7)V99.
       01  WS-INTEREST-RATE       PIC 9V9(4).
       01  WS-RISK-LEVEL          PIC X(6).
       01  WS-CUSTOMER-TIER       PIC 9(1).
       01  WS-DISCOUNT-PCT        PIC 9V99.
       01  WS-STATUS-CODE         PIC 9(3).
       01  WS-STATUS-MSG          PIC X(30).
       01  WS-REGION              PIC X(2).
       01  WS-TAX-RATE            PIC 9V9(4).

       PROCEDURE DIVISION.
       MAIN-LOGIC.
           EVALUATE TRUE
               WHEN WS-BALANCE > 100000
                   MOVE 'LOW   ' TO WS-RISK-LEVEL
                   MOVE 0.0250 TO WS-INTEREST-RATE
               WHEN WS-BALANCE > 50000
                   MOVE 'MEDIUM' TO WS-RISK-LEVEL
                   MOVE 0.0375 TO WS-INTEREST-RATE
               WHEN WS-BALANCE > 10000
                   MOVE 'HIGH  ' TO WS-RISK-LEVEL
                   MOVE 0.0500 TO WS-INTEREST-RATE
               WHEN OTHER
                   MOVE 'HIGH  ' TO WS-RISK-LEVEL
                   MOVE 0.0650 TO WS-INTEREST-RATE
           END-EVALUATE

           EVALUATE WS-ACCOUNT-TYPE
               WHEN 'S'
                   MOVE 1 TO WS-CUSTOMER-TIER
                   MOVE 0.05 TO WS-DISCOUNT-PCT
               WHEN 'C'
                   MOVE 2 TO WS-CUSTOMER-TIER
                   MOVE 0.10 TO WS-DISCOUNT-PCT
               WHEN 'P'
                   MOVE 3 TO WS-CUSTOMER-TIER
                   MOVE 0.15 TO WS-DISCOUNT-PCT
               WHEN OTHER
                   MOVE 0 TO WS-CUSTOMER-TIER
                   MOVE 0.00 TO WS-DISCOUNT-PCT
           END-EVALUATE

           EVALUATE WS-REGION
               WHEN 'NE'
                   MOVE 0.0625 TO WS-TAX-RATE
               WHEN 'SW'
                   MOVE 0.0500 TO WS-TAX-RATE
               WHEN 'MW'
                   MOVE 0.0450 TO WS-TAX-RATE
               WHEN OTHER
                   MOVE 0.0600 TO WS-TAX-RATE
           END-EVALUATE

           STOP RUN.
