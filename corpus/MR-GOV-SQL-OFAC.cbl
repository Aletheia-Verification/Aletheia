       IDENTIFICATION DIVISION.
       PROGRAM-ID. MR-GOV-SQL-OFAC.
      *================================================================
      * OFAC SDN Database Refresh via EXEC SQL
      * Reads updated SDN entries from DB2, validates records,
      * and updates local screening tables. (MANUAL REVIEW)
      *================================================================
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-SQLCODE                   PIC S9(9) COMP-3.
       01 WS-SDN-RECORD.
           05 WS-SDN-UID              PIC 9(8).
           05 WS-SDN-NAME             PIC X(40).
           05 WS-SDN-TYPE             PIC X(10).
               88 WS-INDIVIDUAL       VALUE 'INDIVIDUAL'.
               88 WS-ENTITY           VALUE 'ENTITY    '.
               88 WS-VESSEL           VALUE 'VESSEL    '.
           05 WS-SDN-PROGRAM          PIC X(15).
           05 WS-SDN-COUNTRY          PIC X(3).
           05 WS-SDN-TITLE            PIC X(20).
           05 WS-SDN-REMARKS          PIC X(60).
       01 WS-ALIAS-DATA.
           05 WS-ALIAS-COUNT          PIC 9(2).
           05 WS-ALIAS-NAME OCCURS 5.
               10 WS-AL-NAME          PIC X(40).
               10 WS-AL-TYPE          PIC X(3).
       01 WS-VALIDATION.
           05 WS-VALID-FLAG           PIC X(1).
               88 WS-REC-VALID        VALUE 'Y'.
               88 WS-REC-INVALID      VALUE 'N'.
           05 WS-SPACE-COUNT          PIC 9(3).
       01 WS-COUNTERS.
           05 WS-TOTAL-READ           PIC 9(6).
           05 WS-TOTAL-INSERTED       PIC 9(6).
           05 WS-TOTAL-UPDATED        PIC 9(6).
           05 WS-TOTAL-SKIPPED        PIC 9(6).
           05 WS-TOTAL-ERRORS         PIC 9(6).
       01 WS-BATCH-FIELDS.
           05 WS-BATCH-ID             PIC 9(8).
           05 WS-BATCH-DATE           PIC 9(8).
           05 WS-COMMIT-INTERVAL      PIC 9(4) VALUE 500.
           05 WS-SINCE-COMMIT         PIC 9(4).
       01 WS-EOF-FLAG                  PIC X VALUE 'N'.
           88 WS-EOF                   VALUE 'Y'.
       01 WS-PROCESS-DATE             PIC 9(8).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-OPEN-CURSOR
           PERFORM 3000-PROCESS-RECORDS
               UNTIL WS-EOF
           PERFORM 4000-FINAL-COMMIT
           PERFORM 5000-CLOSE-CURSOR
           PERFORM 6000-DISPLAY-SUMMARY
           STOP RUN.
       1000-INITIALIZE.
           ACCEPT WS-PROCESS-DATE FROM DATE YYYYMMDD
           MOVE WS-PROCESS-DATE TO WS-BATCH-DATE
           MOVE 0 TO WS-TOTAL-READ
           MOVE 0 TO WS-TOTAL-INSERTED
           MOVE 0 TO WS-TOTAL-UPDATED
           MOVE 0 TO WS-TOTAL-SKIPPED
           MOVE 0 TO WS-TOTAL-ERRORS
           MOVE 0 TO WS-SINCE-COMMIT.
       2000-OPEN-CURSOR.
           EXEC SQL
               DECLARE SDN_CUR CURSOR FOR
               SELECT SDN_UID, SDN_NAME, SDN_TYPE,
                      PROGRAM_CODE, COUNTRY,
                      TITLE, REMARKS
               FROM OFAC_SDN_STAGING
               WHERE BATCH_DATE = :WS-BATCH-DATE
               ORDER BY SDN_UID
           END-EXEC
           EXEC SQL
               OPEN SDN_CUR
           END-EXEC
           IF WS-SQLCODE NOT = 0
               DISPLAY "OPEN CURSOR ERROR: " WS-SQLCODE
               MOVE 'Y' TO WS-EOF-FLAG
           END-IF.
       3000-PROCESS-RECORDS.
           EXEC SQL
               FETCH SDN_CUR
               INTO :WS-SDN-UID, :WS-SDN-NAME,
                    :WS-SDN-TYPE, :WS-SDN-PROGRAM,
                    :WS-SDN-COUNTRY, :WS-SDN-TITLE,
                    :WS-SDN-REMARKS
           END-EXEC
           EVALUATE WS-SQLCODE
               WHEN 0
                   ADD 1 TO WS-TOTAL-READ
                   PERFORM 3100-VALIDATE-RECORD
                   IF WS-REC-VALID
                       PERFORM 3200-UPSERT-RECORD
                   ELSE
                       ADD 1 TO WS-TOTAL-SKIPPED
                   END-IF
                   PERFORM 3300-CHECK-COMMIT
               WHEN 100
                   MOVE 'Y' TO WS-EOF-FLAG
               WHEN OTHER
                   ADD 1 TO WS-TOTAL-ERRORS
                   DISPLAY "FETCH ERROR: " WS-SQLCODE
           END-EVALUATE.
       3100-VALIDATE-RECORD.
           SET WS-REC-VALID TO TRUE
           MOVE 0 TO WS-SPACE-COUNT
           INSPECT WS-SDN-NAME
               TALLYING WS-SPACE-COUNT FOR ALL SPACES
           IF WS-SPACE-COUNT >= 40
               SET WS-REC-INVALID TO TRUE
           END-IF
           IF WS-SDN-UID = 0
               SET WS-REC-INVALID TO TRUE
           END-IF.
       3200-UPSERT-RECORD.
           EXEC SQL
               UPDATE OFAC_SDN_ACTIVE
               SET SDN_NAME = :WS-SDN-NAME,
                   SDN_TYPE = :WS-SDN-TYPE,
                   PROGRAM_CODE = :WS-SDN-PROGRAM,
                   COUNTRY = :WS-SDN-COUNTRY,
                   LAST_UPDATE = :WS-BATCH-DATE
               WHERE SDN_UID = :WS-SDN-UID
           END-EXEC
           IF WS-SQLCODE = 100
               EXEC SQL
                   INSERT INTO OFAC_SDN_ACTIVE
                   (SDN_UID, SDN_NAME, SDN_TYPE,
                    PROGRAM_CODE, COUNTRY, LAST_UPDATE)
                   VALUES
                   (:WS-SDN-UID, :WS-SDN-NAME,
                    :WS-SDN-TYPE, :WS-SDN-PROGRAM,
                    :WS-SDN-COUNTRY, :WS-BATCH-DATE)
               END-EXEC
               ADD 1 TO WS-TOTAL-INSERTED
           ELSE IF WS-SQLCODE = 0
               ADD 1 TO WS-TOTAL-UPDATED
           ELSE
               ADD 1 TO WS-TOTAL-ERRORS
           END-IF.
       3300-CHECK-COMMIT.
           ADD 1 TO WS-SINCE-COMMIT
           IF WS-SINCE-COMMIT >= WS-COMMIT-INTERVAL
               EXEC SQL COMMIT END-EXEC
               MOVE 0 TO WS-SINCE-COMMIT
           END-IF.
       4000-FINAL-COMMIT.
           IF WS-SINCE-COMMIT > 0
               EXEC SQL COMMIT END-EXEC
           END-IF.
       5000-CLOSE-CURSOR.
           EXEC SQL CLOSE SDN_CUR END-EXEC.
       6000-DISPLAY-SUMMARY.
           DISPLAY "OFAC SDN REFRESH COMPLETE"
           DISPLAY "BATCH: " WS-BATCH-ID
           DISPLAY "DATE: " WS-BATCH-DATE
           DISPLAY "READ: " WS-TOTAL-READ
           DISPLAY "INSERTED: " WS-TOTAL-INSERTED
           DISPLAY "UPDATED: " WS-TOTAL-UPDATED
           DISPLAY "SKIPPED: " WS-TOTAL-SKIPPED
           DISPLAY "ERRORS: " WS-TOTAL-ERRORS.
