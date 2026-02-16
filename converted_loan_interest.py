"""
Auto-generated Python from COBOL
Paragraphs: 7
Variables: 20
COMP-3 fields: 10
"""

from decimal import Decimal, ROUND_DOWN, ROUND_HALF_UP, getcontext

# Set precision to match IBM COBOL ARITH(EXTEND)
getcontext().prec = 31

# ============================================================
# WORKING-STORAGE VARIABLES
# ============================================================

ws_account_data = Decimal('0')
ws_account_num = Decimal('0')
ws_principal_bal = Decimal('0.00')
ws_annual_rate = Decimal('0.000000')
ws_days_in_year = Decimal('0')
ws_accrued_int = Decimal('0.00')
ws_penalty_rate = Decimal('0.0000')
ws_calc_fields = Decimal('0')
ws_daily_rate = Decimal('0.00000000')
ws_daily_interest = Decimal('0.00')
ws_compound_factor = Decimal('0.000000')
ws_temp_amount = Decimal('0.0000')
ws_penalty_data = Decimal('0')
ws_days_overdue = Decimal('0')
ws_penalty_amount = Decimal('0.00')
ws_grace_period = Decimal('0')
ws_max_penalty_pct = Decimal('0.00')
ws_account_flags = Decimal('0')
ws_vip_flag = "N"
ws_rate_discount = Decimal('0.0000')

# ============================================================
# PROCEDURE DIVISION
# ============================================================

def para_0000_main_process():
    """COBOL Paragraph: 0000-MAIN-PROCESS"""
    para_1000_init_calculation()
    para_2000_compute_daily_rate()
    para_3000_apply_vip_discount()
    para_4000_calculate_interest()
    para_5000_check_late_penalty()
    para_6000_finalize_amount()

def para_1000_init_calculation():
    """COBOL Paragraph: 1000-INIT-CALCULATION"""
    global ws_rate_discount, ws_vip_flag
    
    if ws_vip_flag != "Y":
        ws_rate_discount = Decimal('0')

def para_2000_compute_daily_rate():
    """COBOL Paragraph: 2000-COMPUTE-DAILY-RATE"""
    global ws_daily_rate, ws_annual_rate, ws_days_in_year
    
    ws_daily_rate = ws_annual_rate / ws_days_in_year

def para_3000_apply_vip_discount():
    """COBOL Paragraph: 3000-APPLY-VIP-DISCOUNT"""
    global ws_daily_rate, ws_rate_discount, ws_vip_flag
    
    if ws_vip_flag == "Y":
        ws_daily_rate = ws_daily_rate - ws_rate_discount
        if ws_daily_rate < 0:
            ws_daily_rate = Decimal('0')

def para_4000_calculate_interest():
    """COBOL Paragraph: 4000-CALCULATE-INTEREST"""
    global ws_temp_amount, ws_daily_interest, ws_principal_bal, ws_daily_rate
    
    ws_temp_amount = ws_principal_bal * ws_daily_rate
    ws_daily_interest = Decimal(int(ws_temp_amount * Decimal('100'))) / Decimal('100')

def para_5000_check_late_penalty():
    """COBOL Paragraph: 5000-CHECK-LATE-PENALTY"""
    global ws_penalty_amount, ws_temp_amount, ws_principal_bal, ws_penalty_rate
    global ws_days_overdue, ws_grace_period, ws_max_penalty_pct, ws_vip_flag
    
    if ws_days_overdue > ws_grace_period:
        ws_penalty_amount = ws_principal_bal * ws_penalty_rate * (ws_days_overdue - ws_grace_period)
        ws_temp_amount = ws_principal_bal * ws_max_penalty_pct
        if ws_penalty_amount > ws_temp_amount:
            ws_penalty_amount = ws_temp_amount
        if ws_vip_flag == "Y":
            ws_penalty_amount = ws_penalty_amount * Decimal('0.5')
    else:
        ws_penalty_amount = Decimal('0')

def para_6000_finalize_amount():
    """COBOL Paragraph: 6000-FINALIZE-AMOUNT"""
    global ws_accrued_int, ws_daily_interest, ws_penalty_amount
    
    ws_accrued_int = ws_daily_interest + ws_penalty_amount

# ============================================================
# MAIN EXECUTION
# ============================================================

def main():
    para_1000_init_calculation()
    para_2000_compute_daily_rate()
    para_3000_apply_vip_discount()
    para_4000_calculate_interest()
    para_5000_check_late_penalty()
    para_6000_finalize_amount()


if __name__ == "__main__":
    main()