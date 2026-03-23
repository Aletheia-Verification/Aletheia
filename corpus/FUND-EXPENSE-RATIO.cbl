       IDENTIFICATION DIVISION.
       PROGRAM-ID. FUND-EXPENSE-RATIO.
      *================================================================
      * FUND EXPENSE RATIO CALCULATOR
      * Computes daily and annual expense charges across management,
      * distribution, administrative, and custodial fee components.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-FUND.
           05 WS-FUND-ID              PIC X(8).
           05 WS-FUND-NAME            PIC X(30).
           05 WS-FUND-CATEGORY        PIC X(2).
               88 FC-EQUITY           VALUE 'EQ'.
               88 FC-BOND             VALUE 'BD'.
               88 FC-MONEY-MKT        VALUE 'MM'.
               88 FC-BALANCED         VALUE 'BL'.
               88 FC-INDEX            VALUE 'IX'.
           05 WS-AVG-NET-ASSETS       PIC S9(13)V99 COMP-3.
           05 WS-SHARE-CLASSES        PIC 9(1).
       01 WS-FEE-COMPONENTS.
           05 WS-MGMT-FEE             PIC S9(1)V9(4) COMP-3.
           05 WS-12B1-FEE             PIC S9(1)V9(4) COMP-3.
           05 WS-ADMIN-FEE            PIC S9(1)V9(4) COMP-3.
           05 WS-CUSTODIAN-FEE        PIC S9(1)V9(4) COMP-3.
           05 WS-TRANSFER-FEE         PIC S9(1)V9(4) COMP-3.
           05 WS-LEGAL-FEE            PIC S9(1)V9(4) COMP-3.
           05 WS-AUDIT-FEE            PIC S9(1)V9(4) COMP-3.
       01 WS-WAIVERS.
           05 WS-MGMT-WAIVER          PIC S9(1)V9(4) COMP-3
               VALUE 0.
           05 WS-WAIVER-EXPIRY        PIC 9(8).
           05 WS-WAIVER-ACTIVE        PIC X VALUE 'N'.
               88 WAIVER-YES          VALUE 'Y'.
       01 WS-BREAKPOINTS.
           05 WS-BP-ENTRY OCCURS 4 TIMES.
               10 WS-BP-THRESHOLD     PIC S9(13)V99 COMP-3.
               10 WS-BP-DISCOUNT      PIC S9(1)V9(4) COMP-3.
       01 WS-CALC.
           05 WS-GROSS-EXPENSE        PIC S9(1)V9(4) COMP-3.
           05 WS-NET-EXPENSE          PIC S9(1)V9(4) COMP-3.
           05 WS-DAILY-RATE           PIC S9(1)V9(8) COMP-3.
           05 WS-DAILY-CHARGE         PIC S9(9)V99 COMP-3.
           05 WS-ANNUAL-CHARGE        PIC S9(11)V99 COMP-3.
           05 WS-BP-DISCOUNT-APPLIED  PIC S9(1)V9(4) COMP-3
               VALUE 0.
           05 WS-EFFECTIVE-MGMT       PIC S9(1)V9(4) COMP-3.
           05 WS-PEER-AVG             PIC S9(1)V9(4) COMP-3.
           05 WS-VS-PEER              PIC S9(3)V9(4) COMP-3.
       01 WS-IDX                      PIC 9(1).
       01 WS-CURRENT-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-APPLY-BREAKPOINTS
           PERFORM 3000-APPLY-WAIVERS
           PERFORM 4000-CALC-GROSS-EXPENSE
           PERFORM 5000-CALC-NET-EXPENSE
           PERFORM 6000-CALC-DAILY-CHARGE
           PERFORM 7000-PEER-COMPARISON
           PERFORM 8000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE 'GRTX0001' TO WS-FUND-ID
           MOVE 'GROWTH EQUITY FUND         '
               TO WS-FUND-NAME
           MOVE 'EQ' TO WS-FUND-CATEGORY
           MOVE 2500000000.00 TO WS-AVG-NET-ASSETS
           MOVE 3 TO WS-SHARE-CLASSES
           MOVE 0.0065 TO WS-MGMT-FEE
           MOVE 0.0025 TO WS-12B1-FEE
           MOVE 0.0010 TO WS-ADMIN-FEE
           MOVE 0.0003 TO WS-CUSTODIAN-FEE
           MOVE 0.0002 TO WS-TRANSFER-FEE
           MOVE 0.0001 TO WS-LEGAL-FEE
           MOVE 0.0001 TO WS-AUDIT-FEE
           MOVE 1000000000.00 TO WS-BP-THRESHOLD(1)
           MOVE 0.0005 TO WS-BP-DISCOUNT(1)
           MOVE 2000000000.00 TO WS-BP-THRESHOLD(2)
           MOVE 0.0010 TO WS-BP-DISCOUNT(2)
           MOVE 5000000000.00 TO WS-BP-THRESHOLD(3)
           MOVE 0.0015 TO WS-BP-DISCOUNT(3)
           MOVE 10000000000.00 TO WS-BP-THRESHOLD(4)
           MOVE 0.0020 TO WS-BP-DISCOUNT(4)
           MOVE 0.0010 TO WS-MGMT-WAIVER
           MOVE 20261231 TO WS-WAIVER-EXPIRY.
       2000-APPLY-BREAKPOINTS.
           MOVE 0 TO WS-BP-DISCOUNT-APPLIED
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 4
               IF WS-AVG-NET-ASSETS >=
                   WS-BP-THRESHOLD(WS-IDX)
                   MOVE WS-BP-DISCOUNT(WS-IDX)
                       TO WS-BP-DISCOUNT-APPLIED
               END-IF
           END-PERFORM
           COMPUTE WS-EFFECTIVE-MGMT =
               WS-MGMT-FEE - WS-BP-DISCOUNT-APPLIED.
       3000-APPLY-WAIVERS.
           IF WS-WAIVER-EXPIRY >= WS-CURRENT-DATE
               MOVE 'Y' TO WS-WAIVER-ACTIVE
               SUBTRACT WS-MGMT-WAIVER
                   FROM WS-EFFECTIVE-MGMT
               IF WS-EFFECTIVE-MGMT < 0
                   MOVE 0 TO WS-EFFECTIVE-MGMT
               END-IF
           END-IF.
       4000-CALC-GROSS-EXPENSE.
           COMPUTE WS-GROSS-EXPENSE =
               WS-MGMT-FEE
               + WS-12B1-FEE
               + WS-ADMIN-FEE
               + WS-CUSTODIAN-FEE
               + WS-TRANSFER-FEE
               + WS-LEGAL-FEE
               + WS-AUDIT-FEE.
       5000-CALC-NET-EXPENSE.
           COMPUTE WS-NET-EXPENSE =
               WS-EFFECTIVE-MGMT
               + WS-12B1-FEE
               + WS-ADMIN-FEE
               + WS-CUSTODIAN-FEE
               + WS-TRANSFER-FEE
               + WS-LEGAL-FEE
               + WS-AUDIT-FEE.
       6000-CALC-DAILY-CHARGE.
           COMPUTE WS-DAILY-RATE =
               WS-NET-EXPENSE / 365
           COMPUTE WS-DAILY-CHARGE =
               WS-AVG-NET-ASSETS * WS-DAILY-RATE
           COMPUTE WS-ANNUAL-CHARGE =
               WS-AVG-NET-ASSETS * WS-NET-EXPENSE.
       7000-PEER-COMPARISON.
           EVALUATE TRUE
               WHEN FC-EQUITY
                   MOVE 0.0085 TO WS-PEER-AVG
               WHEN FC-BOND
                   MOVE 0.0055 TO WS-PEER-AVG
               WHEN FC-MONEY-MKT
                   MOVE 0.0025 TO WS-PEER-AVG
               WHEN FC-BALANCED
                   MOVE 0.0070 TO WS-PEER-AVG
               WHEN FC-INDEX
                   MOVE 0.0010 TO WS-PEER-AVG
               WHEN OTHER
                   MOVE 0.0075 TO WS-PEER-AVG
           END-EVALUATE
           COMPUTE WS-VS-PEER =
               (WS-NET-EXPENSE - WS-PEER-AVG) * 10000.
       8000-DISPLAY-RESULTS.
           DISPLAY 'FUND EXPENSE RATIO REPORT'
           DISPLAY '========================='
           DISPLAY 'FUND:            ' WS-FUND-ID
           DISPLAY 'NAME:            ' WS-FUND-NAME
           DISPLAY 'CATEGORY:        ' WS-FUND-CATEGORY
           DISPLAY 'NET ASSETS:      ' WS-AVG-NET-ASSETS
           DISPLAY 'GROSS EXPENSE:   ' WS-GROSS-EXPENSE
           DISPLAY 'NET EXPENSE:     ' WS-NET-EXPENSE
           DISPLAY 'DAILY RATE:      ' WS-DAILY-RATE
           DISPLAY 'DAILY CHARGE:    ' WS-DAILY-CHARGE
           DISPLAY 'ANNUAL CHARGE:   ' WS-ANNUAL-CHARGE
           DISPLAY 'BP DISCOUNT:     ' WS-BP-DISCOUNT-APPLIED
           IF WAIVER-YES
               DISPLAY 'WAIVER ACTIVE:   YES'
               DISPLAY 'WAIVER AMOUNT:   ' WS-MGMT-WAIVER
           END-IF
           DISPLAY 'PEER AVG:        ' WS-PEER-AVG
           DISPLAY 'VS PEER (BPS):   ' WS-VS-PEER.
