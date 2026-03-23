       IDENTIFICATION DIVISION.
       PROGRAM-ID. APPLY-PENALTY.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-PENALTY-RATE      PIC S9(3)V9(4).

       LINKAGE SECTION.
       01  LS-BALANCE           PIC S9(13)V99.
       01  LS-DAYS              PIC 9(3).
       01  LS-PENALTY           PIC S9(13)V99.

       PROCEDURE DIVISION USING LS-BALANCE
                                LS-DAYS
                                LS-PENALTY.
       APPLY-PENALTY-LOGIC.
           IF LS-DAYS > 30
               MOVE 0.0500 TO WS-PENALTY-RATE
               COMPUTE LS-PENALTY = LS-BALANCE * WS-PENALTY-RATE
           ELSE
               MOVE 0 TO LS-PENALTY
           END-IF.
           GOBACK.
