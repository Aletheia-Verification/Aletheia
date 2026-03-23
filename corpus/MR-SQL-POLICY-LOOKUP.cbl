       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-POLICY-LOOKUP.
      *================================================================
      * MANUAL REVIEW: EXEC SQL
      * Embedded SQL for policy lookup, coverage verification, and
      * premium history retrieval from DB2 tables.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-POLICY-NUM               PIC X(12).
       01 WS-POLICY-DATA.
           05 WS-PD-HOLDER-NAME       PIC X(40).
           05 WS-PD-FACE-AMT          PIC S9(9)V99 COMP-3.
           05 WS-PD-PREMIUM           PIC S9(7)V99 COMP-3.
           05 WS-PD-STATUS            PIC X(1).
               88 PD-ACTIVE           VALUE 'A'.
               88 PD-LAPSED           VALUE 'L'.
               88 PD-CANCELLED        VALUE 'C'.
           05 WS-PD-EFF-DATE          PIC X(10).
           05 WS-PD-EXP-DATE          PIC X(10).
           05 WS-PD-AGENT-CODE        PIC X(6).
       01 WS-PREMIUM-HIST.
           05 WS-PH-ENTRY OCCURS 12 TIMES.
               10 WS-PH-MONTH         PIC 9(2).
               10 WS-PH-AMOUNT        PIC S9(7)V99 COMP-3.
               10 WS-PH-PAID-FLAG     PIC X(1).
                   88 PH-PAID         VALUE 'Y'.
                   88 PH-UNPAID       VALUE 'N'.
       01 WS-IDX                      PIC 9(2).
       01 WS-TOTAL-PAID               PIC S9(9)V99 COMP-3
           VALUE 0.
       01 WS-TOTAL-UNPAID             PIC S9(9)V99 COMP-3
           VALUE 0.
       01 WS-MONTHS-PAID              PIC 9(2) VALUE 0.
       01 WS-MONTHS-UNPAID            PIC 9(2) VALUE 0.
           EXEC SQL INCLUDE SQLCA END-EXEC.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-FETCH-POLICY
           IF PD-ACTIVE
               PERFORM 3000-FETCH-PREMIUM-HIST
               PERFORM 4000-TALLY-PAYMENTS
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'POL-SQL-0042' TO WS-POLICY-NUM
           INITIALIZE WS-POLICY-DATA
           INITIALIZE WS-PREMIUM-HIST.
       2000-FETCH-POLICY.
           EXEC SQL
               SELECT HOLDER_NAME,
                      FACE_AMOUNT,
                      ANNUAL_PREMIUM,
                      STATUS,
                      EFF_DATE,
                      EXP_DATE,
                      AGENT_CODE
               INTO :WS-PD-HOLDER-NAME,
                    :WS-PD-FACE-AMT,
                    :WS-PD-PREMIUM,
                    :WS-PD-STATUS,
                    :WS-PD-EFF-DATE,
                    :WS-PD-EXP-DATE,
                    :WS-PD-AGENT-CODE
               FROM POLICY_MASTER
               WHERE POLICY_NUMBER = :WS-POLICY-NUM
           END-EXEC
           IF PD-ACTIVE
               DISPLAY 'POLICY FOUND - ACTIVE'
           ELSE
               DISPLAY 'POLICY NOT ACTIVE'
           END-IF.
       3000-FETCH-PREMIUM-HIST.
           EXEC SQL
               DECLARE PREM_CURSOR CURSOR FOR
               SELECT PAYMENT_MONTH,
                      PAYMENT_AMOUNT,
                      PAID_FLAG
               FROM PREMIUM_HISTORY
               WHERE POLICY_NUMBER = :WS-POLICY-NUM
               ORDER BY PAYMENT_MONTH
           END-EXEC
           EXEC SQL OPEN PREM_CURSOR END-EXEC
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 12
               EXEC SQL
                   FETCH PREM_CURSOR
                   INTO :WS-PH-MONTH(WS-IDX),
                        :WS-PH-AMOUNT(WS-IDX),
                        :WS-PH-PAID-FLAG(WS-IDX)
               END-EXEC
           END-PERFORM
           EXEC SQL CLOSE PREM_CURSOR END-EXEC.
       4000-TALLY-PAYMENTS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 12
               IF PH-PAID(WS-IDX)
                   ADD WS-PH-AMOUNT(WS-IDX)
                       TO WS-TOTAL-PAID
                   ADD 1 TO WS-MONTHS-PAID
               ELSE
                   ADD WS-PH-AMOUNT(WS-IDX)
                       TO WS-TOTAL-UNPAID
                   ADD 1 TO WS-MONTHS-UNPAID
               END-IF
           END-PERFORM.
       5000-DISPLAY-RESULTS.
           DISPLAY 'POLICY LOOKUP RESULTS (SQL)'
           DISPLAY '==========================='
           DISPLAY 'POLICY:      ' WS-POLICY-NUM
           DISPLAY 'HOLDER:      ' WS-PD-HOLDER-NAME
           DISPLAY 'FACE AMT:    ' WS-PD-FACE-AMT
           DISPLAY 'PREMIUM:     ' WS-PD-PREMIUM
           DISPLAY 'STATUS:      ' WS-PD-STATUS
           DISPLAY 'EFF DATE:    ' WS-PD-EFF-DATE
           DISPLAY 'EXP DATE:    ' WS-PD-EXP-DATE
           IF PD-ACTIVE
               DISPLAY 'MONTHS PAID: ' WS-MONTHS-PAID
               DISPLAY 'TOTAL PAID:  ' WS-TOTAL-PAID
               DISPLAY 'MONTHS DUE:  ' WS-MONTHS-UNPAID
               DISPLAY 'TOTAL DUE:   ' WS-TOTAL-UNPAID
           END-IF.
