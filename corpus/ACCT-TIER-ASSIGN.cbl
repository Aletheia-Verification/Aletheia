       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCT-TIER-ASSIGN.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ACCT-DATA.
           05 WS-ACCT-NUM            PIC X(12).
           05 WS-AVG-BALANCE         PIC S9(9)V99 COMP-3.
           05 WS-TOTAL-DEPOSITS      PIC S9(11)V99 COMP-3.
           05 WS-NUM-PRODUCTS        PIC 9(2).
           05 WS-YEARS-MEMBER        PIC 9(2).
           05 WS-DIRECT-DEPOSIT      PIC X VALUE 'N'.
               88 WS-HAS-DD          VALUE 'Y'.
       01 WS-CURRENT-TIER            PIC X(1).
           88 WS-TIER-BASIC          VALUE 'B'.
           88 WS-TIER-SILVER         VALUE 'S'.
           88 WS-TIER-GOLD           VALUE 'G'.
           88 WS-TIER-PLATINUM       VALUE 'P'.
       01 WS-NEW-TIER                PIC X(1).
       01 WS-RELATIONSHIP-SCORE      PIC S9(5) COMP-3.
       01 WS-BENEFITS.
           05 WS-ATM-REBATE          PIC S9(3)V99 COMP-3.
           05 WS-RATE-BONUS          PIC S9(1)V9(4) COMP-3.
           05 WS-FEE-WAIVER          PIC X VALUE 'N'.
               88 WS-FEES-WAIVED     VALUE 'Y'.
           05 WS-FREE-CHECKS         PIC X VALUE 'N'.
               88 WS-HAS-FREE-CHECKS VALUE 'Y'.
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-SCORE
           PERFORM 3000-ASSIGN-TIER
           PERFORM 4000-SET-BENEFITS
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-RELATIONSHIP-SCORE
           MOVE 0 TO WS-ATM-REBATE
           MOVE 0 TO WS-RATE-BONUS.
       2000-CALC-SCORE.
           IF WS-AVG-BALANCE > 100000
               ADD 50 TO WS-RELATIONSHIP-SCORE
           ELSE
               IF WS-AVG-BALANCE > 25000
                   ADD 30 TO WS-RELATIONSHIP-SCORE
               ELSE
                   IF WS-AVG-BALANCE > 5000
                       ADD 15 TO WS-RELATIONSHIP-SCORE
                   END-IF
               END-IF
           END-IF
           COMPUTE WS-RELATIONSHIP-SCORE =
               WS-RELATIONSHIP-SCORE +
               (WS-NUM-PRODUCTS * 5) +
               (WS-YEARS-MEMBER * 3)
           IF WS-HAS-DD
               ADD 10 TO WS-RELATIONSHIP-SCORE
           END-IF.
       3000-ASSIGN-TIER.
           EVALUATE TRUE
               WHEN WS-RELATIONSHIP-SCORE >= 75
                   SET WS-TIER-PLATINUM TO TRUE
                   MOVE 'P' TO WS-NEW-TIER
               WHEN WS-RELATIONSHIP-SCORE >= 50
                   SET WS-TIER-GOLD TO TRUE
                   MOVE 'G' TO WS-NEW-TIER
               WHEN WS-RELATIONSHIP-SCORE >= 25
                   SET WS-TIER-SILVER TO TRUE
                   MOVE 'S' TO WS-NEW-TIER
               WHEN OTHER
                   SET WS-TIER-BASIC TO TRUE
                   MOVE 'B' TO WS-NEW-TIER
           END-EVALUATE.
       4000-SET-BENEFITS.
           EVALUATE TRUE
               WHEN WS-TIER-PLATINUM
                   MOVE 20.00 TO WS-ATM-REBATE
                   MOVE 0.0025 TO WS-RATE-BONUS
                   MOVE 'Y' TO WS-FEE-WAIVER
                   MOVE 'Y' TO WS-FREE-CHECKS
               WHEN WS-TIER-GOLD
                   MOVE 10.00 TO WS-ATM-REBATE
                   MOVE 0.0010 TO WS-RATE-BONUS
                   MOVE 'Y' TO WS-FEE-WAIVER
                   MOVE 'N' TO WS-FREE-CHECKS
               WHEN WS-TIER-SILVER
                   MOVE 5.00 TO WS-ATM-REBATE
                   MOVE 0 TO WS-RATE-BONUS
                   MOVE 'N' TO WS-FEE-WAIVER
                   MOVE 'N' TO WS-FREE-CHECKS
               WHEN OTHER
                   MOVE 0 TO WS-ATM-REBATE
                   MOVE 0 TO WS-RATE-BONUS
                   MOVE 'N' TO WS-FEE-WAIVER
                   MOVE 'N' TO WS-FREE-CHECKS
           END-EVALUATE.
       5000-DISPLAY-RESULTS.
           DISPLAY 'ACCOUNT TIER ASSIGNMENT'
           DISPLAY '======================='
           DISPLAY 'ACCOUNT:        ' WS-ACCT-NUM
           DISPLAY 'AVG BALANCE:    ' WS-AVG-BALANCE
           DISPLAY 'PRODUCTS:       ' WS-NUM-PRODUCTS
           DISPLAY 'YEARS MEMBER:   ' WS-YEARS-MEMBER
           DISPLAY 'REL SCORE:      ' WS-RELATIONSHIP-SCORE
           DISPLAY 'ASSIGNED TIER:  ' WS-NEW-TIER
           DISPLAY 'ATM REBATE:     ' WS-ATM-REBATE
           DISPLAY 'RATE BONUS:     ' WS-RATE-BONUS
           IF WS-FEES-WAIVED
               DISPLAY 'FEES: WAIVED'
           END-IF
           IF WS-HAS-FREE-CHECKS
               DISPLAY 'FREE CHECKS: YES'
           END-IF.
