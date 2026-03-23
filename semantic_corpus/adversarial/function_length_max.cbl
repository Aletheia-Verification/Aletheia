       IDENTIFICATION DIVISION.
       PROGRAM-ID. FUNC-LENGTH-MAX.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA          PIC X(15) VALUE 'HELLO WORLD'.
       01  WS-A             PIC 9(3) VALUE 50.
       01  WS-B             PIC 9(3) VALUE 200.
       01  WS-C             PIC 9(3) VALUE 125.
       01  WS-LEN           PIC 9(3).
       01  WS-MAX           PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN.
           COMPUTE WS-LEN = FUNCTION LENGTH(WS-DATA).
           COMPUTE WS-MAX = FUNCTION MAX(WS-A WS-B WS-C).
           DISPLAY WS-LEN.
           DISPLAY WS-MAX.
           STOP RUN.
