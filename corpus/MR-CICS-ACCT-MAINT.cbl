       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-ACCT-MAINT.
      *================================================================*
      * MANUAL REVIEW: CICS ACCOUNT MAINTENANCE SCREEN                 *
      * Online account maintenance using EXEC CICS for address         *
      * change, hold/unhold, and beneficiary updates.                  *
      * EXEC CICS triggers REQUIRES_MANUAL_REVIEW.                    *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-MAINT-REQUEST.
           05 WS-ACCT-NUM           PIC X(12).
           05 WS-MAINT-TYPE         PIC X(2).
               88 WS-ADDR-CHANGE    VALUE 'AC'.
               88 WS-HOLD-ACCT      VALUE 'HL'.
               88 WS-UNHOLD-ACCT    VALUE 'UH'.
               88 WS-BENE-UPDATE    VALUE 'BU'.
               88 WS-CLOSE-REQUEST  VALUE 'CL'.
           05 WS-OPERATOR-ID        PIC X(8).
           05 WS-BRANCH-ID          PIC X(4).
       01 WS-ACCT-DATA.
           05 WS-ACCT-NAME          PIC X(30).
           05 WS-ADDR-LINE1         PIC X(35).
           05 WS-ADDR-LINE2         PIC X(35).
           05 WS-ADDR-CITY          PIC X(20).
           05 WS-ADDR-STATE         PIC X(2).
           05 WS-ADDR-ZIP           PIC X(10).
           05 WS-ACCT-STATUS        PIC X(1).
               88 WS-ACTIVE         VALUE 'A'.
               88 WS-ON-HOLD        VALUE 'H'.
               88 WS-ACCT-CLOSED    VALUE 'C'.
           05 WS-BALANCE            PIC S9(11)V99 COMP-3.
       01 WS-NEW-ADDR.
           05 WS-NEW-LINE1          PIC X(35).
           05 WS-NEW-LINE2          PIC X(35).
           05 WS-NEW-CITY           PIC X(20).
           05 WS-NEW-STATE          PIC X(2).
           05 WS-NEW-ZIP            PIC X(10).
       01 WS-HOLD-REASON            PIC X(30).
       01 WS-BENE-DATA.
           05 WS-BENE-NAME          PIC X(30).
           05 WS-BENE-RELATION      PIC X(15).
           05 WS-BENE-PCT           PIC S9(3) COMP-3.
       01 WS-RESPONSE               PIC S9(8) COMP.
       01 WS-MAP-NAME               PIC X(8) VALUE 'ACMTMAP'.
       01 WS-MAPSET-NAME            PIC X(8) VALUE 'ACMTSET'.
       01 WS-RESULT-MSG             PIC X(60).
       01 WS-AUDIT-REC              PIC X(120).
       01 WS-VALID-FLAG             PIC X VALUE 'Y'.
           88 WS-IS-VALID           VALUE 'Y'.
       01 WS-CHANGES-MADE           PIC S9(2) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           EXEC CICS RECEIVE MAP(WS-MAP-NAME)
               MAPSET(WS-MAPSET-NAME)
               INTO(WS-MAINT-REQUEST)
               RESP(WS-RESPONSE)
           END-EXEC
           IF WS-RESPONSE = 0
               PERFORM 2000-LOAD-ACCOUNT
               IF WS-IS-VALID
                   PERFORM 3000-PROCESS-MAINTENANCE
               END-IF
               PERFORM 4000-SEND-RESULT
           ELSE
               MOVE 'MAP RECEIVE ERROR' TO WS-RESULT-MSG
               PERFORM 4000-SEND-RESULT
           END-IF
           EXEC CICS RETURN
               TRANSID('AMNT')
           END-EXEC.
       1000-INITIALIZE.
           MOVE 0 TO WS-CHANGES-MADE
           MOVE SPACES TO WS-RESULT-MSG
           MOVE SPACES TO WS-AUDIT-REC.
       2000-LOAD-ACCOUNT.
           MOVE 'JOHNSON, PATRICIA L' TO WS-ACCT-NAME
           MOVE '456 OAK AVENUE' TO WS-ADDR-LINE1
           MOVE 'SUITE 200' TO WS-ADDR-LINE2
           MOVE 'CHICAGO' TO WS-ADDR-CITY
           MOVE 'IL' TO WS-ADDR-STATE
           MOVE '60601' TO WS-ADDR-ZIP
           MOVE 'A' TO WS-ACCT-STATUS
           MOVE 125450.00 TO WS-BALANCE
           IF WS-ACCT-CLOSED
               MOVE 'N' TO WS-VALID-FLAG
               MOVE 'ACCOUNT IS CLOSED' TO WS-RESULT-MSG
           END-IF.
       3000-PROCESS-MAINTENANCE.
           EVALUATE TRUE
               WHEN WS-ADDR-CHANGE
                   PERFORM 3100-CHANGE-ADDRESS
               WHEN WS-HOLD-ACCT
                   PERFORM 3200-HOLD-ACCOUNT
               WHEN WS-UNHOLD-ACCT
                   PERFORM 3300-UNHOLD-ACCOUNT
               WHEN WS-BENE-UPDATE
                   PERFORM 3400-UPDATE-BENEFICIARY
               WHEN WS-CLOSE-REQUEST
                   PERFORM 3500-CLOSE-ACCOUNT
               WHEN OTHER
                   MOVE 'INVALID MAINTENANCE TYPE' TO
                       WS-RESULT-MSG
           END-EVALUATE
           PERFORM 3900-WRITE-AUDIT.
       3100-CHANGE-ADDRESS.
           IF WS-NEW-LINE1 NOT = SPACES
               MOVE WS-NEW-LINE1 TO WS-ADDR-LINE1
               MOVE WS-NEW-LINE2 TO WS-ADDR-LINE2
               MOVE WS-NEW-CITY TO WS-ADDR-CITY
               MOVE WS-NEW-STATE TO WS-ADDR-STATE
               MOVE WS-NEW-ZIP TO WS-ADDR-ZIP
               ADD 1 TO WS-CHANGES-MADE
               MOVE 'ADDRESS UPDATED' TO WS-RESULT-MSG
           ELSE
               MOVE 'NEW ADDRESS REQUIRED' TO WS-RESULT-MSG
           END-IF.
       3200-HOLD-ACCOUNT.
           IF WS-ACTIVE
               MOVE 'H' TO WS-ACCT-STATUS
               ADD 1 TO WS-CHANGES-MADE
               MOVE 'ACCOUNT PLACED ON HOLD' TO
                   WS-RESULT-MSG
           ELSE
               MOVE 'ACCOUNT NOT ACTIVE' TO WS-RESULT-MSG
           END-IF.
       3300-UNHOLD-ACCOUNT.
           IF WS-ON-HOLD
               MOVE 'A' TO WS-ACCT-STATUS
               ADD 1 TO WS-CHANGES-MADE
               MOVE 'HOLD REMOVED' TO WS-RESULT-MSG
           ELSE
               MOVE 'ACCOUNT NOT ON HOLD' TO WS-RESULT-MSG
           END-IF.
       3400-UPDATE-BENEFICIARY.
           IF WS-BENE-NAME NOT = SPACES
               IF WS-BENE-PCT > 0 AND WS-BENE-PCT <= 100
                   ADD 1 TO WS-CHANGES-MADE
                   MOVE 'BENEFICIARY UPDATED' TO
                       WS-RESULT-MSG
               ELSE
                   MOVE 'INVALID PERCENTAGE' TO
                       WS-RESULT-MSG
               END-IF
           ELSE
               MOVE 'BENEFICIARY NAME REQUIRED' TO
                   WS-RESULT-MSG
           END-IF.
       3500-CLOSE-ACCOUNT.
           IF WS-BALANCE > 0
               MOVE 'BALANCE MUST BE ZERO TO CLOSE' TO
                   WS-RESULT-MSG
           ELSE
               MOVE 'C' TO WS-ACCT-STATUS
               ADD 1 TO WS-CHANGES-MADE
               MOVE 'ACCOUNT CLOSED' TO WS-RESULT-MSG
           END-IF.
       3900-WRITE-AUDIT.
           STRING WS-ACCT-NUM DELIMITED BY SIZE
               '|' DELIMITED BY SIZE
               WS-MAINT-TYPE DELIMITED BY SIZE
               '|' DELIMITED BY SIZE
               WS-OPERATOR-ID DELIMITED BY SIZE
               '|' DELIMITED BY SIZE
               WS-BRANCH-ID DELIMITED BY SIZE
               '|' DELIMITED BY SIZE
               WS-RESULT-MSG DELIMITED BY SPACES
               INTO WS-AUDIT-REC
           DISPLAY 'AUDIT: ' WS-AUDIT-REC.
       4000-SEND-RESULT.
           EXEC CICS SEND MAP(WS-MAP-NAME)
               MAPSET(WS-MAPSET-NAME)
               FROM(WS-RESULT-MSG)
               ERASE
               RESP(WS-RESPONSE)
           END-EXEC
           DISPLAY 'MAINT RESULT: ' WS-RESULT-MSG
           DISPLAY 'CHANGES: ' WS-CHANGES-MADE.
