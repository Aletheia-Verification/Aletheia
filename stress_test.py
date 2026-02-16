"""
BRUTAL TEST SUITE
Edge cases that could actually break financial calculations
"""

from decimal import Decimal, getcontext
import converted_loan_interest as cobol

getcontext().prec = 31

def expected_cobol(principal, annual_rate, days_in_year, days_overdue,
                   grace_period, penalty_rate, max_penalty_pct,
                   rate_discount, is_vip):
    """Ground truth calculation."""
    principal = Decimal(str(principal))
    annual_rate = Decimal(str(annual_rate))
    days_in_year = Decimal(str(days_in_year))
    days_overdue = Decimal(str(days_overdue))
    grace_period = Decimal(str(grace_period))
    penalty_rate = Decimal(str(penalty_rate))
    max_penalty_pct = Decimal(str(max_penalty_pct))
    rate_discount = Decimal(str(rate_discount))
    
    daily_rate = annual_rate / days_in_year
    
    if is_vip:
        daily_rate = daily_rate - rate_discount
        if daily_rate < 0:
            daily_rate = Decimal('0')
    
    temp_amount = principal * daily_rate
    daily_interest = Decimal(int(temp_amount * 100)) / Decimal('100')
    
    if days_overdue > grace_period:
        penalty_amount = principal * penalty_rate * (days_overdue - grace_period)
        temp_amount = principal * max_penalty_pct
        if penalty_amount > temp_amount:
            penalty_amount = temp_amount
        if is_vip:
            penalty_amount = penalty_amount * Decimal('0.5')
    else:
        penalty_amount = Decimal('0')
    
    return daily_rate, daily_interest, penalty_amount

def run_python(principal, annual_rate, days_in_year, days_overdue,
               grace_period, penalty_rate, max_penalty_pct,
               rate_discount, is_vip):
    """Run converted Python."""
    cobol.ws_principal_bal = Decimal(str(principal))
    cobol.ws_annual_rate = Decimal(str(annual_rate))
    cobol.ws_days_in_year = Decimal(str(days_in_year))
    cobol.ws_days_overdue = Decimal(str(days_overdue))
    cobol.ws_grace_period = Decimal(str(grace_period))
    cobol.ws_penalty_rate = Decimal(str(penalty_rate))
    cobol.ws_max_penalty_pct = Decimal(str(max_penalty_pct))
    cobol.ws_rate_discount = Decimal(str(rate_discount))
    cobol.ws_vip_flag = "Y" if is_vip else "N"
    
    cobol.para_1000_init_calculation()
    cobol.para_2000_compute_daily_rate()
    cobol.para_3000_apply_vip_discount()
    cobol.para_4000_calculate_interest()
    cobol.para_5000_check_late_penalty()
    
    return cobol.ws_daily_rate, cobol.ws_daily_interest, cobol.ws_penalty_amount

