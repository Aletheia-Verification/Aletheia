       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-COMPL-SCREEN.
      *================================================================*
      * REGULATORY COMPLIANCE SCREENING ENGINE                         *
      * Screens customers against sanctions lists, PEP databases,      *
      * and adverse media flags. Assigns composite risk rating.        *
      *================================================================*
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-CUSTOMER.
           05 WS-CUST-ID            PIC X(10).
           05 WS-CUST-NAME          PIC X(40).
           05 WS-CUST-COUNTRY       PIC X(3).
           05 WS-CUST-DOB           PIC 9(8).
           05 WS-CUST-TYPE          PIC X(1).
               88 WS-INDIVIDUAL     VALUE 'I'.
               88 WS-CORPORATE      VALUE 'C'.
               88 WS-TRUST          VALUE 'T'.
           05 WS-CUST-INDUSTRY      PIC X(4).
           05 WS-ANNUAL-REVENUE     PIC S9(11)V99 COMP-3.
       01 WS-SCREENING-FLAGS.
           05 WS-OFAC-RESULT        PIC X VALUE 'C'.
               88 WS-OFAC-CLEAR     VALUE 'C'.
               88 WS-OFAC-PARTIAL   VALUE 'P'.
               88 WS-OFAC-EXACT     VALUE 'E'.
           05 WS-PEP-RESULT         PIC X VALUE 'N'.
               88 WS-PEP-NONE       VALUE 'N'.
               88 WS-PEP-DOMESTIC   VALUE 'D'.
               88 WS-PEP-FOREIGN    VALUE 'F'.
           05 WS-ADVERSE-MEDIA      PIC X VALUE 'N'.
               88 WS-NO-ADVERSE     VALUE 'N'.
               88 WS-HAS-ADVERSE    VALUE 'Y'.
           05 WS-DUAL-USE-FLAG      PIC X VALUE 'N'.
               88 WS-DUAL-USE       VALUE 'Y'.
       01 WS-COUNTRY-RISK-TBL.
           05 WS-CNTRY-ENTRY OCCURS 8.
               10 WS-CNTRY-CODE     PIC X(3).
               10 WS-CNTRY-RISK-LVL PIC S9(1) COMP-3.
       01 WS-SCORES.
           05 WS-OFAC-SCORE         PIC S9(3) COMP-3.
           05 WS-PEP-SCORE          PIC S9(3) COMP-3.
           05 WS-COUNTRY-SCORE      PIC S9(3) COMP-3.
           05 WS-INDUSTRY-SCORE     PIC S9(3) COMP-3.
           05 WS-MEDIA-SCORE        PIC S9(3) COMP-3.
           05 WS-REVENUE-SCORE      PIC S9(3) COMP-3.
           05 WS-COMPOSITE-SCORE    PIC S9(5) COMP-3.
       01 WS-RISK-RATING            PIC X(10).
       01 WS-ACTION-REQUIRED        PIC X(30).
       01 WS-IDX                    PIC S9(2) COMP-3.
       01 WS-FOUND-FLAG             PIC X VALUE 'N'.
           88 WS-FOUND              VALUE 'Y'.
       01 WS-EDD-REQUIRED           PIC X VALUE 'N'.
           88 WS-NEEDS-EDD          VALUE 'Y'.
       01 WS-ERR-DETAIL             PIC X(80).
       PROCEDURE DIVISION.
       0000-MAIN-CONTROL.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-SCREEN-OFAC
           PERFORM 3000-SCREEN-PEP
           PERFORM 4000-ASSESS-COUNTRY
           PERFORM 5000-ASSESS-INDUSTRY
           PERFORM 6000-ASSESS-MEDIA
           PERFORM 7000-ASSESS-REVENUE
           PERFORM 8000-CALC-COMPOSITE
               THRU 8500-DETERMINE-ACTION
           PERFORM 9000-DISPLAY-RESULT
           STOP RUN.
       1000-INITIALIZE.
           MOVE 'CUST000123' TO WS-CUST-ID
           MOVE 'ALEXANDER PETROV HOLDINGS LTD' TO
               WS-CUST-NAME
           MOVE 'RUS' TO WS-CUST-COUNTRY
           MOVE 19750815 TO WS-CUST-DOB
           MOVE 'C' TO WS-CUST-TYPE
           MOVE '2911' TO WS-CUST-INDUSTRY
           MOVE 50000000.00 TO WS-ANNUAL-REVENUE
           MOVE 'P' TO WS-OFAC-RESULT
           MOVE 'F' TO WS-PEP-RESULT
           MOVE 'Y' TO WS-ADVERSE-MEDIA
           MOVE 0 TO WS-COMPOSITE-SCORE
           MOVE SPACES TO WS-RISK-RATING
           MOVE SPACES TO WS-ACTION-REQUIRED
           MOVE SPACES TO WS-ERR-DETAIL
           PERFORM 1100-LOAD-COUNTRY-TABLE.
       1100-LOAD-COUNTRY-TABLE.
           MOVE 'USA' TO WS-CNTRY-CODE(1)
           MOVE 1 TO WS-CNTRY-RISK-LVL(1)
           MOVE 'GBR' TO WS-CNTRY-CODE(2)
           MOVE 1 TO WS-CNTRY-RISK-LVL(2)
           MOVE 'CHN' TO WS-CNTRY-CODE(3)
           MOVE 3 TO WS-CNTRY-RISK-LVL(3)
           MOVE 'RUS' TO WS-CNTRY-CODE(4)
           MOVE 5 TO WS-CNTRY-RISK-LVL(4)
           MOVE 'IRN' TO WS-CNTRY-CODE(5)
           MOVE 5 TO WS-CNTRY-RISK-LVL(5)
           MOVE 'PRK' TO WS-CNTRY-CODE(6)
           MOVE 5 TO WS-CNTRY-RISK-LVL(6)
           MOVE 'BRA' TO WS-CNTRY-CODE(7)
           MOVE 2 TO WS-CNTRY-RISK-LVL(7)
           MOVE 'NGA' TO WS-CNTRY-CODE(8)
           MOVE 4 TO WS-CNTRY-RISK-LVL(8).
       2000-SCREEN-OFAC.
           EVALUATE TRUE
               WHEN WS-OFAC-EXACT
                   MOVE 100 TO WS-OFAC-SCORE
               WHEN WS-OFAC-PARTIAL
                   MOVE 60 TO WS-OFAC-SCORE
               WHEN WS-OFAC-CLEAR
                   MOVE 0 TO WS-OFAC-SCORE
           END-EVALUATE.
       3000-SCREEN-PEP.
           EVALUATE TRUE
               WHEN WS-PEP-FOREIGN
                   MOVE 70 TO WS-PEP-SCORE
               WHEN WS-PEP-DOMESTIC
                   MOVE 40 TO WS-PEP-SCORE
               WHEN WS-PEP-NONE
                   MOVE 0 TO WS-PEP-SCORE
           END-EVALUATE.
       4000-ASSESS-COUNTRY.
           MOVE 'N' TO WS-FOUND-FLAG
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 8 OR WS-FOUND
               IF WS-CNTRY-CODE(WS-IDX) = WS-CUST-COUNTRY
                   MOVE 'Y' TO WS-FOUND-FLAG
                   COMPUTE WS-COUNTRY-SCORE =
                       WS-CNTRY-RISK-LVL(WS-IDX) * 20
               END-IF
           END-PERFORM
           IF NOT WS-FOUND
               MOVE 30 TO WS-COUNTRY-SCORE
           END-IF.
       5000-ASSESS-INDUSTRY.
           EVALUATE WS-CUST-INDUSTRY
               WHEN '2911'
                   MOVE 60 TO WS-INDUSTRY-SCORE
               WHEN '6021'
                   MOVE 30 TO WS-INDUSTRY-SCORE
               WHEN '5944'
                   MOVE 70 TO WS-INDUSTRY-SCORE
               WHEN '7993'
                   MOVE 80 TO WS-INDUSTRY-SCORE
               WHEN '5411'
                   MOVE 5 TO WS-INDUSTRY-SCORE
               WHEN OTHER
                   MOVE 20 TO WS-INDUSTRY-SCORE
           END-EVALUATE
           IF WS-DUAL-USE
               ADD 25 TO WS-INDUSTRY-SCORE
               IF WS-INDUSTRY-SCORE > 100
                   MOVE 100 TO WS-INDUSTRY-SCORE
               END-IF
           END-IF.
       6000-ASSESS-MEDIA.
           IF WS-HAS-ADVERSE
               MOVE 50 TO WS-MEDIA-SCORE
           ELSE
               MOVE 0 TO WS-MEDIA-SCORE
           END-IF.
       7000-ASSESS-REVENUE.
           EVALUATE TRUE
               WHEN WS-ANNUAL-REVENUE > 100000000
                   MOVE 10 TO WS-REVENUE-SCORE
               WHEN WS-ANNUAL-REVENUE > 10000000
                   MOVE 30 TO WS-REVENUE-SCORE
               WHEN WS-ANNUAL-REVENUE > 1000000
                   MOVE 20 TO WS-REVENUE-SCORE
               WHEN OTHER
                   MOVE 40 TO WS-REVENUE-SCORE
           END-EVALUATE.
       8000-CALC-COMPOSITE.
           COMPUTE WS-COMPOSITE-SCORE ROUNDED =
               (WS-OFAC-SCORE * 30 +
                WS-PEP-SCORE * 20 +
                WS-COUNTRY-SCORE * 20 +
                WS-INDUSTRY-SCORE * 10 +
                WS-MEDIA-SCORE * 10 +
                WS-REVENUE-SCORE * 10) / 100
           IF WS-OFAC-SCORE = 100
               MOVE 100 TO WS-COMPOSITE-SCORE
           END-IF.
       8500-DETERMINE-ACTION.
           EVALUATE TRUE
               WHEN WS-COMPOSITE-SCORE >= 80
                   MOVE 'PROHIBITED' TO WS-RISK-RATING
                   MOVE 'REJECT - ESCALATE TO BSA' TO
                       WS-ACTION-REQUIRED
               WHEN WS-COMPOSITE-SCORE >= 60
                   MOVE 'HIGH' TO WS-RISK-RATING
                   MOVE 'ENHANCED DUE DILIGENCE' TO
                       WS-ACTION-REQUIRED
                   MOVE 'Y' TO WS-EDD-REQUIRED
               WHEN WS-COMPOSITE-SCORE >= 30
                   MOVE 'MEDIUM' TO WS-RISK-RATING
                   MOVE 'STANDARD REVIEW' TO
                       WS-ACTION-REQUIRED
               WHEN OTHER
                   MOVE 'LOW' TO WS-RISK-RATING
                   MOVE 'AUTO APPROVE' TO
                       WS-ACTION-REQUIRED
           END-EVALUATE
           IF WS-COMPOSITE-SCORE >= 60
               STRING 'RISK FACTORS: OFAC='
                   DELIMITED BY SIZE
                   WS-OFAC-SCORE DELIMITED BY SIZE
                   ' PEP=' DELIMITED BY SIZE
                   WS-PEP-SCORE DELIMITED BY SIZE
                   ' COUNTRY=' DELIMITED BY SIZE
                   WS-COUNTRY-SCORE DELIMITED BY SIZE
                   INTO WS-ERR-DETAIL
           END-IF.
       9000-DISPLAY-RESULT.
           DISPLAY '========================================='
           DISPLAY 'COMPLIANCE SCREENING RESULT'
           DISPLAY '========================================='
           DISPLAY 'CUSTOMER:     ' WS-CUST-ID
           DISPLAY 'NAME:         ' WS-CUST-NAME
           DISPLAY 'COUNTRY:      ' WS-CUST-COUNTRY
           DISPLAY 'TYPE:         ' WS-CUST-TYPE
           DISPLAY 'OFAC SCORE:   ' WS-OFAC-SCORE
           DISPLAY 'PEP SCORE:    ' WS-PEP-SCORE
           DISPLAY 'COUNTRY:      ' WS-COUNTRY-SCORE
           DISPLAY 'INDUSTRY:     ' WS-INDUSTRY-SCORE
           DISPLAY 'MEDIA:        ' WS-MEDIA-SCORE
           DISPLAY 'COMPOSITE:    ' WS-COMPOSITE-SCORE
           DISPLAY 'RISK RATING:  ' WS-RISK-RATING
           DISPLAY 'ACTION:       ' WS-ACTION-REQUIRED
           IF WS-NEEDS-EDD
               DISPLAY 'EDD REQUIRED'
           END-IF
           IF WS-ERR-DETAIL NOT = SPACES
               DISPLAY WS-ERR-DETAIL
           END-IF
           DISPLAY '========================================='.
