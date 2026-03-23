       IDENTIFICATION DIVISION.
       PROGRAM-ID. RETURN-ITEM-PROC.
      *================================================================*
      * Returned Item Processing                                       *
      * Handles returned ACH, checks, and wires. Applies return        *
      * reason codes, reverses postings, notifies originator.          *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- Return Item Table ---
       01  WS-RETURN-TABLE.
           05  WS-RET-ENTRY OCCURS 8 TIMES.
               10  WS-RET-TYPE        PIC X(3).
               10  WS-RET-AMOUNT      PIC S9(9)V99 COMP-3.
               10  WS-RET-REASON      PIC X(4).
               10  WS-RET-ACCT        PIC 9(10).
               10  WS-RET-ORIGIN      PIC X(20).
               10  WS-RET-STATUS      PIC 9.
               10  WS-RET-FEE         PIC S9(5)V99 COMP-3.
       01  WS-RET-IDX                 PIC 9(3).
       01  WS-RET-COUNT               PIC 9(3).
      *--- Reason Code Lookup ---
       01  WS-REASON-TABLE.
           05  WS-RSN-ENTRY OCCURS 6 TIMES.
               10  WS-RSN-CODE        PIC X(4).
               10  WS-RSN-DESC        PIC X(30).
       01  WS-RSN-IDX                 PIC 9(3).
       01  WS-RSN-FOUND              PIC 9.
       01  WS-LOOKUP-DESC            PIC X(30).
      *--- Account Impact ---
       01  WS-REVERSAL-TOTAL         PIC S9(11)V99 COMP-3.
       01  WS-FEE-TOTAL              PIC S9(7)V99 COMP-3.
       01  WS-NET-IMPACT             PIC S9(11)V99 COMP-3.
      *--- Fee Schedule ---
       01  WS-ACH-RETURN-FEE         PIC S9(5)V99 COMP-3.
       01  WS-CHECK-RETURN-FEE       PIC S9(5)V99 COMP-3.
       01  WS-WIRE-RETURN-FEE        PIC S9(5)V99 COMP-3.
      *--- Counters ---
       01  WS-ACH-COUNT              PIC S9(3) COMP-3.
       01  WS-CHECK-COUNT            PIC S9(3) COMP-3.
       01  WS-WIRE-COUNT             PIC S9(3) COMP-3.
       01  WS-PROCESSED-CT           PIC S9(3) COMP-3.
       01  WS-ERROR-CT               PIC S9(3) COMP-3.
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$9.99.
       01  WS-DISP-TOTAL             PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC ZZ9.
      *--- Notification ---
       01  WS-NOTIFY-LINE            PIC X(72).
       01  WS-FORMATTED-MSG          PIC X(50).
      *--- Work ---
       01  WS-WORK-AMT               PIC S9(9)V99 COMP-3.
       01  WS-REASON-TALLY           PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-REASON-CODES
           PERFORM 3000-LOAD-RETURNS
           PERFORM 4000-PROCESS-RETURNS
           PERFORM 5000-GENERATE-NOTIFICATIONS
           PERFORM 6000-DISPLAY-SUMMARY
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-REVERSAL-TOTAL
           MOVE 0 TO WS-FEE-TOTAL
           MOVE 0 TO WS-ACH-COUNT
           MOVE 0 TO WS-CHECK-COUNT
           MOVE 0 TO WS-WIRE-COUNT
           MOVE 0 TO WS-PROCESSED-CT
           MOVE 0 TO WS-ERROR-CT
           MOVE 15.00 TO WS-ACH-RETURN-FEE
           MOVE 12.00 TO WS-CHECK-RETURN-FEE
           MOVE 25.00 TO WS-WIRE-RETURN-FEE.

       2000-LOAD-REASON-CODES.
           MOVE "R01 " TO WS-RSN-CODE(1)
           MOVE "INSUFFICIENT FUNDS"
               TO WS-RSN-DESC(1)
           MOVE "R02 " TO WS-RSN-CODE(2)
           MOVE "ACCOUNT CLOSED"
               TO WS-RSN-DESC(2)
           MOVE "R03 " TO WS-RSN-CODE(3)
           MOVE "NO ACCOUNT ON FILE"
               TO WS-RSN-DESC(3)
           MOVE "R04 " TO WS-RSN-CODE(4)
           MOVE "INVALID ACCOUNT NUMBER"
               TO WS-RSN-DESC(4)
           MOVE "R08 " TO WS-RSN-CODE(5)
           MOVE "PAYMENT STOPPED"
               TO WS-RSN-DESC(5)
           MOVE "R10 " TO WS-RSN-CODE(6)
           MOVE "NOT AUTHORIZED"
               TO WS-RSN-DESC(6).

       3000-LOAD-RETURNS.
           MOVE 5 TO WS-RET-COUNT
           MOVE "ACH" TO WS-RET-TYPE(1)
           MOVE 1250.00 TO WS-RET-AMOUNT(1)
           MOVE "R01 " TO WS-RET-REASON(1)
           MOVE 2233445566 TO WS-RET-ACCT(1)
           MOVE "PAYROLL SERVICES INC"
               TO WS-RET-ORIGIN(1)
           MOVE 0 TO WS-RET-STATUS(1)
           MOVE "CHK" TO WS-RET-TYPE(2)
           MOVE 475.50 TO WS-RET-AMOUNT(2)
           MOVE "R01 " TO WS-RET-REASON(2)
           MOVE 3344556677 TO WS-RET-ACCT(2)
           MOVE "LOCAL MERCHANT"
               TO WS-RET-ORIGIN(2)
           MOVE 0 TO WS-RET-STATUS(2)
           MOVE "ACH" TO WS-RET-TYPE(3)
           MOVE 89.99 TO WS-RET-AMOUNT(3)
           MOVE "R08 " TO WS-RET-REASON(3)
           MOVE 4455667788 TO WS-RET-ACCT(3)
           MOVE "STREAMING SERVICE"
               TO WS-RET-ORIGIN(3)
           MOVE 0 TO WS-RET-STATUS(3)
           MOVE "WIR" TO WS-RET-TYPE(4)
           MOVE 5000.00 TO WS-RET-AMOUNT(4)
           MOVE "R03 " TO WS-RET-REASON(4)
           MOVE 5566778899 TO WS-RET-ACCT(4)
           MOVE "INTL SUPPLIER"
               TO WS-RET-ORIGIN(4)
           MOVE 0 TO WS-RET-STATUS(4)
           MOVE "CHK" TO WS-RET-TYPE(5)
           MOVE 150.00 TO WS-RET-AMOUNT(5)
           MOVE "R02 " TO WS-RET-REASON(5)
           MOVE 6677889900 TO WS-RET-ACCT(5)
           MOVE "INSURANCE CO"
               TO WS-RET-ORIGIN(5)
           MOVE 0 TO WS-RET-STATUS(5).

       4000-PROCESS-RETURNS.
           PERFORM VARYING WS-RET-IDX FROM 1 BY 1
               UNTIL WS-RET-IDX > WS-RET-COUNT
               PERFORM 4100-LOOKUP-REASON
               EVALUATE WS-RET-TYPE(WS-RET-IDX)
                   WHEN "ACH"
                       MOVE WS-ACH-RETURN-FEE
                           TO WS-RET-FEE(WS-RET-IDX)
                       ADD 1 TO WS-ACH-COUNT
                   WHEN "CHK"
                       MOVE WS-CHECK-RETURN-FEE
                           TO WS-RET-FEE(WS-RET-IDX)
                       ADD 1 TO WS-CHECK-COUNT
                   WHEN "WIR"
                       MOVE WS-WIRE-RETURN-FEE
                           TO WS-RET-FEE(WS-RET-IDX)
                       ADD 1 TO WS-WIRE-COUNT
                   WHEN OTHER
                       MOVE 0 TO WS-RET-FEE(WS-RET-IDX)
                       ADD 1 TO WS-ERROR-CT
               END-EVALUATE
               ADD WS-RET-AMOUNT(WS-RET-IDX)
                   TO WS-REVERSAL-TOTAL
               ADD WS-RET-FEE(WS-RET-IDX)
                   TO WS-FEE-TOTAL
               MOVE 1 TO WS-RET-STATUS(WS-RET-IDX)
               ADD 1 TO WS-PROCESSED-CT
           END-PERFORM
           COMPUTE WS-NET-IMPACT =
               WS-REVERSAL-TOTAL + WS-FEE-TOTAL.

       4100-LOOKUP-REASON.
           MOVE 0 TO WS-RSN-FOUND
           MOVE SPACES TO WS-LOOKUP-DESC
           PERFORM VARYING WS-RSN-IDX FROM 1 BY 1
               UNTIL WS-RSN-IDX > 6
                  OR WS-RSN-FOUND = 1
               IF WS-RSN-CODE(WS-RSN-IDX) =
                   WS-RET-REASON(WS-RET-IDX)
                   MOVE WS-RSN-DESC(WS-RSN-IDX)
                       TO WS-LOOKUP-DESC
                   MOVE 1 TO WS-RSN-FOUND
               END-IF
           END-PERFORM.

       5000-GENERATE-NOTIFICATIONS.
           PERFORM VARYING WS-RET-IDX FROM 1 BY 1
               UNTIL WS-RET-IDX > WS-RET-COUNT
               IF WS-RET-STATUS(WS-RET-IDX) = 1
                   MOVE 0 TO WS-REASON-TALLY
                   INSPECT WS-RET-ORIGIN(WS-RET-IDX)
                       TALLYING WS-REASON-TALLY
                       FOR ALL SPACES
                   STRING "RETURN-"
                       WS-RET-TYPE(WS-RET-IDX)
                       "-" WS-RET-REASON(WS-RET-IDX)
                       DELIMITED BY SIZE
                       INTO WS-FORMATTED-MSG
                   DISPLAY "NOTIFY: " WS-FORMATTED-MSG
                       " TO " WS-RET-ORIGIN(WS-RET-IDX)
               END-IF
           END-PERFORM.

       6000-DISPLAY-SUMMARY.
           DISPLAY "========================================"
           DISPLAY "   RETURNED ITEM SUMMARY"
           DISPLAY "========================================"
           MOVE WS-ACH-COUNT TO WS-DISP-CT
           DISPLAY "ACH RETURNS:   " WS-DISP-CT
           MOVE WS-CHECK-COUNT TO WS-DISP-CT
           DISPLAY "CHECK RETURNS:  " WS-DISP-CT
           MOVE WS-WIRE-COUNT TO WS-DISP-CT
           DISPLAY "WIRE RETURNS:   " WS-DISP-CT
           MOVE WS-REVERSAL-TOTAL TO WS-DISP-TOTAL
           DISPLAY "TOTAL REVERSED: " WS-DISP-TOTAL
           MOVE WS-FEE-TOTAL TO WS-DISP-TOTAL
           DISPLAY "TOTAL FEES:     " WS-DISP-TOTAL
           MOVE WS-NET-IMPACT TO WS-DISP-TOTAL
           DISPLAY "NET IMPACT:     " WS-DISP-TOTAL
           DISPLAY "========================================".
