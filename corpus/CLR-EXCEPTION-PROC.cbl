       IDENTIFICATION DIVISION.
       PROGRAM-ID. CLR-EXCEPTION-PROC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ITEM-DATA.
           05 WS-ITEM-NUM            PIC X(15).
           05 WS-ITEM-AMOUNT         PIC S9(9)V99 COMP-3.
           05 WS-ITEM-TYPE           PIC X(2).
       01 WS-EXCEPTION-CODE          PIC X(2).
           88 WS-NSF                 VALUE 'NF'.
           88 WS-STALE-DATE          VALUE 'SD'.
           88 WS-ENCODING-ERR        VALUE 'EE'.
           88 WS-STOP-PAY            VALUE 'SP'.
       01 WS-ACTION                  PIC X(1).
           88 WS-RETURN              VALUE 'R'.
           88 WS-REPRESENT           VALUE 'P'.
           88 WS-MANUAL              VALUE 'M'.
       01 WS-FEE                     PIC S9(5)V99 COMP-3.
       01 WS-ALERT-MSG               PIC X(60).
       01 WS-TOTAL-EXCEPTIONS        PIC S9(5) COMP-3.
       01 WS-TOTAL-RETURNED          PIC S9(5) COMP-3.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CLASSIFY
           PERFORM 3000-DETERMINE-ACTION
           PERFORM 4000-BUILD-ALERT
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-FEE
           MOVE 0 TO WS-TOTAL-EXCEPTIONS
           MOVE 0 TO WS-TOTAL-RETURNED.
       2000-CLASSIFY.
           ADD 1 TO WS-TOTAL-EXCEPTIONS
           EVALUATE TRUE
               WHEN WS-NSF
                   MOVE 36.00 TO WS-FEE
               WHEN WS-STALE-DATE
                   MOVE 0 TO WS-FEE
               WHEN WS-ENCODING-ERR
                   MOVE 0 TO WS-FEE
               WHEN WS-STOP-PAY
                   MOVE 35.00 TO WS-FEE
               WHEN OTHER
                   MOVE 25.00 TO WS-FEE
           END-EVALUATE.
       3000-DETERMINE-ACTION.
           EVALUATE TRUE
               WHEN WS-NSF
                   SET WS-RETURN TO TRUE
                   ADD 1 TO WS-TOTAL-RETURNED
               WHEN WS-STOP-PAY
                   SET WS-RETURN TO TRUE
                   ADD 1 TO WS-TOTAL-RETURNED
               WHEN WS-STALE-DATE
                   SET WS-RETURN TO TRUE
                   ADD 1 TO WS-TOTAL-RETURNED
               WHEN WS-ENCODING-ERR
                   SET WS-REPRESENT TO TRUE
               WHEN OTHER
                   SET WS-MANUAL TO TRUE
           END-EVALUATE.
       4000-BUILD-ALERT.
           STRING 'EXCEPTION ' DELIMITED BY SIZE
                  WS-ITEM-NUM DELIMITED BY SIZE
                  ' CODE=' DELIMITED BY SIZE
                  WS-EXCEPTION-CODE DELIMITED BY SIZE
                  ' AMT=' DELIMITED BY SIZE
                  WS-ITEM-AMOUNT DELIMITED BY SIZE
                  INTO WS-ALERT-MSG
           END-STRING.
       5000-DISPLAY-RESULTS.
           DISPLAY 'CLEARING EXCEPTION'
           DISPLAY '=================='
           DISPLAY 'ITEM:      ' WS-ITEM-NUM
           DISPLAY 'AMOUNT:    ' WS-ITEM-AMOUNT
           DISPLAY 'EXCEPTION: ' WS-EXCEPTION-CODE
           DISPLAY 'FEE:       ' WS-FEE
           IF WS-RETURN
               DISPLAY 'ACTION: RETURN'
           END-IF
           IF WS-REPRESENT
               DISPLAY 'ACTION: RE-PRESENT'
           END-IF
           IF WS-MANUAL
               DISPLAY 'ACTION: MANUAL REVIEW'
           END-IF
           DISPLAY WS-ALERT-MSG.
