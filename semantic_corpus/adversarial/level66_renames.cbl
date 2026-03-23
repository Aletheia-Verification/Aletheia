       IDENTIFICATION DIVISION.
       PROGRAM-ID. RENAMES-TEST.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-RECORD.
           05  WS-PART-A       PIC X(3).
           05  WS-PART-B       PIC X(3).
       66  WS-ALIAS RENAMES WS-PART-A THRU WS-PART-B.
       01  WS-OUT              PIC X(6).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE 'ABC' TO WS-PART-A.
           MOVE 'DEF' TO WS-PART-B.
           MOVE WS-ALIAS TO WS-OUT.
           STOP RUN.
