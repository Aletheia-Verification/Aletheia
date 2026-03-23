       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-MORTALITY-TBL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-INSURED-AGE             PIC 9(3).
       01 WS-GENDER                  PIC X(1).
           88 WS-MALE                VALUE 'M'.
           88 WS-FEMALE              VALUE 'F'.
       01 WS-MORT-TABLE.
           05 WS-MORT-ENTRY OCCURS 10.
               10 WS-MT-AGE-LOW      PIC 9(3).
               10 WS-MT-AGE-HIGH     PIC 9(3).
               10 WS-MT-RATE-M       PIC S9(1)V9(6) COMP-3.
               10 WS-MT-RATE-F       PIC S9(1)V9(6) COMP-3.
       01 WS-MT-IDX                  PIC 9(2).
       01 WS-MORT-RATE               PIC S9(1)V9(6) COMP-3.
       01 WS-LIFE-EXPECT             PIC S9(3)V9(2) COMP-3.
       01 WS-COVERAGE-AMT            PIC S9(9)V99 COMP-3.
       01 WS-ANNUAL-COST-INS         PIC S9(7)V99 COMP-3.
       01 WS-FOUND-FLAG              PIC X VALUE 'N'.
           88 WS-FOUND               VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-TABLE
           PERFORM 3000-LOOKUP-RATE
           PERFORM 4000-CALC-LIFE-EXPECT
           PERFORM 5000-CALC-COST
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-MORT-RATE
           MOVE 0 TO WS-LIFE-EXPECT
           MOVE 'N' TO WS-FOUND-FLAG.
       2000-LOAD-TABLE.
           MOVE 0 TO WS-MT-AGE-LOW(1)
           MOVE 24 TO WS-MT-AGE-HIGH(1)
           MOVE 0.000500 TO WS-MT-RATE-M(1)
           MOVE 0.000200 TO WS-MT-RATE-F(1)
           MOVE 25 TO WS-MT-AGE-LOW(2)
           MOVE 34 TO WS-MT-AGE-HIGH(2)
           MOVE 0.001000 TO WS-MT-RATE-M(2)
           MOVE 0.000500 TO WS-MT-RATE-F(2)
           MOVE 35 TO WS-MT-AGE-LOW(3)
           MOVE 44 TO WS-MT-AGE-HIGH(3)
           MOVE 0.002000 TO WS-MT-RATE-M(3)
           MOVE 0.001200 TO WS-MT-RATE-F(3)
           MOVE 45 TO WS-MT-AGE-LOW(4)
           MOVE 54 TO WS-MT-AGE-HIGH(4)
           MOVE 0.004500 TO WS-MT-RATE-M(4)
           MOVE 0.002800 TO WS-MT-RATE-F(4)
           MOVE 55 TO WS-MT-AGE-LOW(5)
           MOVE 64 TO WS-MT-AGE-HIGH(5)
           MOVE 0.010000 TO WS-MT-RATE-M(5)
           MOVE 0.006500 TO WS-MT-RATE-F(5)
           MOVE 65 TO WS-MT-AGE-LOW(6)
           MOVE 74 TO WS-MT-AGE-HIGH(6)
           MOVE 0.022000 TO WS-MT-RATE-M(6)
           MOVE 0.014000 TO WS-MT-RATE-F(6).
       3000-LOOKUP-RATE.
           PERFORM VARYING WS-MT-IDX FROM 1 BY 1
               UNTIL WS-MT-IDX > 6
               OR WS-FOUND
               IF WS-INSURED-AGE >= WS-MT-AGE-LOW(WS-MT-IDX)
                   IF WS-INSURED-AGE <=
                       WS-MT-AGE-HIGH(WS-MT-IDX)
                       MOVE 'Y' TO WS-FOUND-FLAG
                       IF WS-MALE
                           MOVE WS-MT-RATE-M(WS-MT-IDX) TO
                               WS-MORT-RATE
                       ELSE
                           MOVE WS-MT-RATE-F(WS-MT-IDX) TO
                               WS-MORT-RATE
                       END-IF
                   END-IF
               END-IF
           END-PERFORM.
       4000-CALC-LIFE-EXPECT.
           IF WS-MORT-RATE > 0
               COMPUTE WS-LIFE-EXPECT =
                   1 / WS-MORT-RATE
           END-IF.
       5000-CALC-COST.
           COMPUTE WS-ANNUAL-COST-INS =
               WS-COVERAGE-AMT * WS-MORT-RATE.
       6000-DISPLAY-RESULTS.
           DISPLAY 'MORTALITY TABLE LOOKUP'
           DISPLAY '======================'
           DISPLAY 'AGE:             ' WS-INSURED-AGE
           DISPLAY 'GENDER:          ' WS-GENDER
           DISPLAY 'MORTALITY RATE:  ' WS-MORT-RATE
           DISPLAY 'LIFE EXPECTANCY: ' WS-LIFE-EXPECT
           DISPLAY 'COVERAGE:        ' WS-COVERAGE-AMT
           DISPLAY 'ANNUAL COI:      ' WS-ANNUAL-COST-INS.
