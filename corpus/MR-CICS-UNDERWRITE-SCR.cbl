       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-UNDERWRITE-SCR.
      *================================================================
      * MANUAL REVIEW: EXEC CICS
      * Online underwriting screen for real-time risk assessment
      * using CICS terminal I/O and transient data queues.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SCREEN-INPUT.
           05 WS-SI-APPL-ID           PIC X(10).
           05 WS-SI-AGE               PIC 9(3).
           05 WS-SI-COVERAGE          PIC S9(9)V99 COMP-3.
           05 WS-SI-SMOKER            PIC X(1).
               88 SI-SMOKER-YES       VALUE 'Y'.
               88 SI-SMOKER-NO        VALUE 'N'.
           05 WS-SI-OCCUPATION        PIC X(3).
               88 SI-OCC-LOW          VALUE 'LOW'.
               88 SI-OCC-MED          VALUE 'MED'.
               88 SI-OCC-HIGH         VALUE 'HGH'.
       01 WS-RISK-RESULT.
           05 WS-RR-SCORE             PIC 9(3).
           05 WS-RR-TIER              PIC X(12).
           05 WS-RR-DECISION          PIC X(8).
           05 WS-RR-PREMIUM           PIC S9(7)V99 COMP-3.
           05 WS-RR-RATING            PIC X(1).
               88 RR-STANDARD         VALUE 'S'.
               88 RR-PREFERRED        VALUE 'P'.
               88 RR-SUBSTANDARD      VALUE 'U'.
               88 RR-DECLINED         VALUE 'D'.
       01 WS-BASE-RATES.
           05 WS-BR-ENTRY OCCURS 5 TIMES.
               10 WS-BR-MIN-AGE       PIC 9(3).
               10 WS-BR-MAX-AGE       PIC 9(3).
               10 WS-BR-RATE          PIC S9(5)V99 COMP-3.
       01 WS-IDX                      PIC 9(1).
       01 WS-SELECTED-RATE            PIC S9(5)V99 COMP-3.
       01 WS-RISK-MULT                PIC S9(1)V9(4) COMP-3.
       01 WS-RESPONSE-CODE            PIC S9(8) COMP.
       01 WS-QUEUE-DATA               PIC X(80).
       01 WS-QUEUE-LEN                PIC S9(4) COMP VALUE 80.
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INIT-RATES
           PERFORM 2000-RECEIVE-SCREEN
           PERFORM 3000-SCORE-APPLICANT
           PERFORM 4000-CALC-PREMIUM
           PERFORM 5000-LOG-TO-QUEUE
           PERFORM 6000-SEND-RESULT
           STOP RUN.
       1000-INIT-RATES.
           MOVE 18 TO WS-BR-MIN-AGE(1)
           MOVE 29 TO WS-BR-MAX-AGE(1)
           MOVE 120.00 TO WS-BR-RATE(1)
           MOVE 30 TO WS-BR-MIN-AGE(2)
           MOVE 39 TO WS-BR-MAX-AGE(2)
           MOVE 180.00 TO WS-BR-RATE(2)
           MOVE 40 TO WS-BR-MIN-AGE(3)
           MOVE 49 TO WS-BR-MAX-AGE(3)
           MOVE 300.00 TO WS-BR-RATE(3)
           MOVE 50 TO WS-BR-MIN-AGE(4)
           MOVE 59 TO WS-BR-MAX-AGE(4)
           MOVE 550.00 TO WS-BR-RATE(4)
           MOVE 60 TO WS-BR-MIN-AGE(5)
           MOVE 99 TO WS-BR-MAX-AGE(5)
           MOVE 950.00 TO WS-BR-RATE(5).
       2000-RECEIVE-SCREEN.
           EXEC CICS RECEIVE
               MAP('UWSCR')
               MAPSET('UWSET')
               INTO(WS-SCREEN-INPUT)
               RESP(WS-RESPONSE-CODE)
           END-EXEC
           IF WS-RESPONSE-CODE NOT = 0
               DISPLAY 'SCREEN RECEIVE ERROR'
           END-IF.
       3000-SCORE-APPLICANT.
           MOVE 100 TO WS-RR-SCORE
           IF SI-SMOKER-YES
               SUBTRACT 25 FROM WS-RR-SCORE
           END-IF
           IF WS-SI-AGE > 55
               SUBTRACT 15 FROM WS-RR-SCORE
           ELSE
               IF WS-SI-AGE > 45
                   SUBTRACT 10 FROM WS-RR-SCORE
               END-IF
           END-IF
           EVALUATE TRUE
               WHEN SI-OCC-HIGH
                   SUBTRACT 20 FROM WS-RR-SCORE
               WHEN SI-OCC-MED
                   SUBTRACT 10 FROM WS-RR-SCORE
               WHEN SI-OCC-LOW
                   SUBTRACT 0 FROM WS-RR-SCORE
               WHEN OTHER
                   SUBTRACT 5 FROM WS-RR-SCORE
           END-EVALUATE
           IF WS-RR-SCORE >= 80
               SET RR-PREFERRED TO TRUE
               MOVE 'PREFERRED   ' TO WS-RR-TIER
               MOVE 'APPROVED' TO WS-RR-DECISION
               MOVE 0.8500 TO WS-RISK-MULT
           ELSE
               IF WS-RR-SCORE >= 60
                   SET RR-STANDARD TO TRUE
                   MOVE 'STANDARD    ' TO WS-RR-TIER
                   MOVE 'APPROVED' TO WS-RR-DECISION
                   MOVE 1.0000 TO WS-RISK-MULT
               ELSE
                   IF WS-RR-SCORE >= 40
                       SET RR-SUBSTANDARD TO TRUE
                       MOVE 'SUBSTANDARD ' TO WS-RR-TIER
                       MOVE 'APPROVED' TO WS-RR-DECISION
                       MOVE 1.5000 TO WS-RISK-MULT
                   ELSE
                       SET RR-DECLINED TO TRUE
                       MOVE 'DECLINED    ' TO WS-RR-TIER
                       MOVE 'DECLINED' TO WS-RR-DECISION
                       MOVE 0 TO WS-RISK-MULT
                   END-IF
               END-IF
           END-IF.
       4000-CALC-PREMIUM.
           MOVE 0 TO WS-SELECTED-RATE
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 5
               IF WS-SI-AGE >= WS-BR-MIN-AGE(WS-IDX) AND
                  WS-SI-AGE <= WS-BR-MAX-AGE(WS-IDX)
                   MOVE WS-BR-RATE(WS-IDX)
                       TO WS-SELECTED-RATE
               END-IF
           END-PERFORM
           IF NOT RR-DECLINED
               COMPUTE WS-RR-PREMIUM =
                   (WS-SI-COVERAGE / 1000)
                   * WS-SELECTED-RATE
                   * WS-RISK-MULT
           ELSE
               MOVE 0 TO WS-RR-PREMIUM
           END-IF.
       5000-LOG-TO-QUEUE.
           MOVE SPACES TO WS-QUEUE-DATA
           STRING WS-SI-APPL-ID DELIMITED BY SIZE
                  ' ' DELIMITED BY SIZE
                  WS-RR-TIER DELIMITED BY SIZE
                  INTO WS-QUEUE-DATA
           END-STRING
           EXEC CICS WRITEQ TD
               QUEUE('UWLOG')
               FROM(WS-QUEUE-DATA)
               LENGTH(WS-QUEUE-LEN)
               RESP(WS-RESPONSE-CODE)
           END-EXEC.
       6000-SEND-RESULT.
           EXEC CICS SEND
               MAP('UWRSLT')
               MAPSET('UWSET')
               FROM(WS-RISK-RESULT)
               ERASE
               RESP(WS-RESPONSE-CODE)
           END-EXEC
           DISPLAY 'UNDERWRITE RESULT SENT'
           DISPLAY 'APPLICANT: ' WS-SI-APPL-ID
           DISPLAY 'SCORE:     ' WS-RR-SCORE
           DISPLAY 'TIER:      ' WS-RR-TIER
           DISPLAY 'DECISION:  ' WS-RR-DECISION
           DISPLAY 'PREMIUM:   ' WS-RR-PREMIUM.
