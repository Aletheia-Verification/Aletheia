       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEP-CD-RENEWAL.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CD-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-PRINCIPAL           PIC S9(9)V99 COMP-3.
           05 WS-CURRENT-RATE        PIC S9(3)V9(6) COMP-3.
           05 WS-TERM-MONTHS         PIC 9(3).
           05 WS-MATURITY-DATE       PIC 9(8).
           05 WS-CURRENT-DATE        PIC 9(8).
       01 WS-RENEWAL-TYPE            PIC X(1).
           88 WS-AUTO-RENEW          VALUE 'A'.
           88 WS-MANUAL-RENEW        VALUE 'M'.
           88 WS-CLOSE-OUT           VALUE 'C'.
       01 WS-ACCRUED-INT             PIC S9(7)V99 COMP-3.
       01 WS-NEW-PRINCIPAL           PIC S9(9)V99 COMP-3.
       01 WS-NEW-RATE                PIC S9(3)V9(6) COMP-3.
       01 WS-MATURED-FLAG            PIC X VALUE 'N'.
           88 WS-IS-MATURED          VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-MATURITY
           IF WS-IS-MATURED
               PERFORM 3000-CALC-INTEREST
               PERFORM 4000-PROCESS-RENEWAL
           END-IF
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-ACCRUED-INT
           MOVE 'N' TO WS-MATURED-FLAG.
       2000-CHECK-MATURITY.
           IF WS-CURRENT-DATE >= WS-MATURITY-DATE
               MOVE 'Y' TO WS-MATURED-FLAG
           END-IF.
       3000-CALC-INTEREST.
           COMPUTE WS-ACCRUED-INT =
               WS-PRINCIPAL * WS-CURRENT-RATE *
               WS-TERM-MONTHS / 12.
       4000-PROCESS-RENEWAL.
           EVALUATE TRUE
               WHEN WS-AUTO-RENEW
                   COMPUTE WS-NEW-PRINCIPAL =
                       WS-PRINCIPAL + WS-ACCRUED-INT
                   DISPLAY 'CD AUTO-RENEWED'
               WHEN WS-CLOSE-OUT
                   COMPUTE WS-NEW-PRINCIPAL =
                       WS-PRINCIPAL + WS-ACCRUED-INT
                   DISPLAY 'CD CLOSED OUT'
               WHEN OTHER
                   MOVE WS-PRINCIPAL TO WS-NEW-PRINCIPAL
           END-EVALUATE.
       5000-DISPLAY-RESULTS.
           DISPLAY 'CD RENEWAL REPORT'
           DISPLAY '================='
           DISPLAY 'ACCOUNT:     ' WS-ACCT-NUM
           DISPLAY 'PRINCIPAL:   ' WS-PRINCIPAL
           DISPLAY 'RATE:        ' WS-CURRENT-RATE
           DISPLAY 'INTEREST:    ' WS-ACCRUED-INT
           DISPLAY 'NEW BALANCE: ' WS-NEW-PRINCIPAL.
