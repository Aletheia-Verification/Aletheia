# Stabilization Report — 2026-03-20

## Test Suite Summary

| Metric | Value |
|--------|-------|
| **Test files executed** | 57 + semantic_corpus (58 total) |
| **Total tests collected** | 1076 |
| **Passed** | 1057 |
| **Failed** | 19 |
| **New regressions** | 0 |
| **Run time** | ~12 min |

## PVR (Viability Experiment)

| Metric | Value |
|--------|-------|
| Programs tested | 200 |
| Parse success | 199/200 (99.5%) |
| Generate success | 200/200 (100.0%) |
| Compile success | 199/200 (99.5%) |
| Clean (0 MR) | 192/200 (96.0%) |
| **PVR** | **96.0%** |

## Every Failing Test (all 19 pre-existing)

### test_core_logic.py (14 failures)

All caused by core_logic.py divergence from test expectations (decimal precision 31 vs 28, auth/registration endpoint changes):

| # | Test Name | Root Cause |
|---|-----------|------------|
| 1 | `TestDecimalContext::test_precision_is_28` | Decimal prec=31, test expects 28 |
| 2 | `TestHeartbeat::test_heartbeat_returns_operational` | decimal_context.precision=31 vs 28 |
| 3 | `TestHealth::test_health_returns_online` | decimal_precision="31" vs "28" |
| 4 | `TestTokenVerificationPrecision::test_unknown_subject_returns_specific_message` | Auth endpoint mismatch |
| 5 | `TestNormalizedTokenSubject::test_mixed_case_login_produces_usable_token` | Auth endpoint mismatch |
| 6 | `TestApproveRequiresAuth::test_approve_with_token_succeeds` | Auth endpoint mismatch |
| 7 | `TestRegistration::test_register_new_user` | Registration endpoint mismatch |
| 8 | `TestRegistration::test_register_duplicate_rejected` | Registration endpoint mismatch |
| 9 | `TestLogin::test_login_valid_credentials` | Login endpoint mismatch |
| 10 | `TestLogin::test_login_wrong_password` | Login endpoint mismatch |
| 11 | `TestAuthorization::test_analyze_allows_any_authenticated_user` | Auth flow mismatch |
| 12 | `TestAnalyzeOffline::test_extraction_returns_stub_with_string_score` | Stub shape changed |
| 13 | `TestAnalyticsDashboard::test_analytics_shape` | Dashboard shape changed |

### test_cli_verify.py (1 failure)

| # | Test Name | Root Cause |
|---|-----------|------------|
| 14 | `TestVerifyCommand::test_verify_auto_layout_exit_0` | Drift on COMPOUND-FACTOR field (15/100 records) — auto-layout field alignment issue |

### test_layout_generator.py (1 failure)

| # | Test Name | Root Cause |
|---|-----------|------------|
| 15 | `TestGenerateLayout::test_full_layout_matches_demo_inputs` | Auto-generated fields don't match manual loan_layout.json (field ordering/naming) |

### test_license.py (2 failures)

| # | Test Name | Root Cause |
|---|-----------|------------|
| 16 | `TestLicenseManager::test_valid_license` | asyncio.run() call issue |
| 17 | `TestLicenseManager::test_expired_license` | asyncio.run() call issue |

### semantic_corpus (1 failure)

| # | Test Name | Root Cause |
|---|-----------|------------|
| 18-19 | `test_corpus_entry[string/initialize_mixed]` | INITIALIZE on mixed group: expected '' got ' ' (space vs empty) |

## Pre-existing Verification

All 19 failures were verified pre-existing by running `git stash` (reverting to commit `64e0b4d`) and re-running the failing tests — identical failures occurred without any of the PIC edited changes.

## New Tests Added (this session)

| File | Tests | Status |
|------|-------|--------|
| test_pic_edited.py | 53 | 53/53 PASSED |

Covers: PIC detection (13), pattern expansion (5), display formatting (19), numeric extraction (11), Shadow Diff comparison (6).

## Conclusion

- **Zero regressions introduced** by the numeric edited PIC feature
- **PVR stable at 96.0%**
- 19 pre-existing failures need attention in a separate stabilization pass (13 are auth/precision changes in core_logic.py tests)
