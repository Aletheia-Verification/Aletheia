       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-GOV-CICS-FILING.
      *================================================================
      * Government Regulatory Filing via CICS
      * Online filing submission for BSA/CTR with CICS
      * queue management and map I/O. (MANUAL REVIEW - CICS)
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-COMMAREA.
           05 WS-TRANS-CODE           PIC X(4).
           05 WS-USER-ID              PIC X(8).
           05 WS-RETURN-CODE          PIC X(2).
       01 WS-FILING-DATA.
           05 WS-FILING-TYPE          PIC X(3).
               88 WS-CTR-FILING       VALUE 'CTR'.
               88 WS-SAR-FILING       VALUE 'SAR'.
               88 WS-CMIR-FILING      VALUE 'CMR'.
           05 WS-FILING-ID            PIC 9(10).
           05 WS-FILER-EIN            PIC X(9).
           05 WS-FILER-NAME           PIC X(30).
       01 WS-SUBJECT-DATA.
           05 WS-SUBJ-NAME            PIC X(30).
           05 WS-SUBJ-TIN             PIC X(9).
           05 WS-SUBJ-DOB             PIC 9(8).
           05 WS-TXN-AMOUNT           PIC S9(13)V99 COMP-3.
           05 WS-TXN-DATE             PIC 9(8).
       01 WS-VALIDATION-FIELDS.
           05 WS-ALL-VALID            PIC X(1).
               88 WS-VALID            VALUE 'Y'.
               88 WS-INVALID          VALUE 'N'.
           05 WS-ERROR-COUNT          PIC 9(2).
           05 WS-ERROR-LIST.
               10 WS-ERR-MSG OCCURS 5.
                   15 WS-ERR-TEXT     PIC X(40).
       01 WS-QUEUE-FIELDS.
           05 WS-QUEUE-NAME           PIC X(8).
           05 WS-QUEUE-ITEM           PIC 9(4).
       01 WS-FILING-STATUS            PIC X(1).
           88 WS-SUBMITTED            VALUE 'S'.
           88 WS-REJECTED             VALUE 'R'.
           88 WS-PENDING              VALUE 'P'.
       01 WS-MAP-OUTPUT.
           05 WS-SCREEN-MSG           PIC X(60).
           05 WS-STATUS-MSG           PIC X(30).
       01 WS-RESPONSE                 PIC S9(8) COMP.
       01 WS-ERR-IDX                  PIC 9(2).
       01 WS-COUNTERS.
           05 WS-FILINGS-TODAY        PIC 9(5).
           05 WS-FILINGS-REJECTED     PIC 9(5).
       01 WS-PROCESS-DATE             PIC 9(8).
       01 WS-SPACE-COUNT              PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-RECEIVE-INPUT
           PERFORM 3000-VALIDATE-FILING
           IF WS-VALID
               PERFORM 4000-SUBMIT-FILING
           ELSE
               PERFORM 5000-REJECT-FILING
           END-IF
           PERFORM 6000-SEND-RESPONSE
           EXEC CICS RETURN
               TRANSID('BSAF')
               COMMAREA(WS-COMMAREA)
           END-EXEC.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           SET WS-VALID TO TRUE
           MOVE 0 TO WS-ERROR-COUNT
           SET WS-PENDING TO TRUE.
       2000-RECEIVE-INPUT.
           EXEC CICS RECEIVE
               MAP('FILEMAP')
               MAPSET('FILESET')
               INTO(WS-FILING-DATA)
               RESP(WS-RESPONSE)
           END-EXEC
           IF WS-RESPONSE NOT = 0
               SET WS-INVALID TO TRUE
               MOVE "MAP RECEIVE FAILED"
                   TO WS-ERR-TEXT(1)
               ADD 1 TO WS-ERROR-COUNT
           END-IF.
       3000-VALIDATE-FILING.
           IF WS-FILER-EIN = SPACES
               ADD 1 TO WS-ERROR-COUNT
               MOVE "FILER EIN REQUIRED"
                   TO WS-ERR-TEXT(WS-ERROR-COUNT)
               SET WS-INVALID TO TRUE
           END-IF
           MOVE 0 TO WS-SPACE-COUNT
           INSPECT WS-SUBJ-NAME
               TALLYING WS-SPACE-COUNT FOR ALL SPACES
           IF WS-SPACE-COUNT >= 30
               ADD 1 TO WS-ERROR-COUNT
               MOVE "SUBJECT NAME REQUIRED"
                   TO WS-ERR-TEXT(WS-ERROR-COUNT)
               SET WS-INVALID TO TRUE
           END-IF
           IF WS-TXN-AMOUNT <= 0
               ADD 1 TO WS-ERROR-COUNT
               MOVE "AMOUNT MUST BE POSITIVE"
                   TO WS-ERR-TEXT(WS-ERROR-COUNT)
               SET WS-INVALID TO TRUE
           END-IF
           IF WS-CTR-FILING
           AND WS-TXN-AMOUNT < 10000.01
               ADD 1 TO WS-ERROR-COUNT
               MOVE "CTR REQ AMT > $10,000"
                   TO WS-ERR-TEXT(WS-ERROR-COUNT)
               SET WS-INVALID TO TRUE
           END-IF.
       4000-SUBMIT-FILING.
           ADD 1 TO WS-FILING-ID
           MOVE "BSAQUEUE" TO WS-QUEUE-NAME
           EXEC CICS WRITEQ TS
               QUEUE(WS-QUEUE-NAME)
               FROM(WS-FILING-DATA)
               ITEM(WS-QUEUE-ITEM)
               RESP(WS-RESPONSE)
           END-EXEC
           IF WS-RESPONSE = 0
               SET WS-SUBMITTED TO TRUE
               ADD 1 TO WS-FILINGS-TODAY
               MOVE "FILING SUBMITTED SUCCESSFULLY"
                   TO WS-SCREEN-MSG
               MOVE '00' TO WS-RETURN-CODE
           ELSE
               SET WS-REJECTED TO TRUE
               MOVE "QUEUE WRITE FAILED"
                   TO WS-SCREEN-MSG
               MOVE 'QF' TO WS-RETURN-CODE
           END-IF.
       5000-REJECT-FILING.
           SET WS-REJECTED TO TRUE
           ADD 1 TO WS-FILINGS-REJECTED
           MOVE "FILING REJECTED - SEE ERRORS"
               TO WS-SCREEN-MSG
           MOVE 'VE' TO WS-RETURN-CODE
           DISPLAY "ERRORS:"
           PERFORM VARYING WS-ERR-IDX FROM 1 BY 1
               UNTIL WS-ERR-IDX > WS-ERROR-COUNT
               DISPLAY "  " WS-ERR-TEXT(WS-ERR-IDX)
           END-PERFORM.
       6000-SEND-RESPONSE.
           EXEC CICS SEND
               MAP('FILEMAP')
               MAPSET('FILESET')
               FROM(WS-MAP-OUTPUT)
               RESP(WS-RESPONSE)
           END-EXEC.
