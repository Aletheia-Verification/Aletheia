       IDENTIFICATION DIVISION.
       PROGRAM-ID. INSPECT-CONVERTING.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATA          PIC X(20) VALUE 'Hello World abcdef'.
       01  WS-OUT           PIC X(20).
       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE WS-DATA TO WS-OUT.
           INSPECT WS-OUT CONVERTING 'abcdef' TO 'ABCDEF'.
           DISPLAY WS-OUT.
           STOP RUN.
