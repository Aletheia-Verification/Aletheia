       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-CLAIM-INQ.
      *================================================================
      * MANUAL REVIEW: EXEC CICS
      * Online claims inquiry screen using CICS SEND/RECEIVE MAP
      * and BMS screen interaction. Triggers MANUAL REVIEW.
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-COMM-AREA.
           05 WS-CA-CLAIM-NUM         PIC X(15).
           05 WS-CA-ACTION            PIC X(1).
               88 CA-INQUIRE          VALUE 'I'.
               88 CA-UPDATE           VALUE 'U'.
           05 WS-CA-RETURN-CODE       PIC 9(2).
       01 WS-CLAIM-DETAIL.
           05 WS-CD-CLAIM-NUM         PIC X(15).
           05 WS-CD-POLICY-NUM        PIC X(12).
           05 WS-CD-CLAIMANT          PIC X(30).
           05 WS-CD-DATE-FILED        PIC 9(8).
           05 WS-CD-AMOUNT            PIC S9(9)V99 COMP-3.
           05 WS-CD-STATUS            PIC X(2).
               88 CD-OPEN             VALUE 'OP'.
               88 CD-CLOSED           VALUE 'CL'.
               88 CD-DENIED           VALUE 'DN'.
               88 CD-PENDING          VALUE 'PN'.
           05 WS-CD-ADJUSTER          PIC X(8).
           05 WS-CD-NOTES             PIC X(60).
       01 WS-PAYMENT-SUMMARY.
           05 WS-PS-TOTAL-PAID        PIC S9(9)V99 COMP-3
               VALUE 0.
           05 WS-PS-PAYMENTS          PIC 9(3) VALUE 0.
           05 WS-PS-LAST-PAY-DATE     PIC 9(8).
           05 WS-PS-REMAINING         PIC S9(9)V99 COMP-3.
       01 WS-RESPONSE-CODE            PIC S9(8) COMP.
       01 WS-ERROR-MSG                PIC X(40).
       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-RECEIVE-INPUT
           IF CA-INQUIRE
               PERFORM 3000-READ-CLAIM
               PERFORM 4000-CALC-PAYMENTS
               PERFORM 5000-SEND-DETAIL
           ELSE
               PERFORM 6000-SEND-ERROR
           END-IF
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'CLM-2026-00042' TO WS-CA-CLAIM-NUM
           MOVE 'I' TO WS-CA-ACTION
           MOVE 0 TO WS-CA-RETURN-CODE
           INITIALIZE WS-CLAIM-DETAIL.
       2000-RECEIVE-INPUT.
           EXEC CICS RECEIVE
               MAP('CLMINQ')
               MAPSET('CLMSET')
               INTO(WS-COMM-AREA)
               RESP(WS-RESPONSE-CODE)
           END-EXEC
           IF WS-RESPONSE-CODE NOT = 0
               MOVE 'MAP RECEIVE FAILED'
                   TO WS-ERROR-MSG
               PERFORM 6000-SEND-ERROR
           END-IF.
       3000-READ-CLAIM.
           EXEC CICS READ
               FILE('CLAIMFL')
               INTO(WS-CLAIM-DETAIL)
               RIDFLD(WS-CA-CLAIM-NUM)
               RESP(WS-RESPONSE-CODE)
           END-EXEC
           IF WS-RESPONSE-CODE NOT = 0
               MOVE 'CLAIM NOT FOUND' TO WS-ERROR-MSG
               MOVE 99 TO WS-CA-RETURN-CODE
           ELSE
               MOVE 0 TO WS-CA-RETURN-CODE
           END-IF.
       4000-CALC-PAYMENTS.
           IF WS-CA-RETURN-CODE = 0
               COMPUTE WS-PS-REMAINING =
                   WS-CD-AMOUNT - WS-PS-TOTAL-PAID
               IF WS-PS-REMAINING < 0
                   MOVE 0 TO WS-PS-REMAINING
               END-IF
               EVALUATE TRUE
                   WHEN CD-OPEN
                       DISPLAY 'CLAIM STATUS: OPEN'
                   WHEN CD-CLOSED
                       DISPLAY 'CLAIM STATUS: CLOSED'
                   WHEN CD-DENIED
                       DISPLAY 'CLAIM STATUS: DENIED'
                   WHEN CD-PENDING
                       DISPLAY 'CLAIM STATUS: PENDING REVIEW'
                   WHEN OTHER
                       DISPLAY 'CLAIM STATUS: UNKNOWN'
               END-EVALUATE
           END-IF.
       5000-SEND-DETAIL.
           EXEC CICS SEND
               MAP('CLMDTL')
               MAPSET('CLMSET')
               FROM(WS-CLAIM-DETAIL)
               ERASE
               RESP(WS-RESPONSE-CODE)
           END-EXEC.
       6000-SEND-ERROR.
           DISPLAY 'ERROR: ' WS-ERROR-MSG
           EXEC CICS SEND
               MAP('CLMERR')
               MAPSET('CLMSET')
               FROM(WS-ERROR-MSG)
               ERASE
               RESP(WS-RESPONSE-CODE)
           END-EXEC.
