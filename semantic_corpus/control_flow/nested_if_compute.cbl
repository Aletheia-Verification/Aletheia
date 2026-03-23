       IDENTIFICATION DIVISION.
       PROGRAM-ID. NESTED-IF-COMP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CODE       PIC 9(1).
       01  WS-AMT        PIC 9(5)V99.
       01  WS-RESULT     PIC 9(5)V99.
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-CODE = 1
               COMPUTE WS-RESULT = WS-AMT * 1.10
           ELSE
               IF WS-CODE = 2
                   COMPUTE WS-RESULT = WS-AMT * 1.25
               ELSE
                   COMPUTE WS-RESULT = WS-AMT
               END-IF
           END-IF.
           STOP RUN.
