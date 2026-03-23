       IDENTIFICATION DIVISION.
       PROGRAM-ID. SET-TO-TRUE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-STATUS       PIC X(1).
           88 IS-ACTIVE     VALUE 'A'.
           88 IS-INACTIVE   VALUE 'I'.
       01  WS-RESULT        PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 'I' TO WS-STATUS.
           MOVE 0 TO WS-RESULT.
           SET IS-ACTIVE TO TRUE.
           IF IS-ACTIVE
               MOVE 100 TO WS-RESULT
           END-IF.
           STOP RUN.
