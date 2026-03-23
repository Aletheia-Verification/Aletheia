       IDENTIFICATION DIVISION.
       PROGRAM-ID. EVAL-COMPUTE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X            PIC 9(3).
       01  WS-Y            PIC 9(5) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE TRUE
               WHEN WS-X = 1
                   COMPUTE WS-Y = WS-X * 100
               WHEN WS-X = 2
                   COMPUTE WS-Y = WS-X * 200
               WHEN OTHER
                   MOVE 0 TO WS-Y
           END-EVALUATE.
           STOP RUN.
