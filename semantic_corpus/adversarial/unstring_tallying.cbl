       IDENTIFICATION DIVISION.
       PROGRAM-ID. UNSTR-TALLY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SRC          PIC X(20).
       01  WS-P1           PIC X(5).
       01  WS-P2           PIC X(5).
       01  WS-P3           PIC X(5).
       01  WS-TALLY        PIC 9(3) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           UNSTRING WS-SRC DELIMITED BY ','
               INTO WS-P1 WS-P2 WS-P3
               TALLYING IN WS-TALLY.
           STOP RUN.