# BRUTAL TEST CASES - designed to break things
BRUTAL_CASES = [
    # ===== PRECISION NIGHTMARES =====
    {
        "name": "Repeating decimal (1/3 rate)",
        "inputs": {"principal": 100000, "annual_rate": 0.333333333333, "days_in_year": 365,
                   "days_overdue": 45, "grace_period": 15, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.0001, "is_vip": False}
    },
    {
        "name": "Pi-based rate",
        "inputs": {"principal": 314159.26, "annual_rate": 0.0314159265359, "days_in_year": 365,
                   "days_overdue": 31, "grace_period": 14, "penalty_rate": 0.00314,
                   "max_penalty_pct": 0.0314, "rate_discount": 0.00159, "is_vip": True}
    },
    {
        "name": "Maximum precision stress",
        "inputs": {"principal": 123456789.12, "annual_rate": 0.123456789012, "days_in_year": 365,
                   "days_overdue": 123, "grace_period": 12, "penalty_rate": 0.0123,
                   "max_penalty_pct": 0.09, "rate_discount": 0.00123, "is_vip": True}
    },
    
    # ===== BOUNDARY CONDITIONS =====
    {
        "name": "One cent principal",
        "inputs": {"principal": 0.01, "annual_rate": 0.25, "days_in_year": 365,
                   "days_overdue": 100, "grace_period": 10, "penalty_rate": 0.01,
                   "max_penalty_pct": 0.10, "rate_discount": 0.001, "is_vip": False}
    },
    {
        "name": "Billion dollar principal",
        "inputs": {"principal": 1000000000.00, "annual_rate": 0.001, "days_in_year": 360,
                   "days_overdue": 1, "grace_period": 0, "penalty_rate": 0.0001,
                   "max_penalty_pct": 0.001, "rate_discount": 0.0001, "is_vip": True}
    },
    {
        "name": "Days overdue exactly equals grace period",
        "inputs": {"principal": 50000, "annual_rate": 0.05, "days_in_year": 365,
                   "days_overdue": 15, "grace_period": 15, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.001, "is_vip": False}
    },
    {
        "name": "Days overdue is grace period + 1",
        "inputs": {"principal": 50000, "annual_rate": 0.05, "days_in_year": 365,
                   "days_overdue": 16, "grace_period": 15, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.001, "is_vip": False}
    },
    {
        "name": "Zero days overdue",
        "inputs": {"principal": 50000, "annual_rate": 0.05, "days_in_year": 365,
                   "days_overdue": 0, "grace_period": 15, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.001, "is_vip": True}
    },
    
    # ===== PENALTY CAP SCENARIOS =====
    {
        "name": "Penalty exactly at cap",
        "inputs": {"principal": 100000, "annual_rate": 0.10, "days_in_year": 365,
                   "days_overdue": 60, "grace_period": 10, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.001, "is_vip": False}
    },
    {
        "name": "Penalty way over cap",
        "inputs": {"principal": 100000, "annual_rate": 0.10, "days_in_year": 365,
                   "days_overdue": 365, "grace_period": 5, "penalty_rate": 0.01,
                   "max_penalty_pct": 0.02, "rate_discount": 0.001, "is_vip": False}
    },
    {
        "name": "Penalty just under cap",
        "inputs": {"principal": 100000, "annual_rate": 0.10, "days_in_year": 365,
                   "days_overdue": 20, "grace_period": 10, "penalty_rate": 0.0004,
                   "max_penalty_pct": 0.05, "rate_discount": 0.001, "is_vip": False}
    },
    
    # ===== VIP DISCOUNT EDGE CASES =====
    {
        "name": "VIP discount larger than daily rate (should floor to 0)",
        "inputs": {"principal": 100000, "annual_rate": 0.00365, "days_in_year": 365,
                   "days_overdue": 30, "grace_period": 15, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.01, "is_vip": True}
    },
    {
        "name": "VIP discount exactly equals daily rate",
        "inputs": {"principal": 100000, "annual_rate": 0.0365, "days_in_year": 365,
                   "days_overdue": 30, "grace_period": 15, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.0001, "is_vip": True}
    },
    {
        "name": "VIP with penalty cap hit",
        "inputs": {"principal": 500000, "annual_rate": 0.08, "days_in_year": 360,
                   "days_overdue": 180, "grace_period": 10, "penalty_rate": 0.005,
                   "max_penalty_pct": 0.03, "rate_discount": 0.002, "is_vip": True}
    },
    
    # ===== TRUNCATION vs ROUNDING =====
    {
        "name": "Interest that would round UP (but must truncate)",
        "inputs": {"principal": 33333.33, "annual_rate": 0.06, "days_in_year": 365,
                   "days_overdue": 10, "grace_period": 15, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.001, "is_vip": False}
    },
    {
        "name": "Interest at .XX5 boundary",
        "inputs": {"principal": 10000.00, "annual_rate": 0.0365, "days_in_year": 365,
                   "days_overdue": 5, "grace_period": 10, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.0001, "is_vip": False}
    },
    {
        "name": "Interest at .XX9 boundary",
        "inputs": {"principal": 99999.99, "annual_rate": 0.0999, "days_in_year": 365,
                   "days_overdue": 0, "grace_period": 10, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.001, "is_vip": False}
    },
    
    # ===== LEAP YEAR / DAY COUNT =====
    {
        "name": "360-day year (banking convention)",
        "inputs": {"principal": 100000, "annual_rate": 0.06, "days_in_year": 360,
                   "days_overdue": 30, "grace_period": 15, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.001, "is_vip": False}
    },
    {
        "name": "366-day year (leap year)",
        "inputs": {"principal": 100000, "annual_rate": 0.06, "days_in_year": 366,
                   "days_overdue": 30, "grace_period": 15, "penalty_rate": 0.001,
                   "max_penalty_pct": 0.05, "rate_discount": 0.001, "is_vip": False}
    },
    
    # ===== EXTREME COMBINATIONS =====
    {
        "name": "Everything at maximum",
        "inputs": {"principal": 9999999999.99, "annual_rate": 0.99, "days_in_year": 360,
                   "days_overdue": 999, "grace_period": 1, "penalty_rate": 0.99,
                   "max_penalty_pct": 0.99, "rate_discount": 0.001, "is_vip": True}
    },
    {
        "name": "Everything at minimum",
        "inputs": {"principal": 0.01, "annual_rate": 0.0001, "days_in_year": 366,
                   "days_overdue": 1, "grace_period": 0, "penalty_rate": 0.0001,
                   "max_penalty_pct": 0.01, "rate_discount": 0.0001, "is_vip": False}
    },
]

def run_brutal_tests():
    """Run all brutal test cases."""
    print("=" * 70)
    print("BRUTAL TEST SUITE - EDGE CASES THAT BREAK FINANCIAL SYSTEMS")
    print("=" * 70)
    print()
    
    passed = 0
    failed = 0
    
    for tc in BRUTAL_CASES:
        expected = expected_cobol(**tc["inputs"])
        actual = run_python(**tc["inputs"])
        
        if expected == actual:
            print(f"✅ PASS: {tc['name']}")
            passed += 1
        else:
            print(f"❌ FAIL: {tc['name']}")
            print(f"   Expected: {expected}")
            print(f"   Actual:   {actual}")
            failed += 1
    
    print()
    print("=" * 70)
    print(f"RESULTS: {passed}/{len(BRUTAL_CASES)} PASSED")
    if failed == 0:
        print("🎯 ALL BRUTAL TESTS PASSED - ENGINE IS A TANK")
    else:
        print(f"⚠️  {failed} FAILURES - NEEDS FIXING")
    print("=" * 70)

if __name__ == "__main__":
    run_brutal_tests()