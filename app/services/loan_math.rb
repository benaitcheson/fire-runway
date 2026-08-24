# Pure amortisation and growth math shared by the investment comparison
# scenarios and the loan tax simulator. Rates are decimals (0.06, not 6).
module LoanMath
  module_function

  def monthly_loan_repayment(principal, annual_rate, term_years)
    return 0.0 if principal <= 0 || term_years <= 0
    r = annual_rate / 12.0
    n = term_years * 12
    principal * (r * (1 + r)**n) / ((1 + r)**n - 1)
  end

  def remaining_loan_balance(principal, annual_rate, term_years, months_elapsed)
    return 0.0 if months_elapsed >= term_years * 12
    r = annual_rate / 12.0
    n = term_years * 12
    factor = (1 + r)**n
    elapsed_factor = (1 + r)**months_elapsed
    principal * (factor - elapsed_factor) / (factor - 1)
  end

  def compound_growth(value, annual_rate, years)
    value * (1 + annual_rate)**years
  end

  def annual_interest_paid(principal, annual_rate, term_years, year)
    return 0.0 if year > term_years
    r = annual_rate / 12.0
    total_interest = 0.0

    start_month = (year - 1) * 12
    12.times do |i|
      month = start_month + i
      balance = remaining_loan_balance(principal, annual_rate, term_years, month)
      total_interest += balance * r
    end

    total_interest
  end
end
