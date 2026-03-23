<ACCT-TITLE-CHANGE>:83: SyntaxWarning: invalid escape sequence '\ '
line 158:15 no viable alternative at input 'IF WS-LATE-DAYS > 30\n                   MULTIPLY WS-PAYMENT-AMT BY WS-LATE-FEE-RATE\n                       GIVING WS-LATE-FEE\n                   MULTIPLY WS-LATE-FEE BY 2\n               ELSE'
line 158:15 no viable alternative at input 'MULTIPLY WS-PAYMENT-AMT BY WS-LATE-FEE-RATE\n                       GIVING WS-LATE-FEE\n                   MULTIPLY WS-LATE-FEE BY 2\n               ELSE'
line 158:15 no viable alternative at input '2\n               ELSE'
line 158:15 mismatched input 'ELSE' expecting SECTION
line 159:43 mismatched input 'BY' expecting SECTION
line 160:23 mismatched input 'GIVING' expecting SECTION
line 161:15 mismatched input 'END-IF' expecting SECTION
line 162:31 mismatched input 'TO' expecting SECTION
line 163:11 mismatched input 'END-IF' expecting SECTION
<CLR-CHECK-IMAGE>:67: SyntaxWarning: invalid escape sequence '\ '
line 10:17 mismatched input '*' expecting <EOF>
<FRAUD-ALERT-FORMAT>:75: SyntaxWarning: invalid escape sequence '\|'
line 3:17 mismatched input 'J' expecting <EOF>
line 30:15 no viable alternative at input 'SUBTRACT 40 FROM WS-HOURS\n                   GIVING WS-OVERTIME-HRS\n               MULTIPLY WS-OVERTIME-HRS BY WS-RATE\n                   GIVING WS-OVERTIME-PAY\n               MULTIPLY WS-OVERTIME-PAY BY 1.5\n               ADD'
line 30:15 mismatched input 'ADD' expecting GIVING
line 31:11 no viable alternative at input 'WS-GROSS-PAY\n           END-IF'
line 68:28 mismatched input 'SIZE' expecting {ABORT, ADDRESS, ALL, AS, ASCII, ASSOCIATED_DATA, ASSOCIATED_DATA_LENGTH, ATTRIBUTE, AUTO, AUTO_SKIP, BACKGROUND_COLOR, BACKGROUND_COLOUR, BEEP, BELL, BINARY, BIT, BLINK, BOUNDS, CAPABLE, CCSVERSION, CHANGED, CHANNEL, CLOSE_DISPOSITION, COBOL, COMMITMENT, CONTROL_POINT, CONVENTION, CRUNCH, CURSOR, DATE, DAY, DAY_OF_WEEK, DEBUG_CONTENTS, DEBUG_ITEM, DEBUG_LINE, DEBUG_NAME, DEBUG_SUB_1, DEBUG_SUB_2, DEBUG_SUB_3, DEFAULT, DEFAULT_DISPLAY, DEFINITION, DFHRESP, DFHVALUE, DISK, DONTCARE, DOUBLE, EBCDIC, EMPTY_CHECK, ENTER, ENTRY_PROCEDURE, ERASE, EOL, EOS, ESCAPE, EVENT, EXCLUSIVE, EXPORT, EXTENDED, FALSE, FOREGROUND_COLOR, FOREGROUND_COLOUR, FULL, FUNCTION, FUNCTIONNAME, FUNCTION_POINTER, GRID, HIGHLIGHT, HIGH_VALUE, HIGH_VALUES, IMPLICIT, IMPORT, INTEGER, KEPT, KEYBOARD, LANGUAGE, LB, LD, LEFTLINE, LENGTH, LENGTH_CHECK, LIBACCESS, LIBPARAMETER, LIBRARY, LINAGE_COUNTER, LINE_COUNTER, LIST, LOCAL, LONG_DATE, LONG_TIME, LOWER, LOWLIGHT, LOW_VALUE, LOW_VALUES, MMDDYYYY, NAMED, NATIONAL, NATIONAL_EDITED, NETWORK, NO_ECHO, NULL_, NULLS, NUMERIC_DATE, NUMERIC_TIME, ODT, ORDERLY, OVERLINE, OWN, PAGE_COUNTER, PASSWORD, PORT, PRINTER, PRIVATE, PROCESS, PROGRAM, PROMPT, QUOTE, QUOTES, READER, REMOTE, REAL, RECEIVED, RECURSIVE, REF, REMOVE, REQUIRED, REVERSE_VIDEO, RETURN_CODE, SAVE, SECURE, SHARED, SHAREDBYALL, SHAREDBYRUNUNIT, SHARING, SHIFT_IN, SHIFT_OUT, SHORT_DATE, SORT_CONTROL, SORT_CORE_SIZE, SORT_FILE_SIZE, SORT_MESSAGE, SORT_MODE_SIZE, SORT_RETURN, SPACE, SPACES, SYMBOL, TALLY, TASK, THREAD, THREAD_LOCAL, TIME, TIMER, TODAYS_DATE, TODAYS_NAME, TRUE, TRUNCATED, TYPEDEF, UNDERLINE, VIRTUAL, WAIT, WHEN_COMPILED, YEAR, YYYYMMDD, YYYYDDD, ZERO, ZERO_FILL, ZEROS, ZEROES, NONNUMERICLITERAL, '66', '77', '88', INTEGERLITERAL, NUMERICLITERAL, IDENTIFIER}
<REG-OFAC-MATCH>:82: SyntaxWarning: invalid escape sequence '\ '
<REG-OFAC-MATCH>:96: SyntaxWarning: invalid decimal literal
<REG-TIN-VALIDATOR>:120: SyntaxWarning: invalid decimal literal
<STMT-LINE-BUILDER>:196: SyntaxWarning: invalid escape sequence '\|'
<STRING-INSPECT-REPORT>:161: SyntaxWarning: invalid escape sequence '\|'
<TAX-CORRECTED-1099>:86: SyntaxWarning: invalid escape sequence '\ '
<TRADE-CUSTODY-FEE>:68: SyntaxWarning: invalid decimal literal
<TREAS-LOCKBOX-PROC>:83: SyntaxWarning: invalid escape sequence '\|'
<WIRE-VALIDATE>:86: SyntaxWarning: invalid escape sequence '\|'
==========================================================================================
  ALETHEIA VIABILITY EXPERIMENT
