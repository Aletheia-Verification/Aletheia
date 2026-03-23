       IDENTIFICATION DIVISION.
       PROGRAM-ID. SUBTRACT-CORRESPONDING.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SRC2.
           05  WS-RATE        PIC 9(4) VALUE 5.
           05  WS-FEE         PIC 9(4) VALUE 10.
       01  WS-TGT2.
           05  WS-RATE        PIC 9(4) VALUE 100.
           05  WS-FEE         PIC 9(4) VALUE 200.
       01  WS-OUT-R           PIC 9(5).
       01  WS-OUT-F           PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           SUBTRACT CORRESPONDING WS-SRC2 FROM WS-TGT2.
           MOVE WS-RATE TO WS-OUT-R.
           MOVE WS-FEE TO WS-OUT-F.
           STOP RUN.
