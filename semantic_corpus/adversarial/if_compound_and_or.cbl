       IDENTIFICATION DIVISION.
       PROGRAM-ID. IF-ANDOR.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A            PIC 9(3).
       01  WS-B            PIC 9(3).
       01  WS-C            PIC 9(3).
       01  WS-RESULT       PIC X(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-A > 1 AND WS-B < 10 OR WS-C = 99
               MOVE 'TRUE' TO WS-RESULT
           ELSE
               MOVE 'FALSE' TO WS-RESULT
           END-IF.
           STOP RUN.
