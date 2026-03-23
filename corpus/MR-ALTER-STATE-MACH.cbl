       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ALTER-STATE-MACH.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CURRENT-STATE       PIC X(2).
           88 ST-NEW              VALUE 'NW'.
           88 ST-REVIEW           VALUE 'RV'.
           88 ST-APPROVED         VALUE 'AP'.
           88 ST-FUNDED           VALUE 'FN'.
           88 ST-CLOSED           VALUE 'CL'.
           88 ST-DENIED           VALUE 'DN'.
       01 WS-EVENT               PIC X(2).
           88 EV-SUBMIT           VALUE 'SB'.
           88 EV-APPROVE          VALUE 'AV'.
           88 EV-DENY             VALUE 'DY'.
           88 EV-FUND             VALUE 'FD'.
           88 EV-CLOSE            VALUE 'CS'.
       01 WS-LOAN-ID             PIC X(12).
       01 WS-TRANSITION-MSG      PIC X(40).
       01 WS-VALID-TRANSITION    PIC X VALUE 'N'.
           88 IS-VALID-TRANS     VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           ALTER 2000-STATE-HANDLER TO PROCEED TO
               2100-NEW-STATE
           PERFORM 3000-PROCESS-EVENT
           DISPLAY 'LOAN:  ' WS-LOAN-ID
           DISPLAY 'STATE: ' WS-CURRENT-STATE
           DISPLAY 'MSG:   ' WS-TRANSITION-MSG
           STOP RUN.
       1000-INIT.
           MOVE 'N' TO WS-VALID-TRANSITION.
       2000-STATE-HANDLER.
           GO TO 2100-NEW-STATE.
       2100-NEW-STATE.
           IF EV-SUBMIT
               MOVE 'RV' TO WS-CURRENT-STATE
               MOVE 'SUBMITTED FOR REVIEW' TO
                   WS-TRANSITION-MSG
               MOVE 'Y' TO WS-VALID-TRANSITION
               ALTER 2000-STATE-HANDLER TO PROCEED TO
                   2200-REVIEW-STATE
           ELSE
               MOVE 'INVALID EVENT FOR NEW' TO
                   WS-TRANSITION-MSG
           END-IF.
       2200-REVIEW-STATE.
           IF EV-APPROVE
               MOVE 'AP' TO WS-CURRENT-STATE
               MOVE 'APPLICATION APPROVED' TO
                   WS-TRANSITION-MSG
               MOVE 'Y' TO WS-VALID-TRANSITION
               ALTER 2000-STATE-HANDLER TO PROCEED TO
                   2300-APPROVED-STATE
           ELSE
               IF EV-DENY
                   MOVE 'DN' TO WS-CURRENT-STATE
                   MOVE 'APPLICATION DENIED' TO
                       WS-TRANSITION-MSG
                   MOVE 'Y' TO WS-VALID-TRANSITION
               ELSE
                   MOVE 'INVALID EVENT FOR REVIEW' TO
                       WS-TRANSITION-MSG
               END-IF
           END-IF.
       2300-APPROVED-STATE.
           IF EV-FUND
               MOVE 'FN' TO WS-CURRENT-STATE
               MOVE 'LOAN FUNDED' TO WS-TRANSITION-MSG
               MOVE 'Y' TO WS-VALID-TRANSITION
           ELSE
               MOVE 'INVALID EVENT FOR APPROVED' TO
                   WS-TRANSITION-MSG
           END-IF.
       3000-PROCESS-EVENT.
           PERFORM 2000-STATE-HANDLER.
