       IDENTIFICATION DIVISION.
       PROGRAM-ID. FILLER-GRP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-GROUP.
           05  WS-A            PIC X(3).
           05  FILLER          PIC X(2).
           05  WS-B            PIC X(3).
       01  WS-TARGET           PIC X(8).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 'ABC' TO WS-A.
           MOVE 'DEF' TO WS-B.
           MOVE WS-GROUP TO WS-TARGET.
           STOP RUN.
