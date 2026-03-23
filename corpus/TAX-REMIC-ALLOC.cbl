       IDENTIFICATION DIVISION.
       PROGRAM-ID. TAX-REMIC-ALLOC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-REMIC-DATA.
           05 WS-POOL-ID             PIC X(10).
           05 WS-TOTAL-INCOME        PIC S9(11)V99 COMP-3.
       01 WS-TRANCHE-TABLE.
           05 WS-TRANCHE OCCURS 5.
               10 WS-TR-ID           PIC X(4).
               10 WS-TR-PCT          PIC S9(3)V99 COMP-3.
               10 WS-TR-INCOME       PIC S9(9)V99 COMP-3.
               10 WS-TR-OID          PIC S9(7)V99 COMP-3.
               10 WS-TR-NET          PIC S9(9)V99 COMP-3.
       01 WS-TR-IDX                  PIC 9(1).
       01 WS-TRANCHE-COUNT           PIC 9(1).
       01 WS-TOTAL-ALLOC             PIC S9(11)V99 COMP-3.
       01 WS-TOTAL-OID               PIC S9(9)V99 COMP-3.
       01 WS-TOTAL-PCT               PIC S9(3)V99 COMP-3.
       01 WS-BALANCED-FLAG           PIC X VALUE 'N'.
           88 WS-IS-BALANCED         VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-PCTS
           IF WS-IS-BALANCED
               PERFORM 3000-ALLOCATE-INCOME
               PERFORM 4000-CALC-OID
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-TOTAL-ALLOC
           MOVE 0 TO WS-TOTAL-OID
           MOVE 0 TO WS-TOTAL-PCT
           MOVE 'N' TO WS-BALANCED-FLAG.
       2000-VALIDATE-PCTS.
           PERFORM VARYING WS-TR-IDX FROM 1 BY 1
               UNTIL WS-TR-IDX > WS-TRANCHE-COUNT
               ADD WS-TR-PCT(WS-TR-IDX) TO WS-TOTAL-PCT
           END-PERFORM
           IF WS-TOTAL-PCT = 100
               MOVE 'Y' TO WS-BALANCED-FLAG
           ELSE
               DISPLAY 'ERROR: TRANCHES DO NOT SUM TO 100'
           END-IF.
       3000-ALLOCATE-INCOME.
           PERFORM VARYING WS-TR-IDX FROM 1 BY 1
               UNTIL WS-TR-IDX > WS-TRANCHE-COUNT
               COMPUTE WS-TR-INCOME(WS-TR-IDX) =
                   WS-TOTAL-INCOME *
                   WS-TR-PCT(WS-TR-IDX) / 100
               ADD WS-TR-INCOME(WS-TR-IDX) TO
                   WS-TOTAL-ALLOC
           END-PERFORM.
       4000-CALC-OID.
           PERFORM VARYING WS-TR-IDX FROM 1 BY 1
               UNTIL WS-TR-IDX > WS-TRANCHE-COUNT
               EVALUATE TRUE
                   WHEN WS-TR-PCT(WS-TR-IDX) < 20
                       COMPUTE WS-TR-OID(WS-TR-IDX) =
                           WS-TR-INCOME(WS-TR-IDX) * 0.15
                   WHEN WS-TR-PCT(WS-TR-IDX) < 50
                       COMPUTE WS-TR-OID(WS-TR-IDX) =
                           WS-TR-INCOME(WS-TR-IDX) * 0.10
                   WHEN OTHER
                       COMPUTE WS-TR-OID(WS-TR-IDX) =
                           WS-TR-INCOME(WS-TR-IDX) * 0.05
               END-EVALUATE
               COMPUTE WS-TR-NET(WS-TR-IDX) =
                   WS-TR-INCOME(WS-TR-IDX) -
                   WS-TR-OID(WS-TR-IDX)
               ADD WS-TR-OID(WS-TR-IDX) TO WS-TOTAL-OID
           END-PERFORM.
       5000-DISPLAY-RESULTS.
           DISPLAY 'REMIC INCOME ALLOCATION'
           DISPLAY '======================='
           DISPLAY 'POOL:         ' WS-POOL-ID
           DISPLAY 'TOTAL INCOME: ' WS-TOTAL-INCOME
           DISPLAY 'TOTAL ALLOC:  ' WS-TOTAL-ALLOC
           DISPLAY 'TOTAL OID:    ' WS-TOTAL-OID
           PERFORM VARYING WS-TR-IDX FROM 1 BY 1
               UNTIL WS-TR-IDX > WS-TRANCHE-COUNT
               DISPLAY '  TRANCHE=' WS-TR-ID(WS-TR-IDX)
                   ' PCT=' WS-TR-PCT(WS-TR-IDX)
                   ' INC=' WS-TR-INCOME(WS-TR-IDX)
                   ' OID=' WS-TR-OID(WS-TR-IDX)
                   ' NET=' WS-TR-NET(WS-TR-IDX)
           END-PERFORM.
