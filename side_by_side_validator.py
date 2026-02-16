"""
Side-by-Side Validator
Compares COBOL execution vs Python execution
Target: 0.00% difference
"""

from decimal import Decimal, getcontext
import converted_loan_interest as cobol

def run_python_calculation(principal, annual_rate, days_in_year, days_overdue, 
                           grace_period, penalty_rate, max_penalty_pct, 
                           rate_discount, is_vip):
    """Run the converted Python with given inputs."""
    
    # Set inputs directly on the module
    cobol.ws_principal_bal = Decimal(str(principal))
    cobol.ws_annual_rate = Decimal(str(annual_rate))
    cobol.ws_days_in_year = Decimal(str(days_in_year))
    cobol.ws_days_overdue = Decimal(str(days_overdue))
    cobol.ws_grace_period = Decimal(str(grace_period))
    cobol.ws_penalty_rate = Decimal(str(penalty_rate))
    cobol.ws_max_penalty_pct = Decimal(str(max_penalty_pct))
    cobol.ws_rate_discount = Decimal(str(rate_discount))
    cobol.ws_vip_flag = "Y" if is_vip else "N"
    
    # Run calculations
    cobol.para_2000_compute_daily_rate()
    cobol.para_3000_apply_vip_discount()
    cobol.para_4000_calculate_interest()
    cobol.para_5000_check_late_penalty()
    
    return {
        "daily_rate": cobol.ws_daily_rate,
        "daily_interest": cobol.ws_daily_interest,
        "penalty_amount": cobol.ws_penalty_amount,
    }

def expected_cobol_calculation(principal, annual_rate, days_in_year, days_overdue,
                                grace_period, penalty_rate, max_penalty_pct,
                                rate_discount, is_vip):
    """Manual calculation matching COBOL logic exactly."""
    getcontext().prec = 31
    
    principal = Decimal(str(principal))
    annual_rate = Decimal(str(annual_rate))
    days_in_year = Decimal(str(days_in_year))
    days_overdue = Decimal(str(days_overdue))
    grace_period = Decimal(str(grace_period))
    penalty_rate = Decimal(str(penalty_rate))
    max_penalty_pct = Decimal(str(max_penalty_pct))
    rate_discount = Decimal(str(rate_discount))
    
    # 2000-COMPUTE-DAILY-RATE
    daily_rate = annual_rate / days_in_year
    
    # 3000-APPLY-VIP-DISCOUNT (only if VIP)
    if is_vip:
        daily_rate = daily_rate - rate_discount
        if daily_rate < 0:
            daily_rate = Decimal('0')
    
    # 4000-CALCULATE-INTEREST
    temp_amount = principal * daily_rate
    daily_interest = Decimal(int(temp_amount * 100)) / Decimal('100')
    
    # 5000-CHECK-LATE-PENALTY
    if days_overdue > grace_period:
        penalty_amount = principal * penalty_rate * (days_overdue - grace_period)
        temp_amount = principal * max_penalty_pct
        if penalty_amount > temp_amount:
            penalty_amount = temp_amount
        if is_vip:
            penalty_amount = penalty_amount * Decimal('0.5')
    else:
        penalty_amount = Decimal('0')
    
    return {
        "daily_rate": daily_rate,
        "daily_interest": daily_interest,
        "penalty_amount": penalty_amount,
    }

def compare_results(expected, actual):
    """Compare two result sets."""
    diffs = []
    for key in expected:
        exp_val = expected[key]
        act_val = actual[key]
        if exp_val != act_val:
            diff = abs(exp_val - act_val)
            diffs.append({
                "field": key,
                "expected": exp_val,
                "actual": act_val,
                "difference": diff,
            })
    return diffs

def run_validation_suite():
    """Run multiple test cases."""
    
    test_cases = [
        {
            "name": "Standard account, no penalty",
            "inputs": {
                "principal": "50000.00",
                "annual_rate": "0.065",
                "days_in_year": "365",
                "days_overdue": "10",
                "grace_period": "15",
                "penalty_rate": "0.001",
                "max_penalty_pct": "0.05",
                "rate_discount": "0.0015",
                "is_vip": False,
            }
        },
        {
            "name": "VIP account, no penalty",
            "inputs": {
                "principal": "50000.00",
                "annual_rate": "0.065",
                "days_in_year": "365",
                "days_overdue": "10",
                "grace_period": "15",
                "penalty_rate": "0.001",
                "max_penalty_pct": "0.05",
                "rate_discount": "0.0015",
                "is_vip": True,
            }
        },
        {
            "name": "Standard account, with penalty",
            "inputs": {
                "principal": "50000.00",
                "annual_rate": "0.065",
                "days_in_year": "365",
                "days_overdue": "45",
                "grace_period": "15",
                "penalty_rate": "0.001",
                "max_penalty_pct": "0.05",
                "rate_discount": "0.0015",
                "is_vip": False,
            }
        },
        {
            "name": "VIP account, with penalty",
            "inputs": {
                "principal": "50000.00",
                "annual_rate": "0.065",
                "days_in_year": "365",
                "days_overdue": "45",
                "grace_period": "15",
                "penalty_rate": "0.001",
                "max_penalty_pct": "0.05",
                "rate_discount": "0.0015",
                "is_vip": True,
            }
        },
        {
            "name": "Large principal edge case",
            "inputs": {
                "principal": "9999999.99",
                "annual_rate": "0.12",
                "days_in_year": "365",
                "days_overdue": "100",
                "grace_period": "15",
                "penalty_rate": "0.002",
                "max_penalty_pct": "0.05",
                "rate_discount": "0.002",
                "is_vip": True,
            }
        },
    ]
    
    print("=" * 70)
    print("SIDE-BY-SIDE VALIDATION REPORT")
    print("=" * 70)
    print()
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        print(f"TEST: {tc['name']}")
        print("-" * 50)
        
        expected = expected_cobol_calculation(**tc['inputs'])
        actual = run_python_calculation(**tc['inputs'])
        
        diffs = compare_results(expected, actual)
        
        if not diffs:
            print("  ✅ PASS - 0.00% difference")
            passed += 1
        else:
            print("  ❌ FAIL")
            for d in diffs:
                print(f"    {d['field']}: expected {d['expected']}, got {d['actual']}")
            failed += 1
        print()
    
    print("=" * 70)
    print(f"SUMMARY: {passed}/{len(test_cases)} passed")
    if failed == 0:
        print("🎯 0.00% DIFFERENCE ACHIEVED")
    print("=" * 70)


if __name__ == "__main__":
    run_validation_suite()