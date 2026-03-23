       IDENTIFICATION DIVISION.
       PROGRAM-ID. MISC-DATE-CALC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-INPUT-DATE              PIC 9(8).
       01 WS-DAYS-TO-ADD             PIC S9(3) COMP-3.
       01 WS-RESULT-DATE             PIC 9(8).
       01 WS-DAY-OF-WEEK             PIC 9(1).
           88 WS-MONDAY              VALUE 1.
           88 WS-TUESDAY             VALUE 2.
           88 WS-WEDNESDAY           VALUE 3.
           88 WS-THURSDAY            VALUE 4.
           88 WS-FRIDAY              VALUE 5.
           88 WS-SATURDAY            VALUE 6.
           88 WS-SUNDAY              VALUE 7.
       01 WS-IS-BUSINESS-DAY         PIC X VALUE 'N'.
           88 WS-BUS-DAY             VALUE 'Y'.
       01 WS-BUS-DAYS-ADDED          PIC 9(3).
       01 WS-DAY-IDX                 PIC 9(3).
       01 WS-WORKING-DATE            PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-WEEKDAY
           PERFORM 3000-ADD-BUSINESS-DAYS
           PERFORM 4000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE WS-INPUT-DATE TO WS-WORKING-DATE
           MOVE 0 TO WS-BUS-DAYS-ADDED.
       2000-CHECK-WEEKDAY.
           EVALUATE TRUE
               WHEN WS-SATURDAY
                   MOVE 'N' TO WS-IS-BUSINESS-DAY
               WHEN WS-SUNDAY
                   MOVE 'N' TO WS-IS-BUSINESS-DAY
               WHEN OTHER
                   MOVE 'Y' TO WS-IS-BUSINESS-DAY
           END-EVALUATE.
       3000-ADD-BUSINESS-DAYS.
           PERFORM VARYING WS-DAY-IDX FROM 1 BY 1
               UNTIL WS-BUS-DAYS-ADDED >= WS-DAYS-TO-ADD
               ADD 1 TO WS-WORKING-DATE
               ADD 1 TO WS-DAY-OF-WEEK
               IF WS-DAY-OF-WEEK > 7
                   MOVE 1 TO WS-DAY-OF-WEEK
               END-IF
               IF WS-DAY-OF-WEEK <= 5
                   ADD 1 TO WS-BUS-DAYS-ADDED
               END-IF
           END-PERFORM
           MOVE WS-WORKING-DATE TO WS-RESULT-DATE.
       4000-DISPLAY-RESULTS.
           DISPLAY 'BUSINESS DATE CALCULATION'
           DISPLAY '========================='
           DISPLAY 'INPUT DATE:  ' WS-INPUT-DATE
           DISPLAY 'BUS DAYS:    ' WS-DAYS-TO-ADD
           DISPLAY 'RESULT DATE: ' WS-RESULT-DATE
           IF WS-BUS-DAY
               DISPLAY 'INPUT: BUSINESS DAY'
           ELSE
               DISPLAY 'INPUT: WEEKEND'
           END-IF.
