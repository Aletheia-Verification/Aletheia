       IDENTIFICATION DIVISION.
       PROGRAM-ID. NESTED-IF-10.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-X          PIC 9(3).
       01  WS-RESULT     PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-X = 1
               MOVE 1 TO WS-RESULT
           ELSE
               IF WS-X = 2
                   MOVE 2 TO WS-RESULT
               ELSE
                   IF WS-X = 3
                       MOVE 3 TO WS-RESULT
                   ELSE
                       IF WS-X = 4
                           MOVE 4 TO WS-RESULT
                       ELSE
                           IF WS-X = 5
                               MOVE 5 TO WS-RESULT
                           ELSE
                               IF WS-X = 6
                                   MOVE 6 TO WS-RESULT
                               ELSE
                                   IF WS-X = 7
                                       MOVE 7 TO WS-RESULT
                                   ELSE
                                       IF WS-X = 8
                                           MOVE 8 TO WS-RESULT
                                       ELSE
                                           IF WS-X = 9
                                               MOVE 9 TO WS-RESULT
                                           ELSE
                                               IF WS-X = 10
                                                   MOVE 10 TO WS-RESULT
                                               ELSE
                                                   MOVE 0 TO WS-RESULT
                                               END-IF
                                           END-IF
                                       END-IF
                                   END-IF
                               END-IF
                           END-IF
                       END-IF
                   END-IF
               END-IF
           END-IF.
           STOP RUN.
