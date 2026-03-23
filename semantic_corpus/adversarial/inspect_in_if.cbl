       IDENTIFICATION DIVISION.
       PROGRAM-ID. INSP-IN-IF.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-FLAG          PIC X(1).
       01  WS-STR           PIC X(6).
       01  WS-CNT           PIC 9(3) VALUE 0.
       PROCEDURE DIVISION.
       0000-MAIN.
           IF WS-FLAG = 'Y'
               INSPECT WS-STR TALLYING WS-CNT
                   FOR ALL 'A'
           END-IF.
           STOP RUN.
