       IDENTIFICATION DIVISION.
       PROGRAM-ID. EIGHTY-EIGHT-MULTI.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DAY           PIC X(3) VALUE 'SUN'.
           88  WEEKEND       VALUE 'SAT' 'SUN'.
           88  WEEKDAY       VALUE 'MON' 'TUE' 'WED' 'THU' 'FRI'.
       01  WS-RESULT        PIC X(7) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WEEKEND
               MOVE 'WEEKEND' TO WS-RESULT
           ELSE
               MOVE 'WORKDAY' TO WS-RESULT
           END-IF.
           DISPLAY WS-RESULT.
           STOP RUN.
