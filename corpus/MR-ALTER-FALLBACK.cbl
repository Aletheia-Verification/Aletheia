       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ALTER-FALLBACK.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SERVICE-TIER            PIC 9(1).
           88 WS-PRIMARY             VALUE 1.
           88 WS-SECONDARY           VALUE 2.
           88 WS-TERTIARY            VALUE 3.
       01 WS-REQUEST-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-REQUEST-AMT         PIC S9(9)V99 COMP-3.
           05 WS-REQUEST-TYPE        PIC X(3).
       01 WS-RESULT.
           05 WS-RESP-CODE           PIC X(2).
               88 WS-OK              VALUE 'OK'.
               88 WS-FAIL            VALUE 'FL'.
           05 WS-RESP-MSG            PIC X(40).
           05 WS-PROCESSED-AMT       PIC S9(9)V99 COMP-3.
           05 WS-FEE                 PIC S9(5)V99 COMP-3.
       01 WS-TIER-ATTEMPTS           PIC 9(1).
       01 WS-MAX-TIERS               PIC 9(1) VALUE 3.
       01 WS-ESCALATED               PIC X VALUE 'N'.
           88 WS-WAS-ESCALATED       VALUE 'Y'.
       01 WS-ALERT-MSG               PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM INIT-REQUEST
           PERFORM ROUTE-TO-TIER
           PERFORM EXECUTE-REQUEST THRU EXECUTE-EXIT
           PERFORM BUILD-ALERT
           PERFORM DISPLAY-RESULTS
           STOP RUN.
       INIT-REQUEST.
           MOVE 0 TO WS-TIER-ATTEMPTS
           MOVE 0 TO WS-FEE
           MOVE 0 TO WS-PROCESSED-AMT
           SET WS-FAIL TO TRUE
           MOVE 'N' TO WS-ESCALATED.
       ROUTE-TO-TIER.
           ADD 1 TO WS-TIER-ATTEMPTS
           EVALUATE TRUE
               WHEN WS-PRIMARY
                   ALTER SERVICE-GOTO TO PROCEED TO
                       PRIMARY-SERVICE
               WHEN WS-SECONDARY
                   ALTER SERVICE-GOTO TO PROCEED TO
                       SECONDARY-SERVICE
                   MOVE 'Y' TO WS-ESCALATED
               WHEN WS-TERTIARY
                   ALTER SERVICE-GOTO TO PROCEED TO
                       TERTIARY-SERVICE
                   MOVE 'Y' TO WS-ESCALATED
           END-EVALUATE.
       EXECUTE-REQUEST.
           PERFORM SERVICE-GOTO THRU SERVICE-GOTO-EXIT.
       EXECUTE-EXIT.
           EXIT.
       SERVICE-GOTO.
           GO TO PRIMARY-SERVICE.
       SERVICE-GOTO-EXIT.
           EXIT.
       PRIMARY-SERVICE.
           IF WS-REQUEST-AMT <= 100000
               MOVE WS-REQUEST-AMT TO WS-PROCESSED-AMT
               COMPUTE WS-FEE = WS-REQUEST-AMT * 0.001
               SET WS-OK TO TRUE
               MOVE 'PRIMARY PROCESSED' TO WS-RESP-MSG
           ELSE
               SET WS-FAIL TO TRUE
               MOVE 'PRIMARY: LIMIT EXCEEDED' TO
                   WS-RESP-MSG
           END-IF
           GO TO SERVICE-GOTO-EXIT.
       SECONDARY-SERVICE.
           IF WS-REQUEST-AMT <= 500000
               MOVE WS-REQUEST-AMT TO WS-PROCESSED-AMT
               COMPUTE WS-FEE = WS-REQUEST-AMT * 0.002
               SET WS-OK TO TRUE
               MOVE 'SECONDARY PROCESSED' TO WS-RESP-MSG
           ELSE
               SET WS-FAIL TO TRUE
               MOVE 'SECONDARY: LIMIT EXCEEDED' TO
                   WS-RESP-MSG
           END-IF
           GO TO SERVICE-GOTO-EXIT.
       TERTIARY-SERVICE.
           MOVE WS-REQUEST-AMT TO WS-PROCESSED-AMT
           COMPUTE WS-FEE = WS-REQUEST-AMT * 0.005
           SET WS-OK TO TRUE
           MOVE 'TERTIARY PROCESSED' TO WS-RESP-MSG
           GO TO SERVICE-GOTO-EXIT.
       BUILD-ALERT.
           STRING WS-REQUEST-TYPE DELIMITED BY SIZE
                  ' ACCT=' DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  ' AMT=' DELIMITED BY SIZE
                  WS-PROCESSED-AMT DELIMITED BY SIZE
                  ' TIER=' DELIMITED BY SIZE
                  WS-SERVICE-TIER DELIMITED BY SIZE
                  INTO WS-ALERT-MSG
           END-STRING.
       DISPLAY-RESULTS.
           DISPLAY 'FALLBACK SERVICE REPORT'
           DISPLAY '======================='
           DISPLAY 'ACCOUNT:    ' WS-ACCT-NUM
           DISPLAY 'AMOUNT:     ' WS-REQUEST-AMT
           DISPLAY 'TIER:       ' WS-SERVICE-TIER
           DISPLAY 'ATTEMPTS:   ' WS-TIER-ATTEMPTS
           DISPLAY 'RESULT:     ' WS-RESP-CODE
           DISPLAY 'MESSAGE:    ' WS-RESP-MSG
           DISPLAY 'PROCESSED:  ' WS-PROCESSED-AMT
           DISPLAY 'FEE:        ' WS-FEE
           IF WS-WAS-ESCALATED
               DISPLAY 'ESCALATED: YES'
           END-IF
           DISPLAY 'ALERT: ' WS-ALERT-MSG.
