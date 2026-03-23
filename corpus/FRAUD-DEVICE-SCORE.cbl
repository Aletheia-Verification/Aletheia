       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAUD-DEVICE-SCORE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-DEVICE-DATA.
           05 WS-DEVICE-ID           PIC X(20).
           05 WS-IP-ADDRESS          PIC X(15).
           05 WS-USER-AGENT          PIC X(40).
           05 WS-ACCT-NUM            PIC X(12).
       01 WS-DEVICE-FLAGS.
           05 WS-KNOWN-DEVICE        PIC X VALUE 'N'.
               88 WS-IS-KNOWN        VALUE 'Y'.
           05 WS-VPN-DETECTED        PIC X VALUE 'N'.
               88 WS-HAS-VPN         VALUE 'Y'.
           05 WS-PROXY-DETECTED      PIC X VALUE 'N'.
               88 WS-HAS-PROXY       VALUE 'Y'.
           05 WS-BOT-DETECTED        PIC X VALUE 'N'.
               88 WS-IS-BOT          VALUE 'Y'.
       01 WS-SCORE-FIELDS.
           05 WS-DEVICE-SCORE        PIC S9(3) COMP-3.
           05 WS-IP-SCORE            PIC S9(3) COMP-3.
           05 WS-BEHAVIOR-SCORE      PIC S9(3) COMP-3.
           05 WS-TOTAL-SCORE         PIC S9(3) COMP-3.
       01 WS-RISK-LEVEL              PIC X(1).
           88 WS-LOW-RISK            VALUE 'L'.
           88 WS-MED-RISK            VALUE 'M'.
           88 WS-HIGH-RISK           VALUE 'H'.
       01 WS-ACTION                  PIC X(1).
           88 WS-ALLOW               VALUE 'A'.
           88 WS-CHALLENGE           VALUE 'C'.
           88 WS-DENY                VALUE 'D'.
       01 WS-LOGINS-TODAY            PIC 9(3).
       01 WS-FAILED-LOGINS           PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SCORE-DEVICE
           PERFORM 3000-SCORE-IP
           PERFORM 4000-SCORE-BEHAVIOR
           PERFORM 5000-CALC-TOTAL
           PERFORM 6000-DETERMINE-ACTION
           PERFORM 7000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-DEVICE-SCORE
           MOVE 0 TO WS-IP-SCORE
           MOVE 0 TO WS-BEHAVIOR-SCORE
           MOVE 0 TO WS-TOTAL-SCORE.
       2000-SCORE-DEVICE.
           IF WS-IS-KNOWN
               MOVE 0 TO WS-DEVICE-SCORE
           ELSE
               MOVE 30 TO WS-DEVICE-SCORE
           END-IF
           IF WS-IS-BOT
               ADD 40 TO WS-DEVICE-SCORE
           END-IF.
       3000-SCORE-IP.
           IF WS-HAS-VPN
               ADD 20 TO WS-IP-SCORE
           END-IF
           IF WS-HAS-PROXY
               ADD 25 TO WS-IP-SCORE
           END-IF.
       4000-SCORE-BEHAVIOR.
           IF WS-FAILED-LOGINS > 3
               COMPUTE WS-BEHAVIOR-SCORE =
                   WS-FAILED-LOGINS * 10
           END-IF
           IF WS-LOGINS-TODAY > 10
               ADD 15 TO WS-BEHAVIOR-SCORE
           END-IF.
       5000-CALC-TOTAL.
           COMPUTE WS-TOTAL-SCORE =
               WS-DEVICE-SCORE + WS-IP-SCORE +
               WS-BEHAVIOR-SCORE
           EVALUATE TRUE
               WHEN WS-TOTAL-SCORE >= 70
                   SET WS-HIGH-RISK TO TRUE
               WHEN WS-TOTAL-SCORE >= 35
                   SET WS-MED-RISK TO TRUE
               WHEN OTHER
                   SET WS-LOW-RISK TO TRUE
           END-EVALUATE.
       6000-DETERMINE-ACTION.
           EVALUATE TRUE
               WHEN WS-HIGH-RISK
                   SET WS-DENY TO TRUE
               WHEN WS-MED-RISK
                   SET WS-CHALLENGE TO TRUE
               WHEN OTHER
                   SET WS-ALLOW TO TRUE
           END-EVALUATE.
       7000-DISPLAY-RESULTS.
           DISPLAY 'DEVICE FINGERPRINT SCORE'
           DISPLAY '========================'
           DISPLAY 'DEVICE ID:    ' WS-DEVICE-ID
           DISPLAY 'IP:           ' WS-IP-ADDRESS
           DISPLAY 'DEVICE SCORE: ' WS-DEVICE-SCORE
           DISPLAY 'IP SCORE:     ' WS-IP-SCORE
           DISPLAY 'BEHAV SCORE:  ' WS-BEHAVIOR-SCORE
           DISPLAY 'TOTAL SCORE:  ' WS-TOTAL-SCORE
           IF WS-ALLOW
               DISPLAY 'ACTION: ALLOW'
           END-IF
           IF WS-CHALLENGE
               DISPLAY 'ACTION: CHALLENGE'
           END-IF
           IF WS-DENY
               DISPLAY 'ACTION: DENY'
           END-IF.
