       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOAN-COUPON-STRIP.
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT BOND-FILE ASSIGN TO 'BONDS.DAT'
               FILE STATUS IS WS-BOND-STATUS.
           SELECT STRIP-FILE ASSIGN TO 'STRIPS.DAT'
               FILE STATUS IS WS-STRIP-STATUS.
       DATA DIVISION.
       FILE SECTION.
       FD BOND-FILE.
       01 BOND-RECORD.
           05 BR-CUSIP               PIC X(9).
           05 BR-FACE-VALUE          PIC 9(9)V99.
           05 BR-COUPON-RATE         PIC 9(2)V9(6).
           05 BR-MATURITY-DATE       PIC 9(8).
           05 BR-SEMI-ANNUAL-FLAG    PIC X(1).
           05 BR-PERIODS-REMAIN      PIC 9(3).
       FD STRIP-FILE.
       01 STRIP-RECORD.
           05 SR-CUSIP               PIC X(9).
           05 SR-PERIOD-NUM          PIC 9(3).
           05 SR-COUPON-AMT          PIC 9(7)V99.
           05 SR-PRINCIPAL-AMT       PIC 9(9)V99.
           05 SR-PV-COUPON           PIC 9(9)V99.
           05 SR-PV-PRINCIPAL        PIC 9(9)V99.
           05 SR-STRIP-TYPE          PIC X(2).
       WORKING-STORAGE SECTION.
       01 WS-BOND-STATUS             PIC XX.
       01 WS-STRIP-STATUS            PIC XX.
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.
       01 WS-CALC-FIELDS.
           05 WS-COUPON-PMT          PIC S9(7)V99 COMP-3.
           05 WS-PERIODIC-RATE       PIC S9(1)V9(8) COMP-3.
           05 WS-DISCOUNT-RATE       PIC S9(1)V9(8) COMP-3
               VALUE 0.0250.
           05 WS-DISC-PER-PERIOD     PIC S9(1)V9(8) COMP-3.
           05 WS-PV-FACTOR           PIC S9(3)V9(10) COMP-3.
           05 WS-PV-COUPON           PIC S9(9)V99 COMP-3.
           05 WS-PV-PRINCIPAL        PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-PV-COUPONS    PIC S9(11)V99 COMP-3.
           05 WS-TOTAL-PV-PRINCIPAL  PIC S9(11)V99 COMP-3.
       01 WS-PERIOD-IDX              PIC 9(3).
       01 WS-BOND-COUNT              PIC S9(5) COMP-3.
       01 WS-STRIP-COUNT             PIC S9(5) COMP-3.
       01 WS-SEMI-FLAG               PIC X(1).
           88 WS-IS-SEMI             VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 0100-INITIALIZE
           PERFORM 0200-OPEN-FILES
           PERFORM 0300-PROCESS-BONDS UNTIL WS-EOF
           PERFORM 0400-CLOSE-FILES
           PERFORM 0500-DISPLAY-SUMMARY
           STOP RUN.
       0100-INITIALIZE.
           MOVE 0 TO WS-BOND-COUNT
           MOVE 0 TO WS-STRIP-COUNT
           MOVE 0 TO WS-TOTAL-PV-COUPONS
           MOVE 0 TO WS-TOTAL-PV-PRINCIPAL
           MOVE 'N' TO WS-EOF-FLAG.
       0200-OPEN-FILES.
           OPEN INPUT BOND-FILE
           OPEN OUTPUT STRIP-FILE.
       0300-PROCESS-BONDS.
           READ BOND-FILE
               AT END SET WS-EOF TO TRUE
               NOT AT END PERFORM 1000-STRIP-BOND
           END-READ.
       1000-STRIP-BOND.
           ADD 1 TO WS-BOND-COUNT
           MOVE BR-SEMI-ANNUAL-FLAG TO WS-SEMI-FLAG
           IF WS-IS-SEMI
               COMPUTE WS-COUPON-PMT =
                   BR-FACE-VALUE * BR-COUPON-RATE / 2
               COMPUTE WS-DISC-PER-PERIOD =
                   WS-DISCOUNT-RATE / 2
           ELSE
               COMPUTE WS-COUPON-PMT =
                   BR-FACE-VALUE * BR-COUPON-RATE
               MOVE WS-DISCOUNT-RATE TO WS-DISC-PER-PERIOD
           END-IF
           PERFORM VARYING WS-PERIOD-IDX FROM 1 BY 1
               UNTIL WS-PERIOD-IDX > BR-PERIODS-REMAIN
               COMPUTE WS-PV-FACTOR =
                   1 / ((1 + WS-DISC-PER-PERIOD) **
                   WS-PERIOD-IDX)
               COMPUTE WS-PV-COUPON =
                   WS-COUPON-PMT * WS-PV-FACTOR
               ADD WS-PV-COUPON TO WS-TOTAL-PV-COUPONS
               MOVE BR-CUSIP TO SR-CUSIP
               MOVE WS-PERIOD-IDX TO SR-PERIOD-NUM
               MOVE WS-COUPON-PMT TO SR-COUPON-AMT
               MOVE WS-PV-COUPON TO SR-PV-COUPON
               IF WS-PERIOD-IDX = BR-PERIODS-REMAIN
                   COMPUTE WS-PV-PRINCIPAL =
                       BR-FACE-VALUE * WS-PV-FACTOR
                   MOVE BR-FACE-VALUE TO SR-PRINCIPAL-AMT
                   MOVE WS-PV-PRINCIPAL TO SR-PV-PRINCIPAL
                   ADD WS-PV-PRINCIPAL TO
                       WS-TOTAL-PV-PRINCIPAL
                   MOVE 'PO' TO SR-STRIP-TYPE
               ELSE
                   MOVE 0 TO SR-PRINCIPAL-AMT
                   MOVE 0 TO SR-PV-PRINCIPAL
                   MOVE 'IO' TO SR-STRIP-TYPE
               END-IF
               WRITE STRIP-RECORD
               ADD 1 TO WS-STRIP-COUNT
           END-PERFORM.
       0400-CLOSE-FILES.
           CLOSE BOND-FILE
           CLOSE STRIP-FILE.
       0500-DISPLAY-SUMMARY.
           DISPLAY 'COUPON STRIP SUMMARY'
           DISPLAY '===================='
           DISPLAY 'BONDS PROCESSED:    ' WS-BOND-COUNT
           DISPLAY 'STRIPS GENERATED:   ' WS-STRIP-COUNT
           DISPLAY 'TOTAL PV COUPONS:   ' WS-TOTAL-PV-COUPONS
           DISPLAY 'TOTAL PV PRINCIPAL: '
               WS-TOTAL-PV-PRINCIPAL.
