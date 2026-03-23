       IDENTIFICATION DIVISION.
       PROGRAM-ID. NESTED-IF-MOVE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X            PIC 9(1).
       01  WS-Y            PIC 9(1).
       01  WS-Z            PIC 9(1).
       01  WS-W            PIC 9(1).
       01  WS-V            PIC 9(1).
       01  WS-FLAG          PIC X(4) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-X = 1
               IF WS-Y = 2
                   IF WS-Z = 3
                       IF WS-W = 4
                           IF WS-V = 5
                               MOVE 'DEEP' TO WS-FLAG
                           END-IF
                       END-IF
                   END-IF
               END-IF
           END-IF.
           STOP RUN.