==========================================================================================

  Programs tested    : 200
  Parse success      : 199/200 (99.5%)
  Generate success   : 200/200 (100.0%)
  Compile success    : 181/200 (90.5%)
  Clean (0 MR)       : 165/200 (82.5%)
  With MANUAL REVIEW : 31 programs, 100 total flags

  PVR (Parse-Verify Rate) = 82.5%

  PROGRAM                   LINES  PARSE   GEN  COMP   MR STATUS                        
  --------------------------------------------------------------------------------------
  ACCT-BENE-UPDATE            121     OK    OK    OK    0 VERIFIED                      
  ACCT-CLOSE-PROC             123     OK    OK    OK    0 VERIFIED                      
  ACCT-ESCHEAT-SCAN           111     OK    OK    OK    0 VERIFIED                      
  ACCT-HOLD-RELEASE           116     OK    OK    OK    0 VERIFIED                      
  ACCT-INTEREST               124     OK    OK    OK    0 VERIFIED                      
  ACCT-MERGE-HANDLER           94     OK    OK    OK    0 VERIFIED                      
  ACCT-MIN-BAL-CHECK          105     OK    OK    OK    0 VERIFIED                      
  ACCT-RECON-DAILY            142     OK    OK    OK    0 VERIFIED                      
  ACCT-REDEFINE                22     OK    OK    OK    0 VERIFIED                      
  ACCT-STMT-CYCLE             127     OK    OK    OK    0 VERIFIED                      
  ACCT-TIER-ASSIGN            112     OK    OK    OK    0 VERIFIED                      
  ACCT-TITLE-CHANGE           100     OK    OK  FAIL    1 COMPILE ERROR: expected ':' (l
  ACH-BATCH-VALIDATOR         312     OK    OK    OK    0 VERIFIED                      
  ALTER-DANGER                 18     OK    OK    OK    2 2 MANUAL REVIEW flags         
  ALTER-SQL-HYBRID            212     OK    OK    OK   12 12 MANUAL REVIEW flags        
  ALTER-TEST                   25     OK    OK    OK    2 2 MANUAL REVIEW flags         
  APPLY-PENALTY                23     OK    OK    OK    0 VERIFIED                      
  ARITHMETIC-STRESS           102     OK    OK    OK    0 VERIFIED                      
  BATCH-GL-POSTING            337     OK    OK    OK    0 VERIFIED                      
  BATCH-PAYMENT               192     OK    OK    OK    0 VERIFIED                      
  BATCH-PAYROLL-RUN           305     OK    OK    OK    0 VERIFIED                      
  CALC-INT                     18     OK    OK    OK    0 VERIFIED                      
  CARD-AUTH-PROCESSOR         294     OK    OK    OK    0 VERIFIED                      
  CD-MATURITY-CALC            220     OK    OK    OK    0 VERIFIED                      
  CHECK-DIGIT-VALIDATOR       246     OK    OK    OK    0 VERIFIED                      
  CLR-CHECK-IMAGE              68     OK    OK    OK    0 VERIFIED                      
  CLR-CORRESPONDENT            68     OK    OK    OK    0 VERIFIED                      
  CLR-DISPUTE-CALC             66     OK    OK    OK    0 VERIFIED                      
  CLR-EXCEPTION-PROC           89     OK    OK    OK    0 VERIFIED                      
  CLR-FED-RESERVE-FMT          72     OK    OK    OK    0 VERIFIED                      
  CLR-INTERBANK-FEE            58     OK    OK    OK    0 VERIFIED                      
  CLR-NET-SETTLE               62     OK    OK    OK    0 VERIFIED                      
  CLR-RETURN-REASON            86     OK    OK    OK    0 VERIFIED                      
  COLLATERAL-LTV-CALC         234     OK    OK    OK    0 VERIFIED                      
  COMPOUND-INT                 27     OK    OK    OK    0 VERIFIED                      
  CREDIT-SCORE                180     OK    OK    OK    0 VERIFIED                      
  CSV-PARSER                   21     OK    OK    OK    0 VERIFIED                      
  CURRENCY-DENOM-CALC         198     OK    OK    OK    0 VERIFIED                      
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
  DEP-REG-D-MONITOR            64     OK    OK    OK    0 VERIFIED                      
  DEP-TIER-INTEREST            75     OK    OK    OK    0 VERIFIED                      
  DEP-UNCLM-PROP               83     OK    OK    OK    1 1 MANUAL REVIEW flags         
  DEPOSIT-RECONCILE           254     OK    OK    OK    0 VERIFIED                      
  DISPLAY-MIX                  18     OK    OK    OK    0 VERIFIED                      
  DIV-REMAINDER                18     OK    OK    OK    0 VERIFIED                      
  DORMANT-ACCT-SWEEP          220     OK    OK    OK    0 VERIFIED                      
  DYNAMIC-TABLE                25     OK    OK    OK    0 VERIFIED                      
  EMBEDDED-SQL-BATCH          215     OK    OK    OK    3 3 MANUAL REVIEW flags         
  ESCROW-ANALYSIS             233     OK    OK    OK    0 VERIFIED                      
  EVAL-ALSO                    22     OK    OK    OK    0 VERIFIED                      
  EVAL-ALSO-PRICING            68     OK    OK    OK    0 VERIFIED                      
  EVAL-ALSO-RATE-MATRIX       205     OK    OK    OK    0 VERIFIED                      
  EVAL-VARIABLE                36     OK    OK    OK    0 VERIFIED                      
  EVALUATE-TEST                60     OK    OK    OK    0 VERIFIED                      
  EXEC-SQL-TEST                45     OK    OK    OK    0 VERIFIED                      
  FRAUD-ACCT-TAKEOVER         108     OK    OK    OK    0 VERIFIED                      
  FRAUD-ALERT-FORMAT           91     OK    OK    OK    0 VERIFIED                      
  FRAUD-BIN-LOOKUP             71     OK    OK    OK    0 VERIFIED                      
  FRAUD-CHARGEBACK             89     OK    OK    OK    0 VERIFIED                      
  FRAUD-DEVICE-SCORE          111     OK    OK    OK    0 VERIFIED                      
  FRAUD-GEO-ANOMALY           100     OK    OK    OK    0 VERIFIED                      
  FRAUD-LINK-ANALYZE           93     OK    OK  FAIL    2 COMPILE ERROR: expected ':' (l
  FRAUD-RULE-ENGINE           114     OK    OK    OK    1 1 MANUAL REVIEW flags         
  FRAUD-THRESHOLD-ADJ          94     OK    OK    OK    0 VERIFIED                      
  FRAUD-VELOCITY-CHK          100     OK    OK    OK    0 VERIFIED                      
  FX-RATE-CONVERTER           274     OK    OK    OK    0 VERIFIED                      
  GOTO-DEPEND                  21     OK    OK    OK    0 VERIFIED                      
  GOTO-DEPEND-ROUTER           66     OK    OK    OK    0 VERIFIED                      
  GOTO-FLOW                    26     OK    OK    OK    0 VERIFIED                      
  INIT-TEST                    22     OK    OK    OK    0 VERIFIED                      
  INS-ANNUITY-VALUE            75     OK    OK    OK    0 VERIFIED                      
  INS-BENEFIT-SCHED           105     OK    OK    OK    0 VERIFIED                      
  INS-CLAIM-ADJUDIC           120     OK    OK    OK    1 1 MANUAL REVIEW flags         
  INS-COINSURE-SPLIT           85     OK    OK  FAIL    0 COMPILE ERROR: invalid syntax 
  INS-LAPSE-NOTICE            103     OK    OK    OK    0 VERIFIED                      
  INS-MORTALITY-TBL            94     OK    OK    OK    0 VERIFIED                      
  INS-PREM-CALC                98     OK    OK    OK    0 VERIFIED                      
  INS-RESERVE-POST             81     OK    OK    OK    0 VERIFIED                      
  INSPECT-CONV                 12     OK    OK    OK    0 VERIFIED                      
  INSPECT-CONV-SANITIZE        69     OK    OK    OK    0 VERIFIED                      
  INTEREST-ACCRUAL-BATCH      258     OK    OK    OK    0 VERIFIED                      
  INTR-CALC-3270               37   FAIL    OK    OK    0 VERIFIED                      
  INVOICE-GEN                  59     OK    OK    OK    0 VERIFIED                      
  LATE-FEE-ASSESSOR           228     OK    OK    OK    0 VERIFIED                      
  LEGACY-ALTER-DISPATCH       154     OK    OK    OK   12 12 MANUAL REVIEW flags        
  LOAN-AMORT-ENGINE           256     OK    OK    OK    0 VERIFIED                      
  LOAN-CONV-ASSESS            161     OK    OK    OK    0 VERIFIED                      
  LOAN-COUPON-STRIP           123     OK    OK    OK    0 VERIFIED                      
  LOAN-DELINQ-TRACKER         153     OK    OK    OK    0 VERIFIED                      
  LOAN-ESCROW-ADJUST          145     OK    OK    OK    0 VERIFIED                      
  LOAN-FORBEARANCE-CALC       183     OK    OK    OK    0 VERIFIED                      
  LOAN-GRACE-PERIOD-CALC      189     OK    OK  FAIL    5 COMPILE ERROR: expected ':' (l
  LOAN-LOSS-RESERVE           130     OK    OK    OK    0 VERIFIED                      
  LOAN-MODIF-ENGINE           156     OK    OK    OK    0 VERIFIED                      
  LOAN-PAYOFF-QUOTE           123     OK    OK    OK    0 VERIFIED                      
  LOAN-PMI-REMOVAL            155     OK    OK  FAIL    2 COMPILE ERROR: expected ':' (l
  LOAN-PREPAY-PENALTY         176     OK    OK    OK    0 VERIFIED                      
  LOAN-RATE-RESET             171     OK    OK    OK    0 VERIFIED                      
  MAIN-LOAN                    34     OK    OK    OK    0 VERIFIED                      
  MISC-AUDIT-TRAIL             75     OK    OK    OK    1 1 MANUAL REVIEW flags         
  MISC-BATCH-TOTALS            68     OK    OK    OK    0 VERIFIED                      
  MISC-BRANCH-GL-POST         111     OK    OK    OK    0 VERIFIED                      
  MISC-DATE-CALC               63     OK    OK    OK    0 VERIFIED                      
  MISC-FEE-WAIVER              65     OK    OK    OK    0 VERIFIED                      
  MISC-LETTER-GEN              83     OK    OK    OK    1 1 MANUAL REVIEW flags         
  MISC-RATE-COMPARE            64     OK    OK    OK    0 VERIFIED                      
  MISC-SAFE-BOX-BILL           64     OK    OK    OK    0 VERIFIED                      
  MONTHLY-TOTALS               28     OK    OK    OK    0 VERIFIED                      
  MR-ALTER-DISPATCH-V2        112     OK    OK    OK   12 12 MANUAL REVIEW flags        
  MR-ALTER-FALLBACK           116     OK    OK    OK    9 9 MANUAL REVIEW flags         
  MR-ALTER-RECOVERY           100     OK    OK    OK    9 9 MANUAL REVIEW flags         
  MR-EXEC-CICS-MAP            112     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-CICS-QUEUE           96     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-SQL-CURSOR          105     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-SQL-REPORT          102     OK    OK    OK    0 VERIFIED                      
  MR-EXEC-SQL-UPDATE          111     OK    OK  FAIL    2 COMPILE ERROR: expected an ind
  MR-ODO-INVOICE              112     OK    OK  FAIL    2 COMPILE ERROR: expected ':' (l
  MR-ODO-TABLE                 92     OK    OK    OK    0 VERIFIED                      
  MSG-BUILDER                  18     OK    OK    OK    0 VERIFIED                      
  NESTED-EVAL                  38     OK    OK    OK    0 VERIFIED                      
  OVERDRAFT-PROCESSOR         240     OK    OK    OK    0 VERIFIED                      
  PAY-ADDENDA-PARSE           118     OK    OK  FAIL    1 COMPILE ERROR: expected ':' (l
  PAY-BATCH-SETTLE            130     OK    OK    OK    0 VERIFIED                      
  PAY-CUTOFF-CHECK            104     OK    OK    OK    0 VERIFIED                      
  PAY-FLOAT-CALC              120     OK    OK    OK    0 VERIFIED                      
  PAY-LIMIT-ENFORCE           125     OK    OK  FAIL    4 COMPILE ERROR: expected ':' (l
  PAY-NSF-FEE-CALC            150     OK    OK  FAIL    1 COMPILE ERROR: expected an ind
  PAY-OFFSET-APPLY            112     OK    OK    OK    0 VERIFIED                      
  PAY-ORIGINATOR-FEE          100     OK    OK    OK    0 VERIFIED                      
  PAY-PRENOTE-VALID           134     OK    OK  FAIL    1 COMPILE ERROR: expected ':' (l
  PAY-RECUR-SCHED             120     OK    OK  FAIL    0 COMPILE ERROR: invalid syntax 
  PAY-RETURN-PROC             126     OK    OK    OK    0 VERIFIED                      
  PAY-SAME-DAY-ACH            139     OK    OK  FAIL    1 COMPILE ERROR: expected ':' (l
  PAYROLL-CALC                 47     OK    OK    OK    0 VERIFIED                      
  PENSION-BENEFIT-CALC        262     OK    OK    OK    0 VERIFIED                      
  PERFORM-VARYING-TEST         71     OK    OK    OK    0 VERIFIED                      
  REG-BSA-AGGREGATE           105     OK    OK    OK    0 VERIFIED                      
  REG-CALL-RPT-GEN             85     OK    OK    OK    0 VERIFIED                      
  REG-CRA-GEOCODE             102     OK    OK  FAIL    2 COMPILE ERROR: expected ':' (l
  REG-CTR-BUILDER             103     OK    OK    OK    0 VERIFIED                      
  REG-HMDA-EXTRACT            110     OK    OK    OK    1 1 MANUAL REVIEW flags         
  REG-OFAC-MATCH              112     OK    OK  FAIL    1 COMPILE ERROR: invalid decimal
  REG-RISK-WEIGHT              96     OK    OK    OK    0 VERIFIED                      
  REG-SAR-SCREEN              100     OK    OK    OK    0 VERIFIED                      
  REG-STRESS-CALC              98     OK    OK    OK    0 VERIFIED                      
  REG-TIN-VALIDATOR           111     OK    OK  FAIL    3 COMPILE ERROR: expected ':' (l
  REPEAT-TIMES                 16     OK    OK    OK    0 VERIFIED                      
  REWRITE-ACCT-UPDATE          75     OK    OK    OK    0 VERIFIED                      
  SORT-MERGE-RECON             58     OK    OK    OK    0 VERIFIED                      
  SORT-TXN-REPORT             203     OK    OK    OK    0 VERIFIED                      
  STATUS-CHECKER               35     OK    OK    OK    0 VERIFIED                      
  STMT-LINE-BUILDER           246     OK    OK    OK    0 VERIFIED                      
  STRING-INSPECT-REPORT       207     OK    OK    OK    0 VERIFIED                      
  STRING-PTR                   16     OK    OK    OK    0 VERIFIED                      
  STRING-PTR-ASSEMBLER         61     OK    OK    OK    0 VERIFIED                      
  TAX-1099-INT-GEN             93     OK    OK    OK    1 1 MANUAL REVIEW flags         
  TAX-BACKUP-SCREEN            78     OK    OK    OK    0 VERIFIED                      
  TAX-CORRECTED-1099           88     OK    OK    OK    0 VERIFIED                      
  TAX-COST-BASIS               71     OK    OK    OK    0 VERIFIED                      
  TAX-FOREIGN-CREDIT           63     OK    OK    OK    0 VERIFIED                      
  TAX-REMIC-ALLOC              89     OK    OK    OK    0 VERIFIED                      
  TAX-W8BEN-VALID             114     OK    OK    OK    3 3 MANUAL REVIEW flags         
  TAX-WITHOLD-CALC            103     OK    OK    OK    0 VERIFIED                      
  TELLER-BATCH-BALANCE        291     OK    OK    OK    0 VERIFIED                      
  TRADE-ACCRUED-INT            84     OK    OK    OK    0 VERIFIED                      
  TRADE-BOND-YIELD            130     OK    OK    OK    0 VERIFIED                      
  TRADE-CONFIRM-GEN            78     OK    OK    OK    0 VERIFIED                      
  TRADE-CORP-ACTION           102     OK    OK    OK    0 VERIFIED                      
  TRADE-CUSTODY-FEE            89     OK    OK  FAIL    0 COMPILE ERROR: invalid decimal
  TRADE-DIVIDEND-POST          84     OK    OK    OK    0 VERIFIED                      
  TRADE-FAIL-TRACKER          116     OK    OK    OK    0 VERIFIED                      
  TRADE-MARGIN-CALC           112     OK    OK    OK    0 VERIFIED                      
  TRADE-SETTLE-BATCH          124     OK    OK    OK    0 VERIFIED                      
  TRADE-TAX-LOT-CALC           95     OK    OK  FAIL    1 COMPILE ERROR: expected ':' (l
  TREAS-FED-FUNDS-PRC          73     OK    OK    OK    0 VERIFIED                      
  TREAS-LIQUIDITY-RPT          93     OK    OK    OK    0 VERIFIED                      
  TREAS-LOCKBOX-PROC          113     OK    OK    OK    0 VERIFIED                      
  TREAS-NOSTRO-RECON          126     OK    OK    OK    0 VERIFIED                      
  TREAS-POOL-ALLOC            111     OK    OK  FAIL    0 COMPILE ERROR: invalid decimal
  TREAS-POS-CASH-CALC          90     OK    OK    OK    0 VERIFIED                      
  TREAS-REPO-SETTLE            97     OK    OK    OK    0 VERIFIED                      
  TREAS-SWEEP-ENGINE          122     OK    OK    OK    0 VERIFIED                      
  TREAS-WIRE-FEE-CALC         105     OK    OK    OK    0 VERIFIED                      
  TREAS-ZBA-TRANSFER           98     OK    OK    OK    0 VERIFIED                      
  TYPE-CHECKER                 25     OK    OK    OK    0 VERIFIED                      
  UNSTR-COMPLEX                20     OK    OK    OK    0 VERIFIED                      
  UNSTRING-DELIM-PARSER        87     OK    OK    OK    0 VERIFIED                      
  VSAM-ACCT-UPDATE            247     OK    OK    OK    0 VERIFIED                      
  WIRE-TRANSFER-CALC          286     OK    OK    OK    0 VERIFIED                      
  WIRE-VALIDATE               130     OK    OK    OK    0 VERIFIED                      
  WRITE-ADV-REPORT             90     OK    OK    OK    0 VERIFIED                      

  CONSTRUCT FREQUENCY (across all programs)
  --------------------------------------------------
  STOP RUN                  195 ########################################
  MOVE                      190 ########################################
  PERFORM                   174 ########################################
  IF/ELSE                   172 ########################################
  DISPLAY                   163 ########################################
  INITIALIZE                157 ########################################
  COMP-3                    155 ########################################
  88-level                  154 ########################################
  COMPUTE                   142 ########################################
  ADD                       117 ########################################
  EVALUATE TRUE              88 ########################################
  PERFORM VARYING            76 ########################################
  OCCURS                     61 ########################################
  SUBTRACT                   47 ########################################
  STRING                     44 ########################################
  MULTIPLY                   19 ###################
  EVALUATE variable          19 ###################
  DIVIDE                     17 #################
  UNSTRING                   16 ################
  GO TO                      15 ###############
  PERFORM THRU               15 ###############
  IS NUMERIC                 14 ##############
  DIVIDE REMAINDER            9 #########
  ALTER                       7 #######
  PERFORM TIMES               7 #######
  EXEC SQL                    6 ######
  REDEFINES                   3 ###
  STRING POINTER              3 ###
  EVALUATE ALSO               3 ###
  DELIMITER IN                2 ##
  COPY                        1 #
  88 THRU                     1 #
  IS ALPHABETIC               1 #

  FAILURE CATEGORIES
  --------------------------------------------------
  compile_error                  19

  MANUAL REVIEW FLAGS (100 total)
  --------------------------------------------------
  ACCT-TITLE-CHANGE: if True  # MANUAL REVIEW: WS-NEW-FIRST(1:1)ISNUMERIC:
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
  DEP-UNCLM-PROP: # MANUAL REVIEW: WRITERPT-RECORD
  EMBEDDED-SQL-BATCH: # MANUAL REVIEW: CONTINUE
  EMBEDDED-SQL-BATCH: # MANUAL REVIEW: CONTINUE
  EMBEDDED-SQL-BATCH: # MANUAL REVIEW: CONTINUE
  FRAUD-LINK-ANALYZE: if True  # MANUAL REVIEW: WS-BLOCKORWS-REVIEW:
  FRAUD-LINK-ANALYZE: # IF WS-BLOCKORWS-REVIEW                         if True  # MANUAL REVIEW: WS-BLOCKORWS-REVIEW  [FAI
  FRAUD-RULE-ENGINE: # MANUAL REVIEW: CONTINUE
  INS-CLAIM-ADJUDIC: # MANUAL REVIEW: CONTINUE
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
  LOAN-GRACE-PERIOD-CALC: if True  # MANUAL REVIEW: WS-LATEORWS-DEFAULT:
  LOAN-GRACE-PERIOD-CALC: # MANUAL REVIEW: Nested IF
  LOAN-GRACE-PERIOD-CALC: # MANUAL REVIEW: Nested IF
  LOAN-GRACE-PERIOD-CALC: # MANUAL REVIEW: Nested IF
  LOAN-GRACE-PERIOD-CALC: # IF WS-LATEORWS-DEFAULT                         if True  # MANUAL REVIEW: WS-LATEORWS-DEFAULT  [FAI
  LOAN-PMI-REMOVAL: if True  # MANUAL REVIEW: WS-PMI-AUTO-REMOVEORWS-PMI-ELIGIBLE:
  LOAN-PMI-REMOVAL: # IF WS-PMI-AUTO-REMOVEORWS-PMI-ELIGIBLE         if True  # MANUAL REVIEW: WS-PMI-AUTO-REMOVEO  [FAI
  MISC-AUDIT-TRAIL: # MANUAL REVIEW: WRITEAUDIT-RECORD
  MISC-LETTER-GEN: # MANUAL REVIEW: UNSTRINGWS-FULL-NAMEDELIMITEDBY' 'INTOWS-FIRST-NAMEWS-LAST-N
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
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTERSERVICE-GOTOTOPROCEEDTOPRIMARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTERSERVICE-GOTOTOPROCEEDTOSECONDARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTERSERVICE-GOTOTOPROCEEDTOTERTIARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTER SERVICE-GOTO TO PROCEED TO PRIMARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTER SERVICE-GOTO TO PROCEED TO SECONDARY-SERVICE
  MR-ALTER-FALLBACK: # MANUAL REVIEW: ALTER SERVICE-GOTO TO PROCEED TO TERTIARY-SERVICE
  MR-ALTER-FALLBACK: # ALTER SERVICE-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-FALLBACK: # ALTER SERVICE-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-FALLBACK: # ALTER SERVICE-GOTO                             # MANUAL REVIEW                                [FAI
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTERERROR-HANDLERTOPROCEEDTOHANDLE-TIMEOUT
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTERERROR-HANDLERTOPROCEEDTOHANDLE-DATA-ERR
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTERERROR-HANDLERTOPROCEEDTOHANDLE-CONN-FAIL
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTER ERROR-HANDLER TO PROCEED TO HANDLE-TIMEOUT
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTER ERROR-HANDLER TO PROCEED TO HANDLE-DATA-ERR
  MR-ALTER-RECOVERY: # MANUAL REVIEW: ALTER ERROR-HANDLER TO PROCEED TO HANDLE-CONN-FAIL
  MR-ALTER-RECOVERY: # ALTER ERROR-HANDLER                            # MANUAL REVIEW                                [FAI
  MR-ALTER-RECOVERY: # ALTER ERROR-HANDLER                            # MANUAL REVIEW                                [FAI
  MR-ALTER-RECOVERY: # ALTER ERROR-HANDLER                            # MANUAL REVIEW                                [FAI
  MR-EXEC-SQL-UPDATE: # MANUAL REVIEW: Nested IF
  MR-EXEC-SQL-UPDATE: # MANUAL REVIEW: CONTINUE
  MR-ODO-INVOICE: if True  # MANUAL REVIEW: WS-IL-TAXABLE(WS-IDX):
  MR-ODO-INVOICE: # IF WS-IL-TAXABLE(WS-IDX)                       if True  # MANUAL REVIEW: WS-IL-TAXABLE(WS-ID  [FAI
  PAY-ADDENDA-PARSE: if True  # MANUAL REVIEW: WS-RETURNSORWS-PAYMENT-RELORWS-ADDENDA-CTX:
  PAY-LIMIT-ENFORCE: if True  # MANUAL REVIEW: WS-APPROVEDORWS-PENDING-REVIEW:
  PAY-LIMIT-ENFORCE: if True  # MANUAL REVIEW: WS-APPROVEDORWS-PENDING-REVIEW:
  PAY-LIMIT-ENFORCE: # IF WS-APPROVEDORWS-PENDING-REVIEW              if True  # MANUAL REVIEW: WS-APPROVEDORWS-PEN  [FAI
  PAY-LIMIT-ENFORCE: # IF WS-APPROVEDORWS-PENDING-REVIEW              if True  # MANUAL REVIEW: WS-APPROVEDORWS-PEN  [FAI
  PAY-NSF-FEE-CALC: # MANUAL REVIEW: Nested IF
  PAY-PRENOTE-VALID: if True  # MANUAL REVIEW: WS-ACCT-NUM(1:1)ISNUMERIC:
  PAY-SAME-DAY-ACH: if True  # MANUAL REVIEW: WS-CREDIT-TXNORWS-DEBIT-TXNORWS-PAYROLL-TXN:
  REG-CRA-GEOCODE: if True  # MANUAL REVIEW: WS-LOW-INCOMEORWS-MODERATE:
  REG-CRA-GEOCODE: # IF WS-LOW-INCOMEORWS-MODERATE                  if True  # MANUAL REVIEW: WS-LOW-INCOMEORWS-M  [FAI
  REG-HMDA-EXTRACT: # MANUAL REVIEW: CONTINUE
  REG-OFAC-MATCH: # MANUAL REVIEW: INSPECTWS-SDN-NAME(WS-SDN-IDX)TALLYINGWS-WORD-COUNTFORALLWS-
  REG-TIN-VALIDATOR: if True  # MANUAL REVIEW: WS-TIN-VALUEISNUMERIC:
  REG-TIN-VALIDATOR: # MANUAL REVIEW: INSPECTWS-TIN-VALUETALLYINGWS-DIGIT-COUNTFORALL'0'
  REG-TIN-VALIDATOR: # IF WS-TIN-VALUEISNUMERIC                       if True  # MANUAL REVIEW: WS-TIN-VALUEISNUMER  [FAI
  TAX-1099-INT-GEN: # MANUAL REVIEW: WRITETAX-RECORD
  TAX-W8BEN-VALID: # MANUAL REVIEW: UNSTRINGWS-BENE-NAMEDELIMITEDBY' 'INTOWS-FIRSTWS-LASTEND-UNS
  TAX-W8BEN-VALID: # MANUAL REVIEW: INSPECTWS-TIN-VALUETALLYINGWS-DASH-COUNTFORALL'-'
  TAX-W8BEN-VALID: # MANUAL REVIEW: INSPECTWS-TIN-VALUETALLYINGWS-SPACE-COUNTFORALL' '
  TRADE-TAX-LOT-CALC: if True  # MANUAL REVIEW: WS-LT-LONG(WS-LT-IDX):

==========================================================================================
  PVR = 82.5%  (165 clean / 200 tested)
==========================================================================================
