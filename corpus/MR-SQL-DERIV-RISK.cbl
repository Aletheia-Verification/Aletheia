       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-DERIV-RISK.
      *================================================================*
      * MANUAL REVIEW: Derivatives Risk Aggregation with EXEC SQL       *
      * Embedded SQL for counterparty exposure aggregation, netting     *
      * set computation, and risk reporting — triggers MANUAL REVIEW.  *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-CPTY-ID             PIC X(10).
       01  WS-CPTY-NAME           PIC X(30).
       01  WS-TRADE-ID            PIC X(12).
       01  WS-PRODUCT-TYPE        PIC X(04).
       01  WS-NOTIONAL            PIC S9(15)V99 COMP-3.
       01  WS-MTM-VALUE           PIC S9(13)V99 COMP-3.
       01  WS-COLLATERAL          PIC S9(13)V99 COMP-3.
       01  WS-NETTING-SET         PIC X(08).
       01  WS-GROSS-POSITIVE      PIC S9(15)V99 VALUE 0.
       01  WS-GROSS-NEGATIVE      PIC S9(15)V99 VALUE 0.
       01  WS-NET-EXPOSURE        PIC S9(15)V99.
       01  WS-COLL-NET-EXP        PIC S9(15)V99.
       01  WS-TOTAL-GROSS-POS     PIC S9(17)V99 VALUE 0.
       01  WS-TOTAL-NET-EXP      PIC S9(17)V99 VALUE 0.
       01  WS-CPTY-CNT            PIC 9(06) VALUE 0.
       01  WS-TRADE-CNT           PIC 9(08) VALUE 0.
       01  WS-BREACH-CNT          PIC 9(04) VALUE 0.
       01  WS-THRESHOLD           PIC S9(13)V99
                                  VALUE 50000000.00.
       01  WS-PFE-MULTIPLIER      PIC 9V9(04) VALUE 1.4000.
       01  WS-PFE                 PIC S9(15)V99.
       01  WS-EAD                 PIC S9(15)V99.
       01  WS-SQLCODE             PIC S9(09) COMP.
       01  WS-PREV-CPTY           PIC X(10) VALUE SPACES.
       01  WS-MSG                 PIC X(80) VALUE SPACES.
           EXEC SQL INCLUDE SQLCA END-EXEC.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-OPEN-CPTY-CURSOR
           PERFORM 3000-PROCESS-COUNTERPARTIES
           PERFORM 9000-FINALIZE
           STOP RUN.
       1000-INITIALIZE.
           EXEC SQL
               CONNECT TO RISK_DB
               USER 'RISKBATCH'
               USING 'RISKBATCH_PWD'
           END-EXEC
           IF SQLCODE NOT = 0
               DISPLAY 'DB CONNECT ERROR: ' SQLCODE
               STOP RUN
           END-IF.
       2000-OPEN-CPTY-CURSOR.
           EXEC SQL
               DECLARE CPTY_CURSOR CURSOR FOR
               SELECT DISTINCT C.CPTY_ID, C.CPTY_NAME
               FROM COUNTERPARTIES C
               INNER JOIN DERIVATIVE_TRADES T
                   ON C.CPTY_ID = T.CPTY_ID
               WHERE T.STATUS = 'ACTIVE'
               ORDER BY C.CPTY_ID
           END-EXEC
           EXEC SQL OPEN CPTY_CURSOR END-EXEC.
       3000-PROCESS-COUNTERPARTIES.
           PERFORM 3100-FETCH-CPTY
           PERFORM UNTIL SQLCODE NOT = 0
               ADD 1 TO WS-CPTY-CNT
               MOVE ZERO TO WS-GROSS-POSITIVE
               MOVE ZERO TO WS-GROSS-NEGATIVE
               MOVE ZERO TO WS-COLLATERAL
               PERFORM 4000-AGGREGATE-TRADES
               PERFORM 5000-CALC-NET-EXPOSURE
               PERFORM 6000-CALC-PFE
               PERFORM 7000-CHECK-THRESHOLD
               PERFORM 3100-FETCH-CPTY
           END-PERFORM
           EXEC SQL CLOSE CPTY_CURSOR END-EXEC.
       3100-FETCH-CPTY.
           EXEC SQL
               FETCH CPTY_CURSOR
               INTO :WS-CPTY-ID, :WS-CPTY-NAME
           END-EXEC.
       4000-AGGREGATE-TRADES.
           EXEC SQL
               SELECT SUM(CASE WHEN MTM_VALUE > 0
                         THEN MTM_VALUE ELSE 0 END),
                      SUM(CASE WHEN MTM_VALUE < 0
                         THEN MTM_VALUE ELSE 0 END),
                      SUM(COLLATERAL_VALUE),
                      COUNT(*)
               INTO :WS-GROSS-POSITIVE,
                    :WS-GROSS-NEGATIVE,
                    :WS-COLLATERAL,
                    :WS-TRADE-CNT
               FROM DERIVATIVE_TRADES
               WHERE CPTY_ID = :WS-CPTY-ID
               AND STATUS = 'ACTIVE'
           END-EXEC
           ADD WS-GROSS-POSITIVE TO WS-TOTAL-GROSS-POS.
       5000-CALC-NET-EXPOSURE.
           COMPUTE WS-NET-EXPOSURE =
               WS-GROSS-POSITIVE + WS-GROSS-NEGATIVE
           IF WS-NET-EXPOSURE < ZERO
               MOVE ZERO TO WS-NET-EXPOSURE
           END-IF
           COMPUTE WS-COLL-NET-EXP =
               WS-NET-EXPOSURE - WS-COLLATERAL
           IF WS-COLL-NET-EXP < ZERO
               MOVE ZERO TO WS-COLL-NET-EXP
           END-IF
           ADD WS-COLL-NET-EXP TO WS-TOTAL-NET-EXP.
       6000-CALC-PFE.
           COMPUTE WS-PFE ROUNDED =
               WS-NET-EXPOSURE * WS-PFE-MULTIPLIER
           COMPUTE WS-EAD =
               WS-COLL-NET-EXP + WS-PFE.
       7000-CHECK-THRESHOLD.
           IF WS-COLL-NET-EXP > WS-THRESHOLD
               ADD 1 TO WS-BREACH-CNT
               EXEC SQL
                   INSERT INTO RISK_ALERTS
                   (CPTY_ID, ALERT_TYPE, EXPOSURE,
                    THRESHOLD, ALERT_DATE)
                   VALUES (:WS-CPTY-ID, 'EXPOSURE',
                           :WS-COLL-NET-EXP,
                           :WS-THRESHOLD,
                           CURRENT DATE)
               END-EXEC
               MOVE SPACES TO WS-MSG
               STRING 'BREACH: '
                   DELIMITED BY SIZE
                   WS-CPTY-NAME
                   DELIMITED BY SIZE
                   ' EXP='
                   DELIMITED BY SIZE
                   INTO WS-MSG
               DISPLAY WS-MSG WS-COLL-NET-EXP
           END-IF.
       9000-FINALIZE.
           EXEC SQL COMMIT END-EXEC
           EXEC SQL DISCONNECT END-EXEC
           DISPLAY 'DERIVATIVES RISK AGGREGATION COMPLETE'
           DISPLAY 'COUNTERPARTIES:  ' WS-CPTY-CNT
           DISPLAY 'GROSS POSITIVE:  ' WS-TOTAL-GROSS-POS
           DISPLAY 'NET EXPOSURE:    ' WS-TOTAL-NET-EXP
           DISPLAY 'THRESHOLD BREACH:' WS-BREACH-CNT.
