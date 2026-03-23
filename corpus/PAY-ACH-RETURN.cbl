       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAY-ACH-RETURN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-RETURN-RECORD.
           05 WS-ORIG-TRACE       PIC X(15).
           05 WS-RETURN-CODE      PIC X(3).
               88 RC-NSF          VALUE 'R01'.
               88 RC-CLOSED       VALUE 'R02'.
               88 RC-NO-ACCT      VALUE 'R03'.
               88 RC-INVALID-NUM  VALUE 'R04'.
               88 RC-UNAUTHORIZED VALUE 'R10'.
               88 RC-DECEASED     VALUE 'R14'.
               88 RC-FROZEN       VALUE 'R16'.
           05 WS-ORIG-AMOUNT      PIC S9(9)V99 COMP-3.
           05 WS-ORIG-ACCT        PIC X(17).
           05 WS-ORIG-NAME        PIC X(22).
           05 WS-RETURN-DATE      PIC 9(8).
       01 WS-RETURN-TABLE.
           05 WS-RTN OCCURS 20 TIMES.
               10 WS-RTN-TRACE    PIC X(15).
               10 WS-RTN-CODE     PIC X(3).
               10 WS-RTN-AMT      PIC S9(9)V99 COMP-3.
               10 WS-RTN-ACTION   PIC X(10).
       01 WS-RTN-COUNT            PIC 99 VALUE 20.
       01 WS-IDX                  PIC 99.
       01 WS-ADMIN-RETURNS        PIC 9(3).
       01 WS-UNAUTH-RETURNS       PIC 9(3).
       01 WS-NSF-RETURNS          PIC 9(3).
       01 WS-OTHER-RETURNS        PIC 9(3).
       01 WS-TOTAL-RETURNED       PIC S9(11)V99 COMP-3.
       01 WS-NSF-FEE              PIC S9(5)V99 COMP-3
           VALUE 25.00.
       01 WS-TOTAL-FEES           PIC S9(7)V99 COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-PROCESS-RETURNS
           PERFORM 3000-REPORT
           STOP RUN.
       1000-INIT.
           MOVE 0 TO WS-ADMIN-RETURNS
           MOVE 0 TO WS-UNAUTH-RETURNS
           MOVE 0 TO WS-NSF-RETURNS
           MOVE 0 TO WS-OTHER-RETURNS
           MOVE 0 TO WS-TOTAL-RETURNED
           MOVE 0 TO WS-TOTAL-FEES.
       2000-PROCESS-RETURNS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-RTN-COUNT
               PERFORM 2100-CLASSIFY-RETURN
           END-PERFORM.
       2100-CLASSIFY-RETURN.
           ADD WS-RTN-AMT(WS-IDX) TO WS-TOTAL-RETURNED
           EVALUATE WS-RTN-CODE(WS-IDX)
               WHEN 'R01'
                   ADD 1 TO WS-NSF-RETURNS
                   ADD WS-NSF-FEE TO WS-TOTAL-FEES
                   MOVE 'RE-DEBIT  ' TO WS-RTN-ACTION(WS-IDX)
               WHEN 'R02'
                   ADD 1 TO WS-ADMIN-RETURNS
                   MOVE 'NOTIFY    ' TO WS-RTN-ACTION(WS-IDX)
               WHEN 'R03'
                   ADD 1 TO WS-ADMIN-RETURNS
                   MOVE 'NOTIFY    ' TO WS-RTN-ACTION(WS-IDX)
               WHEN 'R04'
                   ADD 1 TO WS-ADMIN-RETURNS
                   MOVE 'CORRECT   ' TO WS-RTN-ACTION(WS-IDX)
               WHEN 'R10'
                   ADD 1 TO WS-UNAUTH-RETURNS
                   MOVE 'REVERSE   ' TO WS-RTN-ACTION(WS-IDX)
               WHEN 'R14'
                   ADD 1 TO WS-ADMIN-RETURNS
                   MOVE 'CLOSE ACCT' TO WS-RTN-ACTION(WS-IDX)
               WHEN 'R16'
                   ADD 1 TO WS-ADMIN-RETURNS
                   MOVE 'HOLD      ' TO WS-RTN-ACTION(WS-IDX)
               WHEN OTHER
                   ADD 1 TO WS-OTHER-RETURNS
                   MOVE 'REVIEW    ' TO WS-RTN-ACTION(WS-IDX)
           END-EVALUATE.
       3000-REPORT.
           DISPLAY 'ACH RETURN PROCESSING REPORT'
           DISPLAY '============================'
           DISPLAY 'NSF RETURNS:   ' WS-NSF-RETURNS
           DISPLAY 'ADMIN RETURNS: ' WS-ADMIN-RETURNS
           DISPLAY 'UNAUTH RETURNS:' WS-UNAUTH-RETURNS
           DISPLAY 'OTHER RETURNS: ' WS-OTHER-RETURNS
           DISPLAY 'TOTAL AMOUNT:  $' WS-TOTAL-RETURNED
           DISPLAY 'FEES ASSESSED: $' WS-TOTAL-FEES
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-RTN-COUNT
               DISPLAY '  ' WS-RTN-TRACE(WS-IDX)
                   ' ' WS-RTN-CODE(WS-IDX)
                   ' $' WS-RTN-AMT(WS-IDX)
                   ' ' WS-RTN-ACTION(WS-IDX)
           END-PERFORM.
