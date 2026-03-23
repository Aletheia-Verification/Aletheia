       IDENTIFICATION DIVISION.
       PROGRAM-ID. FRAUD-BIN-LOOKUP.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CARD-NUM                PIC X(16).
       01 WS-BIN                     PIC X(6).
       01 WS-BIN-TABLE.
           05 WS-BIN-ENTRY OCCURS 10.
               10 WS-BE-BIN          PIC X(6).
               10 WS-BE-ISSUER       PIC X(20).
               10 WS-BE-NETWORK      PIC X(4).
               10 WS-BE-COUNTRY      PIC X(3).
               10 WS-BE-TYPE         PIC X(1).
       01 WS-BE-IDX                  PIC 9(2).
       01 WS-BIN-COUNT               PIC 9(2).
       01 WS-FOUND-FLAG              PIC X VALUE 'N'.
           88 WS-BIN-FOUND           VALUE 'Y'.
       01 WS-MATCH-IDX               PIC 9(2).
       01 WS-CARD-TYPE               PIC X(1).
           88 WS-CREDIT              VALUE 'C'.
           88 WS-DEBIT               VALUE 'D'.
           88 WS-PREPAID             VALUE 'P'.
       01 WS-NETWORK                 PIC X(4).
       01 WS-ISSUER-NAME             PIC X(20).
       01 WS-ISSUER-COUNTRY          PIC X(3).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-EXTRACT-BIN
           PERFORM 2000-SEARCH-TABLE
           PERFORM 3000-DISPLAY-RESULTS
           STOP RUN.
       1000-EXTRACT-BIN.
           MOVE WS-CARD-NUM(1:6) TO WS-BIN
           MOVE 'N' TO WS-FOUND-FLAG.
       2000-SEARCH-TABLE.
           PERFORM VARYING WS-BE-IDX FROM 1 BY 1
               UNTIL WS-BE-IDX > WS-BIN-COUNT
               OR WS-BIN-FOUND
               IF WS-BE-BIN(WS-BE-IDX) = WS-BIN
                   MOVE 'Y' TO WS-FOUND-FLAG
                   MOVE WS-BE-IDX TO WS-MATCH-IDX
                   MOVE WS-BE-ISSUER(WS-MATCH-IDX) TO
                       WS-ISSUER-NAME
                   MOVE WS-BE-NETWORK(WS-MATCH-IDX) TO
                       WS-NETWORK
                   MOVE WS-BE-COUNTRY(WS-MATCH-IDX) TO
                       WS-ISSUER-COUNTRY
                   MOVE WS-BE-TYPE(WS-MATCH-IDX) TO
                       WS-CARD-TYPE
               END-IF
           END-PERFORM.
       3000-DISPLAY-RESULTS.
           DISPLAY 'BIN LOOKUP RESULT'
           DISPLAY '================='
           DISPLAY 'CARD BIN:    ' WS-BIN
           IF WS-BIN-FOUND
               DISPLAY 'ISSUER:      ' WS-ISSUER-NAME
               DISPLAY 'NETWORK:     ' WS-NETWORK
               DISPLAY 'COUNTRY:     ' WS-ISSUER-COUNTRY
               IF WS-CREDIT
                   DISPLAY 'TYPE: CREDIT'
               END-IF
               IF WS-DEBIT
                   DISPLAY 'TYPE: DEBIT'
               END-IF
               IF WS-PREPAID
                   DISPLAY 'TYPE: PREPAID'
               END-IF
           ELSE
               DISPLAY 'STATUS: BIN NOT FOUND'
           END-IF.
