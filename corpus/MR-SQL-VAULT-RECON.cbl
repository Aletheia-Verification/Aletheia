       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-SQL-VAULT-RECON.
      *================================================================*
      * Vault Reconciliation via Embedded SQL                          *
      * Reads vault movement records from DB2, computes book vs        *
      * physical balance, identifies discrepancies by denomination.    *
      * INTENTIONAL: Uses EXEC SQL to trigger MANUAL REVIEW.           *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
      *--- SQL Host Variables ---
       01  WS-SQLCODE                PIC S9(9) COMP-3.
       01  WS-H-BRANCH-ID           PIC X(6).
       01  WS-H-RECON-DATE          PIC X(10).
       01  WS-H-DENOM               PIC 9(5).
       01  WS-H-MOVEMENT-TYPE       PIC X(3).
       01  WS-H-QUANTITY            PIC S9(7) COMP-3.
       01  WS-H-AMOUNT              PIC S9(9)V99 COMP-3.
      *--- Book Balance ---
       01  WS-BOOK-TABLE.
           05  WS-BOOK-ENTRY OCCURS 7 TIMES.
               10  WS-BK-DENOM       PIC 9(5).
               10  WS-BK-IN-QTY      PIC S9(7) COMP-3.
               10  WS-BK-OUT-QTY     PIC S9(7) COMP-3.
               10  WS-BK-NET-QTY     PIC S9(7) COMP-3.
               10  WS-BK-VALUE       PIC S9(11)V99 COMP-3.
       01  WS-BK-IDX                PIC 9(3).
      *--- Physical Count ---
       01  WS-PHYS-TABLE.
           05  WS-PHYS-ENTRY OCCURS 7 TIMES.
               10  WS-PH-DENOM       PIC 9(5).
               10  WS-PH-COUNT       PIC S9(7) COMP-3.
               10  WS-PH-VALUE       PIC S9(11)V99 COMP-3.
       01  WS-PH-IDX                PIC 9(3).
      *--- Variance ---
       01  WS-VAR-TABLE.
           05  WS-VAR-ENTRY OCCURS 7 TIMES.
               10  WS-VR-DENOM       PIC 9(5).
               10  WS-VR-QTY-DIFF    PIC S9(7) COMP-3.
               10  WS-VR-VALUE-DIFF  PIC S9(9)V99 COMP-3.
       01  WS-VR-IDX                PIC 9(3).
      *--- Totals ---
       01  WS-TOTAL-BOOK-VAL        PIC S9(13)V99 COMP-3.
       01  WS-TOTAL-PHYS-VAL        PIC S9(13)V99 COMP-3.
       01  WS-TOTAL-VARIANCE        PIC S9(11)V99 COMP-3.
       01  WS-VARIANCE-CT           PIC S9(3) COMP-3.
      *--- EOF ---
       01  WS-EOF-FLAG              PIC X VALUE 'N'.
           88  WS-AT-EOF            VALUE 'Y'.
      *--- Display ---
       01  WS-DISP-AMT              PIC -$$$,$$$,$$$,$$9.99.
       01  WS-DISP-QTY              PIC -ZZZ,ZZ9.
       01  WS-DISP-CT               PIC ZZ9.
      *--- Tally ---
       01  WS-DENOM-TALLY           PIC S9(3) COMP-3.

       PROCEDURE DIVISION.

       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-LOAD-PHYSICAL
           PERFORM 3000-OPEN-MOVEMENT-CURSOR
           IF WS-SQLCODE = 0
               PERFORM 4000-FETCH-MOVEMENTS
                   UNTIL WS-AT-EOF
               PERFORM 4500-CLOSE-CURSOR
           END-IF
           PERFORM 5000-COMPUTE-VARIANCES
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.

       1000-INITIALIZE.
           MOVE "BR0042" TO WS-H-BRANCH-ID
           MOVE "2026-03-21" TO WS-H-RECON-DATE
           MOVE 0 TO WS-TOTAL-BOOK-VAL
           MOVE 0 TO WS-TOTAL-PHYS-VAL
           MOVE 0 TO WS-VARIANCE-CT
           MOVE 'N' TO WS-EOF-FLAG
           INITIALIZE WS-BOOK-TABLE
           MOVE 100 TO WS-BK-DENOM(1)
           MOVE 50  TO WS-BK-DENOM(2)
           MOVE 20  TO WS-BK-DENOM(3)
           MOVE 10  TO WS-BK-DENOM(4)
           MOVE 5   TO WS-BK-DENOM(5)
           MOVE 2   TO WS-BK-DENOM(6)
           MOVE 1   TO WS-BK-DENOM(7).

       2000-LOAD-PHYSICAL.
           MOVE 100 TO WS-PH-DENOM(1)
           MOVE 4523 TO WS-PH-COUNT(1)
           MOVE 50  TO WS-PH-DENOM(2)
           MOVE 2247 TO WS-PH-COUNT(2)
           MOVE 20  TO WS-PH-DENOM(3)
           MOVE 5065 TO WS-PH-COUNT(3)
           MOVE 10  TO WS-PH-DENOM(4)
           MOVE 1530 TO WS-PH-COUNT(4)
           MOVE 5   TO WS-PH-DENOM(5)
           MOVE 815 TO WS-PH-COUNT(5)
           MOVE 2   TO WS-PH-DENOM(6)
           MOVE 245 TO WS-PH-COUNT(6)
           MOVE 1   TO WS-PH-DENOM(7)
           MOVE 150 TO WS-PH-COUNT(7)
           PERFORM VARYING WS-PH-IDX FROM 1 BY 1
               UNTIL WS-PH-IDX > 7
               COMPUTE WS-PH-VALUE(WS-PH-IDX) =
                   WS-PH-DENOM(WS-PH-IDX)
                   * WS-PH-COUNT(WS-PH-IDX)
               ADD WS-PH-VALUE(WS-PH-IDX)
                   TO WS-TOTAL-PHYS-VAL
           END-PERFORM.

       3000-OPEN-MOVEMENT-CURSOR.
           EXEC SQL
               DECLARE VAULT_MOVE_CUR CURSOR FOR
               SELECT DENOMINATION, MOVEMENT_TYPE,
                      QUANTITY, AMOUNT
               FROM VAULT_MOVEMENTS
               WHERE BRANCH_ID = :WS-H-BRANCH-ID
                 AND MOVEMENT_DATE = :WS-H-RECON-DATE
               ORDER BY DENOMINATION DESC
           END-EXEC
           MOVE 0 TO WS-SQLCODE
           EXEC SQL
               OPEN VAULT_MOVE_CUR
           END-EXEC.

       4000-FETCH-MOVEMENTS.
           EXEC SQL
               FETCH VAULT_MOVE_CUR
               INTO :WS-H-DENOM, :WS-H-MOVEMENT-TYPE,
                    :WS-H-QUANTITY, :WS-H-AMOUNT
           END-EXEC
           IF WS-SQLCODE NOT = 0
               MOVE 'Y' TO WS-EOF-FLAG
           ELSE
               PERFORM 4100-UPDATE-BOOK
           END-IF.

       4100-UPDATE-BOOK.
           PERFORM VARYING WS-BK-IDX FROM 1 BY 1
               UNTIL WS-BK-IDX > 7
               IF WS-BK-DENOM(WS-BK-IDX) = WS-H-DENOM
                   IF WS-H-MOVEMENT-TYPE = "IN "
                       ADD WS-H-QUANTITY
                           TO WS-BK-IN-QTY(WS-BK-IDX)
                   ELSE
                       ADD WS-H-QUANTITY
                           TO WS-BK-OUT-QTY(WS-BK-IDX)
                   END-IF
               END-IF
           END-PERFORM.

       4500-CLOSE-CURSOR.
           EXEC SQL
               CLOSE VAULT_MOVE_CUR
           END-EXEC.

       5000-COMPUTE-VARIANCES.
           PERFORM VARYING WS-BK-IDX FROM 1 BY 1
               UNTIL WS-BK-IDX > 7
               COMPUTE WS-BK-NET-QTY(WS-BK-IDX) =
                   WS-BK-IN-QTY(WS-BK-IDX)
                   - WS-BK-OUT-QTY(WS-BK-IDX)
               COMPUTE WS-BK-VALUE(WS-BK-IDX) =
                   WS-BK-NET-QTY(WS-BK-IDX)
                   * WS-BK-DENOM(WS-BK-IDX)
               ADD WS-BK-VALUE(WS-BK-IDX)
                   TO WS-TOTAL-BOOK-VAL
               MOVE WS-BK-DENOM(WS-BK-IDX)
                   TO WS-VR-DENOM(WS-BK-IDX)
               COMPUTE WS-VR-QTY-DIFF(WS-BK-IDX) =
                   WS-PH-COUNT(WS-BK-IDX)
                   - WS-BK-NET-QTY(WS-BK-IDX)
               COMPUTE WS-VR-VALUE-DIFF(WS-BK-IDX) =
                   WS-VR-QTY-DIFF(WS-BK-IDX)
                   * WS-VR-DENOM(WS-BK-IDX)
               IF WS-VR-QTY-DIFF(WS-BK-IDX) NOT = 0
                   ADD 1 TO WS-VARIANCE-CT
               END-IF
           END-PERFORM
           COMPUTE WS-TOTAL-VARIANCE =
               WS-TOTAL-PHYS-VAL - WS-TOTAL-BOOK-VAL.

       6000-DISPLAY-REPORT.
           DISPLAY "========================================"
           DISPLAY "   VAULT RECON (SQL)"
           DISPLAY "========================================"
           DISPLAY "BRANCH: " WS-H-BRANCH-ID
           DISPLAY "DATE:   " WS-H-RECON-DATE
           PERFORM VARYING WS-BK-IDX FROM 1 BY 1
               UNTIL WS-BK-IDX > 7
               MOVE 0 TO WS-DENOM-TALLY
               INSPECT WS-H-BRANCH-ID
                   TALLYING WS-DENOM-TALLY FOR ALL "0"
               MOVE WS-VR-QTY-DIFF(WS-BK-IDX)
                   TO WS-DISP-QTY
               DISPLAY "$" WS-BK-DENOM(WS-BK-IDX)
                   " DIFF: " WS-DISP-QTY
           END-PERFORM
           MOVE WS-TOTAL-PHYS-VAL TO WS-DISP-AMT
           DISPLAY "PHYSICAL:  " WS-DISP-AMT
           MOVE WS-TOTAL-BOOK-VAL TO WS-DISP-AMT
           DISPLAY "BOOK:      " WS-DISP-AMT
           MOVE WS-TOTAL-VARIANCE TO WS-DISP-AMT
           DISPLAY "VARIANCE:  " WS-DISP-AMT
           MOVE WS-VARIANCE-CT TO WS-DISP-CT
           DISPLAY "DENOM DIFF:" WS-DISP-CT
           DISPLAY "========================================".
