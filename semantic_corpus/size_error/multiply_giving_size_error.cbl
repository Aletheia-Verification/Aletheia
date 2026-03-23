       IDENTIFICATION DIVISION.
       PROGRAM-ID. MUL-GIVING-OSE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-QTY        PIC 9(2).
       01  WS-PRICE       PIC 9(3)V99.
       01  WS-TOTAL       PIC 9(4)V99.
       01  WS-FLAG        PIC X(1) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN.
           MULTIPLY WS-QTY BY WS-PRICE
               GIVING WS-TOTAL
               ON SIZE ERROR
                   MOVE 'E' TO WS-FLAG
           END-MULTIPLY.
           STOP RUN.
