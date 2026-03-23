       IDENTIFICATION DIVISION.
       PROGRAM-ID. SUB-NEG-UNSIGNED.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SMALL         PIC 9(3) VALUE 500.
       01  WS-BIG           PIC 9(4) VALUE 1000.
       01  WS-FLAG          PIC X(1) VALUE ' '.
       PROCEDURE DIVISION.
       0000-MAIN.
           SUBTRACT WS-BIG FROM WS-SMALL
               ON SIZE ERROR
                   MOVE 'Y' TO WS-FLAG
               NOT ON SIZE ERROR
                   MOVE 'N' TO WS-FLAG
           END-SUBTRACT.
           DISPLAY WS-SMALL.
           DISPLAY WS-FLAG.
           STOP RUN.
