       IDENTIFICATION DIVISION.
       PROGRAM-ID. ADD-TO-MULTIPLE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A             PIC 9(4) VALUE 1.
       01  WS-B             PIC 9(4) VALUE 2.
       01  WS-C             PIC 9(4) VALUE 3.
       PROCEDURE DIVISION.
       0000-MAIN.
           ADD 10 TO WS-A WS-B WS-C.
           DISPLAY WS-A.
           DISPLAY WS-B.
           DISPLAY WS-C.
           STOP RUN.
