       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-ALTER-MTG-ROUTE.
      *================================================================*
      * MANUAL REVIEW: Mortgage Processing Router with ALTER            *
      * Legacy flow control using ALTER to redirect paragraph execution *
      * based on loan type — triggers MANUAL REVIEW detection.         *
      *================================================================*
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-LOAN-TYPE            PIC X(02).
       01  WS-LOAN-AMOUNT          PIC S9(09)V99
                                   VALUE 285000.00.
       01  WS-RATE                 PIC 9V9(06)
                                   VALUE 0.065000.
       01  WS-TERM                 PIC 9(03) VALUE 360.
       01  WS-PAYMENT              PIC S9(07)V99.
       01  WS-MONTHLY-RATE         PIC 9V9(10).
       01  WS-TOTAL-INT            PIC S9(11)V99.
       01  WS-FHA-MIP              PIC S9(05)V99.
       01  WS-VA-FUNDING           PIC S9(07)V99.
       01  WS-CONV-PMI             PIC S9(05)V99.
       01  WS-LTV                  PIC 9(03)V99.
       01  WS-PROPERTY-VALUE       PIC 9(09)V99
                                   VALUE 350000.00.
       01  WS-RESULT-MSG           PIC X(60) VALUE SPACES.
       01  WS-ROUTE-IDX            PIC 9(02).
       01  WS-PROCESSED            PIC X VALUE 'N'.
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           MOVE 'FH' TO WS-LOAN-TYPE
           PERFORM 1000-DETERMINE-ROUTE
           PERFORM 2000-ROUTE-DISPATCH
           DISPLAY 'PROCESSING COMPLETE'
           DISPLAY WS-RESULT-MSG
           STOP RUN.
       1000-DETERMINE-ROUTE.
           COMPUTE WS-LTV ROUNDED =
               (WS-LOAN-AMOUNT / WS-PROPERTY-VALUE) * 100
           EVALUATE WS-LOAN-TYPE
               WHEN 'FH'
                   ALTER 2000-ROUTE-DISPATCH
                       TO PROCEED TO 3000-FHA-PROCESS
               WHEN 'VA'
                   ALTER 2000-ROUTE-DISPATCH
                       TO PROCEED TO 4000-VA-PROCESS
               WHEN 'CV'
                   ALTER 2000-ROUTE-DISPATCH
                       TO PROCEED TO 5000-CONV-PROCESS
               WHEN OTHER
                   ALTER 2000-ROUTE-DISPATCH
                       TO PROCEED TO 6000-ERROR-HANDLER
           END-EVALUATE.
       2000-ROUTE-DISPATCH.
           GO TO 6000-ERROR-HANDLER.
       3000-FHA-PROCESS.
           COMPUTE WS-MONTHLY-RATE =
               WS-RATE / 12
           COMPUTE WS-PAYMENT ROUNDED =
               WS-LOAN-AMOUNT * WS-MONTHLY-RATE /
               (1 - (1 / (1 + WS-MONTHLY-RATE)))
           COMPUTE WS-FHA-MIP ROUNDED =
               WS-LOAN-AMOUNT * 0.0055 / 12
           ADD WS-FHA-MIP TO WS-PAYMENT
           COMPUTE WS-TOTAL-INT ROUNDED =
               (WS-PAYMENT * WS-TERM) - WS-LOAN-AMOUNT
           STRING 'FHA LOAN PMT='
               DELIMITED BY SIZE
               INTO WS-RESULT-MSG
           MOVE 'Y' TO WS-PROCESSED
           GO TO 8000-FINALIZE.
       4000-VA-PROCESS.
           COMPUTE WS-MONTHLY-RATE =
               WS-RATE / 12
           COMPUTE WS-VA-FUNDING ROUNDED =
               WS-LOAN-AMOUNT * 0.0215
           COMPUTE WS-PAYMENT ROUNDED =
               (WS-LOAN-AMOUNT + WS-VA-FUNDING) *
               WS-MONTHLY-RATE /
               (1 - (1 / (1 + WS-MONTHLY-RATE)))
           STRING 'VA LOAN PMT='
               DELIMITED BY SIZE
               INTO WS-RESULT-MSG
           MOVE 'Y' TO WS-PROCESSED
           GO TO 8000-FINALIZE.
       5000-CONV-PROCESS.
           COMPUTE WS-MONTHLY-RATE =
               WS-RATE / 12
           COMPUTE WS-PAYMENT ROUNDED =
               WS-LOAN-AMOUNT * WS-MONTHLY-RATE /
               (1 - (1 / (1 + WS-MONTHLY-RATE)))
           IF WS-LTV > 80
               COMPUTE WS-CONV-PMI ROUNDED =
                   WS-LOAN-AMOUNT * 0.005 / 12
               ADD WS-CONV-PMI TO WS-PAYMENT
           END-IF
           STRING 'CONV LOAN PMT='
               DELIMITED BY SIZE
               INTO WS-RESULT-MSG
           MOVE 'Y' TO WS-PROCESSED
           GO TO 8000-FINALIZE.
       6000-ERROR-HANDLER.
           MOVE 'ERROR: UNKNOWN LOAN TYPE' TO WS-RESULT-MSG
           DISPLAY WS-RESULT-MSG.
       8000-FINALIZE.
           DISPLAY 'LOAN TYPE: ' WS-LOAN-TYPE
           DISPLAY 'AMOUNT:    ' WS-LOAN-AMOUNT
           DISPLAY 'RATE:      ' WS-RATE
           DISPLAY 'LTV:       ' WS-LTV '%'
           DISPLAY 'PAYMENT:   ' WS-PAYMENT.
