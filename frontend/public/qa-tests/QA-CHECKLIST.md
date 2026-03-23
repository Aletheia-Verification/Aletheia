# Aletheia QA Checklist

## Analyze Page
- [ ] 01-basic-arithmetic.cbl → VERIFIED
- [ ] 02-manual-review-alter.cbl → MANUAL REVIEW (ALTER)
- [ ] 03-comp3-packed.cbl → VERIFIED (COMP-3 detected)
- [ ] 04-ebcdic-compare.cbl → VERIFIED (ebcdic_compare used)
- [ ] 05-perform-varying.cbl → VERIFIED
- [ ] 06-evaluate.cbl → VERIFIED
- [ ] 07-string-pointer.cbl → VERIFIED (STRING with POINTER)
- [ ] 08-level88.cbl → VERIFIED (88-level SET/IF)
- [ ] 09-redefines.cbl → VERIFIED (REDEFINES + refmod)
- [ ] 10-dead-code.cbl → use on Dead Code page
- [ ] 11-copybook-test.cbl + CUSTBOOK.cpy → VERIFIED

## Verify Page
- [ ] verify-source.cbl + verify-mainframe.txt + verify-migrated-match.txt → all fields match
- [ ] verify-source.cbl + verify-mainframe.txt + verify-migrated-drift.txt → drift detected

## Portfolio
- [ ] Upload portfolio-01/02/03 → 2 VERIFIED, 1 MR

## Dead Code
- [ ] 10-dead-code.cbl → 2000-ORPHAN + 3000-ALSO-ORPHAN flagged

## Compiler Matrix
- [ ] 03-comp3-packed.cbl → shows TRUNC/ARITH options

## SBOM
- [ ] After analysis → shows CycloneDX output

## JCL
- [ ] test-job.jcl → shows STEP01→STEP02 DAG

## Trace
- [ ] After VERIFIED analysis → shows execution steps

## Dashboard
- [ ] Shows stats from your testing session

## Reports
- [ ] Shows list of past verifications

## Dark Mode
- [ ] Toggle dark mode → all pages consistent

## Mobile
- [ ] Narrow browser → hamburger menu works

## No files modified. Just test data created.
