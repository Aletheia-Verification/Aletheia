       IDENTIFICATION DIVISION.
       PROGRAM-ID. ADD-CORRESPONDING.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-SRC.
           05  WS-AMT         PIC 9(4) VALUE 10.
           05  WS-QTY         PIC 9(4) VALUE 20.
       01  WS-TGT.
           05  WS-AMT         PIC 9(4) VALUE 100.
           05  WS-QTY         PIC 9(4) VALUE 200.
       01  WS-RES-A           PIC 9(5).
       01  WS-RES-Q           PIC 9(5).
       PROCEDURE DIVISION.
       0000-MAIN.
           ADD CORRESPONDING WS-SRC TO WS-TGT.
           MOVE WS-AMT TO WS-RES-A.
           MOVE WS-QTY TO WS-RES-Q.
           STOP RUN.
