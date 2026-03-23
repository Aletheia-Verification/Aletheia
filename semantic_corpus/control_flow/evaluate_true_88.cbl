       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVALUATE-TRUE-88.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-STATUS      PIC 9(2).
           88  STATUS-OK       VALUE 0.
           88  STATUS-EOF      VALUE 10.
       01  WS-ACTION      PIC X(10).
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE TRUE
               WHEN STATUS-OK
                   MOVE 'CONTINUE' TO WS-ACTION
               WHEN STATUS-EOF
                   MOVE 'STOP' TO WS-ACTION
               WHEN OTHER
                   MOVE 'ERROR' TO WS-ACTION
           END-EVALUATE.
           STOP RUN.
