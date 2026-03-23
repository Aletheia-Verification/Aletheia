       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-ALSO-PRICING.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PRODUCT-TYPE            PIC X(1).
           88 WS-CHECKING            VALUE 'C'.
           88 WS-SAVINGS             VALUE 'S'.
           88 WS-CD                  VALUE 'D'.
       01 WS-TIER-LEVEL              PIC X(1).
           88 WS-BASIC               VALUE 'B'.
           88 WS-PREFERRED           VALUE 'P'.
           88 WS-PREMIUM             VALUE 'R'.
       01 WS-RATE                    PIC S9(1)V9(6) COMP-3.
       01 WS-MONTHLY-FEE             PIC S9(5)V99 COMP-3.
       01 WS-BALANCE                 PIC S9(9)V99 COMP-3.
       01 WS-ANNUAL-EARN             PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-SET-PRICING
           PERFORM 2000-CALC-EARNINGS
           PERFORM 3000-DISPLAY-RESULTS
           STOP RUN.
       1000-SET-PRICING.
           EVALUATE WS-PRODUCT-TYPE ALSO WS-TIER-LEVEL
               WHEN 'C' ALSO 'B'
                   MOVE 0.0010 TO WS-RATE
                   MOVE 12.00 TO WS-MONTHLY-FEE
               WHEN 'C' ALSO 'P'
                   MOVE 0.0025 TO WS-RATE
                   MOVE 0 TO WS-MONTHLY-FEE
               WHEN 'C' ALSO 'R'
                   MOVE 0.0050 TO WS-RATE
                   MOVE 0 TO WS-MONTHLY-FEE
               WHEN 'S' ALSO 'B'
                   MOVE 0.0100 TO WS-RATE
                   MOVE 5.00 TO WS-MONTHLY-FEE
               WHEN 'S' ALSO 'P'
                   MOVE 0.0200 TO WS-RATE
                   MOVE 0 TO WS-MONTHLY-FEE
               WHEN 'S' ALSO 'R'
                   MOVE 0.0350 TO WS-RATE
                   MOVE 0 TO WS-MONTHLY-FEE
               WHEN 'D' ALSO 'B'
                   MOVE 0.0400 TO WS-RATE
                   MOVE 0 TO WS-MONTHLY-FEE
               WHEN 'D' ALSO 'P'
                   MOVE 0.0450 TO WS-RATE
                   MOVE 0 TO WS-MONTHLY-FEE
               WHEN 'D' ALSO 'R'
                   MOVE 0.0500 TO WS-RATE
                   MOVE 0 TO WS-MONTHLY-FEE
               WHEN OTHER
                   MOVE 0.0010 TO WS-RATE
                   MOVE 15.00 TO WS-MONTHLY-FEE
           END-EVALUATE.
       2000-CALC-EARNINGS.
           COMPUTE WS-ANNUAL-EARN =
               (WS-BALANCE * WS-RATE) -
               (WS-MONTHLY-FEE * 12).
       3000-DISPLAY-RESULTS.
           DISPLAY 'EVALUATE ALSO PRICING'
           DISPLAY '====================='
           DISPLAY 'PRODUCT:     ' WS-PRODUCT-TYPE
           DISPLAY 'TIER:        ' WS-TIER-LEVEL
           DISPLAY 'RATE:        ' WS-RATE
           DISPLAY 'MONTHLY FEE: ' WS-MONTHLY-FEE
           DISPLAY 'BALANCE:     ' WS-BALANCE
           DISPLAY 'ANNUAL EARN: ' WS-ANNUAL-EARN.
