       IDENTIFICATION DIVISION.
       PROGRAM-ID. NESTED-EVAL-ARITH.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-TIER      PIC 9(1).
       01  WS-AMOUNT    PIC S9(7)V99.
       01  WS-RATE      PIC S9(1)V9(4).
       01  WS-RESULT    PIC S9(7)V99.
       PROCEDURE DIVISION.
       0000-MAIN.
           EVALUATE TRUE
               WHEN WS-TIER = 1
                   COMPUTE WS-RATE = 0.0500
               WHEN WS-TIER = 2
                   COMPUTE WS-RATE = 0.0300
               WHEN WS-TIER = 3
                   EVALUATE TRUE
                       WHEN WS-AMOUNT > 10000
                           COMPUTE WS-RATE = 0.0100
                       WHEN OTHER
                           COMPUTE WS-RATE = 0.0200
                   END-EVALUATE
               WHEN OTHER
                   COMPUTE WS-RATE = 0.0000
           END-EVALUATE.
           COMPUTE WS-RESULT = WS-AMOUNT * WS-RATE.
           STOP RUN.
