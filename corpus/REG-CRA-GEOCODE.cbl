       IDENTIFICATION DIVISION.
       PROGRAM-ID. REG-CRA-GEOCODE.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-ADDRESS-DATA.
           05 WS-STREET              PIC X(40).
           05 WS-CITY                PIC X(25).
           05 WS-STATE               PIC X(2).
           05 WS-ZIP                 PIC X(10).
       01 WS-CENSUS-DATA.
           05 WS-STATE-FIPS          PIC X(2).
           05 WS-COUNTY-FIPS         PIC X(3).
           05 WS-TRACT               PIC X(6).
           05 WS-MSA-CODE            PIC X(5).
       01 WS-CRA-FIELDS.
           05 WS-INCOME-LEVEL        PIC X(1).
               88 WS-LOW-INCOME      VALUE 'L'.
               88 WS-MODERATE        VALUE 'M'.
               88 WS-MIDDLE          VALUE 'I'.
               88 WS-UPPER           VALUE 'U'.
           05 WS-MEDIAN-INCOME       PIC S9(7)V99 COMP-3.
           05 WS-AREA-MEDIAN         PIC S9(7)V99 COMP-3.
           05 WS-INCOME-PCT          PIC S9(3)V99 COMP-3.
       01 WS-LOAN-AMOUNT             PIC S9(9)V99 COMP-3.
       01 WS-LOAN-PURPOSE            PIC X(1).
           88 WS-PURCHASE            VALUE 'P'.
           88 WS-REFINANCE           VALUE 'R'.
           88 WS-HOME-IMPROVE        VALUE 'I'.
       01 WS-CRA-CREDIT              PIC X VALUE 'N'.
           88 WS-GETS-CRA-CREDIT     VALUE 'Y'.
       01 WS-GEOCODE-MSG             PIC X(60).
       PROCEDURE DIVISION.
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-CALC-INCOME-PCT
           PERFORM 3000-CLASSIFY-TRACT
           PERFORM 4000-CHECK-CRA-CREDIT
           PERFORM 5000-BUILD-GEOCODE
           PERFORM 6000-DISPLAY-RESULTS
           STOP RUN.
       1000-INITIALIZE.
           MOVE 0 TO WS-INCOME-PCT
           MOVE 'N' TO WS-CRA-CREDIT.
       2000-CALC-INCOME-PCT.
           IF WS-AREA-MEDIAN > 0
               COMPUTE WS-INCOME-PCT =
                   (WS-MEDIAN-INCOME / WS-AREA-MEDIAN)
                   * 100
           END-IF.
       3000-CLASSIFY-TRACT.
           EVALUATE TRUE
               WHEN WS-INCOME-PCT < 50
                   SET WS-LOW-INCOME TO TRUE
               WHEN WS-INCOME-PCT < 80
                   SET WS-MODERATE TO TRUE
               WHEN WS-INCOME-PCT < 120
                   SET WS-MIDDLE TO TRUE
               WHEN OTHER
                   SET WS-UPPER TO TRUE
           END-EVALUATE.
       4000-CHECK-CRA-CREDIT.
           IF WS-LOW-INCOME OR WS-MODERATE
               MOVE 'Y' TO WS-CRA-CREDIT
           END-IF
           IF WS-PURCHASE
               IF WS-LOAN-AMOUNT <= 250000
                   IF WS-MODERATE
                       MOVE 'Y' TO WS-CRA-CREDIT
                   END-IF
               END-IF
           END-IF.
       5000-BUILD-GEOCODE.
           STRING WS-STATE-FIPS DELIMITED BY SIZE
                  WS-COUNTY-FIPS DELIMITED BY SIZE
                  WS-TRACT DELIMITED BY SIZE
                  INTO WS-GEOCODE-MSG
           END-STRING.
       6000-DISPLAY-RESULTS.
           DISPLAY 'CRA GEOCODING REPORT'
           DISPLAY '===================='
           DISPLAY 'ADDRESS:     ' WS-STREET
           DISPLAY 'CITY/ST:     ' WS-CITY ' ' WS-STATE
           DISPLAY 'ZIP:         ' WS-ZIP
           DISPLAY 'CENSUS TRACT:' WS-GEOCODE-MSG
           DISPLAY 'INCOME PCT:  ' WS-INCOME-PCT
           IF WS-LOW-INCOME
               DISPLAY 'INCOME: LOW'
           END-IF
           IF WS-MODERATE
               DISPLAY 'INCOME: MODERATE'
           END-IF
           IF WS-MIDDLE
               DISPLAY 'INCOME: MIDDLE'
           END-IF
           IF WS-UPPER
               DISPLAY 'INCOME: UPPER'
           END-IF
           IF WS-GETS-CRA-CREDIT
               DISPLAY 'CRA CREDIT: YES'
           ELSE
               DISPLAY 'CRA CREDIT: NO'
           END-IF.
