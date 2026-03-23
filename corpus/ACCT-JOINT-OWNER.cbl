       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-JOINT-OWNER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-OWNER-TABLE.
           05 WS-OWNER OCCURS 4 TIMES.
               10 WS-OWNER-NAME       PIC X(25).
               10 WS-OWNER-SSN        PIC X(9).
               10 WS-OWNER-PCT        PIC 9(3).
               10 WS-OWNER-ACTIVE     PIC X.
                   88 OWNER-ACTIVE     VALUE 'Y'.
       01 WS-OWNER-COUNT              PIC 9.
       01 WS-IDX                      PIC 9.
       01 WS-TOTAL-PCT                PIC 9(3).
       01 WS-ACTIVE-COUNT             PIC 9.
       01 WS-OPERATION                PIC X(1).
           88 OP-ADD                   VALUE 'A'.
           88 OP-REMOVE                VALUE 'R'.
           88 OP-MODIFY                VALUE 'M'.
       01 WS-NEW-OWNER.
           05 WS-NEW-NAME             PIC X(25).
           05 WS-NEW-SSN              PIC X(9).
           05 WS-NEW-PCT              PIC 9(3).
       01 WS-TARGET-IDX               PIC 9.
       01 WS-VALID                    PIC X VALUE 'N'.
           88 IS-VALID                 VALUE 'Y'.
       01 WS-ERR-MSG                  PIC X(40).
       01 WS-ACCT-NUM                 PIC X(12).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-COUNT-OWNERS
           PERFORM 2000-VALIDATE-OP
           IF IS-VALID
               PERFORM 3000-EXECUTE-OP
           END-IF
           PERFORM 4000-DISPLAY-RESULT
           STOP RUN.
       1000-COUNT-OWNERS.
           MOVE 0 TO WS-ACTIVE-COUNT
           MOVE 0 TO WS-TOTAL-PCT
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 4
               IF OWNER-ACTIVE(WS-IDX)
                   ADD 1 TO WS-ACTIVE-COUNT
                   ADD WS-OWNER-PCT(WS-IDX) TO WS-TOTAL-PCT
               END-IF
           END-PERFORM.
       2000-VALIDATE-OP.
           MOVE 'N' TO WS-VALID
           EVALUATE TRUE
               WHEN OP-ADD
                   IF WS-ACTIVE-COUNT >= 4
                       MOVE 'MAX OWNERS REACHED' TO WS-ERR-MSG
                   ELSE
                       IF WS-NEW-SSN = SPACES
                           MOVE 'SSN REQUIRED' TO WS-ERR-MSG
                       ELSE
                           IF WS-NEW-PCT = 0
                               MOVE 'PCT MUST BE > 0'
                                   TO WS-ERR-MSG
                           ELSE
                               COMPUTE WS-TOTAL-PCT =
                                   WS-TOTAL-PCT + WS-NEW-PCT
                               IF WS-TOTAL-PCT > 100
                                   MOVE 'TOTAL PCT > 100'
                                       TO WS-ERR-MSG
                               ELSE
                                   MOVE 'Y' TO WS-VALID
                               END-IF
                           END-IF
                       END-IF
                   END-IF
               WHEN OP-REMOVE
                   IF WS-ACTIVE-COUNT <= 1
                       MOVE 'CANNOT REMOVE LAST OWNER'
                           TO WS-ERR-MSG
                   ELSE
                       IF WS-TARGET-IDX > 0
                           AND WS-TARGET-IDX <= 4
                           MOVE 'Y' TO WS-VALID
                       ELSE
                           MOVE 'INVALID OWNER INDEX'
                               TO WS-ERR-MSG
                       END-IF
                   END-IF
               WHEN OP-MODIFY
                   IF WS-TARGET-IDX > 0
                       AND WS-TARGET-IDX <= 4
                       MOVE 'Y' TO WS-VALID
                   ELSE
                       MOVE 'INVALID OWNER INDEX'
                           TO WS-ERR-MSG
                   END-IF
               WHEN OTHER
                   MOVE 'INVALID OPERATION' TO WS-ERR-MSG
           END-EVALUATE.
       3000-EXECUTE-OP.
           IF OP-ADD
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > 4
                   IF NOT OWNER-ACTIVE(WS-IDX)
                       MOVE WS-NEW-NAME TO
                           WS-OWNER-NAME(WS-IDX)
                       MOVE WS-NEW-SSN TO
                           WS-OWNER-SSN(WS-IDX)
                       MOVE WS-NEW-PCT TO
                           WS-OWNER-PCT(WS-IDX)
                       MOVE 'Y' TO
                           WS-OWNER-ACTIVE(WS-IDX)
                   END-IF
               END-PERFORM
           END-IF
           IF OP-REMOVE
               MOVE 'N' TO
                   WS-OWNER-ACTIVE(WS-TARGET-IDX)
               MOVE 0 TO
                   WS-OWNER-PCT(WS-TARGET-IDX)
           END-IF
           IF OP-MODIFY
               MOVE WS-NEW-NAME TO
                   WS-OWNER-NAME(WS-TARGET-IDX)
               MOVE WS-NEW-PCT TO
                   WS-OWNER-PCT(WS-TARGET-IDX)
           END-IF.
       4000-DISPLAY-RESULT.
           DISPLAY 'JOINT OWNERSHIP MANAGEMENT'
           DISPLAY '=========================='
           DISPLAY 'ACCOUNT: ' WS-ACCT-NUM
           IF IS-VALID
               DISPLAY 'OPERATION: ' WS-OPERATION
                   ' - COMPLETED'
               PERFORM VARYING WS-IDX FROM 1 BY 1
                   UNTIL WS-IDX > 4
                   IF OWNER-ACTIVE(WS-IDX)
                       DISPLAY '  OWNER: '
                           WS-OWNER-NAME(WS-IDX)
                           ' PCT=' WS-OWNER-PCT(WS-IDX)
                   END-IF
               END-PERFORM
           ELSE
               DISPLAY 'REJECTED: ' WS-ERR-MSG
           END-IF.
