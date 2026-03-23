line 158:15 no viable alternative at input 'IF WS-LATE-DAYS > 30\n                   MULTIPLY WS-PAYMENT-AMT BY WS-LATE-FEE-RATE\n                       GIVING WS-LATE-FEE\n                   MULTIPLY WS-LATE-FEE BY 2\n               ELSE'
line 158:15 no viable alternative at input 'MULTIPLY WS-PAYMENT-AMT BY WS-LATE-FEE-RATE\n                       GIVING WS-LATE-FEE\n                   MULTIPLY WS-LATE-FEE BY 2\n               ELSE'
line 158:15 no viable alternative at input '2\n               ELSE'
line 158:15 mismatched input 'ELSE' expecting SECTION
line 159:43 mismatched input 'BY' expecting SECTION
line 160:23 mismatched input 'GIVING' expecting SECTION
line 161:15 mismatched input 'END-IF' expecting SECTION
line 162:31 mismatched input 'TO' expecting SECTION
line 163:11 mismatched input 'END-IF' expecting SECTION
line 61:7 mismatched input 'FD' expecting <EOF>
line 10:17 mismatched input '*' expecting <EOF>
line 110:15 no viable alternative at input 'WS-TOTAL-COST\n               REMAINDER'
line 3:17 mismatched input 'J' expecting <EOF>
line 25:68 mismatched input 'CONTINUE' expecting <EOF>
line 35:68 mismatched input 'CONTINUE' expecting <EOF>
line 41:71 mismatched input 'CONTINUE' expecting <EOF>
line 35:66 mismatched input 'CONTINUE' expecting <EOF>
line 13:62 mismatched input 'CONTINUE' expecting <EOF>
line 30:15 no viable alternative at input 'SUBTRACT 40 FROM WS-HOURS\n                   GIVING WS-OVERTIME-HRS\n               MULTIPLY WS-OVERTIME-HRS BY WS-RATE\n                   GIVING WS-OVERTIME-PAY\n               MULTIPLY WS-OVERTIME-PAY BY 1.5\n               ADD'
line 30:15 mismatched input 'ADD' expecting GIVING
line 31:11 no viable alternative at input 'WS-GROSS-PAY\n           END-IF'
line 208:36 no viable alternative at input 'IF WS-MED-ADDL-SUBJECT > WS-GROSS-PAY\n                   ADD WS-GROSS-PAY *'
line 208:36 no viable alternative at input 'WS-GROSS-PAY *'
line 208:36 mismatched input '*' expecting SECTION
line 209:23 mismatched input 'TO' expecting SECTION
line 210:15 mismatched input 'ELSE' expecting SECTION
line 211:43 mismatched input '*' expecting SECTION
line 212:40 mismatched input 'TO' expecting SECTION
line 213:15 mismatched input 'END-IF' expecting SECTION
line 68:28 mismatched input 'SIZE' expecting {ABORT, ADDRESS, ALL, AS, ASCII, ASSOCIATED_DATA, ASSOCIATED_DATA_LENGTH, ATTRIBUTE, AUTO, AUTO_SKIP, BACKGROUND_COLOR, BACKGROUND_COLOUR, BEEP, BELL, BINARY, BIT, BLINK, BOUNDS, CAPABLE, CCSVERSION, CHANGED, CHANNEL, CLOSE_DISPOSITION, COBOL, COMMITMENT, CONTROL_POINT, CONVENTION, CRUNCH, CURSOR, DATE, DAY, DAY_OF_WEEK, DEBUG_CONTENTS, DEBUG_ITEM, DEBUG_LINE, DEBUG_NAME, DEBUG_SUB_1, DEBUG_SUB_2, DEBUG_SUB_3, DEFAULT, DEFAULT_DISPLAY, DEFINITION, DFHRESP, DFHVALUE, DISK, DONTCARE, DOUBLE, EBCDIC, EMPTY_CHECK, ENTER, ENTRY_PROCEDURE, ERASE, EOL, EOS, ESCAPE, EVENT, EXCLUSIVE, EXPORT, EXTENDED, FALSE, FOREGROUND_COLOR, FOREGROUND_COLOUR, FULL, FUNCTION, FUNCTIONNAME, FUNCTION_POINTER, GRID, HIGHLIGHT, HIGH_VALUE, HIGH_VALUES, IMPLICIT, IMPORT, INTEGER, KEPT, KEYBOARD, LANGUAGE, LB, LD, LEFTLINE, LENGTH, LENGTH_CHECK, LIBACCESS, LIBPARAMETER, LIBRARY, LINAGE_COUNTER, LINE_COUNTER, LIST, LOCAL, LONG_DATE, LONG_TIME, LOWER, LOWLIGHT, LOW_VALUE, LOW_VALUES, MMDDYYYY, NAMED, NATIONAL, NATIONAL_EDITED, NETWORK, NO_ECHO, NULL_, NULLS, NUMERIC_DATE, NUMERIC_TIME, ODT, ORDERLY, OVERLINE, OWN, PAGE_COUNTER, PASSWORD, PORT, PRINTER, PRIVATE, PROCESS, PROGRAM, PROMPT, QUOTE, QUOTES, READER, REMOTE, REAL, RECEIVED, RECURSIVE, REF, REMOVE, REQUIRED, REVERSE_VIDEO, RETURN_CODE, SAVE, SECURE, SHARED, SHAREDBYALL, SHAREDBYRUNUNIT, SHARING, SHIFT_IN, SHIFT_OUT, SHORT_DATE, SORT_CONTROL, SORT_CORE_SIZE, SORT_FILE_SIZE, SORT_MESSAGE, SORT_MODE_SIZE, SORT_RETURN, SPACE, SPACES, SYMBOL, TALLY, TASK, THREAD, THREAD_LOCAL, TIME, TIMER, TODAYS_DATE, TODAYS_NAME, TRUE, TRUNCATED, TYPEDEF, UNDERLINE, VIRTUAL, WAIT, WHEN_COMPILED, YEAR, YYYYMMDD, YYYYDDD, ZERO, ZERO_FILL, ZEROS, ZEROES, NONNUMERICLITERAL, '66', '77', '88', INTEGERLITERAL, NUMERICLITERAL, IDENTIFIER}
==========================================================================================
  ALETHEIA VIABILITY EXPERIMENT
