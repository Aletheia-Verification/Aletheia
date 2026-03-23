       IDENTIFICATION DIVISION.
       PROGRAM-ID. MAIN-LOAN.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PRINCIPAL        PIC S9(13)V99.
       01  WS-RATE              PIC S9(3)V9(4).
       01  WS-RESULT            PIC S9(13)V99.
       01  WS-PENALTY           PIC S9(13)V99.
       01  WS-DAYS-LATE         PIC 9(3).

       PROCEDURE DIVISION.
       MAIN-LOGIC.
           MOVE 100000.00 TO WS-PRINCIPAL.
           MOVE 0.0500 TO WS-RATE.
           MOVE 45 TO WS-DAYS-LATE.

           CALL 'CALC-INT' USING WS-PRINCIPAL
                                  WS-RATE
                                  WS-RESULT.

           CALL 'APPLY-PENALTY' USING WS-RESULT
                                       WS-DAYS-LATE
                                       WS-PENALTY.

           COMPUTE WS-RESULT = WS-RESULT + WS-PENALTY.

           DISPLAY "PRINCIPAL:  " WS-PRINCIPAL.
           DISPLAY "RATE:       " WS-RATE.
           DISPLAY "INTEREST:   " WS-RESULT.
           DISPLAY "PENALTY:    " WS-PENALTY.
           DISPLAY "FINAL:      " WS-RESULT.

           STOP RUN.
