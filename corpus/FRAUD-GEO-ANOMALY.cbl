       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAUD-GEO-ANOMALY.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-TXN-DATA.
           05 WS-CARD-NUM            PIC X(16).
           05 WS-TXN-AMOUNT          PIC S9(9)V99 COMP-3.
           05 WS-TXN-COUNTRY         PIC X(3).
           05 WS-TXN-CITY            PIC X(20).
           05 WS-TXN-TIME            PIC 9(6).
       01 WS-LAST-TXN.
           05 WS-LAST-COUNTRY        PIC X(3).
           05 WS-LAST-CITY           PIC X(20).
           05 WS-LAST-TIME           PIC 9(6).
       01 WS-GEO-FIELDS.
           05 WS-TIME-DIFF           PIC 9(6).
           05 WS-SAME-COUNTRY        PIC X VALUE 'Y'.
               88 WS-DOMESTIC        VALUE 'Y'.
           05 WS-MAX-TRAVEL-MIN      PIC 9(4) VALUE 120.
       01 WS-ALERT-STATUS            PIC X(1).
           88 WS-CLEAR               VALUE 'C'.
           88 WS-SUSPICIOUS          VALUE 'S'.
           88 WS-IMPOSSIBLE-TRAVEL   VALUE 'I'.
       01 WS-RISK-SCORE              PIC S9(3) COMP-3.
       01 WS-ALERT-MSG               PIC X(60).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CHECK-GEOGRAPHY
           PERFORM 3000-CHECK-TIMING
           PERFORM 4000-BUILD-ALERT
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-RISK-SCORE
           SET WS-CLEAR TO TRUE
           MOVE SPACES TO WS-ALERT-MSG.
       2000-CHECK-GEOGRAPHY.
           IF WS-TXN-COUNTRY NOT = WS-LAST-COUNTRY
               MOVE 'N' TO WS-SAME-COUNTRY
               ADD 30 TO WS-RISK-SCORE
           END-IF
           IF WS-TXN-CITY NOT = WS-LAST-CITY
               ADD 10 TO WS-RISK-SCORE
           END-IF.
       3000-CHECK-TIMING.
           IF WS-TXN-TIME > WS-LAST-TIME
               COMPUTE WS-TIME-DIFF =
                   WS-TXN-TIME - WS-LAST-TIME
           ELSE
               COMPUTE WS-TIME-DIFF =
                   WS-LAST-TIME - WS-TXN-TIME
           END-IF
           IF WS-SAME-COUNTRY = 'N'
               IF WS-TIME-DIFF < WS-MAX-TRAVEL-MIN
                   SET WS-IMPOSSIBLE-TRAVEL TO TRUE
                   ADD 50 TO WS-RISK-SCORE
               ELSE
                   SET WS-SUSPICIOUS TO TRUE
               END-IF
           ELSE
               IF WS-TIME-DIFF < 30
                   IF WS-TXN-CITY NOT = WS-LAST-CITY
                       SET WS-SUSPICIOUS TO TRUE
                       ADD 20 TO WS-RISK-SCORE
                   END-IF
               END-IF
           END-IF.
       4000-BUILD-ALERT.
           IF WS-IMPOSSIBLE-TRAVEL
               STRING 'IMPOSSIBLE TRAVEL: '
                          DELIMITED BY SIZE
                      WS-LAST-COUNTRY DELIMITED BY SIZE
                      '->' DELIMITED BY SIZE
                      WS-TXN-COUNTRY DELIMITED BY SIZE
                      ' IN ' DELIMITED BY SIZE
                      WS-TIME-DIFF DELIMITED BY SIZE
                      ' MIN' DELIMITED BY SIZE
                      INTO WS-ALERT-MSG
               END-STRING
           END-IF.
       5000-DISPLAY-RESULTS.
           DISPLAY 'GEO ANOMALY CHECK'
           DISPLAY '=================='
           DISPLAY 'CARD:        ' WS-CARD-NUM
           DISPLAY 'AMOUNT:      ' WS-TXN-AMOUNT
           DISPLAY 'COUNTRY:     ' WS-TXN-COUNTRY
           DISPLAY 'LAST COUNTRY:' WS-LAST-COUNTRY
           DISPLAY 'TIME DIFF:   ' WS-TIME-DIFF
           DISPLAY 'RISK SCORE:  ' WS-RISK-SCORE
           IF WS-IMPOSSIBLE-TRAVEL
               DISPLAY 'STATUS: IMPOSSIBLE TRAVEL'
               DISPLAY WS-ALERT-MSG
           END-IF
           IF WS-SUSPICIOUS
               DISPLAY 'STATUS: SUSPICIOUS'
           END-IF
           IF WS-CLEAR
               DISPLAY 'STATUS: CLEAR'
           END-IF.
