       IDENTIFICATION DIVISION.
       PROGRAM-ID. UNSTR-MULTI-DLM.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SRC          PIC X(10).
       01  WS-P1           PIC X(5).
       01  WS-P2           PIC X(5).
       01  WS-P3           PIC X(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           UNSTRING WS-SRC DELIMITED BY ',' OR ';'
               INTO WS-P1 WS-P2 WS-P3.
           STOP RUN.
