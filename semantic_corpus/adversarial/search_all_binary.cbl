       IDENTIFICATION DIVISION.
       PROGRAM-ID. SEARCH-ALL-BINARY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TABLE.
           05  WS-ENTRY OCCURS 5 TIMES
               ASCENDING KEY WS-CODE
               INDEXED BY WS-IDX.
               10  WS-CODE  PIC 9(3).
               10  WS-DESC  PIC X(10).
       01  WS-RESULT        PIC X(10) VALUE SPACES.
       01  WS-FOUND         PIC X(1) VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 100 TO WS-CODE(1).
           MOVE 'SAVINGS' TO WS-DESC(1).
           MOVE 200 TO WS-CODE(2).
           MOVE 'CHECKING' TO WS-DESC(2).
           MOVE 300 TO WS-CODE(3).
           MOVE 'LOAN' TO WS-DESC(3).
           MOVE 400 TO WS-CODE(4).
           MOVE 'MORTGAGE' TO WS-DESC(4).
           MOVE 500 TO WS-CODE(5).
           MOVE 'CREDIT' TO WS-DESC(5).
           SEARCH ALL WS-ENTRY
               AT END
                   MOVE 'NOT-FOUND' TO WS-RESULT
               WHEN WS-CODE(WS-IDX) = 300
                   MOVE WS-DESC(WS-IDX) TO WS-RESULT
                   MOVE 'Y' TO WS-FOUND
           END-SEARCH.
           DISPLAY WS-RESULT.
           DISPLAY WS-FOUND.
           STOP RUN.
