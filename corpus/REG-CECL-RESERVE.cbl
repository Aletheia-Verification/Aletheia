       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-CECL-RESERVE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PORTFOLIO-SEGMENTS.
           05 WS-SEGMENT OCCURS 5 TIMES.
               10 WS-SEG-NAME     PIC X(15).
               10 WS-SEG-BALANCE  PIC S9(13)V99 COMP-3.
               10 WS-SEG-PD       PIC S9(1)V9(6) COMP-3.
               10 WS-SEG-LGD      PIC S9(1)V99 COMP-3.
               10 WS-SEG-EAD      PIC S9(13)V99 COMP-3.
               10 WS-SEG-ECL      PIC S9(11)V99 COMP-3.
               10 WS-SEG-STAGE    PIC 9.
                   88 STAGE-1     VALUE 1.
                   88 STAGE-2     VALUE 2.
                   88 STAGE-3     VALUE 3.
       01 WS-SEG-COUNT            PIC 9 VALUE 5.
       01 WS-IDX                  PIC 9.
       01 WS-TOTAL-BALANCE        PIC S9(15)V99 COMP-3.
       01 WS-TOTAL-ECL            PIC S9(13)V99 COMP-3.
       01 WS-RESERVE-RATIO        PIC S9(1)V9(6) COMP-3.
       01 WS-PRIOR-RESERVE        PIC S9(13)V99 COMP-3.
       01 WS-PROVISION-NEEDED     PIC S9(13)V99 COMP-3.
       01 WS-MACRO-ADJ            PIC S9(1)V99 COMP-3.
       01 WS-ECONOMIC-SCENARIO    PIC X(1).
           88 ECON-BASE           VALUE 'B'.
           88 ECON-ADVERSE        VALUE 'A'.
           88 ECON-SEVERE         VALUE 'S'.
       01 WS-REPORT-DATE          PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-CALC-ECL
           PERFORM 3000-APPLY-MACRO-ADJ
           PERFORM 4000-CALC-PROVISION
           PERFORM 5000-REPORT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-REPORT-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-BALANCE
           MOVE 0 TO WS-TOTAL-ECL.
       2000-CALC-ECL.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-SEG-COUNT
               MOVE WS-SEG-BALANCE(WS-IDX) TO
                   WS-SEG-EAD(WS-IDX)
               COMPUTE WS-SEG-ECL(WS-IDX) =
                   WS-SEG-EAD(WS-IDX) *
                   WS-SEG-PD(WS-IDX) *
                   WS-SEG-LGD(WS-IDX)
               EVALUATE TRUE
                   WHEN STAGE-2(WS-IDX)
                       COMPUTE WS-SEG-ECL(WS-IDX) =
                           WS-SEG-ECL(WS-IDX) * 2.5
                   WHEN STAGE-3(WS-IDX)
                       COMPUTE WS-SEG-ECL(WS-IDX) =
                           WS-SEG-ECL(WS-IDX) * 5.0
               END-EVALUATE
               ADD WS-SEG-BALANCE(WS-IDX) TO WS-TOTAL-BALANCE
               ADD WS-SEG-ECL(WS-IDX) TO WS-TOTAL-ECL
           END-PERFORM.
       3000-APPLY-MACRO-ADJ.
           EVALUATE TRUE
               WHEN ECON-BASE
                   MOVE 1.00 TO WS-MACRO-ADJ
               WHEN ECON-ADVERSE
                   MOVE 1.30 TO WS-MACRO-ADJ
               WHEN ECON-SEVERE
                   MOVE 1.75 TO WS-MACRO-ADJ
               WHEN OTHER
                   MOVE 1.00 TO WS-MACRO-ADJ
           END-EVALUATE
           COMPUTE WS-TOTAL-ECL =
               WS-TOTAL-ECL * WS-MACRO-ADJ.
       4000-CALC-PROVISION.
           COMPUTE WS-PROVISION-NEEDED =
               WS-TOTAL-ECL - WS-PRIOR-RESERVE
           IF WS-TOTAL-BALANCE > 0
               COMPUTE WS-RESERVE-RATIO =
                   WS-TOTAL-ECL / WS-TOTAL-BALANCE
           ELSE
               MOVE 0 TO WS-RESERVE-RATIO
           END-IF.
       5000-REPORT.
           DISPLAY 'CECL RESERVE CALCULATION'
           DISPLAY '========================'
           DISPLAY 'DATE:       ' WS-REPORT-DATE
           DISPLAY 'SCENARIO:   ' WS-ECONOMIC-SCENARIO
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-SEG-COUNT
               DISPLAY '  ' WS-SEG-NAME(WS-IDX)
                   ' BAL=$' WS-SEG-BALANCE(WS-IDX)
                   ' ECL=$' WS-SEG-ECL(WS-IDX)
                   ' STG=' WS-SEG-STAGE(WS-IDX)
           END-PERFORM
           DISPLAY 'TOTAL BAL:  $' WS-TOTAL-BALANCE
           DISPLAY 'TOTAL ECL:  $' WS-TOTAL-ECL
           DISPLAY 'MACRO ADJ:  ' WS-MACRO-ADJ
           DISPLAY 'RESERVE %:  ' WS-RESERVE-RATIO
           DISPLAY 'PRIOR RSV:  $' WS-PRIOR-RESERVE
           DISPLAY 'PROVISION:  $' WS-PROVISION-NEEDED.
