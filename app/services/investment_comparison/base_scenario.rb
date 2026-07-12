module InvestmentComparison
  class BaseScenario
    def initialize(params)
      @params = params
      @initial_capital = params[:initial_capital].to_f
      @monthly_savings = params[:monthly_savings].to_f
      @salary = params[:salary].to_f
      @salary_growth_rate = params[:salary_growth_rate].to_f / 100.0
      @tax_rate = params[:tax_rate].to_f / 100.0
      @timeframe = params[:timeframe].to_i
    end

    def calculate
      raise NotImplementedError
    end

    private

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

    def nab_eb_rate(loan_amount, base_rate_over_250k, small_loan_premium)
      if loan_amount >= 250_000
        base_rate_over_250k
      else
        base_rate_over_250k + small_loan_premium
      end
    end

    def compound_growth(value, annual_rate, years)
      value * (1 + annual_rate)**years
    end

    def annual_interest_paid(principal, annual_rate, term_years, year)
      return 0.0 if year > term_years
      r = annual_rate / 12.0
      monthly_payment = monthly_loan_repayment(principal, annual_rate, term_years)
      total_interest = 0.0

      start_month = (year - 1) * 12
      12.times do |i|
        month = start_month + i
        balance = remaining_loan_balance(principal, annual_rate, term_years, month)
        interest = balance * r
        total_interest += interest
      end

      total_interest
    end

    def salary_at_year(year)
      capped = [@salary * (1 + @salary_growth_rate)**(year - 1), 200_000].min
      capped
    end

    def format_snapshot(year:, asset_value:, loan_balance:, equity:, annual_income:, annual_costs:, tax_benefit:, cumulative_invested:)
      {
        year: year,
        asset_value: asset_value.round(0),
        loan_balance: loan_balance.round(0),
        equity: equity.round(0),
        annual_income: annual_income.round(0),
        annual_costs: annual_costs.round(0),
        tax_benefit: tax_benefit.round(0),
        net_cashflow: (annual_income - annual_costs + tax_benefit).round(0),
        cumulative_invested: cumulative_invested.round(0)
      }
    end
  end
end
