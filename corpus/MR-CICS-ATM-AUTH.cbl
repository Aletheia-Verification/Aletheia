       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-ATM-AUTH.
      *================================================================*
      * ATM Authorization via CICS Terminal Control                    *
      * Uses CICS SEND/RECEIVE for real-time ATM card authorization,  *
      * validates PIN, checks balance, returns auth code.              *
      * INTENTIONAL: Uses EXEC CICS to trigger MANUAL REVIEW.         *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- CICS Communication Area ---
       01  WS-COMMAREA.
           05  WS-COMM-CARD-NUM      PIC X(16).
           05  WS-COMM-PIN           PIC X(4).
           05  WS-COMM-AMOUNT        PIC S9(7)V99 COMP-3.
           05  WS-COMM-ACCT-TYPE     PIC 9.
           05  WS-COMM-RESP-CODE     PIC X(2).
           05  WS-COMM-AUTH-CODE     PIC X(6).
           05  WS-COMM-BALANCE       PIC S9(11)V99 COMP-3.
      *--- Account Lookup ---
       01  WS-ACCT-NUM               PIC 9(10).
       01  WS-ACCT-BALANCE           PIC S9(11)V99 COMP-3.
       01  WS-AVAIL-BALANCE          PIC S9(11)V99 COMP-3.
       01  WS-ACCT-STATUS            PIC 9.
           88  WS-ACCT-ACTIVE        VALUE 1.
           88  WS-ACCT-FROZEN        VALUE 2.
           88  WS-ACCT-CLOSED        VALUE 3.
      *--- PIN Verification ---
       01  WS-STORED-PIN             PIC X(4).
       01  WS-PIN-TRIES              PIC S9(3) COMP-3.
       01  WS-MAX-PIN-TRIES          PIC S9(3) COMP-3.
       01  WS-PIN-OK                 PIC 9.
      *--- Authorization ---
       01  WS-AUTH-STATUS             PIC 9.
           88  WS-AUTH-APPROVED       VALUE 1.
           88  WS-AUTH-DECLINED       VALUE 2.
           88  WS-AUTH-REFERRAL       VALUE 3.
       01  WS-AUTH-SEQUENCE           PIC 9(6).
       01  WS-DAILY-LIMIT            PIC S9(7)V99 COMP-3.
       01  WS-DAILY-USED             PIC S9(7)V99 COMP-3.
       01  WS-REMAINING              PIC S9(7)V99 COMP-3.
      *--- Counters ---
       01  WS-TXN-CT                 PIC S9(5) COMP-3.
       01  WS-APPROVED-CT            PIC S9(5) COMP-3.
       01  WS-DECLINED-CT            PIC S9(5) COMP-3.
      *--- Display ---
       01  WS-DISP-AMT               PIC -$$$,$$$,$$9.99.
       01  WS-DISP-CT                PIC ZZ,ZZ9.
      *--- CICS Response ---
       01  WS-RESP                   PIC S9(8) COMP.
       01  WS-RESP2                  PIC S9(8) COMP.
      *--- Work ---
       01  WS-TALLY-WORK             PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-RECEIVE-REQUEST
           PERFORM 3000-VALIDATE-CARD
           IF WS-PIN-OK = 1
               PERFORM 4000-CHECK-BALANCE
               PERFORM 5000-AUTHORIZE
           ELSE
               MOVE "05" TO WS-COMM-RESP-CODE
           END-IF
           PERFORM 6000-SEND-RESPONSE
           PERFORM 7000-DISPLAY-LOG
           EXEC CICS RETURN
           END-EXEC
           STOP RUN.

       1000-INITIALIZE.
           MOVE 0 TO WS-TXN-CT
           MOVE 0 TO WS-APPROVED-CT
           MOVE 0 TO WS-DECLINED-CT
           MOVE "1234" TO WS-STORED-PIN
           MOVE 0 TO WS-PIN-TRIES
           MOVE 3 TO WS-MAX-PIN-TRIES
           MOVE 0 TO WS-PIN-OK
           MOVE 500.00 TO WS-DAILY-LIMIT
           MOVE 100.00 TO WS-DAILY-USED
           MOVE 5425.75 TO WS-ACCT-BALANCE
           MOVE 1 TO WS-ACCT-STATUS
           MOVE 100001 TO WS-AUTH-SEQUENCE.

       2000-RECEIVE-REQUEST.
           EXEC CICS RECEIVE
               INTO(WS-COMMAREA)
               LENGTH(50)
               RESP(WS-RESP)
           END-EXEC
           IF WS-RESP NOT = 0
               MOVE "99" TO WS-COMM-RESP-CODE
           ELSE
               ADD 1 TO WS-TXN-CT
           END-IF.

       3000-VALIDATE-CARD.
           MOVE 0 TO WS-PIN-OK
           IF WS-COMM-PIN = WS-STORED-PIN
               MOVE 1 TO WS-PIN-OK
           ELSE
               ADD 1 TO WS-PIN-TRIES
               IF WS-PIN-TRIES >= WS-MAX-PIN-TRIES
                   MOVE 2 TO WS-ACCT-STATUS
               END-IF
           END-IF.

       4000-CHECK-BALANCE.
           COMPUTE WS-AVAIL-BALANCE =
               WS-ACCT-BALANCE
           COMPUTE WS-REMAINING =
               WS-DAILY-LIMIT - WS-DAILY-USED.

       5000-AUTHORIZE.
           IF WS-ACCT-FROZEN
               MOVE "14" TO WS-COMM-RESP-CODE
               MOVE 2 TO WS-AUTH-STATUS
               ADD 1 TO WS-DECLINED-CT
           ELSE IF WS-COMM-AMOUNT > WS-REMAINING
               MOVE "61" TO WS-COMM-RESP-CODE
               MOVE 2 TO WS-AUTH-STATUS
               ADD 1 TO WS-DECLINED-CT
           ELSE IF WS-COMM-AMOUNT > WS-AVAIL-BALANCE
               MOVE "51" TO WS-COMM-RESP-CODE
               MOVE 2 TO WS-AUTH-STATUS
               ADD 1 TO WS-DECLINED-CT
           ELSE
               MOVE "00" TO WS-COMM-RESP-CODE
               ADD 1 TO WS-AUTH-SEQUENCE
               MOVE WS-AUTH-SEQUENCE
                   TO WS-COMM-AUTH-CODE
               COMPUTE WS-ACCT-BALANCE =
                   WS-ACCT-BALANCE - WS-COMM-AMOUNT
               MOVE WS-ACCT-BALANCE TO WS-COMM-BALANCE
               ADD WS-COMM-AMOUNT TO WS-DAILY-USED
               MOVE 1 TO WS-AUTH-STATUS
               ADD 1 TO WS-APPROVED-CT
           END-IF.

       6000-SEND-RESPONSE.
           EXEC CICS SEND
               FROM(WS-COMMAREA)
               LENGTH(50)
               RESP(WS-RESP)
           END-EXEC
           MOVE 0 TO WS-TALLY-WORK
           INSPECT WS-COMM-RESP-CODE
               TALLYING WS-TALLY-WORK FOR ALL "0".

       7000-DISPLAY-LOG.
           DISPLAY "========================================"
           DISPLAY "   ATM AUTH LOG"
           DISPLAY "========================================"
           DISPLAY "RESP CODE: " WS-COMM-RESP-CODE
           MOVE WS-COMM-AMOUNT TO WS-DISP-AMT
           DISPLAY "AMOUNT:    " WS-DISP-AMT
           DISPLAY "AUTH CODE: " WS-COMM-AUTH-CODE
           MOVE WS-ACCT-BALANCE TO WS-DISP-AMT
           DISPLAY "BALANCE:   " WS-DISP-AMT
           DISPLAY "========================================".
