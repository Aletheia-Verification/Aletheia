       IDENTIFICATION DIVISION.
       PROGRAM-ID. CUSTODY-PROXY-VOTE.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT VOTE-FILE ASSIGN TO 'VOTEIN'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-VOTE-STATUS.
           SELECT RESULT-FILE ASSIGN TO 'VOTEOUT'
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-RES-STATUS.
           SELECT SORT-FILE ASSIGN TO 'SORTWORK'.

       DATA DIVISION.
       FILE SECTION.

       FD VOTE-FILE.
       01 VOTE-RECORD.
           05 VT-CUSIP                PIC X(9).
           05 VT-ACCT-ID             PIC X(12).
           05 VT-SHARES-HELD         PIC S9(9) COMP-3.
           05 VT-RECORD-DATE         PIC 9(8).
           05 VT-VOTE-ITEMS OCCURS 5.
               10 VT-ITEM-NUM        PIC 9(2).
               10 VT-VOTE-CODE       PIC X(1).
                   88 VT-FOR         VALUE 'F'.
                   88 VT-AGAINST     VALUE 'A'.
                   88 VT-ABSTAIN     VALUE 'X'.
                   88 VT-NO-VOTE     VALUE ' '.

       SD SORT-FILE.
       01 SORT-RECORD.
           05 SORT-CUSIP             PIC X(9).
           05 SORT-ACCT-ID           PIC X(12).
           05 SORT-SHARES            PIC S9(9) COMP-3.
           05 SORT-REC-DATE          PIC 9(8).
           05 SORT-ITEMS OCCURS 5.
               10 SORT-ITEM-NUM     PIC 9(2).
               10 SORT-VOTE-CODE    PIC X(1).

       FD RESULT-FILE.
       01 RESULT-RECORD.
           05 RS-CUSIP               PIC X(9).
           05 RS-ITEM-NUM            PIC 9(2).
           05 RS-FOR-SHARES          PIC S9(11) COMP-3.
           05 RS-AGAINST-SHARES      PIC S9(11) COMP-3.
           05 RS-ABSTAIN-SHARES      PIC S9(11) COMP-3.
           05 RS-TOTAL-SHARES        PIC S9(11) COMP-3.
           05 RS-FOR-PCT             PIC S9(3)V99 COMP-3.
           05 RS-OUTCOME             PIC X(10).

       WORKING-STORAGE SECTION.

       01 WS-VOTE-STATUS             PIC X(2).
       01 WS-RES-STATUS              PIC X(2).
       01 WS-EOF-FLAG                PIC X VALUE 'N'.
           88 WS-EOF                  VALUE 'Y'.

       01 WS-PREV-CUSIP              PIC X(9) VALUE SPACES.

       01 WS-ITEM-TALLIES.
           05 WS-ITEM-TALLY OCCURS 5.
               10 WS-IT-FOR          PIC S9(11) COMP-3.
               10 WS-IT-AGAINST      PIC S9(11) COMP-3.
               10 WS-IT-ABSTAIN      PIC S9(11) COMP-3.

       01 WS-TOTAL-VOTED-SHARES     PIC S9(11) COMP-3.
       01 WS-ITEM-IDX               PIC 9(1).
       01 WS-PASS-THRESHOLD         PIC S9(3)V99 COMP-3
           VALUE 50.00.

       01 WS-COUNTERS.
           05 WS-SECURITIES-COUNT    PIC S9(5) COMP-3 VALUE 0.
           05 WS-BALLOTS-COUNT       PIC S9(7) COMP-3 VALUE 0.
           05 WS-ITEMS-PASSED        PIC S9(5) COMP-3 VALUE 0.
           05 WS-ITEMS-FAILED        PIC S9(5) COMP-3 VALUE 0.

       01 WS-VOTE-TALLY             PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           SORT SORT-FILE
               ON ASCENDING KEY SORT-CUSIP
               USING VOTE-FILE
               GIVING VOTE-FILE
           PERFORM 1000-OPEN-FILES
           PERFORM 1100-READ-FIRST
           PERFORM 2000-PROCESS-BALLOT
               UNTIL WS-EOF
           IF WS-PREV-CUSIP NOT = SPACES
               PERFORM 3000-TALLY-AND-WRITE
           END-IF
           PERFORM 4000-CLOSE-FILES
           PERFORM 5000-DISPLAY-SUMMARY
           STOP RUN.

       1000-OPEN-FILES.
           OPEN INPUT VOTE-FILE
           OPEN OUTPUT RESULT-FILE
           MOVE 'N' TO WS-EOF-FLAG
           PERFORM 1010-RESET-TALLIES.

       1010-RESET-TALLIES.
           PERFORM VARYING WS-ITEM-IDX FROM 1 BY 1
               UNTIL WS-ITEM-IDX > 5
               MOVE 0 TO WS-IT-FOR(WS-ITEM-IDX)
               MOVE 0 TO WS-IT-AGAINST(WS-ITEM-IDX)
               MOVE 0 TO WS-IT-ABSTAIN(WS-ITEM-IDX)
           END-PERFORM.

       1100-READ-FIRST.
           READ VOTE-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ
           IF NOT WS-EOF
               MOVE VT-CUSIP TO WS-PREV-CUSIP
           END-IF.

       2000-PROCESS-BALLOT.
           IF VT-CUSIP NOT = WS-PREV-CUSIP
               PERFORM 3000-TALLY-AND-WRITE
               PERFORM 1010-RESET-TALLIES
               MOVE VT-CUSIP TO WS-PREV-CUSIP
           END-IF
           ADD 1 TO WS-BALLOTS-COUNT
           PERFORM VARYING WS-ITEM-IDX FROM 1 BY 1
               UNTIL WS-ITEM-IDX > 5
               EVALUATE TRUE
                   WHEN VT-FOR(WS-ITEM-IDX)
                       ADD VT-SHARES-HELD TO
                           WS-IT-FOR(WS-ITEM-IDX)
                   WHEN VT-AGAINST(WS-ITEM-IDX)
                       ADD VT-SHARES-HELD TO
                           WS-IT-AGAINST(WS-ITEM-IDX)
                   WHEN VT-ABSTAIN(WS-ITEM-IDX)
                       ADD VT-SHARES-HELD TO
                           WS-IT-ABSTAIN(WS-ITEM-IDX)
                   WHEN OTHER
                       CONTINUE
               END-EVALUATE
           END-PERFORM
           READ VOTE-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       3000-TALLY-AND-WRITE.
           ADD 1 TO WS-SECURITIES-COUNT
           PERFORM VARYING WS-ITEM-IDX FROM 1 BY 1
               UNTIL WS-ITEM-IDX > 5
               MOVE WS-PREV-CUSIP TO RS-CUSIP
               MOVE WS-ITEM-IDX TO RS-ITEM-NUM
               MOVE WS-IT-FOR(WS-ITEM-IDX) TO
                   RS-FOR-SHARES
               MOVE WS-IT-AGAINST(WS-ITEM-IDX) TO
                   RS-AGAINST-SHARES
               MOVE WS-IT-ABSTAIN(WS-ITEM-IDX) TO
                   RS-ABSTAIN-SHARES
               COMPUTE RS-TOTAL-SHARES =
                   WS-IT-FOR(WS-ITEM-IDX) +
                   WS-IT-AGAINST(WS-ITEM-IDX) +
                   WS-IT-ABSTAIN(WS-ITEM-IDX)
               IF RS-TOTAL-SHARES > 0
                   COMPUTE RS-FOR-PCT =
                       (WS-IT-FOR(WS-ITEM-IDX) /
                       RS-TOTAL-SHARES) * 100
                   IF RS-FOR-PCT >= WS-PASS-THRESHOLD
                       MOVE 'PASSED    ' TO RS-OUTCOME
                       ADD 1 TO WS-ITEMS-PASSED
                   ELSE
                       MOVE 'FAILED    ' TO RS-OUTCOME
                       ADD 1 TO WS-ITEMS-FAILED
                   END-IF
               ELSE
                   MOVE 0 TO RS-FOR-PCT
                   MOVE 'NO VOTES  ' TO RS-OUTCOME
               END-IF
               WRITE RESULT-RECORD
           END-PERFORM.

       4000-CLOSE-FILES.
           CLOSE VOTE-FILE
           CLOSE RESULT-FILE.

       5000-DISPLAY-SUMMARY.
           MOVE 0 TO WS-VOTE-TALLY
           INSPECT WS-PREV-CUSIP
               TALLYING WS-VOTE-TALLY FOR ALL '0'
           DISPLAY 'PROXY VOTING TABULATION COMPLETE'
           DISPLAY 'SECURITIES PROCESSED: '
               WS-SECURITIES-COUNT
           DISPLAY 'BALLOTS PROCESSED:    '
               WS-BALLOTS-COUNT
           DISPLAY 'ITEMS PASSED:         '
               WS-ITEMS-PASSED
           DISPLAY 'ITEMS FAILED:         '
               WS-ITEMS-FAILED.
