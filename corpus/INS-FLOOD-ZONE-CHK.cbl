       IDENTIFICATION DIVISION.
       PROGRAM-ID. INS-FLOOD-ZONE-CHK.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-PROPERTY-DATA.
           05 WS-LOAN-NUM        PIC X(12).
           05 WS-PROP-ADDRESS    PIC X(40).
           05 WS-PROP-ZIP        PIC X(10).
           05 WS-PROP-STATE      PIC X(2).
           05 WS-PROP-VALUE      PIC S9(11)V99 COMP-3.
       01 WS-FLOOD-ZONE-TBL.
           05 WS-FZ OCCURS 8 TIMES.
               10 WS-FZ-ZIP      PIC X(5).
               10 WS-FZ-ZONE     PIC X(4).
               10 WS-FZ-RISK     PIC X(1).
                   88 FZ-HIGH    VALUE 'H'.
                   88 FZ-MODERATE VALUE 'M'.
                   88 FZ-LOW     VALUE 'L'.
               10 WS-FZ-RATE     PIC S9(1)V9(4) COMP-3.
       01 WS-FZ-COUNT            PIC 9 VALUE 8.
       01 WS-IDX                 PIC 9.
       01 WS-ZONE-FOUND          PIC X VALUE 'N'.
           88 FOUND-ZONE         VALUE 'Y'.
       01 WS-ZONE-IDX            PIC 9.
       01 WS-FLOOD-INS-REQUIRED  PIC X VALUE 'N'.
           88 NEEDS-FLOOD-INS    VALUE 'Y'.
       01 WS-ANNUAL-PREMIUM      PIC S9(7)V99 COMP-3.
       01 WS-COVERAGE-NEEDED     PIC S9(11)V99 COMP-3.
       01 WS-MAX-COVERAGE        PIC S9(11)V99 COMP-3
           VALUE 250000.00.
       01 WS-DETERMINATION       PIC X(15).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-LOOKUP-ZONE
           PERFORM 2000-DETERMINE-REQ
           IF NEEDS-FLOOD-INS
               PERFORM 3000-CALC-PREMIUM
           END-IF
           PERFORM 4000-OUTPUT
           STOP RUN.
       1000-LOOKUP-ZONE.
           MOVE 'N' TO WS-ZONE-FOUND
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > WS-FZ-COUNT
               IF WS-FZ-ZIP(WS-IDX) = WS-PROP-ZIP(1:5)
                   MOVE 'Y' TO WS-ZONE-FOUND
                   MOVE WS-IDX TO WS-ZONE-IDX
               END-IF
           END-PERFORM.
       2000-DETERMINE-REQ.
           IF NOT FOUND-ZONE
               MOVE 'ZONE UNKNOWN   ' TO WS-DETERMINATION
           ELSE
               IF FZ-HIGH(WS-ZONE-IDX)
                   MOVE 'Y' TO WS-FLOOD-INS-REQUIRED
                   MOVE 'MANDATORY      ' TO WS-DETERMINATION
               ELSE
                   IF FZ-MODERATE(WS-ZONE-IDX)
                       MOVE 'Y' TO WS-FLOOD-INS-REQUIRED
                       MOVE 'RECOMMENDED    ' TO
                           WS-DETERMINATION
                   ELSE
                       MOVE 'NOT REQUIRED   ' TO
                           WS-DETERMINATION
                   END-IF
               END-IF
           END-IF.
       3000-CALC-PREMIUM.
           IF WS-PROP-VALUE < WS-MAX-COVERAGE
               MOVE WS-PROP-VALUE TO WS-COVERAGE-NEEDED
           ELSE
               MOVE WS-MAX-COVERAGE TO WS-COVERAGE-NEEDED
           END-IF
           COMPUTE WS-ANNUAL-PREMIUM =
               WS-COVERAGE-NEEDED *
               WS-FZ-RATE(WS-ZONE-IDX).
       4000-OUTPUT.
           DISPLAY 'FLOOD ZONE DETERMINATION'
           DISPLAY '========================'
           DISPLAY 'LOAN:     ' WS-LOAN-NUM
           DISPLAY 'ADDRESS:  ' WS-PROP-ADDRESS
           DISPLAY 'ZIP:      ' WS-PROP-ZIP
           IF FOUND-ZONE
               DISPLAY 'ZONE:     '
                   WS-FZ-ZONE(WS-ZONE-IDX)
               DISPLAY 'RISK:     '
                   WS-FZ-RISK(WS-ZONE-IDX)
           END-IF
           DISPLAY 'STATUS:   ' WS-DETERMINATION
           IF NEEDS-FLOOD-INS
               DISPLAY 'COVERAGE: $' WS-COVERAGE-NEEDED
               DISPLAY 'PREMIUM:  $' WS-ANNUAL-PREMIUM
           END-IF.
