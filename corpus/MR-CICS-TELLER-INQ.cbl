       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-TELLER-INQ.
      *================================================================*
      * Teller Account Inquiry via CICS BMS Map                        *
      * Receives customer inquiry from CICS terminal, retrieves        *
      * account data, formats response map, sends to terminal.         *
      * INTENTIONAL: Uses EXEC CICS to trigger MANUAL REVIEW.          *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- CICS Fields ---
       01  WS-RESP                   PIC S9(8) COMP.
       01  WS-RESP2                  PIC S9(8) COMP.
       01  WS-TRANSID                PIC X(4).
       01  WS-TERMINAL-ID            PIC X(4).
      *--- Input Map ---
       01  WS-INPUT-MAP.
           05  WS-INP-ACCT-NUM       PIC 9(10).
           05  WS-INP-INQUIRY-TYPE   PIC 9.
               88  WS-INQ-BALANCE    VALUE 1.
               88  WS-INQ-HISTORY    VALUE 2.
               88  WS-INQ-HOLDS      VALUE 3.
           05  WS-INP-TELLER-ID      PIC X(8).
      *--- Account Data ---
       01  WS-ACCT-DATA.
           05  WS-AD-NAME            PIC X(35).
           05  WS-AD-TYPE            PIC 9.
               88  WS-AD-CHECKING    VALUE 1.
               88  WS-AD-SAVINGS     VALUE 2.
               88  WS-AD-MMA         VALUE 3.
           05  WS-AD-STATUS          PIC X(2).
           05  WS-AD-BALANCE         PIC S9(11)V99 COMP-3.
           05  WS-AD-AVAILABLE       PIC S9(11)V99 COMP-3.
           05  WS-AD-HOLD-AMT        PIC S9(9)V99 COMP-3.
           05  WS-AD-LAST-TXN-DATE   PIC 9(8).
           05  WS-AD-OPEN-DATE       PIC 9(8).
      *--- Output Map ---
       01  WS-OUTPUT-MAP.
           05  WS-OUT-NAME            PIC X(35).
           05  WS-OUT-ACCT            PIC X(10).
           05  WS-OUT-TYPE-DESC       PIC X(10).
           05  WS-OUT-BALANCE         PIC -$$$,$$$,$$$,$$9.99.
           05  WS-OUT-AVAILABLE       PIC -$$$,$$$,$$$,$$9.99.
           05  WS-OUT-HOLD            PIC -$$$,$$$,$$9.99.
           05  WS-OUT-STATUS          PIC X(10).
           05  WS-OUT-MSG             PIC X(40).
      *--- Recent Transactions ---
       01  WS-RECENT-TABLE.
           05  WS-RECENT-ENTRY OCCURS 5 TIMES.
               10  WS-REC-DATE        PIC 9(8).
               10  WS-REC-DESC        PIC X(20).
               10  WS-REC-AMOUNT      PIC S9(9)V99 COMP-3.
       01  WS-REC-IDX                PIC 9(3).
      *--- Validation ---
       01  WS-VALID-ACCT             PIC 9.
           88  WS-ACCT-VALID         VALUE 1.
           88  WS-ACCT-INVALID       VALUE 0.
       01  WS-FOUND-FLAG             PIC 9.
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC ZZ9.
      *--- Tally ---
       01  WS-ACCT-TALLY             PIC S9(5) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-RECEIVE-MAP
           IF WS-RESP = 0
               PERFORM 3000-VALIDATE-INPUT
               IF WS-ACCT-VALID
                   PERFORM 4000-RETRIEVE-ACCOUNT
                   PERFORM 5000-FORMAT-OUTPUT
                   PERFORM 6000-SEND-MAP
               ELSE
                   MOVE "INVALID ACCOUNT NUMBER"
                       TO WS-OUT-MSG
                   PERFORM 6000-SEND-MAP
               END-IF
           END-IF
           PERFORM 7000-DISPLAY-LOG
           EXEC CICS RETURN
               TRANSID('TINQ')
           END-EXEC
           STOP RUN.

       1000-INITIALIZE.
           MOVE "TINQ" TO WS-TRANSID
           MOVE 0 TO WS-FOUND-FLAG
           MOVE 1 TO WS-VALID-ACCT
           MOVE SPACES TO WS-OUT-MSG.

       2000-RECEIVE-MAP.
           EXEC CICS RECEIVE
               MAP('INQMAP')
               MAPSET('TLLRSET')
               INTO(WS-INPUT-MAP)
               RESP(WS-RESP)
           END-EXEC.

       3000-VALIDATE-INPUT.
           MOVE 1 TO WS-VALID-ACCT
           IF WS-INP-ACCT-NUM = 0
               MOVE 0 TO WS-VALID-ACCT
           END-IF
           MOVE 0 TO WS-ACCT-TALLY
           INSPECT WS-INP-TELLER-ID
               TALLYING WS-ACCT-TALLY FOR ALL SPACES
           IF WS-ACCT-TALLY >= 8
               MOVE 0 TO WS-VALID-ACCT
           END-IF.

       4000-RETRIEVE-ACCOUNT.
           MOVE "ANDERSON, THOMAS K"
               TO WS-AD-NAME
           MOVE 1 TO WS-AD-TYPE
           MOVE "AC" TO WS-AD-STATUS
           MOVE 24567.89 TO WS-AD-BALANCE
           MOVE 500.00 TO WS-AD-HOLD-AMT
           COMPUTE WS-AD-AVAILABLE =
               WS-AD-BALANCE - WS-AD-HOLD-AMT
           MOVE 20260320 TO WS-AD-LAST-TXN-DATE
           MOVE 20180115 TO WS-AD-OPEN-DATE
           MOVE 1 TO WS-FOUND-FLAG
           MOVE 20260320 TO WS-REC-DATE(1)
           MOVE "ATM WITHDRAWAL"
               TO WS-REC-DESC(1)
           MOVE -200.00 TO WS-REC-AMOUNT(1)
           MOVE 20260319 TO WS-REC-DATE(2)
           MOVE "DIRECT DEPOSIT"
               TO WS-REC-DESC(2)
           MOVE 3250.00 TO WS-REC-AMOUNT(2)
           MOVE 20260318 TO WS-REC-DATE(3)
           MOVE "CHECK 1055"
               TO WS-REC-DESC(3)
           MOVE -750.00 TO WS-REC-AMOUNT(3)
           MOVE 20260315 TO WS-REC-DATE(4)
           MOVE "POS PURCHASE"
               TO WS-REC-DESC(4)
           MOVE -45.99 TO WS-REC-AMOUNT(4)
           MOVE 20260312 TO WS-REC-DATE(5)
           MOVE "ACH PAYMENT"
               TO WS-REC-DESC(5)
           MOVE -125.00 TO WS-REC-AMOUNT(5).

       5000-FORMAT-OUTPUT.
           MOVE WS-AD-NAME TO WS-OUT-NAME
           MOVE WS-INP-ACCT-NUM TO WS-OUT-ACCT
           EVALUATE TRUE
               WHEN WS-AD-CHECKING
                   MOVE "CHECKING" TO WS-OUT-TYPE-DESC
               WHEN WS-AD-SAVINGS
                   MOVE "SAVINGS" TO WS-OUT-TYPE-DESC
               WHEN WS-AD-MMA
                   MOVE "MMA" TO WS-OUT-TYPE-DESC
           END-EVALUATE
           MOVE WS-AD-BALANCE TO WS-OUT-BALANCE
           MOVE WS-AD-AVAILABLE TO WS-OUT-AVAILABLE
           MOVE WS-AD-HOLD-AMT TO WS-OUT-HOLD
           IF WS-AD-STATUS = "AC"
               MOVE "ACTIVE" TO WS-OUT-STATUS
           ELSE
               MOVE "RESTRICTED" TO WS-OUT-STATUS
           END-IF
           MOVE "INQUIRY SUCCESSFUL"
               TO WS-OUT-MSG.

       6000-SEND-MAP.
           EXEC CICS SEND
               MAP('OUTMAP')
               MAPSET('TLLRSET')
               FROM(WS-OUTPUT-MAP)
               ERASE
               RESP(WS-RESP)
           END-EXEC.

       7000-DISPLAY-LOG.
           DISPLAY "========================================"
           DISPLAY "   TELLER INQUIRY LOG"
           DISPLAY "========================================"
           DISPLAY "TELLER:  " WS-INP-TELLER-ID
           DISPLAY "ACCOUNT: " WS-INP-ACCT-NUM
           DISPLAY "NAME:    " WS-OUT-NAME
           DISPLAY "TYPE:    " WS-OUT-TYPE-DESC
           DISPLAY "BALANCE: " WS-OUT-BALANCE
           DISPLAY "MESSAGE: " WS-OUT-MSG
           IF WS-FOUND-FLAG = 1
               DISPLAY "--- RECENT ACTIVITY ---"
               PERFORM VARYING WS-REC-IDX FROM 1 BY 1
                   UNTIL WS-REC-IDX > 5
                   MOVE WS-REC-AMOUNT(WS-REC-IDX)
                       TO WS-DISP-AMT
                   DISPLAY WS-REC-DATE(WS-REC-IDX) " "
                       WS-REC-DESC(WS-REC-IDX) " "
                       WS-DISP-AMT
               END-PERFORM
           END-IF
           DISPLAY "========================================".
