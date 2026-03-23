       IDENTIFICATION DIVISION.
       PROGRAM-ID. IF-ALPHA.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FIELD        PIC X(10).
       01  WS-RESULT       PIC X(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-FIELD IS ALPHABETIC
               MOVE 'Y' TO WS-RESULT
           ELSE
               MOVE 'N' TO WS-RESULT
           END-IF.
           STOP RUN.
