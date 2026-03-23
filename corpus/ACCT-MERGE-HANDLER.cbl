       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-MERGE-HANDLER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SOURCE-ACCT.
           05 WS-SRC-NUM             PIC X(12).
           05 WS-SRC-BALANCE         PIC S9(9)V99 COMP-3.
           05 WS-SRC-TYPE            PIC X(1).
           05 WS-SRC-PRODUCTS        PIC 9(2).
       01 WS-TARGET-ACCT.
           05 WS-TGT-NUM             PIC X(12).
           05 WS-TGT-BALANCE         PIC S9(9)V99 COMP-3.
           05 WS-TGT-TYPE            PIC X(1).
           05 WS-TGT-PRODUCTS        PIC 9(2).
       01 WS-MERGE-TABLE.
           05 WS-MERGE-ITEM OCCURS 10.
               10 WS-MI-TYPE         PIC X(10).
               10 WS-MI-BALANCE      PIC S9(9)V99 COMP-3.
               10 WS-MI-STATUS       PIC X(1).
       01 WS-MI-IDX                  PIC 9(2).
       01 WS-MI-COUNT                PIC 9(2).
       01 WS-MERGED-BAL              PIC S9(11)V99 COMP-3.
       01 WS-MERGE-STATUS            PIC X(1).
           88 WS-MERGE-OK            VALUE 'Y'.
           88 WS-MERGE-FAIL          VALUE 'N'.
       01 WS-ERROR-MSG               PIC X(40).
       01 WS-AUDIT-MSG               PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-VALIDATE-MERGE
           IF WS-MERGE-OK
               PERFORM 3000-CONSOLIDATE-BALANCES
               PERFORM 4000-BUILD-AUDIT
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-MERGED-BAL
           MOVE 0 TO WS-MI-COUNT
           SET WS-MERGE-FAIL TO TRUE
           MOVE SPACES TO WS-ERROR-MSG.
       2000-VALIDATE-MERGE.
           IF WS-SRC-NUM = WS-TGT-NUM
               MOVE 'CANNOT MERGE SAME ACCOUNT'
                   TO WS-ERROR-MSG
           ELSE
               IF WS-SRC-TYPE NOT = WS-TGT-TYPE
                   MOVE 'ACCOUNT TYPES MUST MATCH'
                       TO WS-ERROR-MSG
               ELSE
                   SET WS-MERGE-OK TO TRUE
               END-IF
           END-IF.
       3000-CONSOLIDATE-BALANCES.
           ADD WS-SRC-BALANCE TO WS-TGT-BALANCE
               GIVING WS-MERGED-BAL
           PERFORM VARYING WS-MI-IDX FROM 1 BY 1
               UNTIL WS-MI-IDX > WS-SRC-PRODUCTS
               OR WS-MI-IDX > 10
               MOVE 'TRANSFERRED' TO
                   WS-MI-TYPE(WS-MI-IDX)
               MOVE WS-MI-BALANCE(WS-MI-IDX) TO
                   WS-MI-BALANCE(WS-MI-IDX)
               MOVE 'M' TO WS-MI-STATUS(WS-MI-IDX)
               ADD 1 TO WS-MI-COUNT
               ADD WS-MI-BALANCE(WS-MI-IDX) TO
                   WS-MERGED-BAL
           END-PERFORM.
       4000-BUILD-AUDIT.
           STRING 'MERGE ' DELIMITED BY SIZE
                  WS-SRC-NUM DELIMITED BY SIZE
                  ' INTO ' DELIMITED BY SIZE
                  WS-TGT-NUM DELIMITED BY SIZE
                  ' BAL=' DELIMITED BY SIZE
                  WS-MERGED-BAL DELIMITED BY SIZE
                  INTO WS-AUDIT-MSG
           END-STRING.
       5000-DISPLAY-RESULTS.
           DISPLAY 'ACCOUNT MERGE HANDLER'
           DISPLAY '====================='
           DISPLAY 'SOURCE:       ' WS-SRC-NUM
           DISPLAY 'SOURCE BAL:   ' WS-SRC-BALANCE
           DISPLAY 'TARGET:       ' WS-TGT-NUM
           DISPLAY 'TARGET BAL:   ' WS-TGT-BALANCE
           IF WS-MERGE-OK
               DISPLAY 'STATUS: MERGED'
               DISPLAY 'MERGED BAL:   ' WS-MERGED-BAL
               DISPLAY 'ITEMS MOVED:  ' WS-MI-COUNT
               DISPLAY 'AUDIT: ' WS-AUDIT-MSG
           ELSE
               DISPLAY 'STATUS: FAILED'
               DISPLAY 'ERROR: ' WS-ERROR-MSG
           END-IF.
