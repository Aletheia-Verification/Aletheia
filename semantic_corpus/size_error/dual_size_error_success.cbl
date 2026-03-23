       IDENTIFICATION DIVISION.
       PROGRAM-ID. DUAL-OSE-SUCCESS.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A         PIC 9(2).
       01  WS-B         PIC 9(2).
       01  WS-RESULT    PIC 9(2).
       01  WS-FLAG      PIC X(1) VALUE SPACES.
       PROCEDURE DIVISION.
       0000-MAIN.
           ADD WS-A WS-B GIVING WS-RESULT
               ON SIZE ERROR
                   MOVE 'E' TO WS-FLAG
               NOT ON SIZE ERROR
                   MOVE 'S' TO WS-FLAG
           END-ADD.
           STOP RUN.
