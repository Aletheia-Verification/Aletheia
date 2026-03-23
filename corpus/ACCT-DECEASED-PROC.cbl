       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-DECEASED-PROC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-DECEASED-INFO.
           05 WS-CUST-ID         PIC X(12).
           05 WS-CUST-NAME       PIC X(30).
           05 WS-DATE-OF-DEATH   PIC 9(8).
           05 WS-ESTATE-REP      PIC X(30).
           05 WS-COURT-ORDER     PIC X(15).
       01 WS-ACCT-LIST.
           05 WS-DA OCCURS 5 TIMES.
               10 WS-DA-NUM      PIC X(12).
               10 WS-DA-TYPE     PIC X(2).
               10 WS-DA-BALANCE  PIC S9(9)V99 COMP-3.
               10 WS-DA-STATUS   PIC X(2).
       01 WS-DA-COUNT            PIC 9 VALUE 5.
       01 WS-IDX                 PIC 9.
       01 WS-TOTAL-BAL           PIC S9(11)V99 COMP-3.
       01 WS-FROZEN-COUNT        PIC 9.
       01 WS-NOTIFICATION-DATE   PIC 9(8).
       01 WS-ESTATE-STATUS       PIC X(15).
       01 WS-ACTIONS-LOG         PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-FREEZE-ACCOUNTS
           PERFORM 3000-CALC-ESTATE
           PERFORM 4000-SET-STATUS
           PERFORM 5000-OUTPUT
           STOP RUN.
       1000-INIT.
           ACCEPT WS-NOTIFICATION-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-TOTAL-BAL
           MOVE 0 TO WS-FROZEN-COUNT.
       2000-FREEZE-ACCOUNTS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-DA-COUNT
               IF WS-DA-STATUS(WS-IDX) = 'AC'
                   MOVE 'FR' TO WS-DA-STATUS(WS-IDX)
                   ADD 1 TO WS-FROZEN-COUNT
               END-IF
               ADD WS-DA-BALANCE(WS-IDX) TO WS-TOTAL-BAL
           END-PERFORM.
       3000-CALC-ESTATE.
           IF WS-TOTAL-BAL > 0
               IF WS-COURT-ORDER NOT = SPACES
                   MOVE 'COURT ORDER    ' TO WS-ESTATE-STATUS
               ELSE
                   IF WS-ESTATE-REP NOT = SPACES
                       MOVE 'REP ASSIGNED   ' TO
                           WS-ESTATE-STATUS
                   ELSE
                       MOVE 'PENDING        ' TO
                           WS-ESTATE-STATUS
                   END-IF
               END-IF
           ELSE
               MOVE 'ZERO BALANCE   ' TO WS-ESTATE-STATUS
           END-IF.
       4000-SET-STATUS.
           STRING 'DECEASED ' DELIMITED BY SIZE
               WS-CUST-ID DELIMITED BY ' '
               ' DOD=' DELIMITED BY SIZE
               WS-DATE-OF-DEATH DELIMITED BY SIZE
               ' BAL=$' DELIMITED BY SIZE
               WS-TOTAL-BAL DELIMITED BY SIZE
               INTO WS-ACTIONS-LOG
           END-STRING.
       5000-OUTPUT.
           DISPLAY 'DECEASED ACCOUNT PROCESSING'
           DISPLAY '==========================='
           DISPLAY 'CUSTOMER: ' WS-CUST-ID
           DISPLAY 'NAME:     ' WS-CUST-NAME
           DISPLAY 'DOD:      ' WS-DATE-OF-DEATH
           DISPLAY 'FROZEN:   ' WS-FROZEN-COUNT
           DISPLAY 'TOTAL BAL:$' WS-TOTAL-BAL
           DISPLAY 'ESTATE:   ' WS-ESTATE-STATUS
           IF WS-ESTATE-REP NOT = SPACES
               DISPLAY 'REP:      ' WS-ESTATE-REP
           END-IF
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-DA-COUNT
               DISPLAY '  ' WS-DA-NUM(WS-IDX)
                   ' ' WS-DA-TYPE(WS-IDX)
                   ' $' WS-DA-BALANCE(WS-IDX)
                   ' [' WS-DA-STATUS(WS-IDX) ']'
           END-PERFORM.
