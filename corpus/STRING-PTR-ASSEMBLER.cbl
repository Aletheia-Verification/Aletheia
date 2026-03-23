       IDENTIFICATION DIVISION.
       PROGRAM-ID. STRING-PTR-ASSEMBLER.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-BUFFER                  PIC X(200).
       01 WS-PTR                     PIC 9(3) VALUE 1.
       01 WS-HEADER-LINE             PIC X(40).
       01 WS-DETAIL-LINE             PIC X(40).
       01 WS-FOOTER-LINE             PIC X(40).
       01 WS-ACCT-NUM                PIC X(12).
       01 WS-AMOUNT                  PIC X(12).
       01 WS-DATE-FIELD              PIC X(10).
       01 WS-SEPARATOR               PIC X VALUE '|'.
       01 WS-MSG-TYPE                PIC X(1).
           88 WS-TYPE-HEADER         VALUE 'H'.
           88 WS-TYPE-DETAIL         VALUE 'D'.
           88 WS-TYPE-FOOTER         VALUE 'F'.
       01 WS-FINAL-LENGTH            PIC 9(3).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-ASSEMBLE-HEADER
           PERFORM 3000-ASSEMBLE-DETAIL
           PERFORM 4000-ASSEMBLE-FOOTER
           PERFORM 5000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 1 TO WS-PTR
           MOVE SPACES TO WS-BUFFER.
       2000-ASSEMBLE-HEADER.
           STRING 'HDR' DELIMITED BY SIZE
                  WS-SEPARATOR DELIMITED BY SIZE
                  WS-DATE-FIELD DELIMITED BY SIZE
                  WS-SEPARATOR DELIMITED BY SIZE
                  INTO WS-BUFFER
                  WITH POINTER WS-PTR
           END-STRING.
       3000-ASSEMBLE-DETAIL.
           STRING 'DTL' DELIMITED BY SIZE
                  WS-SEPARATOR DELIMITED BY SIZE
                  WS-ACCT-NUM DELIMITED BY SIZE
                  WS-SEPARATOR DELIMITED BY SIZE
                  WS-AMOUNT DELIMITED BY SIZE
                  WS-SEPARATOR DELIMITED BY SIZE
                  INTO WS-BUFFER
                  WITH POINTER WS-PTR
           END-STRING.
       4000-ASSEMBLE-FOOTER.
           STRING 'FTR' DELIMITED BY SIZE
                  WS-SEPARATOR DELIMITED BY SIZE
                  'END' DELIMITED BY SIZE
                  INTO WS-BUFFER
                  WITH POINTER WS-PTR
           END-STRING
           COMPUTE WS-FINAL-LENGTH = WS-PTR - 1.
       5000-DISPLAY-RESULTS.
           DISPLAY 'STRING POINTER ASSEMBLY'
           DISPLAY '======================='
           DISPLAY 'BUFFER:  ' WS-BUFFER
           DISPLAY 'LENGTH:  ' WS-FINAL-LENGTH
           DISPLAY 'POINTER: ' WS-PTR.
