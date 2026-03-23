       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ODO-CLAIM-BATCH.
      *================================================================
      * MANUAL REVIEW: OCCURS DEPENDING ON
      * Variable-length claims batch with ODO for flexible record
      * counts. Triggers MANUAL REVIEW due to ODO construct.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BATCH-HEADER.
           05 WS-BATCH-ID             PIC X(10).
           05 WS-BATCH-DATE           PIC 9(8).
           05 WS-CLAIM-COUNT          PIC 9(3).
       01 WS-CLAIM-TABLE.
           05 WS-CLAIM-ENTRY OCCURS 1 TO 200 TIMES
               DEPENDING ON WS-CLAIM-COUNT.
               10 WS-CE-CLAIM-ID      PIC X(15).
               10 WS-CE-AMOUNT        PIC S9(9)V99 COMP-3.
               10 WS-CE-TYPE          PIC X(3).
                   88 CE-MEDICAL       VALUE 'MED'.
                   88 CE-DENTAL        VALUE 'DEN'.
                   88 CE-VISION        VALUE 'VIS'.
               10 WS-CE-STATUS        PIC X(1).
                   88 CE-APPROVED      VALUE 'A'.
                   88 CE-DENIED        VALUE 'D'.
                   88 CE-PENDING       VALUE 'P'.
       01 WS-IDX                      PIC 9(3).
       01 WS-TOTALS.
           05 WS-TOTAL-APPROVED       PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOTAL-DENIED         PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-TOTAL-PENDING        PIC S9(11)V99 COMP-3
               VALUE 0.
           05 WS-APPROVED-COUNT       PIC 9(5) VALUE 0.
           05 WS-DENIED-COUNT         PIC 9(5) VALUE 0.
           05 WS-PENDING-COUNT        PIC 9(5) VALUE 0.
       01 WS-MAX-SINGLE-CLAIM         PIC S9(9)V99 COMP-3
           VALUE 100000.00.
       01 WS-AUTO-DENY-FLAG           PIC X VALUE 'N'.
           88 WS-AUTO-DENY            VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           IF WS-CLAIM-COUNT > 0
               PERFORM 2000-PROCESS-CLAIMS
               PERFORM 3000-SUMMARIZE
           END-IF
           PERFORM 4000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'BATCH-C-099' TO WS-BATCH-ID
           ACCEPT WS-BATCH-DATE FROM DATE YYYYMMDD
           MOVE 5 TO WS-CLAIM-COUNT
           MOVE 'CLM-2026-00001' TO WS-CE-CLAIM-ID(1)
           MOVE 15000.00 TO WS-CE-AMOUNT(1)
           MOVE 'MED' TO WS-CE-TYPE(1)
           MOVE 'P' TO WS-CE-STATUS(1)
           MOVE 'CLM-2026-00002' TO WS-CE-CLAIM-ID(2)
           MOVE 3500.00 TO WS-CE-AMOUNT(2)
           MOVE 'DEN' TO WS-CE-TYPE(2)
           MOVE 'P' TO WS-CE-STATUS(2)
           MOVE 'CLM-2026-00003' TO WS-CE-CLAIM-ID(3)
           MOVE 250000.00 TO WS-CE-AMOUNT(3)
           MOVE 'MED' TO WS-CE-TYPE(3)
           MOVE 'P' TO WS-CE-STATUS(3)
           MOVE 'CLM-2026-00004' TO WS-CE-CLAIM-ID(4)
           MOVE 750.00 TO WS-CE-AMOUNT(4)
           MOVE 'VIS' TO WS-CE-TYPE(4)
           MOVE 'P' TO WS-CE-STATUS(4)
           MOVE 'CLM-2026-00005' TO WS-CE-CLAIM-ID(5)
           MOVE 42000.00 TO WS-CE-AMOUNT(5)
           MOVE 'MED' TO WS-CE-TYPE(5)
           MOVE 'P' TO WS-CE-STATUS(5).
       2000-PROCESS-CLAIMS.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-CLAIM-COUNT
               MOVE 'N' TO WS-AUTO-DENY-FLAG
               IF WS-CE-AMOUNT(WS-IDX) >
                   WS-MAX-SINGLE-CLAIM
                   MOVE 'Y' TO WS-AUTO-DENY-FLAG
               END-IF
               IF WS-AUTO-DENY
                   MOVE 'D' TO WS-CE-STATUS(WS-IDX)
               ELSE
                   EVALUATE TRUE
                       WHEN CE-MEDICAL(WS-IDX)
                           IF WS-CE-AMOUNT(WS-IDX) <= 50000
                               MOVE 'A'
                                   TO WS-CE-STATUS(WS-IDX)
                           ELSE
                               MOVE 'P'
                                   TO WS-CE-STATUS(WS-IDX)
                           END-IF
                       WHEN CE-DENTAL(WS-IDX)
                           IF WS-CE-AMOUNT(WS-IDX) <= 5000
                               MOVE 'A'
                                   TO WS-CE-STATUS(WS-IDX)
                           ELSE
                               MOVE 'P'
                                   TO WS-CE-STATUS(WS-IDX)
                           END-IF
                       WHEN CE-VISION(WS-IDX)
                           IF WS-CE-AMOUNT(WS-IDX) <= 1000
                               MOVE 'A'
                                   TO WS-CE-STATUS(WS-IDX)
                           ELSE
                               MOVE 'P'
                                   TO WS-CE-STATUS(WS-IDX)
                           END-IF
                       WHEN OTHER
                           MOVE 'P' TO WS-CE-STATUS(WS-IDX)
                   END-EVALUATE
               END-IF
           END-PERFORM.
       3000-SUMMARIZE.
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-CLAIM-COUNT
               EVALUATE TRUE
                   WHEN CE-APPROVED(WS-IDX)
                       ADD WS-CE-AMOUNT(WS-IDX)
                           TO WS-TOTAL-APPROVED
                       ADD 1 TO WS-APPROVED-COUNT
                   WHEN CE-DENIED(WS-IDX)
                       ADD WS-CE-AMOUNT(WS-IDX)
                           TO WS-TOTAL-DENIED
                       ADD 1 TO WS-DENIED-COUNT
                   WHEN CE-PENDING(WS-IDX)
                       ADD WS-CE-AMOUNT(WS-IDX)
                           TO WS-TOTAL-PENDING
                       ADD 1 TO WS-PENDING-COUNT
               END-EVALUATE
           END-PERFORM.
       4000-DISPLAY-REPORT.
           DISPLAY 'ODO CLAIMS BATCH REPORT'
           DISPLAY '======================='
           DISPLAY 'BATCH ID:        ' WS-BATCH-ID
           DISPLAY 'BATCH DATE:      ' WS-BATCH-DATE
           DISPLAY 'CLAIMS COUNT:    ' WS-CLAIM-COUNT
           DISPLAY 'APPROVED:        ' WS-APPROVED-COUNT
           DISPLAY 'APPROVED AMT:    ' WS-TOTAL-APPROVED
           DISPLAY 'DENIED:          ' WS-DENIED-COUNT
           DISPLAY 'DENIED AMT:      ' WS-TOTAL-DENIED
           DISPLAY 'PENDING:         ' WS-PENDING-COUNT
           DISPLAY 'PENDING AMT:     ' WS-TOTAL-PENDING.
