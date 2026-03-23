       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-CICS-KYC-INQUIRY.
      *---------------------------------------------------------------
      * MANUAL REVIEW: Contains EXEC CICS commands for online
      * KYC inquiry screens at teller stations.
      *---------------------------------------------------------------

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-COMM-AREA.
           05 WS-CUST-ID              PIC X(12).
           05 WS-CUST-NAME            PIC X(35).
           05 WS-KYC-STATUS           PIC X(2).
               88 WS-KYC-APPROVED     VALUE 'AP'.
               88 WS-KYC-PENDING      VALUE 'PD'.
               88 WS-KYC-EXPIRED      VALUE 'EX'.
           05 WS-DOC-COUNT            PIC 9(2).
           05 WS-LAST-REVIEW-DATE     PIC 9(8).
           05 WS-NEXT-REVIEW-DATE     PIC 9(8).
           05 WS-RISK-LEVEL           PIC X(1).
               88 WS-HIGH-RISK        VALUE 'H'.
               88 WS-MED-RISK         VALUE 'M'.
               88 WS-LOW-RISK         VALUE 'L'.

       01 WS-SCREEN-FIELDS.
           05 WS-INPUT-CUST-ID        PIC X(12).
           05 WS-INPUT-ACTION         PIC X(2).
               88 WS-ACTION-VIEW      VALUE 'VW'.
               88 WS-ACTION-UPDATE    VALUE 'UP'.
               88 WS-ACTION-REFRESH   VALUE 'RF'.
           05 WS-MESSAGE-LINE         PIC X(60).

       01 WS-TELLER-DATA.
           05 WS-TELLER-ID            PIC X(8).
           05 WS-BRANCH-CODE          PIC X(4).

       01 WS-ERROR-FLAG               PIC X VALUE 'N'.
           88 WS-HAS-ERROR            VALUE 'Y'.

       01 WS-RESP-CODE                PIC S9(8) COMP.
       01 WS-EIBTRNID                 PIC X(4).
       01 WS-EIBTIME                  PIC S9(7) COMP-3.

       01 WS-DISPLAY-BUF              PIC X(60).
       01 WS-DISPLAY-PTR              PIC 9(3).
       01 WS-TALLY-WORK               PIC 9(3).

       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-RECEIVE-SCREEN
           PERFORM 3000-PROCESS-REQUEST
           PERFORM 4000-SEND-RESPONSE
           STOP RUN.

       1000-INITIALIZE.
           MOVE 'N' TO WS-ERROR-FLAG
           MOVE SPACES TO WS-MESSAGE-LINE.

       2000-RECEIVE-SCREEN.
           EXEC CICS RECEIVE
               MAP('KYCMAP')
               MAPSET('KYCSET')
               INTO(WS-SCREEN-FIELDS)
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE NOT = 0
               MOVE 'Y' TO WS-ERROR-FLAG
               MOVE 'SCREEN RECEIVE FAILED'
                   TO WS-MESSAGE-LINE
           END-IF.

       3000-PROCESS-REQUEST.
           IF NOT WS-HAS-ERROR
               MOVE WS-INPUT-CUST-ID TO WS-CUST-ID
               EVALUATE TRUE
                   WHEN WS-ACTION-VIEW
                       PERFORM 3100-READ-KYC-DATA
                   WHEN WS-ACTION-UPDATE
                       PERFORM 3200-UPDATE-KYC-DATA
                   WHEN WS-ACTION-REFRESH
                       PERFORM 3300-REFRESH-KYC
                   WHEN OTHER
                       MOVE 'Y' TO WS-ERROR-FLAG
                       MOVE SPACES TO WS-DISPLAY-BUF
                       MOVE 1 TO WS-DISPLAY-PTR
                       STRING 'INVALID ACTION: '
                           WS-INPUT-ACTION
                           DELIMITED BY SIZE
                           INTO WS-DISPLAY-BUF
                           WITH POINTER WS-DISPLAY-PTR
                       END-STRING
                       MOVE WS-DISPLAY-BUF TO
                           WS-MESSAGE-LINE
               END-EVALUATE
           END-IF.

       3100-READ-KYC-DATA.
           EXEC CICS READ
               FILE('KYCFILE')
               INTO(WS-COMM-AREA)
               RIDFLD(WS-CUST-ID)
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE NOT = 0
               MOVE 'Y' TO WS-ERROR-FLAG
               MOVE 'CUSTOMER NOT FOUND' TO
                   WS-MESSAGE-LINE
           ELSE
               PERFORM 3110-CHECK-EXPIRY
               MOVE SPACES TO WS-DISPLAY-BUF
               MOVE 1 TO WS-DISPLAY-PTR
               STRING 'KYC STATUS: ' WS-KYC-STATUS
                   ' RISK: ' WS-RISK-LEVEL
                   DELIMITED BY SIZE
                   INTO WS-DISPLAY-BUF
                   WITH POINTER WS-DISPLAY-PTR
               END-STRING
               MOVE WS-DISPLAY-BUF TO WS-MESSAGE-LINE
           END-IF.

       3110-CHECK-EXPIRY.
           MOVE 0 TO WS-TALLY-WORK
           INSPECT WS-CUST-NAME
               TALLYING WS-TALLY-WORK FOR ALL ' '
           EVALUATE TRUE
               WHEN WS-KYC-APPROVED
                   IF WS-HIGH-RISK
                       DISPLAY 'HIGH RISK CUSTOMER - '
                           'ENHANCED DUE DILIGENCE'
                   END-IF
               WHEN WS-KYC-PENDING
                   DISPLAY 'KYC PENDING - RESTRICT TXNS'
               WHEN WS-KYC-EXPIRED
                   DISPLAY 'KYC EXPIRED - BLOCK ACCOUNT'
               WHEN OTHER
                   DISPLAY 'UNKNOWN KYC STATUS'
           END-EVALUATE.

       3200-UPDATE-KYC-DATA.
           EXEC CICS READ
               FILE('KYCFILE')
               INTO(WS-COMM-AREA)
               RIDFLD(WS-CUST-ID)
               UPDATE
               RESP(WS-RESP-CODE)
           END-EXEC
           IF WS-RESP-CODE = 0
               ACCEPT WS-LAST-REVIEW-DATE FROM DATE YYYYMMDD
               EXEC CICS REWRITE
                   FILE('KYCFILE')
                   FROM(WS-COMM-AREA)
                   RESP(WS-RESP-CODE)
               END-EXEC
               IF WS-RESP-CODE = 0
                   MOVE 'KYC RECORD UPDATED'
                       TO WS-MESSAGE-LINE
               ELSE
                   MOVE 'UPDATE FAILED' TO WS-MESSAGE-LINE
               END-IF
           ELSE
               MOVE 'READ FOR UPDATE FAILED'
                   TO WS-MESSAGE-LINE
           END-IF.

       3300-REFRESH-KYC.
           EXEC CICS STARTBR
               FILE('KYCFILE')
               RIDFLD(WS-CUST-ID)
               RESP(WS-RESP-CODE)
           END-EXEC
           DISPLAY 'KYC REFRESH STARTED FOR ' WS-CUST-ID
           EXEC CICS ENDBR
               FILE('KYCFILE')
               RESP(WS-RESP-CODE)
           END-EXEC
           MOVE 'KYC REFRESH INITIATED'
               TO WS-MESSAGE-LINE.

       4000-SEND-RESPONSE.
           EXEC CICS SEND
               MAP('KYCMAP')
               MAPSET('KYCSET')
               FROM(WS-SCREEN-FIELDS)
               ERASE
               RESP(WS-RESP-CODE)
           END-EXEC
           DISPLAY 'SCREEN SENT TO TELLER '
               WS-TELLER-ID.
