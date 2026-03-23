       IDENTIFICATION DIVISION.
       PROGRAM-ID. DODD-FRANK-SWAP.
      *================================================================
      * Dodd-Frank Title VII Swap Data Reporting
      * Processes OTC derivatives for SDR (Swap Data Repository)
      * reporting, calculates margin and clearing eligibility.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-COUNTERPARTY.
           05 WS-CP-LEI               PIC X(20).
           05 WS-CP-NAME              PIC X(30).
           05 WS-CP-TYPE              PIC X(1).
               88 WS-SWAP-DEALER      VALUE 'D'.
               88 WS-MAJOR-PART       VALUE 'M'.
               88 WS-END-USER         VALUE 'E'.
           05 WS-CP-CLEARING-EXEMPT   PIC X(1).
               88 WS-IS-EXEMPT        VALUE 'Y'.
       01 WS-SWAP-DATA.
           05 WS-SWAP-USI             PIC X(20).
           05 WS-SWAP-TYPE            PIC X(2).
               88 WS-IRS              VALUE 'IR'.
               88 WS-CDS              VALUE 'CD'.
               88 WS-FX-SWAP          VALUE 'FX'.
               88 WS-EQUITY-SWAP      VALUE 'EQ'.
           05 WS-NOTIONAL             PIC S9(15)V99 COMP-3.
           05 WS-FIXED-RATE           PIC S9(2)V9(6) COMP-3.
           05 WS-FLOATING-SPREAD      PIC S9(2)V9(6) COMP-3.
           05 WS-MATURITY-DATE        PIC 9(8).
           05 WS-EFFECTIVE-DATE       PIC 9(8).
           05 WS-MTM-VALUE            PIC S9(13)V99 COMP-3.
       01 WS-MARGIN-FIELDS.
           05 WS-INITIAL-MARGIN       PIC S9(13)V99 COMP-3.
           05 WS-VARIATION-MARGIN     PIC S9(13)V99 COMP-3.
           05 WS-IM-PCT               PIC S9(1)V9(4) COMP-3.
           05 WS-THRESHOLD            PIC S9(13)V99 COMP-3
               VALUE 50000000.00.
           05 WS-MIN-TRANSFER         PIC S9(9)V99 COMP-3
               VALUE 500000.00.
       01 WS-CLEARING-FIELDS.
           05 WS-REQUIRES-CLEARING    PIC X(1).
               88 WS-MUST-CLEAR       VALUE 'Y'.
               88 WS-NO-CLEAR         VALUE 'N'.
           05 WS-CCP-NAME             PIC X(20).
       01 WS-REPORTING-FIELDS.
           05 WS-REPORT-TYPE          PIC X(1).
               88 WS-REAL-TIME        VALUE 'R'.
               88 WS-CONTINUATION     VALUE 'C'.
               88 WS-VALUATION        VALUE 'V'.
           05 WS-SDR-NAME             PIC X(20).
           05 WS-REPORT-TIMESTAMP     PIC 9(14).
       01 WS-RISK-METRICS.
           05 WS-DV01                 PIC S9(9)V99 COMP-3.
           05 WS-CS01                 PIC S9(9)V99 COMP-3.
           05 WS-VEGA                 PIC S9(9)V99 COMP-3.
       01 WS-WORK-FIELDS.
           05 WS-DAYS-TO-MATURITY     PIC 9(5).
           05 WS-YEARS-TO-MAT         PIC S9(3)V9(4) COMP-3.
           05 WS-TEMP-MARGIN          PIC S9(13)V99 COMP-3.
           05 WS-MULT-RESULT          PIC S9(15)V99 COMP-3.
           05 WS-MULT-REMAINDER       PIC S9(11)V99 COMP-3.
       01 WS-PROCESS-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-DETERMINE-CLEARING
           PERFORM 3000-CALC-MARGIN
           PERFORM 4000-CALC-RISK-METRICS
           PERFORM 5000-BUILD-SDR-RECORD
           PERFORM 6000-DISPLAY-REPORT
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE 0 TO WS-INITIAL-MARGIN
           MOVE 0 TO WS-VARIATION-MARGIN
           SET WS-NO-CLEAR TO TRUE.
       2000-DETERMINE-CLEARING.
           EVALUATE TRUE
               WHEN WS-IRS
                   IF NOT WS-IS-EXEMPT
                       SET WS-MUST-CLEAR TO TRUE
                       MOVE "LCH CLEARNET"
                           TO WS-CCP-NAME
                   END-IF
               WHEN WS-CDS
                   IF NOT WS-IS-EXEMPT
                       SET WS-MUST-CLEAR TO TRUE
                       MOVE "ICE CLEAR CREDIT"
                           TO WS-CCP-NAME
                   END-IF
               WHEN WS-FX-SWAP
                   SET WS-NO-CLEAR TO TRUE
               WHEN WS-EQUITY-SWAP
                   SET WS-NO-CLEAR TO TRUE
               WHEN OTHER
                   SET WS-NO-CLEAR TO TRUE
           END-EVALUATE.
       3000-CALC-MARGIN.
           EVALUATE TRUE
               WHEN WS-IRS
                   MOVE 0.0200 TO WS-IM-PCT
               WHEN WS-CDS
                   MOVE 0.0500 TO WS-IM-PCT
               WHEN WS-FX-SWAP
                   MOVE 0.0150 TO WS-IM-PCT
               WHEN OTHER
                   MOVE 0.0300 TO WS-IM-PCT
           END-EVALUATE
           MULTIPLY WS-NOTIONAL BY WS-IM-PCT
               GIVING WS-INITIAL-MARGIN
           IF WS-MTM-VALUE > 0
               COMPUTE WS-VARIATION-MARGIN =
                   WS-MTM-VALUE - WS-THRESHOLD
               IF WS-VARIATION-MARGIN < 0
                   MOVE 0 TO WS-VARIATION-MARGIN
               END-IF
               IF WS-VARIATION-MARGIN < WS-MIN-TRANSFER
                   MOVE 0 TO WS-VARIATION-MARGIN
               END-IF
           ELSE
               MOVE 0 TO WS-VARIATION-MARGIN
           END-IF.
       4000-CALC-RISK-METRICS.
           COMPUTE WS-DV01 =
               WS-NOTIONAL * 0.0001
           IF WS-CDS
               COMPUTE WS-CS01 =
                   WS-NOTIONAL * 0.0001
           ELSE
               MOVE 0 TO WS-CS01
           END-IF.
       5000-BUILD-SDR-RECORD.
           SET WS-REAL-TIME TO TRUE
           MOVE "DTCC DDR" TO WS-SDR-NAME
           DISPLAY "SDR RECORD BUILT FOR " WS-SWAP-USI.
       6000-DISPLAY-REPORT.
           DISPLAY "DODD-FRANK SWAP REPORT"
           DISPLAY "DATE: " WS-PROCESS-DATE
           DISPLAY "USI: " WS-SWAP-USI
           DISPLAY "TYPE: " WS-SWAP-TYPE
           DISPLAY "NOTIONAL: " WS-NOTIONAL
           DISPLAY "MTM: " WS-MTM-VALUE
           DISPLAY "COUNTERPARTY: " WS-CP-NAME
           IF WS-MUST-CLEAR
               DISPLAY "CLEARING: REQUIRED"
               DISPLAY "CCP: " WS-CCP-NAME
           ELSE
               DISPLAY "CLEARING: NOT REQUIRED"
           END-IF
           DISPLAY "INITIAL MARGIN: " WS-INITIAL-MARGIN
           DISPLAY "VARIATION MARGIN: "
               WS-VARIATION-MARGIN
           DISPLAY "DV01: " WS-DV01
           DISPLAY "SDR: " WS-SDR-NAME.