==========================================================================================

  Programs tested    : 459
  Parse success      : 458/459 (99.8%)
  Generate success   : 459/459 (100.0%)
  Compile success    : 459/459 (100.0%)
  Clean (0 MR)       : 430/459 (93.7%)
  With MANUAL REVIEW : 29 programs, 170 total flags

  PVR (Parse-Verify Rate) = 93.7%

  PROGRAM                   LINES  PARSE   GEN  COMP   MR STATUS                        
  --------------------------------------------------------------------------------------
  ACCT-ADDRESS-CHG            112     OK    OK    OK    0 VERIFIED                      
  ACCT-BENE-UPDATE            121     OK    OK    OK    0 VERIFIED                      
  ACCT-BENEFICIARY-RMD        100     OK    OK    OK    0 VERIFIED                      
  ACCT-CD-EARLY-WD             87     OK    OK    OK    0 VERIFIED                      
  ACCT-CLOSE-PROC             123     OK    OK    OK    0 VERIFIED                      
  ACCT-DECEASED-PROC           88     OK    OK    OK    0 VERIFIED                      
  ACCT-DORMANCY-FEE           103     OK    OK    OK    0 VERIFIED                      
  ACCT-ESCHEAT-SCAN           111     OK    OK    OK    0 VERIFIED                      
  ACCT-FEE-WAIVER-EVAL        102     OK    OK    OK    0 VERIFIED                      
  ACCT-GARNISHMENT             90     OK    OK    OK    0 VERIFIED                      
  ACCT-HOLD-RELEASE           116     OK    OK    OK    0 VERIFIED                      
  ACCT-INTEREST               124     OK    OK    OK    0 VERIFIED                      
  ACCT-INTEREST-SWEEP          85     OK    OK    OK    0 VERIFIED                      
  ACCT-JOINT-OWNER            142     OK    OK    OK    0 VERIFIED                      
  ACCT-MERGE-HANDLER           94     OK    OK    OK    0 VERIFIED                      
  ACCT-MIN-BAL-CHECK          105     OK    OK    OK    0 VERIFIED                      
  ACCT-OVERDRAFT-TIER         119     OK    OK    OK    0 VERIFIED                      
  ACCT-POA-MGMT               120     OK    OK    OK    0 VERIFIED                      
  ACCT-RECON-DAILY            142     OK    OK    OK    0 VERIFIED                      
  ACCT-REDEFINE                22     OK    OK    OK    0 VERIFIED                      
  ACCT-SIG-VERIFY              99     OK    OK    OK    0 VERIFIED                      
  ACCT-STMT-CYCLE             127     OK    OK    OK    0 VERIFIED                      
  ACCT-TIER-ASSIGN            112     OK    OK    OK    0 VERIFIED                      
  ACCT-TITLE-CHANGE           100     OK    OK    OK    0 VERIFIED                      
  ACCT-TRUST-DIST             118     OK    OK    OK    0 VERIFIED                      
  ACH-BATCH-VALIDATOR         312     OK    OK    OK    0 VERIFIED                      
  ACH-NACHA-FORMAT            195     OK    OK    OK    0 VERIFIED                      
  ACH-OFAC-SCREEN             184     OK    OK    OK    0 VERIFIED                      
  ACH-RETURN-HANDLER          196     OK    OK    OK    0 VERIFIED                      
  ACH-RETURN-PROC             218     OK    OK    OK    0 VERIFIED                      
  ALTER-DANGER                 18     OK    OK    OK    2 2 MANUAL REVIEW flags         
  ALTER-SQL-HYBRID            212     OK    OK    OK   12 12 MANUAL REVIEW flags        
  ALTER-TEST                   25     OK    OK    OK    2 2 MANUAL REVIEW flags         
  AML-PATTERN-DETECT          215     OK    OK    OK    0 VERIFIED                      
  AML-TXN-MONITOR             282     OK    OK    OK    0 VERIFIED                      
  ANNUITY-PAYOUT-CALC         168     OK    OK    OK    0 VERIFIED                      
  APPLY-PENALTY                23     OK    OK    OK    0 VERIFIED                      
  ARITHMETIC-STRESS           102     OK    OK    OK    0 VERIFIED                      
  ASSET-NAV-CALC              154     OK    OK    OK    0 VERIFIED                      
  ASSET-PERF-ATTRIB           160     OK    OK    OK    0 VERIFIED                      
  ASSET-REBAL-OPT             175     OK    OK    OK    0 VERIFIED                      
  ATM-CASH-REPLEN             187     OK    OK    OK    0 VERIFIED                      
  ATM-DISPUTE-CLAIM           232     OK    OK    OK    0 VERIFIED                      
  ATM-JOURNAL-AUDIT           221     OK    OK    OK    1 1 MANUAL REVIEW flags         
  ATM-SURCHARGE-CALC          182     OK    OK    OK    0 VERIFIED                      
  BASEL3-CAPITAL              181     OK    OK    OK    2 2 MANUAL REVIEW flags         
  BASEL3-LCR-CALC             171     OK    OK    OK    0 VERIFIED                      
  BATCH-ACH-ORIG              114     OK    OK    OK    0 VERIFIED                      
  BATCH-ARCHIVE-PURGE          94     OK    OK    OK    0 VERIFIED                      
  BATCH-CHECK-CLEAR           100     OK    OK    OK    0 VERIFIED                      
  BATCH-EOD-BALANCE           106     OK    OK    OK    0 VERIFIED                      
  BATCH-ESCHEAT-FILE           85     OK    OK    OK    0 VERIFIED                      
  BATCH-EXCEPTION-RPT          92     OK    OK    OK    0 VERIFIED                      
  BATCH-GL-POSTING            337     OK    OK    OK    0 VERIFIED                      
  BATCH-INTEREST-POST          89     OK    OK    OK    0 VERIFIED                      
  BATCH-NIGHT-CYCLE           139     OK    OK    OK    0 VERIFIED                      
  BATCH-PAYMENT               192     OK    OK    OK    0 VERIFIED                      
  BATCH-PAYROLL-RUN           305     OK    OK    OK    0 VERIFIED                      
  BATCH-SETTLE-PROC           234     OK    OK    OK    0 VERIFIED                      
  BATCH-STMT-RENDER           103     OK    OK    OK    0 VERIFIED                      
  BOND-ACCRETE-DISC           148     OK    OK    OK    0 VERIFIED                      
  BOND-AMORT-PREM             165     OK    OK    OK    0 VERIFIED                      
  BOND-COUPON-CALC            168     OK    OK    OK    0 VERIFIED                      
  BRANCH-ACCT-POST            217     OK    OK    OK    0 VERIFIED                      
  BRANCH-CASH-ORDER           189     OK    OK    OK    0 VERIFIED                      
  BRANCH-DAILY-CLOSE          214     OK    OK    OK    0 VERIFIED                      
  BRANCH-FEE-REVENUE          198     OK    OK    OK    0 VERIFIED                      
  BSA-AGGREGATE-CTR           185     OK    OK    OK    0 VERIFIED                      
  BSA-AGGREGATE-RPT           203     OK    OK    OK    0 VERIFIED                      
  BSA-CTR-FILING              182     OK    OK    OK    0 VERIFIED                      
  CALC-INT                     18     OK    OK    OK    0 VERIFIED                      
  CAP-GAINS-TRACK             187     OK    OK    OK    0 VERIFIED                      
  CARD-AUTH-PROCESSOR         294     OK    OK    OK    0 VERIFIED                      
  CARD-BIN-VALIDATOR          102     OK    OK    OK    0 VERIFIED                      
  CARD-BLOCK-REISSUE          111     OK    OK    OK    0 VERIFIED                      
  CARD-CASHBACK-TIER          108     OK    OK    OK    0 VERIFIED                      
  CARD-CLI-ENGINE             271     OK    OK    OK    0 VERIFIED                      
  CARD-DISPUTE-ENGINE         211     OK    OK    OK    0 VERIFIED                      
  CARD-DISPUTE-PROC           129     OK    OK    OK    0 VERIFIED                      
  CARD-EMV-AUTH               119     OK    OK    OK    0 VERIFIED                      
  CARD-FOREIGN-TXN             97     OK    OK    OK    0 VERIFIED                      
  CARD-LIMIT-REVIEW           120     OK    OK    OK    0 VERIFIED                      
  CARD-REWARD-CALC            119     OK    OK    OK    0 VERIFIED                      
  CARD-TEMP-INCREASE           94     OK    OK    OK    0 VERIFIED                      
  CASH-MGMT-ENGINE            216     OK    OK    OK    0 VERIFIED                      
  CCAR-LOSS-PROJ              175     OK    OK    OK    0 VERIFIED                      
  CCAR-STRESS-TEST            158     OK    OK    OK    0 VERIFIED                      
  CD-MATURITY-CALC            220     OK    OK    OK    0 VERIFIED                      
  CHECK-DIGIT-VALIDATOR       246     OK    OK    OK    0 VERIFIED                      
  CHECK-HOLD-POLICY           221     OK    OK    OK    0 VERIFIED                      
  CLAIMS-ADJUDICATE           216     OK    OK    OK    0 VERIFIED                      
  CLR-CHECK-IMAGE              68     OK    OK    OK    0 VERIFIED                      
  CLR-CORRESPONDENT            68     OK    OK    OK    0 VERIFIED                      
  CLR-DISPUTE-CALC             66     OK    OK    OK    0 VERIFIED                      
  CLR-EXCEPTION-PROC           89     OK    OK    OK    0 VERIFIED                      
  CLR-FED-RESERVE-FMT          72     OK    OK    OK    0 VERIFIED                      
  CLR-INTERBANK-FEE            58     OK    OK    OK    0 VERIFIED                      
  CLR-NET-SETTLE               62     OK    OK    OK    0 VERIFIED                      
  CLR-RETURN-REASON            86     OK    OK    OK    0 VERIFIED                      
  COLLATERAL-LTV-CALC         234     OK    OK    OK    0 VERIFIED                      
  COMML-COVENANT-CHK          204     OK    OK    OK    0 VERIFIED                      
  COMML-LINE-UTIL             178     OK    OK    OK    0 VERIFIED                      
  COMML-LOAN-GRADE            213     OK    OK    OK    0 VERIFIED                      
  COMML-PARTICIP-ALLOC        145     OK    OK    OK    0 VERIFIED                      
  COMP-AML-VELOCITY           143     OK    OK    OK    0 VERIFIED                      
  COMP-CIP-VERIFY             116     OK    OK    OK    0 VERIFIED                      
  COMP-ELDER-ABUSE            110     OK    OK    OK    0 VERIFIED                      
  COMP-KYC-REFRESH            136     OK    OK    OK    0 VERIFIED                      
  COMPOUND-INT                 27     OK    OK    OK    0 VERIFIED                      
  CORR-BANK-SETTLE            201     OK    OK    OK    0 VERIFIED                      
  CORR-NOSTRO-MATCH           234     OK    OK    OK    0 VERIFIED                      
  CORR-SWIFT-ROUTER           186     OK    OK    OK    1 1 MANUAL REVIEW flags         
  CREDIT-BUREAU-RPT           174     OK    OK    OK    0 VERIFIED                      
  CREDIT-SCORE                180     OK    OK    OK    0 VERIFIED                      
  CSV-PARSER                   21     OK    OK    OK    0 VERIFIED                      
  CURRENCY-DENOM-CALC         198     OK    OK    OK    0 VERIFIED                      
  CUST-STMT-GEN               230     OK    OK    OK    0 VERIFIED                      
  CUSTODY-CORP-ACTION         213     OK    OK    OK    0 VERIFIED                      
  CUSTODY-FEE-ENGINE          147     OK    OK    OK    0 VERIFIED                      
  CUSTODY-PROXY-VOTE          197     OK    OK    OK    0 VERIFIED                      
  DATA-CLEANER                 20     OK    OK    OK    0 VERIFIED                      
  DATA-MASKING-ENGINE         215     OK    OK    OK    0 VERIFIED                      
  DEEP-NEST                    34     OK    OK    OK    0 VERIFIED                      
  DEMO-WITH-COPY               36     OK    OK    OK    0 VERIFIED                      
  DEMO_LOAN_INTEREST           93     OK    OK    OK    0 VERIFIED                      
  DEP-CD-RENEWAL               62     OK    OK    OK    0 VERIFIED                      
  DEP-INT-ACCRUE-360           46     OK    OK    OK    0 VERIFIED                      
  DEP-IRA-CONTRIB              67     OK    OK    OK    0 VERIFIED                      
  DEP-PENALTY-EARLY            60     OK    OK    OK    0 VERIFIED                      
  DEP-RATE-BOARD               59     OK    OK    OK    0 VERIFIED                      
  DEP-RATE-CALC               189     OK    OK    OK    0 VERIFIED                      
  DEP-REG-D-MONITOR            64     OK    OK    OK    0 VERIFIED                      
  DEP-TIER-INTEREST            75     OK    OK    OK    0 VERIFIED                      
  DEP-UNCLM-PROP               83     OK    OK    OK    0 VERIFIED                      
  DEPOSIT-RECONCILE           254     OK    OK    OK    0 VERIFIED                      
  DERIV-CDS-SETTLE            158     OK    OK    OK    2 2 MANUAL REVIEW flags         
  DERIV-OPTION-GREEK          213     OK    OK    OK    8 8 MANUAL REVIEW flags         
  DERIV-SWAP-PRICE            152     OK    OK    OK    0 VERIFIED                      
  DISPLAY-MIX                  18     OK    OK    OK    0 VERIFIED                      
  DIV-REMAINDER                18     OK    OK    OK    0 VERIFIED                      
  DIVIDEND-DIST-PROC          196     OK    OK    OK    0 VERIFIED                      
  DODD-FRANK-RPT              141     OK    OK    OK    0 VERIFIED                      
  DODD-FRANK-SWAP             154     OK    OK    OK    0 VERIFIED                      
  DORMANT-ACCT-SWEEP          220     OK    OK    OK    0 VERIFIED                      
  DYNAMIC-TABLE                25     OK    OK    OK    0 VERIFIED                      
  EMBEDDED-SQL-BATCH          215     OK    OK    OK    0 VERIFIED                      
  ESCROW-ANALYSIS             233     OK    OK    OK    0 VERIFIED                      
  EVAL-ALSO                    22     OK    OK    OK    0 VERIFIED                      
  EVAL-ALSO-PRICING            68     OK    OK    OK    0 VERIFIED                      
  EVAL-ALSO-RATE-MATRIX       205     OK    OK    OK    0 VERIFIED                      
  EVAL-VARIABLE                36     OK    OK    OK    0 VERIFIED                      
  EVALUATE-TEST                60     OK    OK    OK    0 VERIFIED                      
  EXEC-SQL-TEST                45     OK    OK    OK    0 VERIFIED                      
  FATCA-WITHHOLD-CALC         246     OK    OK    OK    0 VERIFIED                      
  FDIC-ASSESS-CALC            183     OK    OK    OK    0 VERIFIED                      
  FDIC-ASSESS-TIER            144     OK    OK    OK    0 VERIFIED                      
  FED-DISCOUNT-WIN            133     OK    OK    OK    0 VERIFIED                      
  FED-FUNDS-APPLY             138     OK    OK    OK    0 VERIFIED                      
  FEE-ASSESS-ENGINE           214     OK    OK    OK    0 VERIFIED                      
  FRAUD-ACCT-TAKEOVER         108     OK    OK    OK    0 VERIFIED                      
  FRAUD-ALERT-FORMAT           91     OK    OK    OK    0 VERIFIED                      
  FRAUD-BIN-LOOKUP             71     OK    OK    OK    0 VERIFIED                      
  FRAUD-CHARGEBACK             89     OK    OK    OK    0 VERIFIED                      
  FRAUD-DEVICE-SCORE          111     OK    OK    OK    0 VERIFIED                      
  FRAUD-GEO-ANOMALY           100     OK    OK    OK    0 VERIFIED                      
  FRAUD-LINK-ANALYZE           93     OK    OK    OK    0 VERIFIED                      
  FRAUD-RULE-ENGINE           114     OK    OK    OK    0 VERIFIED                      
  FRAUD-SCORE-ENGINE          272     OK    OK    OK    0 VERIFIED                      
  FRAUD-THRESHOLD-ADJ          94     OK    OK    OK    0 VERIFIED                      
  FRAUD-VELOCITY-CHK          100     OK    OK    OK    0 VERIFIED                      
  FUND-EXPENSE-RATIO          169     OK    OK    OK    0 VERIFIED                      
  FUND-REDEMPTION-PROC        186     OK    OK    OK    0 VERIFIED                      
  FUND-SWITCH-PROC            151     OK    OK    OK    0 VERIFIED                      
  FX-FORWARD-REVALUE          150     OK    OK    OK    2 2 MANUAL REVIEW flags         
  FX-RATE-CONVERTER           274     OK    OK    OK    0 VERIFIED                      
  FX-SPOT-CONVERTER           198     OK    OK    OK    0 VERIFIED                      
  FX-SWAP-VALUATION           186     OK    OK    OK    0 VERIFIED                      
  GOTO-DEPEND                  21     OK    OK    OK    0 VERIFIED                      
  GOTO-DEPEND-ROUTER           66     OK    OK    OK    0 VERIFIED                      
  GOTO-FLOW                    26     OK    OK    OK    0 VERIFIED                      
  INIT-TEST                    22     OK    OK    OK    0 VERIFIED                      
  INS-ANNUITY-VALUE            75     OK    OK    OK    0 VERIFIED                      
  INS-BENEFIT-SCHED           105     OK    OK    OK    0 VERIFIED                      
  INS-CLAIM-ADJUDIC           120     OK    OK    OK    0 VERIFIED                      
  INS-CLAIMS-BATCH            231     OK    OK    OK    0 VERIFIED                      
  INS-COINSURE-SPLIT           85     OK    OK    OK    0 VERIFIED                      
  INS-COVERAGE-GAP            151     OK    OK    OK    0 VERIFIED                      
  INS-DEDUCTIBLE-CALC         123     OK    OK    OK    0 VERIFIED                      
  INS-FLOOD-ZONE-CHK           93     OK    OK    OK    0 VERIFIED                      
  INS-GRACE-PERIOD            165     OK    OK    OK    0 VERIFIED                      
  INS-LAPSE-NOTICE            103     OK    OK    OK    0 VERIFIED                      
  INS-MORTALITY-TBL            94     OK    OK    OK    0 VERIFIED                      
  INS-POLICY-RENEW            125     OK    OK    OK    0 VERIFIED                      
  INS-PREM-CALC                98     OK    OK    OK    0 VERIFIED                      
  INS-PREM-TIERED             212     OK    OK    OK    0 VERIFIED                      
  INS-REINSTATE-PROC          192     OK    OK    OK    0 VERIFIED                      
  INS-RESERVE-POST             81     OK    OK    OK    0 VERIFIED                      
  INS-RIDER-CALC              186     OK    OK    OK    0 VERIFIED                      
  INS-RISK-POOL-ALLOC         115     OK    OK    OK    0 VERIFIED                      
  INS-SUBROG-RECOV            147     OK    OK    OK    0 VERIFIED                      
  INS-SUBROGATION              89     OK    OK    OK    0 VERIFIED                      
  INS-SURR-VALUE              153     OK    OK    OK    0 VERIFIED                      
  INSPECT-CONV                 12     OK    OK    OK    0 VERIFIED                      
  INSPECT-CONV-SANITIZE        69     OK    OK    OK    0 VERIFIED                      
  INTEREST-ACCRUAL-BATCH      258     OK    OK    OK    0 VERIFIED                      
  INTR-CALC-3270               37   FAIL    OK    OK    0 VERIFIED                      
  INV-INCOME-ALLOC            166     OK    OK    OK    0 VERIFIED                      
  INV-MARGIN-CALL             173     OK    OK    OK    0 VERIFIED                      
  INVOICE-GEN                  59     OK    OK    OK    0 VERIFIED                      
  KYC-RISK-RATING             271     OK    OK    OK    0 VERIFIED                      
  LATE-FEE-ASSESSOR           228     OK    OK    OK    0 VERIFIED                      
  LEGACY-ALTER-DISPATCH       154     OK    OK    OK   12 12 MANUAL REVIEW flags        
  LOAN-AMORT-CALC             198     OK    OK    OK    0 VERIFIED                      
  LOAN-AMORT-ENGINE           256     OK    OK    OK    0 VERIFIED                      
  LOAN-APPRAISAL-REV          100     OK    OK    OK    0 VERIFIED                      
  LOAN-ASSUMABILITY            98     OK    OK    OK    0 VERIFIED                      
  LOAN-COLLATERAL-VAL         144     OK    OK    OK    0 VERIFIED                      
  LOAN-CONV-ASSESS            161     OK    OK    OK    0 VERIFIED                      
  LOAN-COUPON-STRIP           123     OK    OK    OK    0 VERIFIED                      
  LOAN-CREDIT-SCORE           140     OK    OK    OK    0 VERIFIED                      
  LOAN-DELINQ-TRACKER         153     OK    OK    OK    0 VERIFIED                      
  LOAN-DTI-CALC               111     OK    OK    OK    0 VERIFIED                      
  LOAN-ESCROW-ADJUST          145     OK    OK    OK    0 VERIFIED                      
  LOAN-ESCROW-DISBUR           94     OK    OK    OK    0 VERIFIED                      
  LOAN-FORBEARANCE-CALC       183     OK    OK    OK    0 VERIFIED                      
  LOAN-GRACE-PERIOD-CALC      189     OK    OK    OK    0 VERIFIED                      
  LOAN-HARDSHIP-EVAL          117     OK    OK    OK    0 VERIFIED                      
  LOAN-INCOME-VERIFY          102     OK    OK    OK    0 VERIFIED                      
  LOAN-LOSS-RESERVE           130     OK    OK    OK    0 VERIFIED                      
  LOAN-MODIF-ENGINE           156     OK    OK    OK    0 VERIFIED                      
  LOAN-PAYOFF-QUOTE           123     OK    OK    OK    0 VERIFIED                      
  LOAN-PMI-REMOVAL            155     OK    OK    OK    0 VERIFIED                      
  LOAN-PMT-APPLY              122     OK    OK    OK    0 VERIFIED                      
  LOAN-PREPAY-PENALTY         176     OK    OK    OK    0 VERIFIED                      
  LOAN-RATE-RESET             171     OK    OK    OK    0 VERIFIED                      
  LOAN-REFI-ASSESS            109     OK    OK    OK    0 VERIFIED                      
  LOAN-RISK-GRADING           294     OK    OK    OK    0 VERIFIED                      
  LOAN-TITLE-SEARCH           101     OK    OK    OK    0 VERIFIED                      
  MAIN-LOAN                    34     OK    OK    OK    4 4 MANUAL REVIEW flags         
  MARGIN-CALL-ENGINE          197     OK    OK    OK    0 VERIFIED                      
  MISC-AUDIT-TRAIL             75     OK    OK    OK    0 VERIFIED                      
  MISC-BATCH-TOTALS            68     OK    OK    OK    0 VERIFIED                      
  MISC-BRANCH-GL-POST         111     OK    OK    OK    0 VERIFIED                      
  MISC-DATE-CALC               63     OK    OK    OK    0 VERIFIED                      
  MISC-FEE-WAIVER              65     OK    OK    OK    0 VERIFIED                      
  MISC-LETTER-GEN              83     OK    OK    OK    0 VERIFIED                      
  MISC-RATE-COMPARE            64     OK    OK    OK    0 VERIFIED                      
  MISC-SAFE-BOX-BILL           64     OK    OK    OK    0 VERIFIED                      
  MMKT-SWEEP-ENGINE           161     OK    OK    OK    0 VERIFIED                      
  MMKT-TIER-ACCRUE            164     OK    OK    OK    0 VERIFIED                      
  MONTHLY-TOTALS               28     OK    OK    OK    0 VERIFIED                      
  MORT-ESCROW-CALC            197     OK    OK    OK    0 VERIFIED                      
  MR-ALTER-AML-DISPATCH       152     OK    OK    OK    2 2 MANUAL REVIEW flags         
  MR-ALTER-ANNUITY-ROUTE       88     OK    OK    OK    9 9 MANUAL REVIEW flags         
  MR-ALTER-ATM-ROUTE          121     OK    OK    OK    8 8 MANUAL REVIEW flags         
  MR-ALTER-BATCH-CTRL          63     OK    OK    OK    8 8 MANUAL REVIEW flags         
  MR-ALTER-DISPATCH-V2        112     OK    OK    OK   12 12 MANUAL REVIEW flags        
  MR-ALTER-ERROR-ROUTE         65     OK    OK    OK   14 14 MANUAL REVIEW flags        
  MR-ALTER-FALLBACK           116     OK    OK    OK    9 9 MANUAL REVIEW flags         
  MR-ALTER-MTG-ROUTE          110     OK    OK    OK   12 12 MANUAL REVIEW flags        
  MR-ALTER-RATE-ROUTE         166     OK    OK    OK   12 12 MANUAL REVIEW flags        
  MR-ALTER-RECOVERY           100     OK    OK    OK    9 9 MANUAL REVIEW flags         
  MR-ALTER-STATE-MACH          77     OK    OK    OK    8 8 MANUAL REVIEW flags         
  MR-CICS-ACCT-INQ             89     OK    OK    OK    0 VERIFIED                      
  MR-CICS-ACCT-MAINT          179     OK    OK    OK    0 VERIFIED                      
  MR-CICS-ATM-AUTH            162     OK    OK    OK    0 VERIFIED                      
  MR-CICS-BALANCE-INQ          80     OK    OK    OK    0 VERIFIED                      
  MR-CICS-CARD-MAINT          101     OK    OK    OK    0 VERIFIED                      
  MR-CICS-CLAIM-INQ           115     OK    OK    OK    0 VERIFIED                      
  MR-CICS-FX-DEAL-ENTRY       246     OK    OK    OK    0 VERIFIED                      
  MR-CICS-KYC-INQUIRY         190     OK    OK    OK    0 VERIFIED                      
  MR-CICS-LOAN-PAY             94     OK    OK    OK    0 VERIFIED                      
  MR-CICS-TELLER-INQ          199     OK    OK    OK    1 1 MANUAL REVIEW flags         
  MR-CICS-TXN-ENTRY           137     OK    OK    OK    0 VERIFIED                      
  MR-CICS-UNDERWRITE-SCR      168     OK    OK    OK    0 VERIFIED                      
  MR-CICS-WIRE-AUTH            90     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-CICS-MAP            112     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-CICS-QUEUE           96     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-CICS-WIRE           174     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-SQL-CURSOR          105     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-SQL-DEPOSIT         139     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-SQL-REPORT          102     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-SQL-UPDATE          111     OK    OK    OK    0 VERIFIED                      
  MR-GOV-CICS-FILING          153     OK    OK    OK    0 VERIFIED                      
  MR-GOV-CICS-TAX             164     OK    OK    OK    0 VERIFIED                      
  MR-GOV-ODO-BENEFIT          134     OK    OK    OK    0 VERIFIED                      
  MR-GOV-SQL-OFAC             163     OK    OK    OK    0 VERIFIED                      
  MR-GOV-SQL-PENSION          143     OK    OK    OK    0 VERIFIED                      
  MR-ODO-AMORT-SCHED           82     OK    OK    OK    0 VERIFIED                      
  MR-ODO-AMORT-TBL            112     OK    OK    OK    0 VERIFIED                      
  MR-ODO-CLAIM-BATCH          145     OK    OK    OK    0 VERIFIED                      
  MR-ODO-CUSTODY-STMT         184     OK    OK    OK    0 VERIFIED                      
  MR-ODO-INVOICE              112     OK    OK    OK    0 VERIFIED                      
  MR-ODO-INVOICE-BATCH         85     OK    OK    OK    0 VERIFIED                      
  MR-ODO-PAYROLL-RUN           83     OK    OK    OK    0 VERIFIED                      
  MR-ODO-STMT-LINES           163     OK    OK    OK    0 VERIFIED                      
  MR-ODO-TABLE                 92     OK    OK    OK    0 VERIFIED                      
  MR-ODO-WIRE-BATCH           211     OK    OK    OK    0 VERIFIED                      
  MR-SQL-BRANCH-RECON          95     OK    OK    OK    0 VERIFIED                      
  MR-SQL-CUST-MERGE            93     OK    OK    OK    0 VERIFIED                      
  MR-SQL-CUSTODY-BALANCE      160     OK    OK    OK    0 VERIFIED                      
  MR-SQL-DAILY-BAL             84     OK    OK    OK    0 VERIFIED                      
  MR-SQL-DELINQ-NOTICE         95     OK    OK    OK    0 VERIFIED                      
  MR-SQL-DERIV-RISK           147     OK    OK    OK    0 VERIFIED                      
  MR-SQL-INVEST-REPORT        149     OK    OK    OK    0 VERIFIED                      
  MR-SQL-LOAN-AGING           129     OK    OK    OK    0 VERIFIED                      
  MR-SQL-OVERDRAFT-RPT         80     OK    OK    OK    0 VERIFIED                      
  MR-SQL-PENSION-REPORT       163     OK    OK    OK    0 VERIFIED                      
  MR-SQL-POLICY-LOOKUP        124     OK    OK    OK    0 VERIFIED                      
  MR-SQL-PORTFOLIO            140     OK    OK    OK    0 VERIFIED                      
  MR-SQL-TELLER-AUDIT         135     OK    OK    OK    0 VERIFIED                      
  MR-SQL-TXN-ARCHIVE          110     OK    OK    OK    0 VERIFIED                      
  MR-SQL-VAULT-RECON          208     OK    OK    OK    0 VERIFIED                      
  MSG-BUILDER                  18     OK    OK    OK    0 VERIFIED                      
  MTG-AMORT-SCHED             145     OK    OK    OK    0 VERIFIED                      
  MTG-ESCROW-CALC             173     OK    OK    OK    0 VERIFIED                      
  MTG-FORBEAR-EVAL            181     OK    OK    OK    0 VERIFIED                      
  MTG-SERVICING-FEE           149     OK    OK    OK    0 VERIFIED                      
  MUTUAL-FUND-NAV             186     OK    OK    OK    0 VERIFIED                      
  NESTED-EVAL                  38     OK    OK    OK    0 VERIFIED                      
  NIGHT-DROP-PROC             200     OK    OK    OK    0 VERIFIED                      
  NSF-CHECK-HANDLER           228     OK    OK    OK    0 VERIFIED                      
  OCC-CALL-REPORT             166     OK    OK    OK    6 6 MANUAL REVIEW flags         
  OCC-EXAM-EXTRACT            160     OK    OK    OK    0 VERIFIED                      
  OD-PROTECT-LINK             214     OK    OK    OK    0 VERIFIED                      
  OVERDRAFT-PROCESSOR         240     OK    OK    OK    0 VERIFIED                      
  PAY-ACH-RETURN               97     OK    OK    OK    0 VERIFIED                      
  PAY-ADDENDA-PARSE           118     OK    OK    OK    0 VERIFIED                      
  PAY-BATCH-SETTLE            130     OK    OK    OK    0 VERIFIED                      
  PAY-CHECK-HOLD-CALC         110     OK    OK    OK    0 VERIFIED                      
  PAY-CUTOFF-CHECK            104     OK    OK    OK    0 VERIFIED                      
  PAY-DIRECT-DEPOSIT          102     OK    OK    OK    0 VERIFIED                      
  PAY-FLOAT-CALC              120     OK    OK    OK    0 VERIFIED                      
  PAY-LIMIT-ENFORCE           125     OK    OK    OK    0 VERIFIED                      
  PAY-NSF-FEE-CALC            150     OK    OK    OK    0 VERIFIED                      
  PAY-OFFSET-APPLY            112     OK    OK    OK    0 VERIFIED                      
  PAY-ORIGINATOR-FEE          100     OK    OK    OK    0 VERIFIED                      
  PAY-POSITIVE-PAY            104     OK    OK    OK    0 VERIFIED                      
  PAY-PRENOTE-VALID           134     OK    OK    OK    0 VERIFIED                      
  PAY-RECUR-SCHED             120     OK    OK    OK    0 VERIFIED                      
  PAY-RETURN-PROC             126     OK    OK    OK    0 VERIFIED                      
  PAY-SAME-DAY-ACH            139     OK    OK    OK    0 VERIFIED                      
  PAY-WIRE-OUTBOUND           141     OK    OK    OK    0 VERIFIED                      
  PAY-ZELLE-LIMIT             123     OK    OK    OK    0 VERIFIED                      
  PAYROLL-CALC                 47     OK    OK    OK    0 VERIFIED                      
  PAYROLL-TAX-ENGINE          253     OK    OK    OK    2 2 MANUAL REVIEW flags         
  PENSION-BENEFIT-CALC        262     OK    OK    OK    0 VERIFIED                      
  PENSION-CONTRIB-CALC        229     OK    OK    OK    0 VERIFIED                      
  PENSION-RMD-CALC            198     OK    OK    OK    0 VERIFIED                      
  PENSION-VESTING-CALC        166     OK    OK    OK    0 VERIFIED                      
  PERFORM-VARYING-TEST         71     OK    OK    OK    0 VERIFIED                      
  POLICY-RENEW-PROC           207     OK    OK    OK    0 VERIFIED                      
  PORT-ASSET-ALLOC            198     OK    OK    OK    0 VERIFIED                      
  PORT-REBALANCE              174     OK    OK    OK    2 2 MANUAL REVIEW flags         
  PORT-RISK-ASSESS            181     OK    OK    OK    0 VERIFIED                      
  REG-AML-CASE-SCORE          150     OK    OK    OK    0 VERIFIED                      
  REG-BSA-AGGREGATE           105     OK    OK    OK    0 VERIFIED                      
  REG-CALL-RPT-GEN             85     OK    OK    OK    0 VERIFIED                      
  REG-CECL-RESERVE            101     OK    OK    OK    0 VERIFIED                      
  REG-COMPL-SCREEN            234     OK    OK    OK    0 VERIFIED                      
  REG-CRA-ASSESS              174     OK    OK    OK    0 VERIFIED                      
  REG-CRA-GEOCODE             102     OK    OK    OK    0 VERIFIED                      
  REG-CTR-BUILDER             103     OK    OK    OK    0 VERIFIED                      
  REG-DODD-FRANK-RPT          121     OK    OK    OK    0 VERIFIED                      
  REG-FAIR-LENDING            112     OK    OK    OK    0 VERIFIED                      
  REG-FATCA-SCREEN            115     OK    OK    OK    0 VERIFIED                      
  REG-HMDA-EXTRACT            110     OK    OK    OK    0 VERIFIED                      
  REG-PRIVACY-OPTOUT          112     OK    OK    OK    0 VERIFIED                      
  REG-REPORT-BUILDER          195     OK    OK    OK    0 VERIFIED                      
  REG-RISK-WEIGHT              96     OK    OK    OK    0 VERIFIED                      
  REG-SAR-SCREEN              100     OK    OK    OK    0 VERIFIED                      
  REG-STRESS-CALC              98     OK    OK    OK    0 VERIFIED                      
  REG-TILA-APR                169     OK    OK    OK    0 VERIFIED                      
  REG-TIN-VALIDATOR           111     OK    OK    OK    0 VERIFIED                      
  REPEAT-TIMES                 16     OK    OK    OK    0 VERIFIED                      
  RETURN-ITEM-PROC            215     OK    OK    OK    0 VERIFIED                      
  REWRITE-ACCT-UPDATE          75     OK    OK    OK    0 VERIFIED                      
  SANCTION-LIST-UPDATE        259     OK    OK    OK    0 VERIFIED                      
  SANCTION-SCREEN             226     OK    OK    OK    0 VERIFIED                      
  SORT-MERGE-RECON             58     OK    OK    OK    0 VERIFIED                      
  SORT-TXN-REPORT             203     OK    OK    OK    0 VERIFIED                      
  SS-BENEFIT-CALC             165     OK    OK    OK    2 2 MANUAL REVIEW flags         
  SS-COLA-ADJUST              143     OK    OK    OK    0 VERIFIED                      
  SS-RETIRE-AGE               189     OK    OK    OK    0 VERIFIED                      
  STATUS-CHECKER               35     OK    OK    OK    0 VERIFIED                      
  STMT-LINE-BUILDER           246     OK    OK    OK    0 VERIFIED                      
  STRING-INSPECT-REPORT       207     OK    OK    OK    0 VERIFIED                      
  STRING-PTR                   16     OK    OK    OK    0 VERIFIED                      
  STRING-PTR-ASSEMBLER         61     OK    OK    OK    0 VERIFIED                      
  SWIFT-MT940-RECON           161     OK    OK    OK    0 VERIFIED                      
  TAX-1042S-FBAR              155     OK    OK    OK    0 VERIFIED                      
  TAX-1099-INT-GEN             93     OK    OK    OK    0 VERIFIED                      
  TAX-AMT-CALC                163     OK    OK    OK    0 VERIFIED                      
  TAX-BACKUP-SCREEN            78     OK    OK    OK    0 VERIFIED                      
  TAX-CORRECTED-1099           88     OK    OK    OK    0 VERIFIED                      
  TAX-COST-BASIS               71     OK    OK    OK    0 VERIFIED                      
  TAX-EITC-CALC               184     OK    OK    OK    4 4 MANUAL REVIEW flags         
  TAX-FOREIGN-CREDIT           63     OK    OK    OK    0 VERIFIED                      
  TAX-LOT-ACCT                197     OK    OK    OK    0 VERIFIED                      
  TAX-REMIC-ALLOC              89     OK    OK    OK    0 VERIFIED                      
  TAX-W8BEN-VALID             114     OK    OK    OK    0 VERIFIED                      
  TAX-WITHOLD-CALC            103     OK    OK    OK    0 VERIFIED                      
  TELLER-BALANCE              214     OK    OK    OK    0 VERIFIED                      
  TELLER-BATCH-BALANCE        291     OK    OK    OK    0 VERIFIED                      
  TELLER-CASH-BUY             179     OK    OK    OK    0 VERIFIED                      
  TELLER-CTR-REPORT           226     OK    OK    OK    0 VERIFIED                      
  TELLER-OVERRIDE-MGR         213     OK    OK    OK    0 VERIFIED                      
  TELLER-TXN-LOG              188     OK    OK    OK    0 VERIFIED                      
  TRADE-ACCRUED-INT            84     OK    OK    OK    0 VERIFIED                      
  TRADE-BOND-SETTLE           172     OK    OK    OK    0 VERIFIED                      
  TRADE-BOND-YIELD            130     OK    OK    OK    0 VERIFIED                      
  TRADE-CONFIRM-GEN            78     OK    OK    OK    0 VERIFIED                      
  TRADE-CORP-ACTION           102     OK    OK    OK    0 VERIFIED                      
  TRADE-CUSTODY-FEE            95     OK    OK    OK    0 VERIFIED                      
  TRADE-DIVIDEND-POST          84     OK    OK    OK    0 VERIFIED                      
  TRADE-FAIL-TRACKER          116     OK    OK    OK    0 VERIFIED                      
  TRADE-FIN-FACTORING         148     OK    OK    OK    0 VERIFIED                      
  TRADE-FIN-GUARANT           171     OK    OK    OK    0 VERIFIED                      
  TRADE-FIN-LC                186     OK    OK    OK    0 VERIFIED                      
  TRADE-MARGIN-CALC           112     OK    OK    OK    0 VERIFIED                      
  TRADE-SETTLE-BATCH          124     OK    OK    OK    0 VERIFIED                      
  TRADE-TAX-LOT-CALC           95     OK    OK    OK    0 VERIFIED                      
  TREAS-BOND-PRICE            101     OK    OK    OK    0 VERIFIED                      
  TREAS-CASH-POSITION         103     OK    OK    OK    0 VERIFIED                      
  TREAS-CASHFLOW-PROJ         174     OK    OK    OK    0 VERIFIED                      
  TREAS-CD-LADDER             121     OK    OK    OK    0 VERIFIED                      
  TREAS-COLLATERAL-MGR         80     OK    OK    OK    0 VERIFIED                      
  TREAS-DURATION-MGMT          92     OK    OK    OK    0 VERIFIED                      
  TREAS-FED-FUNDS-PRC          73     OK    OK    OK    0 VERIFIED                      
  TREAS-FX-HEDGE               94     OK    OK    OK    0 VERIFIED                      
  TREAS-GAP-ANALYSIS           85     OK    OK    OK    0 VERIFIED                      
  TREAS-LIQUIDITY-RPT          93     OK    OK    OK    0 VERIFIED                      
  TREAS-LOCKBOX-PROC          113     OK    OK    OK    0 VERIFIED                      
  TREAS-MM-FUND-NAV           107     OK    OK    OK    0 VERIFIED                      
  TREAS-NOSTRO-RECON          126     OK    OK    OK    0 VERIFIED                      
  TREAS-POOL-ALLOC            111     OK    OK    OK    0 VERIFIED                      
  TREAS-POS-CASH-CALC          90     OK    OK    OK    0 VERIFIED                      
  TREAS-RECON-ENGINE          237     OK    OK    OK    0 VERIFIED                      
  TREAS-REPO-SETTLE            97     OK    OK    OK    0 VERIFIED                      
  TREAS-SWAP-VALUE            117     OK    OK    OK    0 VERIFIED                      
  TREAS-SWEEP-ENGINE          122     OK    OK    OK    0 VERIFIED                      
  TREAS-WIRE-FEE-CALC         105     OK    OK    OK    0 VERIFIED                      
  TREAS-ZBA-TRANSFER           98     OK    OK    OK    0 VERIFIED                      
  TRUST-ACCT-VALUATION        201     OK    OK    OK    0 VERIFIED                      
  TRUST-DISTRIB-CALC          198     OK    OK    OK    0 VERIFIED                      
  TRUST-FEE-BILLING           235     OK    OK    OK    0 VERIFIED                      
  TRUST-FEE-CALC              208     OK    OK    OK    0 VERIFIED                      
  TYPE-CHECKER                 25     OK    OK    OK    0 VERIFIED                      
  UNDERWRITE-RISK             215     OK    OK    OK    0 VERIFIED                      
  UNSTR-COMPLEX                20     OK    OK    OK    0 VERIFIED                      
  UNSTRING-DELIM-PARSER        87     OK    OK    OK    0 VERIFIED                      
  VAULT-DENOM-COUNT           223     OK    OK    OK    0 VERIFIED                      
  VAULT-INSURANCE-CHK         191     OK    OK    OK    0 VERIFIED                      
  VAULT-RECON                 203     OK    OK    OK    0 VERIFIED                      
  VSAM-ACCT-UPDATE            247     OK    OK    OK    0 VERIFIED                      
  WIRE-TRANSFER-CALC          286     OK    OK    OK    0 VERIFIED                      
  WIRE-VALIDATE               130     OK    OK    OK    0 VERIFIED                      
  WIRE-XFER-VALIDATE          251     OK    OK    OK    2 2 MANUAL REVIEW flags         
  WRITE-ADV-REPORT             90     OK    OK    OK    0 VERIFIED                      

  CONSTRUCT FREQUENCY (across all programs)
  --------------------------------------------------
  MOVE                      449 ########################################
  STOP RUN                  445 ########################################
  PERFORM                   433 ########################################
  IF/ELSE                   429 ########################################
  DISPLAY                   416 ########################################
  88-level                  387 ########################################
  COMP-3                    377 ########################################
  COMPUTE                   363 ########################################
  ADD                       331 ########################################
  INITIALIZE                301 ########################################
  PERFORM VARYING           236 ########################################
  OCCURS                    224 ########################################
  EVALUATE TRUE             214 ########################################
  PERFORM TIMES             118 ########################################
  SUBTRACT                   87 ########################################
  STRING                     61 ########################################
  EVALUATE variable          48 ########################################
  DIVIDE                     34 ##################################
  MULTIPLY                   31 ###############################
  DIVIDE REMAINDER           28 ############################
  EXEC SQL                   24 ########################
  GO TO                      23 #######################
  STRING POINTER             21 #####################
  IS NUMERIC                 16 ################
  UNSTRING                   15 ###############
  ALTER                      15 ###############
  PERFORM THRU               15 ###############
  OCCURS DEPENDING            6 ######
  REDEFINES                   4 ####
  88 THRU                     4 ####
  EVALUATE ALSO               3 ###
  DELIMITER IN                2 ##
  COPY                        1 #
  IS ALPHABETIC               1 #
  INSPECT TALLYING            1 #

  MANUAL REVIEW FLAGS (170 total)
  --------------------------------------------------
  ALTER-DANGER: # MANUAL REVIEW: ALTER 1000-DISPATCH TO PROCEED TO 3000-OVERRIDE
  ALTER-DANGER: # ALTER 1000-DISPATCH                            # MANUAL REVIEW                                [FAI
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-ADDRESS
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-NAME
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-CLOSE
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-REOPEN
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-ADDRESS
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-NAME
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-CLOSE
  ALTER-SQL-HYBRID: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-REOPEN
  ALTER-SQL-HYBRID: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  ALTER-SQL-HYBRID: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  ALTER-SQL-HYBRID: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  ALTER-SQL-HYBRID: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  ALTER-TEST: # MANUAL REVIEW: ALTER CALC-DISPATCH TO PROCEED TO CALC-COMPOUND
  ALTER-TEST: # ALTER CALC-DISPATCH                            # MANUAL REVIEW                                [FAI
  ATM-JOURNAL-AUDIT: pass  # MANUAL REVIEW: inline PERFORM VARYING body
  BASEL3-CAPITAL: # MANUAL REVIEW: WS-CET1-PASSANDWS-TIER1-PASSANDWS-TOTAL-PASSANDWS-LEVERAGE-P
  BASEL3-CAPITAL: # IF WS-CET1-PASSANDWS-TIER1-PASSANDWS-TOTAL-PA  # MANUAL REVIEW: WS-CET1-PASSANDWS-TIER1-PASS  [FAI
  CORR-SWIFT-ROUTER: # MANUAL REVIEW: WS-PRIORITY-URGENTDISPLAY'HIGH VALUE URGENT MT103'
  DERIV-CDS-SETTLE: # MANUAL REVIEW: COMPUTEWS-SURV-PROBROUNDED=FUNCTIONEXP(-1*WS-HAZARD-RAT
  DERIV-CDS-SETTLE: # COMPUTE WS-SURV-PROBROUNDED=FUNCTIONEXP(-1*WS  # MANUAL REVIEW (unknown FUNCTION)             [FAI
  DERIV-OPTION-GREEK: # MANUAL REVIEW: COMPUTEWS-PDF-D1ROUNDED=1/FUNCTIONSQRT(2*WS-PI)*FUNCTIO
  DERIV-OPTION-GREEK: # MANUAL REVIEW: COMPUTEWS-ND1ROUNDED=0.50+0.50*(1-FUNCTIONEXP(-0.7*WS-A
  DERIV-OPTION-GREEK: # MANUAL REVIEW: COMPUTEWS-ND2ROUNDED=0.50+0.50*(1-FUNCTIONEXP(-0.7*WS-A
  DERIV-OPTION-GREEK: # MANUAL REVIEW: COMPUTEWS-EXP-RTROUNDED=FUNCTIONEXP(-1*OE-RATE(WS-IDX)*
  DERIV-OPTION-GREEK: # COMPUTE WS-PDF-D1ROUNDED=1/FUNCTIONSQRT(2*WS-  # MANUAL REVIEW (unknown FUNCTION)             [FAI
  DERIV-OPTION-GREEK: # COMPUTE WS-ND1ROUNDED=0.50+0.50*(1-FUNCTIONEX  # MANUAL REVIEW (unknown FUNCTION)             [FAI
  DERIV-OPTION-GREEK: # COMPUTE WS-ND2ROUNDED=0.50+0.50*(1-FUNCTIONEX  # MANUAL REVIEW (unknown FUNCTION)             [FAI
  DERIV-OPTION-GREEK: # COMPUTE WS-EXP-RTROUNDED=FUNCTIONEXP(-1*OE-RA  # MANUAL REVIEW (unknown FUNCTION)             [FAI
  FX-FORWARD-REVALUE: # MANUAL REVIEW: INITIALIZE WS-REVALUE-RESULTS (unknown variable)
  FX-FORWARD-REVALUE: # INITIALIZE WS-REVALUE-RESULTS                  # MANUAL REVIEW                                [FAI
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTERDISPATCH-GOTOTOPROCEEDTOPROCESS-DEPOSIT
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTERDISPATCH-GOTOTOPROCEEDTOPROCESS-WITHDRAWAL
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTERDISPATCH-GOTOTOPROCEEDTOPROCESS-TRANSFER
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTERDISPATCH-GOTOTOPROCEEDTOPROCESS-INQUIRY
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTER DISPATCH-GOTO TO PROCEED TO PROCESS-DEPOSIT
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTER DISPATCH-GOTO TO PROCEED TO PROCESS-WITHDRAWAL
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTER DISPATCH-GOTO TO PROCEED TO PROCESS-TRANSFER
  LEGACY-ALTER-DISPATCH: # MANUAL REVIEW: ALTER DISPATCH-GOTO TO PROCEED TO PROCESS-INQUIRY
  LEGACY-ALTER-DISPATCH: # ALTER DISPATCH-GOTO                            # MANUAL REVIEW                                [FAI
  LEGACY-ALTER-DISPATCH: # ALTER DISPATCH-GOTO                            # MANUAL REVIEW                                [FAI
  LEGACY-ALTER-DISPATCH: # ALTER DISPATCH-GOTO                            # MANUAL REVIEW                                [FAI
  LEGACY-ALTER-DISPATCH: # ALTER DISPATCH-GOTO                            # MANUAL REVIEW                                [FAI
  MAIN-LOAN: # MANUAL REVIEW: CALL 'CALC-INT' — subprogram not analyzed
  MAIN-LOAN: # MANUAL REVIEW: CALL 'APPLY-PENALTY' — subprogram not analyzed
  MAIN-LOAN: # CALL CALC-INT                                  # MANUAL REVIEW                                [FAI
  MAIN-LOAN: # CALL APPLY-PENALTY                             # MANUAL REVIEW                                [FAI
  MR-ALTER-AML-DISPATCH: # MANUAL REVIEW: ALTER 2000-ROUTE-DISPATCH TO PROCEED TO 2100-ROUTE-CRITICAL
  MR-ALTER-AML-DISPATCH: # ALTER 2000-ROUTE-DISPATCH                      # MANUAL REVIEW                                [FAI
  MR-ALTER-ANNUITY-ROUTE: # MANUAL REVIEW: ALTER3000-DISPATCHTOPROCEEDTO3100-FIXED-CALC
  MR-ALTER-ANNUITY-ROUTE: # MANUAL REVIEW: ALTER 3000-DISPATCH TO PROCEED TO 3100-FIXED-CALC
  MR-ALTER-ANNUITY-ROUTE: # MANUAL REVIEW: ALTER3000-DISPATCHTOPROCEEDTO3200-VARIABLE-CALC
  MR-ALTER-ANNUITY-ROUTE: # MANUAL REVIEW: ALTER 3000-DISPATCH TO PROCEED TO 3200-VARIABLE-CALC
  MR-ALTER-ANNUITY-ROUTE: # MANUAL REVIEW: ALTER3000-DISPATCHTOPROCEEDTO3300-INDEXED-CALC
  MR-ALTER-ANNUITY-ROUTE: # MANUAL REVIEW: ALTER 3000-DISPATCH TO PROCEED TO 3300-INDEXED-CALC
  MR-ALTER-ANNUITY-ROUTE: # ALTER 3000-DISPATCH                            # MANUAL REVIEW                                [FAI
  MR-ALTER-ANNUITY-ROUTE: # ALTER 3000-DISPATCH                            # MANUAL REVIEW                                [FAI
  MR-ALTER-ANNUITY-ROUTE: # ALTER 3000-DISPATCH                            # MANUAL REVIEW                                [FAI
  MR-ALTER-ATM-ROUTE: # MANUAL REVIEW: ALTER 9000-ROUTE-EXIT TO PROCEED TO 9100-VISA-HANDLER
  MR-ALTER-ATM-ROUTE: # MANUAL REVIEW: ALTER9000-ROUTE-EXITTOPROCEEDTO9100-VISA-HANDLER
  MR-ALTER-ATM-ROUTE: # MANUAL REVIEW: ALTER 9000-ROUTE-EXIT TO PROCEED TO 9100-VISA-HANDLER
  MR-ALTER-ATM-ROUTE: # MANUAL REVIEW: ALTER9000-ROUTE-EXITTOPROCEEDTO9200-MC-HANDLER
  MR-ALTER-ATM-ROUTE: # MANUAL REVIEW: ALTER 9000-ROUTE-EXIT TO PROCEED TO 9200-MC-HANDLER
  MR-ALTER-ATM-ROUTE: # ALTER 9000-ROUTE-EXIT                          # MANUAL REVIEW                                [FAI
  MR-ALTER-ATM-ROUTE: # ALTER 9000-ROUTE-EXIT                          # MANUAL REVIEW                                [FAI
  MR-ALTER-ATM-ROUTE: # ALTER 9000-ROUTE-EXIT                          # MANUAL REVIEW                                [FAI
  MR-ALTER-BATCH-CTRL: # MANUAL REVIEW: ALTER 2000-DISPATCH TO PROCEED TO 2100-STEP-1
  MR-ALTER-BATCH-CTRL: # MANUAL REVIEW: ALTER2000-DISPATCHTOPROCEEDTO2200-STEP-2
  MR-ALTER-BATCH-CTRL: # MANUAL REVIEW: ALTER 2000-DISPATCH TO PROCEED TO 2200-STEP-2
  MR-ALTER-BATCH-CTRL: # MANUAL REVIEW: ALTER2000-DISPATCHTOPROCEEDTO2300-STEP-3
  MR-ALTER-BATCH-CTRL: # MANUAL REVIEW: ALTER 2000-DISPATCH TO PROCEED TO 2300-STEP-3
  MR-ALTER-BATCH-CTRL: # ALTER 2000-DISPATCH                            # MANUAL REVIEW                                [FAI
  MR-ALTER-BATCH-CTRL: # ALTER 2000-DISPATCH                            # MANUAL REVIEW                                [FAI
  MR-ALTER-BATCH-CTRL: # ALTER 2000-DISPATCH                            # MANUAL REVIEW                                [FAI
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-DEPOSIT
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-WITHDRAWAL
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-TRANSFER
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTERHANDLER-GOTOTOPROCEEDTOHANDLE-INQUIRY
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-DEPOSIT
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-WITHDRAWAL
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-TRANSFER
  MR-ALTER-DISPATCH-V2: # MANUAL REVIEW: ALTER HANDLER-GOTO TO PROCEED TO HANDLE-INQUIRY
  MR-ALTER-DISPATCH-V2: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-DISPATCH-V2: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-DISPATCH-V2: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-DISPATCH-V2: # ALTER HANDLER-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-ERROR-ROUTE: # MANUAL REVIEW: ALTER 2000-ERROR-HANDLER TO PROCEED TO 2100-INFO-HANDLER
  MR-ALTER-ERROR-ROUTE: # MANUAL REVIEW: ALTER2000-ERROR-HANDLERTOPROCEEDTO2100-INFO-HANDLER
  MR-ALTER-ERROR-ROUTE: # MANUAL REVIEW: ALTER2000-ERROR-HANDLERTOPROCEEDTO2200-WARNING-HANDLER
  MR-ALTER-ERROR-ROUTE: # MANUAL REVIEW: ALTER2000-ERROR-HANDLERTOPROCEEDTO2300-ERROR-HANDLER
  MR-ALTER-ERROR-ROUTE: # MANUAL REVIEW: ALTER2000-ERROR-HANDLERTOPROCEEDTO2400-FATAL-HANDLER
  MR-ALTER-ERROR-ROUTE: # MANUAL REVIEW: ALTER 2000-ERROR-HANDLER TO PROCEED TO 2100-INFO-HANDLER
  MR-ALTER-ERROR-ROUTE: # MANUAL REVIEW: ALTER 2000-ERROR-HANDLER TO PROCEED TO 2200-WARNING-HANDLER
  MR-ALTER-ERROR-ROUTE: # MANUAL REVIEW: ALTER 2000-ERROR-HANDLER TO PROCEED TO 2300-ERROR-HANDLER
  MR-ALTER-ERROR-ROUTE: # MANUAL REVIEW: ALTER 2000-ERROR-HANDLER TO PROCEED TO 2400-FATAL-HANDLER
  MR-ALTER-ERROR-ROUTE: # ALTER 2000-ERROR-HANDLER                       # MANUAL REVIEW                                [FAI
  MR-ALTER-ERROR-ROUTE: # ALTER 2000-ERROR-HANDLER                       # MANUAL REVIEW                                [FAI
  MR-ALTER-ERROR-ROUTE: # ALTER 2000-ERROR-HANDLER                       # MANUAL REVIEW                                [FAI
  MR-ALTER-ERROR-ROUTE: # ALTER 2000-ERROR-HANDLER                       # MANUAL REVIEW                                [FAI
  MR-ALTER-ERROR-ROUTE: # ALTER 2000-ERROR-HANDLER                       # MANUAL REVIEW                                [FAI
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTERSERVICE-GOTOTOPROCEEDTOPRIMARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTERSERVICE-GOTOTOPROCEEDTOSECONDARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTERSERVICE-GOTOTOPROCEEDTOTERTIARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTER SERVICE-GOTO TO PROCEED TO PRIMARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTER SERVICE-GOTO TO PROCEED TO SECONDARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTER SERVICE-GOTO TO PROCEED TO TERTIARY-SERVICE
  MR-ALTER-FALLBACK: # ALTER SERVICE-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-FALLBACK: # ALTER SERVICE-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-FALLBACK: # ALTER SERVICE-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-MTG-ROUTE: # MANUAL REVIEW: ALTER2000-ROUTE-DISPATCHTOPROCEEDTO3000-FHA-PROCESS
  MR-ALTER-MTG-ROUTE: # MANUAL REVIEW: ALTER2000-ROUTE-DISPATCHTOPROCEEDTO4000-VA-PROCESS
  MR-ALTER-MTG-ROUTE: # MANUAL REVIEW: ALTER2000-ROUTE-DISPATCHTOPROCEEDTO5000-CONV-PROCESS
  MR-ALTER-MTG-ROUTE: # MANUAL REVIEW: ALTER2000-ROUTE-DISPATCHTOPROCEEDTO6000-ERROR-HANDLER
  MR-ALTER-MTG-ROUTE: # MANUAL REVIEW: ALTER 2000-ROUTE-DISPATCH TO PROCEED TO 3000-FHA-PROCESS
  MR-ALTER-MTG-ROUTE: # MANUAL REVIEW: ALTER 2000-ROUTE-DISPATCH TO PROCEED TO 4000-VA-PROCESS
  MR-ALTER-MTG-ROUTE: # MANUAL REVIEW: ALTER 2000-ROUTE-DISPATCH TO PROCEED TO 5000-CONV-PROCESS
  MR-ALTER-MTG-ROUTE: # MANUAL REVIEW: ALTER 2000-ROUTE-DISPATCH TO PROCEED TO 6000-ERROR-HANDLER
  MR-ALTER-MTG-ROUTE: # ALTER 2000-ROUTE-DISPATCH                      # MANUAL REVIEW                                [FAI
  MR-ALTER-MTG-ROUTE: # ALTER 2000-ROUTE-DISPATCH                      # MANUAL REVIEW                                [FAI
  MR-ALTER-MTG-ROUTE: # ALTER 2000-ROUTE-DISPATCH                      # MANUAL REVIEW                                [FAI
  MR-ALTER-MTG-ROUTE: # ALTER 2000-ROUTE-DISPATCH                      # MANUAL REVIEW                                [FAI
  MR-ALTER-RATE-ROUTE: # MANUAL REVIEW: ALTERROUTE-CALCTOPROCEEDTOCALC-CD-RATE
  MR-ALTER-RATE-ROUTE: # MANUAL REVIEW: ALTERROUTE-CALCTOPROCEEDTOCALC-SAVINGS-RATE
  MR-ALTER-RATE-ROUTE: # MANUAL REVIEW: ALTERROUTE-CALCTOPROCEEDTOCALC-CHECKING-RATE
  MR-ALTER-RATE-ROUTE: # MANUAL REVIEW: ALTERROUTE-CALCTOPROCEEDTOCALC-MM-RATE
  MR-ALTER-RATE-ROUTE: # MANUAL REVIEW: ALTER ROUTE-CALC TO PROCEED TO CALC-CD-RATE
  MR-ALTER-RATE-ROUTE: # MANUAL REVIEW: ALTER ROUTE-CALC TO PROCEED TO CALC-SAVINGS-RATE
  MR-ALTER-RATE-ROUTE: # MANUAL REVIEW: ALTER ROUTE-CALC TO PROCEED TO CALC-CHECKING-RATE
  MR-ALTER-RATE-ROUTE: # MANUAL REVIEW: ALTER ROUTE-CALC TO PROCEED TO CALC-MM-RATE
  MR-ALTER-RATE-ROUTE: # ALTER ROUTE-CALC                               # MANUAL REVIEW                                [FAI
  MR-ALTER-RATE-ROUTE: # ALTER ROUTE-CALC                               # MANUAL REVIEW                                [FAI
  MR-ALTER-RATE-ROUTE: # ALTER ROUTE-CALC                               # MANUAL REVIEW                                [FAI
  MR-ALTER-RATE-ROUTE: # ALTER ROUTE-CALC                               # MANUAL REVIEW                                [FAI
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTERERROR-HANDLERTOPROCEEDTOHANDLE-TIMEOUT
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTERERROR-HANDLERTOPROCEEDTOHANDLE-DATA-ERR
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTERERROR-HANDLERTOPROCEEDTOHANDLE-CONN-FAIL
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTER ERROR-HANDLER TO PROCEED TO HANDLE-TIMEOUT
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTER ERROR-HANDLER TO PROCEED TO HANDLE-DATA-ERR
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTER ERROR-HANDLER TO PROCEED TO HANDLE-CONN-FAIL
  MR-ALTER-RECOVERY: # ALTER ERROR-HANDLER                            # MANUAL REVIEW                                [FAI
  MR-ALTER-RECOVERY: # ALTER ERROR-HANDLER                            # MANUAL REVIEW                                [FAI
  MR-ALTER-RECOVERY: # ALTER ERROR-HANDLER                            # MANUAL REVIEW                                [FAI
  MR-ALTER-STATE-MACH: # MANUAL REVIEW: ALTER 2000-STATE-HANDLER TO PROCEED TO 2100-NEW-STATE
  MR-ALTER-STATE-MACH: # MANUAL REVIEW: ALTER2000-STATE-HANDLERTOPROCEEDTO2200-REVIEW-STATE
  MR-ALTER-STATE-MACH: # MANUAL REVIEW: ALTER 2000-STATE-HANDLER TO PROCEED TO 2200-REVIEW-STATE
  MR-ALTER-STATE-MACH: # MANUAL REVIEW: ALTER2000-STATE-HANDLERTOPROCEEDTO2300-APPROVED-STATE
  MR-ALTER-STATE-MACH: # MANUAL REVIEW: ALTER 2000-STATE-HANDLER TO PROCEED TO 2300-APPROVED-STATE
  MR-ALTER-STATE-MACH: # ALTER 2000-STATE-HANDLER                       # MANUAL REVIEW                                [FAI
  MR-ALTER-STATE-MACH: # ALTER 2000-STATE-HANDLER                       # MANUAL REVIEW                                [FAI
  MR-ALTER-STATE-MACH: # ALTER 2000-STATE-HANDLER                       # MANUAL REVIEW                                [FAI
  MR-CICS-TELLER-INQ: pass  # MANUAL REVIEW: inline PERFORM VARYING body
  OCC-CALL-REPORT: # MANUAL REVIEW: SETWS-CHK-PASS(1)TOTRUE
  OCC-CALL-REPORT: # MANUAL REVIEW: SETWS-CHK-FAIL(1)TOTRUE
  OCC-CALL-REPORT: # MANUAL REVIEW: SETWS-CHK-PASS(2)TOTRUE
  OCC-CALL-REPORT: # MANUAL REVIEW: SETWS-CHK-FAIL(2)TOTRUE
  OCC-CALL-REPORT: # MANUAL REVIEW: SETWS-CHK-PASS(3)TOTRUE
  OCC-CALL-REPORT: # MANUAL REVIEW: SETWS-CHK-FAIL(3)TOTRUE
  PAYROLL-TAX-ENGINE: # MANUAL REVIEW: ADD
  PAYROLL-TAX-ENGINE: # ADD                                            # MANUAL REVIEW                                [FAI
  PORT-REBALANCE: # MANUAL REVIEW: MOVE0TOWS-AC-TRADE-AMT(WS-IDX)END-IFELSEIFWS-AC-TRADE-AMT(WS
  PORT-REBALANCE: # MANUAL REVIEW: MOVE0TOWS-AC-TRADE-AMT(WS-IDX)END-IFELSEMOVE'HOLD'TOWS-AC-AC
  SS-BENEFIT-CALC: # MANUAL REVIEW: SORT — missing USING/GIVING
  SS-BENEFIT-CALC: # SORT WS-EARN-ENTRY                             # MANUAL REVIEW                                [FAI
  TAX-EITC-CALC: # MANUAL REVIEW: WS-MFJMOVE17250TOWS-PHASE-OUT-STARTMOVE25010TOWS-PHASE-OUT-E
  TAX-EITC-CALC: # MANUAL REVIEW: WS-MFJMOVE27380TOWS-PHASE-OUT-STARTMOVE52370TOWS-PHASE-OUT-E
  TAX-EITC-CALC: # MANUAL REVIEW: WS-MFJMOVE27380TOWS-PHASE-OUT-STARTMOVE58730TOWS-PHASE-OUT-E
  TAX-EITC-CALC: # MANUAL REVIEW: WS-MFJMOVE27380TOWS-PHASE-OUT-STARTMOVE62650TOWS-PHASE-OUT-E
  WIRE-XFER-VALIDATE: # MANUAL REVIEW: WS-IBAN-COUNTRYISNOTALPHABETIC
  WIRE-XFER-VALIDATE: # IF WS-IBAN-COUNTRYISNOTALPHABETIC              # MANUAL REVIEW: WS-IBAN-COUNTRYISNOTALPHABET  [FAI

==========================================================================================
  PVR = 93.7%  (430 clean / 459 tested)
==========================================================================================
