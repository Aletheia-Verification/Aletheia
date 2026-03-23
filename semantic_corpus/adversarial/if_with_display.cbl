       IDENTIFICATION DIVISION.
       PROGRAM-ID. IF-DISPLAY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X            PIC 9(3).
       01  WS-MSG           PIC X(10) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-X > 5
               DISPLAY 'BIG'
               MOVE 'BIG' TO WS-MSG
           ELSE
               DISPLAY 'SMALL'
               MOVE 'SMALL' TO WS-MSG
           END-IF.
           STOP RUN.
