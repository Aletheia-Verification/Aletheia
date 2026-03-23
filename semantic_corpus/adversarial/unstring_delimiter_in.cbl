       IDENTIFICATION DIVISION.
       PROGRAM-ID. UNSTR-DLM-IN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SRC          PIC X(20).
       01  WS-P1           PIC X(10).
       01  WS-P2           PIC X(10).
       01  WS-DLM          PIC X(1).
       PROCEDURE DIVISION.
       0000-MAIN.
           UNSTRING WS-SRC DELIMITED BY ',' OR ';'
               INTO WS-P1 DELIMITER IN WS-DLM
                    WS-P2.
           STOP RUN.
