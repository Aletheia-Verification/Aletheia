       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-RISK-WEIGHT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ASSET-DATA.
           05 WS-ASSET-ID            PIC X(10).
           05 WS-ASSET-VALUE         PIC S9(11)V99 COMP-3.
       01 WS-ASSET-CLASS             PIC X(2).
           88 WS-CASH-EQUIV          VALUE 'CE'.
           88 WS-GOVT-BOND           VALUE 'GB'.
           88 WS-RESIDENTIAL-MTG     VALUE 'RM'.
           88 WS-COMMERCIAL-MTG      VALUE 'CM'.
           88 WS-CORPORATE           VALUE 'CO'.
           88 WS-CONSUMER            VALUE 'CN'.
       01 WS-RISK-FIELDS.
           05 WS-RISK-WEIGHT-PCT     PIC S9(3) COMP-3.
           05 WS-RWA                 PIC S9(11)V99 COMP-3.
           05 WS-CAPITAL-CHARGE      PIC S9(9)V99 COMP-3.
           05 WS-CAPITAL-RATIO       PIC S9(1)V9(4) COMP-3
               VALUE 0.0800.
       01 WS-ASSET-TABLE.
           05 WS-AT-ENTRY OCCURS 8.
               10 WS-AT-CLASS        PIC X(2).
               10 WS-AT-VALUE        PIC S9(11)V99 COMP-3.
               10 WS-AT-RW           PIC S9(3) COMP-3.
               10 WS-AT-RWA          PIC S9(11)V99 COMP-3.
       01 WS-AT-IDX                  PIC 9(1).
       01 WS-TOTAL-ASSETS            PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-RWA               PIC S9(13)V99 COMP-3.
       01 WS-TOTAL-CAPITAL           PIC S9(11)V99 COMP-3.
       01 WS-AVG-RW                  PIC S9(3)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-ASSIGN-WEIGHTS
           PERFORM 3000-CALC-RWA
           PERFORM 4000-CALC-CAPITAL
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-ASSETS
           MOVE 0 TO WS-TOTAL-RWA
           MOVE 0 TO WS-TOTAL-CAPITAL.
       2000-ASSIGN-WEIGHTS.
           PERFORM VARYING WS-AT-IDX FROM 1 BY 1
               UNTIL WS-AT-IDX > 8
               EVALUATE WS-AT-CLASS(WS-AT-IDX)
                   WHEN 'CE'
                       MOVE 0 TO WS-AT-RW(WS-AT-IDX)
                   WHEN 'GB'
                       MOVE 0 TO WS-AT-RW(WS-AT-IDX)
                   WHEN 'RM'
                       MOVE 50 TO WS-AT-RW(WS-AT-IDX)
                   WHEN 'CM'
                       MOVE 100 TO WS-AT-RW(WS-AT-IDX)
                   WHEN 'CO'
                       MOVE 100 TO WS-AT-RW(WS-AT-IDX)
                   WHEN 'CN'
                       MOVE 75 TO WS-AT-RW(WS-AT-IDX)
                   WHEN OTHER
                       MOVE 100 TO WS-AT-RW(WS-AT-IDX)
               END-EVALUATE
           END-PERFORM.
       3000-CALC-RWA.
           PERFORM VARYING WS-AT-IDX FROM 1 BY 1
               UNTIL WS-AT-IDX > 8
               COMPUTE WS-AT-RWA(WS-AT-IDX) =
                   WS-AT-VALUE(WS-AT-IDX) *
                   WS-AT-RW(WS-AT-IDX) / 100
               ADD WS-AT-VALUE(WS-AT-IDX) TO
                   WS-TOTAL-ASSETS
               ADD WS-AT-RWA(WS-AT-IDX) TO WS-TOTAL-RWA
           END-PERFORM
           IF WS-TOTAL-ASSETS > 0
               COMPUTE WS-AVG-RW =
                   (WS-TOTAL-RWA / WS-TOTAL-ASSETS) * 100
           END-IF.
       4000-CALC-CAPITAL.
           COMPUTE WS-TOTAL-CAPITAL =
               WS-TOTAL-RWA * WS-CAPITAL-RATIO.
       5000-DISPLAY-RESULTS.
           DISPLAY 'RISK WEIGHT CALCULATION'
           DISPLAY '======================='
           DISPLAY 'TOTAL ASSETS:  ' WS-TOTAL-ASSETS
           DISPLAY 'TOTAL RWA:     ' WS-TOTAL-RWA
           DISPLAY 'AVG RW:        ' WS-AVG-RW
           DISPLAY 'CAPITAL REQ:   ' WS-TOTAL-CAPITAL
           PERFORM VARYING WS-AT-IDX FROM 1 BY 1
               UNTIL WS-AT-IDX > 8
               IF WS-AT-VALUE(WS-AT-IDX) > 0
                   DISPLAY '  CLASS=' WS-AT-CLASS(WS-AT-IDX)
                       ' VAL=' WS-AT-VALUE(WS-AT-IDX)
                       ' RW=' WS-AT-RW(WS-AT-IDX)
                       ' RWA=' WS-AT-RWA(WS-AT-IDX)
               END-IF
           END-PERFORM.
