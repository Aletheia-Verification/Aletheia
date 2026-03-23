       IDENTIFICATION DIVISION.
       PROGRAM-ID. MULTI-VALUE-88.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CODE         PIC X(1).
           88 IS-VALID      VALUE 'A' 'B' 'C'.
       01  WS-RESULT        PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 'B' TO WS-CODE.
           MOVE 0 TO WS-RESULT.
           IF IS-VALID
               MOVE 1 TO WS-RESULT
           END-IF.
           STOP RUN.
