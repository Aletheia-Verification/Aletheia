       IDENTIFICATION DIVISION.
       PROGRAM-ID. UNSTR-COUNT.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SRC          PIC X(20).
       01  WS-P1           PIC X(10).
       01  WS-P2           PIC X(10).
       01  WS-CNT          PIC 9(3) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           UNSTRING WS-SRC DELIMITED BY ','
               INTO WS-P1 COUNT IN WS-CNT
                    WS-P2.
           STOP RUN.
